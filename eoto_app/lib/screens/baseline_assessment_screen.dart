import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/app_theme.dart';
import '../controllers/registration_controller.dart';

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/azure_storage_service.dart';
import '../utils/file_downloader.dart';
import 'learner_pending_status_screen.dart';

class BaselineAssessmentScreen extends StatefulWidget {
  final Map<String, dynamic> learner;

  const BaselineAssessmentScreen({Key? key, required this.learner}) : super(key: key);

  @override
  State<BaselineAssessmentScreen> createState() => _BaselineAssessmentScreenState();
}

class _BaselineAssessmentScreenState extends State<BaselineAssessmentScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // Official master assessment template from Super Admin
  String _officialDocTitle = 'Official NCHD Baseline Diagnostic Assessment Test';
  String _officialDocSize = '1.8 MB';
  String? _officialDocDownloadUrl;
  bool _isLoadingOfficialDoc = true;

  @override
  void initState() {
    super.initState();
    _fetchOfficialBaselineTemplate();
  }

  void _fetchOfficialBaselineTemplate() async {
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('curriculum')
          .doc('official_baseline_assessment')
          .get();

      if (docSnap.exists && docSnap.data() != null) {
        final data = docSnap.data()!;
        if (mounted) {
          setState(() {
            _officialDocTitle = data['title'] ?? data['name'] ?? _officialDocTitle;
            _officialDocSize = data['size'] ?? _officialDocSize;
            _officialDocDownloadUrl = data['downloadUrl'];
            _isLoadingOfficialDoc = false;
          });
        }
        return;
      }

      // Fallback search
      final querySnap = await FirebaseFirestore.instance
          .collection('curriculum')
          .where('cat', isEqualTo: 'Assessment Sheet')
          .get();

      for (var d in querySnap.docs) {
        final dData = d.data();
        final title = (dData['title'] ?? '').toString().toLowerCase();
        if (title.contains('baseline') || dData['assessmentType'] == 'baseline') {
          if (mounted) {
            setState(() {
              _officialDocTitle = dData['title'] ?? _officialDocTitle;
              _officialDocSize = dData['size'] ?? _officialDocSize;
              _officialDocDownloadUrl = dData['downloadUrl'];
              _isLoadingOfficialDoc = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      print('Error fetching official baseline template: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingOfficialDoc = false);
      }
    }
  }

  void _downloadOfficialPdf() async {
    if (_officialDocDownloadUrl == null || _officialDocDownloadUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Official template not published yet. Please contact Super Admin.'),
          backgroundColor: Colors.redAccent,
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
      _uploadProgress = 0.3;
    });

    final List<int> uploadBytes = await _selectedFile!.readAsBytes();
    final String learnerId = widget.learner['id']?.toString() ?? 'unknown';

    // Upload real file directly to Azure Blob Storage
    String? azureUrl;
    try {
      azureUrl = await AzureStorageService.uploadBaselineAssessmentBytes(
        bytes: uploadBytes,
        learnerId: learnerId,
        fileName: _selectedFile!.name,
      );
    } catch (e) {
      print('[AZURE BASELINE UPLOAD ERROR] $e');
    }

    setState(() {
      _uploadProgress = 0.9;
    });

    if (mounted) {
      // Determine final document URL (Azure Blob Storage URL or base64 data URI fallback)
      final String isPdf = _selectedFile!.name.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
      final String finalPaperUrl = azureUrl ?? 'data:$isPdf;base64,${base64Encode(uploadBytes)}';

      final regController = Provider.of<RegistrationController>(context, listen: false);
      final String? assignedFocalEmail = widget.learner['assignedFocalPersonEmail'] ?? regController.assignedFocalPersonEmail;
      final String? assignedFocalName = widget.learner['assignedFocalPersonName'] ?? regController.assignedFocalPersonName;

      try {
        final Map<String, dynamic> updatePayload = {
          'baselinePaperUrl': finalPaperUrl,
          'baselineStatus': 'Submitted',
          'baselineUploadedAt': FieldValue.serverTimestamp(),
          'status': 'Pending Review',
        };
        if (assignedFocalEmail != null && assignedFocalEmail.isNotEmpty) {
          updatePayload['assignedFocalPersonEmail'] = assignedFocalEmail.toLowerCase().trim();
        }
        if (assignedFocalName != null && assignedFocalName.isNotEmpty) {
          updatePayload['assignedFocalPersonName'] = assignedFocalName;
        }

        await FirebaseFirestore.instance
            .collection('learners')
            .doc(learnerId)
            .update(updatePayload);
      } catch (e) {
        print('Firestore update error: $e');
      }

      // Update status to Pending Review in controller
      regController.updateLearnerStatus(learnerId, 'Pending Review');

      setState(() {
        _isUploading = false;
        _uploadProgress = 1.0;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LearnerPendingStatusScreen(
            learner: {
              ...widget.learner,
              'status': 'Pending Review',
              'baselineStatus': 'Submitted',
              'baselinePaperUrl': finalPaperUrl,
              if (assignedFocalEmail != null) 'assignedFocalPersonEmail': assignedFocalEmail,
              if (assignedFocalName != null) 'assignedFocalPersonName': assignedFocalName,
            },
            isNewlySubmitted: true,
          ),
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Success',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: AlertDialog(
            backgroundColor: AppTheme.cardLight,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.primaryLime, size: 30),
                SizedBox(width: 12),
                Text(
                  'Upload Successful',
                  style: TextStyle(color: AppTheme.textBlack, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: const Text(
              'Your baseline assessment has been submitted to the Focal Person. Reviewing and approval will take 3-5 working days. Daily session logging remains locked until approval.',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 14),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Back to dashboard
                },
                child: const Text('OKAY'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textBlack),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Baseline Assessment',
          style: TextStyle(color: AppTheme.textBlack, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Guidelines Container
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppTheme.cardLight,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assessment Guidelines',
                      style: TextStyle(
                        color: AppTheme.textBlack,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    _buildGuidelineRow('1', 'Download the NCHD baseline test and print if required.'),
                    _buildGuidelineRow('2', 'Administer the test physically with ${widget.learner['name']}.'),
                    _buildGuidelineRow('3', 'Take a high-quality picture or scan of the solved paper.'),
                    _buildGuidelineRow('4', 'Upload the PDF/JPG file here (Maximum file size: 5MB).'),
                  ],
                ),
              ),
              const SizedBox(height: 32.0),

              // Download Section
              Text(
                '1. GET BLANK ASSESSMENT SHEET',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 12, color: AppTheme.textGrey, letterSpacing: 1),
              ),
              const SizedBox(height: 12.0),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLime.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: AppTheme.primaryLime.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.textBlack, size: 36),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _officialDocTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Official Super Admin Template • $_officialDocSize',
                            style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_for_offline_rounded, color: AppTheme.textBlack, size: 32),
                      tooltip: 'Download Official PDF',
                      onPressed: _downloadOfficialPdf,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32.0),

              // Upload Section
              Text(
                '2. UPLOAD SOLVED ASSESSMENT',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 12, color: AppTheme.textGrey, letterSpacing: 1),
              ),
              const SizedBox(height: 12.0),
              GestureDetector(
                onTap: _isUploading ? null : _handlePickFile,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.cardLight,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: _selectedFile != null ? AppTheme.primaryLime : Colors.grey[300]!,
                      style: BorderStyle.solid,
                      width: 2,
                    ),
                  ),
                  child: _selectedFile != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.insert_drive_file_rounded, color: AppTheme.primaryLime, size: 48),
                            const SizedBox(height: 12.0),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                _selectedFile!.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            const Text(
                              'Tap to replace file',
                              style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_outlined, color: AppTheme.textGrey, size: 48),
                            SizedBox(height: 12.0),
                            Text(
                              'Select Scan / Solved Paper',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            SizedBox(height: 4.0),
                            Text(
                              'Only PDF, JPG, PNG formats (Max 5MB)',
                              style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 48.0),

              // Upload Action Button
              if (_isUploading) ...[
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: AppTheme.inputFill,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryLime),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Uploadingsolved paper: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textBlack),
                    ),
                  ],
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedFile != null ? _handleSubmit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedFile != null ? AppTheme.primaryLime : Colors.grey[300],
                      foregroundColor: _selectedFile != null ? Colors.black : Colors.grey[500],
                    ),
                    child: const Text('SUBMIT ASSESSMENT'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuidelineRow(String stepNumber, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            alignment: Alignment.center,
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: AppTheme.primaryLime,
              shape: BoxShape.circle,
            ),
            child: Text(
              stepNumber,
              style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
