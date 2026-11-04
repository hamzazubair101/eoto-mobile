import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';
import '../controllers/registration_controller.dart';
import '../services/azure_storage_service.dart';
import '../utils/file_downloader.dart';
import 'midterm_submitted_screen.dart';

class MidtermAssessmentScreen extends StatefulWidget {
  final Map<String, dynamic> learner;

  const MidtermAssessmentScreen({Key? key, required this.learner}) : super(key: key);

  @override
  State<MidtermAssessmentScreen> createState() => _MidtermAssessmentScreenState();
}

class _MidtermAssessmentScreenState extends State<MidtermAssessmentScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedFile;
  bool _isUploading = false;

  // Official master midterm template from Super Admin
  String _officialDocTitle = 'NCHD_MidTerm_Level1.pdf';
  String? _officialDocDownloadUrl;
  bool _isLoadingOfficialDoc = true;

  @override
  void initState() {
    super.initState();
    _fetchOfficialMidtermTemplate();
  }

  void _fetchOfficialMidtermTemplate() async {
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('curriculum')
          .doc('official_midterm_assessment')
          .get();

      if (docSnap.exists && docSnap.data() != null) {
        final data = docSnap.data()!;
        if (mounted) {
          setState(() {
            _officialDocTitle = data['title'] ?? data['name'] ?? _officialDocTitle;
            _officialDocDownloadUrl = data['downloadUrl'];
            _isLoadingOfficialDoc = false;
          });
        }
        return;
      }

      // Fallback search in curriculum
      final querySnap = await FirebaseFirestore.instance
          .collection('curriculum')
          .where('cat', isEqualTo: 'Assessment Sheet')
          .get();

      for (var d in querySnap.docs) {
        final dData = d.data();
        final title = (dData['title'] ?? '').toString().toLowerCase();
        if (title.contains('midterm') || dData['assessmentType'] == 'midterm') {
          if (mounted) {
            setState(() {
              _officialDocTitle = dData['title'] ?? _officialDocTitle;
              _officialDocDownloadUrl = dData['downloadUrl'];
              _isLoadingOfficialDoc = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching official midterm template: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingOfficialDoc = false);
      }
    }
  }

  void _downloadOfficialPdf() async {
    if (_officialDocDownloadUrl == null || _officialDocDownloadUrl!.isEmpty) {
      // In development or if not yet set in curriculum, provide direct feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading "$_officialDocTitle"...'),
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    try {
      AppTheme.showInfoSnackBar(
        context,
        'Downloading "$_officialDocTitle" to your device...',
        isLoading: true,
      );

      final cleanName = _officialDocTitle.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
      final success = await downloadFileToDevice(
        url: _officialDocDownloadUrl!,
        fileName: cleanName.endsWith('.pdf') ? cleanName : '$cleanName.pdf',
      );

      if (mounted) {
        AppTheme.showSuccessSnackBar(
          context,
          success
              ? '"$_officialDocTitle" downloaded directly to your device!'
              : 'Download started in your device downloads.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorSnackBar(
          context,
          'Could not download document: $e',
        );
      }
    }
  }

  void _handlePickFile() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file != null) {
        setState(() {
          _selectedFile = file;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select file: $e')),
      );
    }
  }

  void _handleSubmit() async {
    if (_selectedFile == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final List<int> uploadBytes = await _selectedFile!.readAsBytes();
      final String learnerId = widget.learner['id']?.toString() ?? 'unknown';
      final String learnerName = widget.learner['name'] ?? 'Learner';

      // Upload file to Azure Blob Storage
      final String? azureUrl = await AzureStorageService.uploadMidtermAssessmentBytes(
        bytes: uploadBytes,
        learnerId: learnerId,
        fileName: _selectedFile!.name,
      );

      final String finalPaperUrl = azureUrl ?? 'https://eotostorage.blob.core.windows.net/assessments/${learnerName}_MidTerm_Solved.pdf';

      // Update Firestore document with midterm submission details
      await FirebaseFirestore.instance
          .collection('learners')
          .doc(learnerId)
          .update({
        'midtermPaperUrl': finalPaperUrl,
        'midtermStatus': 'submitted',
        'status': 'Awaiting Mid-Term Review',
        'midtermUploadedAt': FieldValue.serverTimestamp(),
        'midtermFileName': '${learnerName.replaceAll(" ", "_")}_MidTerm_Solved.pdf',
      });

      // Also notify local controller to ensure state consistency
      if (mounted) {
        Provider.of<RegistrationController>(context, listen: false)
            .uploadMidterm(learnerId);

        setState(() {
          _isUploading = false;
        });

        // Navigate directly to Image 6 confirmation screen!
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MidtermSubmittedScreen(learner: widget.learner),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String learnerName = widget.learner['name'] ?? 'Usman';
    final String defaultSelectedFileName = '${learnerName.replaceAll(" ", "_")}_MidTerm_Solved.pdf';
    final String selectedFileName = _selectedFile != null ? _selectedFile!.name : defaultSelectedFileName;

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
          'Mid-term Assessment',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          // Language chip matching 1 (6).png
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.language, size: 14, color: Colors.black87),
                SizedBox(width: 4),
                Text(
                  'EN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions Card matching 1 (6).png
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.grey[700],
                          child: const Icon(Icons.info_outline, color: Colors.white, size: 13),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Instructions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildInstructionRow('1.', 'Download the official Mid-Term exam below.'),
                    const SizedBox(height: 10),
                    _buildInstructionRow('2.', 'Have your learner solve the paper independently.'),
                    const SizedBox(height: 10),
                    _buildInstructionRow('3.', 'Scan the solved paper and upload it.\n(Strictly PDF format, Max 5MB).'),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Section 1: Download Exam Paper
              const Text(
                '1. Download Exam Paper',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),

              // Pale Lime Download Card matching 1 (6).png
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3FCE8), // Pale soft lime tint
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0F3CA), width: 1.2),
                ),
                child: Row(
                  children: [
                    // Red PDF icon badge
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black.withOpacity(0.06)),
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
                            _officialDocTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'AVAILABLE FOR DOWNLOAD',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8E8E93),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Download Circular Button
                    InkWell(
                      onTap: _downloadOfficialPdf,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.download_rounded, color: Colors.black87, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Section 2: Upload Solved Exam
              const Text(
                '2. Upload Solved Exam',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),

              // Dashed Dropzone matching 1 (6).png
              GestureDetector(
                onTap: _isUploading ? null : _handlePickFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFCCCCCC),
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE5E5EA),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cloud_upload_outlined, color: Colors.black87, size: 28),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Tap to select file',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PDF, DOC up to 5MB',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // File Selected Pill Tag matching 1 (6).png
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8D9),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: const Color(0xFFD4F0B5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'File selected: $selectedFileName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedFile = null;
                        });
                      },
                      child: const Icon(Icons.close, color: Colors.black54, size: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Primary Lime Submit Button matching 1 (6).png
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCCFF00), // Vibrant lime
                    foregroundColor: Colors.black,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: _isUploading ? null : _handleSubmit,
                  child: _isUploading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'SUBMIT MID ASSESSMENT',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.send_rounded, size: 18),
                          ],
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

  Widget _buildInstructionRow(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
