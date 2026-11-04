import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_theme.dart';
import '../../utils/file_downloader.dart';
import 'focal_evaluation_submitted_screen.dart';

class FocalMidtermReviewScreen extends StatefulWidget {
  final Map<String, dynamic> learner;

  const FocalMidtermReviewScreen({Key? key, required this.learner}) : super(key: key);

  @override
  State<FocalMidtermReviewScreen> createState() => _FocalMidtermReviewScreenState();
}

class _FocalMidtermReviewScreenState extends State<FocalMidtermReviewScreen> {
  final TextEditingController _remarksController = TextEditingController(
    text: 'Assessment passed, handwriting and basic Urdu numeracy skills verified. Authorized to proceed to Week 7.',
  );
  bool _isSubmitting = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  void _handleDownloadPdf(String? fileUrl, String fileName) async {
    if (fileUrl == null || fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No PDF file attached to this submission.')),
      );
      return;
    }

    try {
      AppTheme.showInfoSnackBar(
        context,
        'Downloading "$fileName" to audit...',
        isLoading: true,
      );

      final success = await downloadFileToDevice(
        url: fileUrl,
        fileName: fileName.endsWith('.pdf') ? fileName : '$fileName.pdf',
      );

      if (mounted) {
        AppTheme.showSuccessSnackBar(
          context,
          success ? '"$fileName" downloaded for inspection.' : 'File opened in browser.',
        );
      }
    } catch (e) {
      if (mounted) {
        // Fallback directly launch URL in browser
        final uri = Uri.parse(fileUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          AppTheme.showErrorSnackBar(context, 'Could not open file: $e');
        }
      }
    }
  }

  void _handleSubmitDecision() async {
    final String remarks = _remarksController.text.trim();
    if (remarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter official remarks before submitting.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final String learnerId = widget.learner['id'] ?? '';
      final String teacherId = widget.learner['teacherId'] ?? widget.learner['assignedTeacherId'] ?? '';
      final String learnerName = widget.learner['name'] ?? 'Learner';

      // 1. Commit approval to Firestore learners collection
      await FirebaseFirestore.instance.collection('learners').doc(learnerId).update({
        'midtermStatus': 'approved',
        'status': 'Active', // Allow normal class logging to continue
        'midtermRemarks': remarks,
        'midtermApprovedAt': FieldValue.serverTimestamp(),
      });

      // 2. Commit audit notification for Teacher
      if (teacherId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('notifications').add({
            'recipientId': teacherId,
            'title': 'Mid-Term Assessment Approved',
            'body': 'Focal Officer evaluated $learnerName: "$remarks"',
            'createdAt': FieldValue.serverTimestamp(),
            'type': 'midterm_approved',
            'read': false,
          });
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        // Navigate to Image 5 confirmation screen!
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FocalEvaluationSubmittedScreen(learner: widget.learner),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting evaluation: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String learnerName = widget.learner['name'] ?? 'Usman Ahmed';
    final String teacherName = widget.learner['teacherName'] ?? widget.learner['assignedTeacherName'] ?? 'Ali Khan';
    final String midtermFileName = widget.learner['midtermFileName'] ?? '${learnerName.replaceAll(" ", "_")}_MidTerm_Exam.pdf';
    final String? midtermUrl = widget.learner['midtermPaperUrl'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Review Assessment',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Metadata Header Card matching 1 (9).png
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Date: April 16,',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              '2026',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        // Dark Pill Badge labeled 'Mid Term' with lime text
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Mid Term',
                            style: TextStyle(
                              color: Color(0xFFCCFF00),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Learner: $learnerName',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Teacher: $teacherName',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Section: Submitted Mid-Assessment
              const Text(
                'Submitted Mid-Assessment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),

              // File Download Card matching 1 (9).png
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    // PDF Icon Badge
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECEB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.picture_as_pdf, color: Color(0xFFD32F2F), size: 24),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            midtermFileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Size: 1.2 MB',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Lime Download Button matching 1 (9).png
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCCFF00),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () => _handleDownloadPdf(midtermUrl, midtermFileName),
                      child: const Text(
                        'Download',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Section: Focal Person Remarks
              const Text(
                'Focal Person Remarks',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),

              // Multiline Remarks Text Area matching 1 (9).png
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _remarksController,
                  maxLines: 6,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Type remarks here (e.g., Assessment passed, proceed to Week 7)...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Lime Submit Decision Button matching 1 (9).png
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCCFF00),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _handleSubmitDecision,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                        )
                      : const Text(
                          'Submit Decision',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
