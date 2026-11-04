import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../utils/app_theme.dart';
import '../../utils/file_downloader.dart';
import '../../utils/embedded_pdf_viewer.dart';

class LearnerReviewDetailScreen extends StatefulWidget {
  final Map<String, dynamic> learner;

  const LearnerReviewDetailScreen({Key? key, required this.learner}) : super(key: key);

  @override
  State<LearnerReviewDetailScreen> createState() => _LearnerReviewDetailScreenState();
}

class _LearnerReviewDetailScreenState extends State<LearnerReviewDetailScreen> {
  final TextEditingController _remarksController = TextEditingController();
  final _rejectFormKey = GlobalKey<FormState>();

  // Reject Checklist variables
  bool _blurryTest = false;
  bool _incompleteTest = false;
  bool _mismatchedData = false;
  bool _incompleteForm = false;
  bool _failsIlliteracyCriteria = false;

  bool _isProcessing = false;
  Map<String, dynamic> _liveLearnerData = {};
  Map<String, dynamic> _teacherData = {};
  bool _isLoadingLive = true;

  String get _learnerDocId =>
      widget.learner['id']?.toString() ??
      widget.learner['uid']?.toString() ??
      widget.learner['docId']?.toString() ??
      '';

  @override
  void initState() {
    super.initState();
    _liveLearnerData = Map<String, dynamic>.from(widget.learner);
    _fetchLiveLearnerAndTeacherData();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveLearnerAndTeacherData() async {
    try {
      DocumentSnapshot<Map<String, dynamic>>? doc;

      // 1. Direct query by doc ID if known
      if (_learnerDocId.isNotEmpty) {
        final directDoc = await FirebaseFirestore.instance
            .collection('learners')
            .doc(_learnerDocId)
            .get();
        if (directDoc.exists && directDoc.data() != null) {
          doc = directDoc;
        }
      }

      // 2. Fallback query by idNumber or name if doc not found
      if (doc == null) {
        final idNum = (widget.learner['idNumber'] ?? widget.learner['cnic'] ?? '').toString().trim();
        final name = (widget.learner['name'] ?? '').toString().trim();

        if (idNum.isNotEmpty && !idNum.toLowerCase().contains('n/a')) {
          final queryByIdNum = await FirebaseFirestore.instance
              .collection('learners')
              .where('idNumber', isEqualTo: idNum)
              .limit(1)
              .get();
          if (queryByIdNum.docs.isNotEmpty) {
            doc = queryByIdNum.docs.first;
          }
        }

        if (doc == null && name.isNotEmpty) {
          final queryByName = await FirebaseFirestore.instance
              .collection('learners')
              .where('name', isEqualTo: name)
              .limit(1)
              .get();
          if (queryByName.docs.isNotEmpty) {
            doc = queryByName.docs.first;
          }
        }
      }

      if (doc != null && doc.exists && doc.data() != null) {
        _liveLearnerData = {
          ...widget.learner,
          ...doc.data()!,
          'id': doc.id,
        };
      }

      // 3. Fetch supervising teacher data
      final teacherId = (_liveLearnerData['teacherId'] ??
              _liveLearnerData['teacherUid'] ??
              widget.learner['teacherId'])
          ?.toString();

      if (teacherId != null && teacherId.isNotEmpty) {
        try {
          final teacherDoc = await FirebaseFirestore.instance
              .collection('teachers')
              .doc(teacherId)
              .get();
          if (teacherDoc.exists && teacherDoc.data() != null) {
            _teacherData = teacherDoc.data()!;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isLoadingLive = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching live learner data: $e');
      if (mounted) setState(() => _isLoadingLive = false);
    }
  }

  void _callTeacher(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contact phone recorded for this volunteer teacher.')),
      );
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Volunteer Contact', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SelectableText('Teacher Phone: $phone', style: const TextStyle(fontSize: 16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            ],
          ),
        );
      }
    }
  }

  void _emailTeacher(String? email) async {
    if (email == null || email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email address recorded for this volunteer teacher.')),
      );
      return;
    }

    final learnerName = _val(_liveLearnerData['name'], 'Learner');
    final Uri uri = Uri(
      scheme: 'mailto',
      path: email.trim(),
      queryParameters: {
        'subject': 'EOTO Inquiry: Learner Review for $learnerName',
      },
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Teacher Email: $email')),
        );
      }
    }
  }

  String _constructFileName(String docTitle) {
    final learnerName = _val(_liveLearnerData['name'], 'Learner').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final idNum = _val(_liveLearnerData['idNumber'], '').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final cleanDoc = docTitle.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    if (idNum.isNotEmpty && idNum != 'N_A') {
      return '${cleanDoc}_${learnerName}_$idNum';
    }
    return '${cleanDoc}_$learnerName';
  }

  void _downloadDocument(String? url, String docTitle) async {
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No $docTitle uploaded to download.')),
      );
      return;
    }

    try {
      final fileName = _constructFileName(docTitle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading $docTitle...'),
          duration: const Duration(seconds: 2),
        ),
      );

      final success = await downloadFileToDevice(url: url, fileName: fileName);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download $docTitle. Opening in browser...')),
        );
        await openFileInBrowser(url: url, title: docTitle);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading document: $e')),
        );
      }
    }
  }

  void _previewDocumentInBrowser(String? url, String docTitle) async {
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No $docTitle uploaded to preview.')),
      );
      return;
    }

    try {
      await openFileInBrowser(url: url, title: docTitle);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open preview: $e')),
        );
      }
    }
  }

  Widget _buildDocImageWidget(String url, {BoxFit fit = BoxFit.cover, bool isThumbnail = true}) {
    if (url.startsWith('data:image')) {
      try {
        final base64Data = url.split(',').last;
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (ctx, err, stack) => _buildPdfOrFallbackWidget(url, isThumbnail: isThumbnail),
        );
      } catch (_) {
        return _buildPdfOrFallbackWidget(url, isThumbnail: isThumbnail);
      }
    } else if (url.toLowerCase().contains('.pdf') || url.startsWith('data:application/pdf')) {
      return _buildPdfOrFallbackWidget(url, isPdf: true, isThumbnail: isThumbnail);
    } else {
      return Image.network(
        url,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryLime),
          );
        },
        errorBuilder: (context, error, stack) {
          return _buildPdfOrFallbackWidget(url, isThumbnail: isThumbnail);
        },
      );
    }
  }

  Widget _buildPdfOrFallbackWidget(String url, {bool isPdf = false, bool isThumbnail = true}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.description_outlined,
              color: AppTheme.primaryLime,
              size: isThumbnail ? 36 : 48,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isPdf ? 'Official PDF Baseline Assessment' : 'Assessment Attached',
            style: TextStyle(
              color: Colors.white,
              fontSize: isThumbnail ? 13 : 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Interactive viewer ready • Tap to inspect full size',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  void _showDocumentViewerDialog(String docTitle, String? url) {
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No document uploaded for $docTitle.')),
      );
      return;
    }

    final bool isPdf = url.toLowerCase().contains('.pdf') || url.startsWith('data:application/pdf');

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                            color: AppTheme.primaryLime,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              docTitle,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                      tooltip: 'Close Preview',
                    ),
                  ],
                ),
              ),

              // Interactive Viewer Container
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.65,
                    minHeight: 280,
                  ),
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: isPdf
                      ? EmbeddedPdfViewer(url: url, height: MediaQuery.of(context).size.height * 0.62)
                      : InteractiveViewer(
                          panEnabled: true,
                          boundaryMargin: const EdgeInsets.all(20),
                          minScale: 0.8,
                          maxScale: 4.0,
                          child: _buildDocImageWidget(url, fit: BoxFit.contain, isThumbnail: false),
                        ),
                ),
              ),

              // Bottom Actions Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _previewDocumentInBrowser(url, docTitle),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text(
                          'Open in New Tab',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: AppTheme.primaryLime,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _downloadDocument(url, docTitle),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text(
                          'Download File',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRejectionDialog() {
    final focalEmail = FirebaseAuth.instance.currentUser?.email ?? 'cust_focal@eoto.pk';
    final learnerName = _val(_liveLearnerData['name'], 'Learner');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Reject Application: $learnerName',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Form(
                key: _rejectFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Please specify audit checklist discrepancies before returning this learner enrollment:',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 14),

                      CheckboxListTile(
                        activeColor: AppTheme.primaryLime,
                        checkColor: Colors.black,
                        title: const Text('Blurry/Unreadable Baseline Sheet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: _blurryTest,
                        onChanged: (val) => setDialogState(() => _blurryTest = val ?? false),
                      ),
                      CheckboxListTile(
                        activeColor: AppTheme.primaryLime,
                        checkColor: Colors.black,
                        title: const Text('Incomplete Baseline Test / Missing Page', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: _incompleteTest,
                        onChanged: (val) => setDialogState(() => _incompleteTest = val ?? false),
                      ),
                      CheckboxListTile(
                        activeColor: AppTheme.primaryLime,
                        checkColor: Colors.black,
                        title: const Text('Data Mismatched (CNIC / Name / Age)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: _mismatchedData,
                        onChanged: (val) => setDialogState(() => _mismatchedData = val ?? false),
                      ),
                      CheckboxListTile(
                        activeColor: AppTheme.primaryLime,
                        checkColor: Colors.black,
                        title: const Text('Incomplete Form Details or Profiling', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: _incompleteForm,
                        onChanged: (val) => setDialogState(() => _incompleteForm = val ?? false),
                      ),
                      CheckboxListTile(
                        activeColor: AppTheme.primaryLime,
                        checkColor: Colors.black,
                        title: const Text('Fails Illiteracy Criteria (Already Literate / Educated)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Learner demonstrates prior reading/writing competence and is ineligible for basic literacy program', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        value: _failsIlliteracyCriteria,
                        onChanged: (val) => setDialogState(() => _failsIlliteracyCriteria = val ?? false),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _remarksController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'MANDATORY AUDIT REMARKS',
                          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          hintText: 'Add required actions or instructions for student teacher...',
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Remarks are required for institutional audit logs';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    if (_rejectFormKey.currentState!.validate()) {
                      setState(() => _isProcessing = true);
                      final reasons = <String>[];
                      if (_blurryTest) reasons.add('Blurry/Unreadable Baseline Sheet');
                      if (_incompleteTest) reasons.add('Incomplete Baseline Test');
                      if (_mismatchedData) reasons.add('Data Mismatched (CNIC/Name/Age)');
                      if (_incompleteForm) reasons.add('Incomplete Form Details');
                      if (_failsIlliteracyCriteria) reasons.add('Fails Illiteracy Criteria (Already Literate / Educated)');
                      reasons.add(_remarksController.text.trim());

                      try {
                        final docIdToUpdate = _learnerDocId.isNotEmpty ? _learnerDocId : _liveLearnerData['id'];

                        // 1. Update Firestore learners collection
                        if (docIdToUpdate != null && docIdToUpdate.toString().isNotEmpty) {
                          await FirebaseFirestore.instance
                              .collection('learners')
                              .doc(docIdToUpdate.toString())
                              .update({
                            'status': 'Rejected',
                            'baselineStatus': 'Rejected',
                            'rejectionRemarks': _remarksController.text.trim(),
                            'rejectionChecklist': {
                              'blurryTest': _blurryTest,
                              'incompleteTest': _incompleteTest,
                              'mismatchedData': _mismatchedData,
                              'incompleteForm': _incompleteForm,
                              'failsIlliteracyCriteria': _failsIlliteracyCriteria,
                            },
                            'rejectedAt': FieldValue.serverTimestamp(),
                            'reviewedBy': focalEmail,
                          });
                        }

                        // 2. Commit audit log
                        await FirebaseFirestore.instance.collection('audit_logs').add({
                          'action': 'Learner Application Rejected',
                          'learnerId': docIdToUpdate,
                          'learnerName': learnerName,
                          'reviewedBy': focalEmail,
                          'reasons': reasons,
                          'remarks': _remarksController.text.trim(),
                          'timestamp': FieldValue.serverTimestamp(),
                        });

                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Learner $learnerName Enrollment Rejected'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isProcessing = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error rejecting learner: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('CONFIRM REJECT', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _approveLearner() async {
    final focalEmail = FirebaseAuth.instance.currentUser?.email ?? 'cust_focal@eoto.pk';
    final learnerName = _val(_liveLearnerData['name'], 'Learner');

    setState(() => _isProcessing = true);

    try {
      final docIdToUpdate = _learnerDocId.isNotEmpty ? _learnerDocId : _liveLearnerData['id'];

      // 1. Update Firestore status to 'Active'
      if (docIdToUpdate != null && docIdToUpdate.toString().isNotEmpty) {
        final Map<String, dynamic> updates = {
          'status': 'Active',
          'baselineStatus': 'Approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': focalEmail,
        };

        await FirebaseFirestore.instance
            .collection('learners')
            .doc(docIdToUpdate.toString())
            .update(updates);
      }

      // 2. Commit audit log
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action': 'Learner Application Approved',
        'learnerId': docIdToUpdate,
        'learnerName': learnerName,
        'reviewedBy': focalEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        AppTheme.showSuccessSnackBar(
          context,
          'Learner $learnerName Approved Successfully!',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving learner: $e')),
        );
      }
    }
  }

  String _val(dynamic v, [String fallback = 'N/A']) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  Widget _buildAuditCard(
    String label,
    String value, {
    IconData? icon,
    VoidCallback? onTapAction,
    String? actionLabel,
    Color? badgeColor,
    Color? badgeTextColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: Colors.black87),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF7A7A80),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                if (badgeColor != null)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      value.trim().isEmpty ? 'N/A' : value,
                      style: TextStyle(
                        color: badgeTextColor ?? Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Text(
                    value.trim().isEmpty ? 'N/A' : value,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (onTapAction != null && actionLabel != null)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: AppTheme.primaryLime,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onTapAction,
              icon: Icon(actionLabel == 'Call' ? Icons.phone : Icons.email, size: 14),
              label: Text(actionLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentPreviewCard({
    required String title,
    required String? url,
    required IconData icon,
    String? subtitle,
  }) {
    final bool hasUrl = url != null && url.trim().isNotEmpty;
    final bool isPdf = hasUrl && (url!.toLowerCase().contains('.pdf') || url.startsWith('data:application/pdf'));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasUrl ? AppTheme.primaryLime.withOpacity(0.5) : Colors.black.withOpacity(0.06),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: hasUrl ? Colors.black : Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasUrl ? const Color(0xFFE8F8D8) : const Color(0xFFFFEAEA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasUrl ? (isPdf ? 'PDF ATTACHED' : 'IMAGE ATTACHED') : 'NOT PROVIDED',
                    style: TextStyle(
                      color: hasUrl ? const Color(0xFF2E7D32) : Colors.redAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ),

          const SizedBox(height: 8),

          // Document Viewer Container
          if (hasUrl) ...[
            InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.zero, bottom: Radius.zero),
              onTap: () => _showDocumentViewerDialog(title, url),
              child: Container(
                height: 190,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E22),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      child: _buildDocImageWidget(url!),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in, color: AppTheme.primaryLime, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Tap to Inspect Full Size',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Direct Card Action Bar for Instant Preview & Clean Download
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFECECED),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black87,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _previewDocumentInBrowser(url, title),
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text('Preview / Open', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: AppTheme.primaryLime,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _downloadDocument(url, title),
                      icon: const Icon(Icons.download_rounded, size: 14),
                      label: const Text('Download File', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(22),
              alignment: Alignment.center,
              child: const Text(
                'No baseline assessment document uploaded yet.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Extract Learner Fields with authentic values
    final String name = _val(_liveLearnerData['name'] ?? _liveLearnerData['fullName'] ?? _liveLearnerData['learnerName']);
    final String age = _val(_liveLearnerData['age'] ?? _liveLearnerData['learnerAge']);
    final String gender = _val(_liveLearnerData['gender'] ?? _liveLearnerData['learnerGender']);
    final String parentage = _val(_liveLearnerData['parentage'] ?? _liveLearnerData['fatherName'] ?? _liveLearnerData['guardianName']);
    final String occupation = _val(_liveLearnerData['occupation'] ?? _liveLearnerData['job']);
    final String province = _val(_liveLearnerData['province'], 'Punjab');
    final String district = _val(_liveLearnerData['district'] ?? _liveLearnerData['city']);
    final String origin = _val(_liveLearnerData['origin']);
    final String idType = _val(_liveLearnerData['idType'], 'CNIC / B-Form');
    final String cnic = _val(_liveLearnerData['idNumber'] ?? _liveLearnerData['cnic'] ?? _liveLearnerData['cnicNumber'], 'Does Not Have Either');
    final bool hasCnic = cnic.isNotEmpty && !cnic.toLowerCase().contains('does not') && !cnic.toLowerCase().contains('n/a');
    final String startingLevel = _val(_liveLearnerData['startingLiteracy'] ?? _liveLearnerData['startingLevel'] ?? _liveLearnerData['level']);
    final String dob = _val(_liveLearnerData['dob'] ?? _liveLearnerData['dateOfBirth']);

    // Supervising Teacher Fields
    final String teacherName = _val(
      _teacherData['fullName'] ?? _teacherData['name'] ?? _liveLearnerData['teacherName'] ?? _liveLearnerData['teacher_name'] ?? _liveLearnerData['volunteerName'],
      'Assigned Volunteer',
    );
    final String teacherRole = _val(_teacherData['role'] ?? _liveLearnerData['teacherRole'], 'Student-Teacher');
    final String teacherInstitute = _val(_teacherData['instituteName'] ?? _teacherData['institute'] ?? _liveLearnerData['instituteName'], '');
    final String teacherPhone = _val(_teacherData['phone'] ?? _teacherData['contact'] ?? _liveLearnerData['teacherPhone'] ?? _liveLearnerData['teacherContact'], '');
    final String teacherEmail = _val(_teacherData['email'] ?? _liveLearnerData['teacherEmail'], '');

    // Baseline Assessment File
    final String? baselineUrl = _liveLearnerData['baselinePaperUrl']?.toString() ??
        _liveLearnerData['baselineUrl']?.toString() ??
        _liveLearnerData['documentUrl']?.toString();

    // Submission Time
    final dynamic createdAtRaw = _liveLearnerData['createdAt'] ?? _liveLearnerData['submittedAt'] ?? _liveLearnerData['baselineUploadedAt'];
    String submittedDate = 'Recently Uploaded';
    if (createdAtRaw is Timestamp) {
      final dt = createdAtRaw.toDate();
      submittedDate = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } else if (createdAtRaw is String && createdAtRaw.isNotEmpty) {
      submittedDate = createdAtRaw;
    }

    final String status = (_liveLearnerData['status'] ?? 'Pending Review').toString().toUpperCase();
    final String statusLower = status.toLowerCase();
    final bool isPendingReview = statusLower == 'pending review' ||
        statusLower == 'pending' ||
        statusLower == 'awaiting baseline';
    final bool isRejected =
        statusLower.contains('reject') || statusLower.contains('delist');
    final String rejectionRemarks = _val(
      _liveLearnerData['rejectionRemarks'] ?? _liveLearnerData['remarks'],
      'Application did not meet NCHD baseline verification criteria.',
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isPendingReview
              ? 'Review Learner'
              : (isRejected ? 'Rejected Learner Record' : 'Learner Record'),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLoadingLive)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryLime),
                ),
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
              // 1. Top Dossier Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DOSSIER: ${_learnerDocId.isEmpty ? "NEW" : _learnerDocId.substring(0, _learnerDocId.length > 14 ? 14 : _learnerDocId.length)}',
                            style: const TextStyle(
                              color: Color(0xFF6C6C70),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Submitted: $submittedDate',
                            style: const TextStyle(color: Colors.black54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: !isPendingReview && !isRejected
                            ? const Color(0xFFD6F5D6)
                            : isRejected
                                ? const Color(0xFFFFD6D6)
                                : const Color(0xFFCCFF00),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isPendingReview
                            ? 'Awaiting Review'
                            : (isRejected ? 'REJECTED' : status),
                        style: TextStyle(
                          color: !isPendingReview && !isRejected
                              ? const Color(0xFF2E7D32)
                              : isRejected
                                  ? const Color(0xFFC9250A)
                                  : Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // If Rejected, show the Rejection Reason & Audit Remarks Banner at the top
              if (isRejected) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFCA5A5),
                      width: 1.4,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.cancel_rounded,
                              color: Color(0xFFDC2626), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'REJECTION AUDIT REMARKS',
                            style: TextStyle(
                              color: Color(0xFF991B1B),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rejectionRemarks,
                        style: const TextStyle(
                          color: Color(0xFF7F1D1D),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 2. Supervising Volunteer Teacher Section
              const Text(
                'ENROLLING VOLUNTEER TEACHER',
                style: TextStyle(
                  color: Color(0xFF6C6C70),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withOpacity(0.06), width: 1.2),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFE8E9EA),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.person_outline, size: 24, color: Color(0xFF555555)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                teacherName,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                teacherInstitute.isNotEmpty
                                    ? '$teacherRole • $teacherInstitute'
                                    : teacherRole,
                                style: const TextStyle(color: Colors.black54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (teacherPhone.isNotEmpty || teacherEmail.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFECECED)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (teacherPhone.isNotEmpty)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black,
                                backgroundColor: AppTheme.primaryLime,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _callTeacher(teacherPhone),
                              icon: const Icon(Icons.phone, size: 14),
                              label: const Text('Call Teacher', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          if (teacherPhone.isNotEmpty && teacherEmail.isNotEmpty)
                            const SizedBox(width: 8),
                          if (teacherEmail.isNotEmpty)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black,
                                backgroundColor: const Color(0xFFE4E5E7),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _emailTeacher(teacherEmail),
                              icon: const Icon(Icons.email_outlined, size: 14),
                              label: const Text('Email', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. Learner Profile Section
              const Text(
                'Learner Profile',
                style: TextStyle(
                  color: Color(0xFF303030),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              _buildAuditCard('LEARNER FULL NAME', name, icon: Icons.school_outlined),
              _buildAuditCard("FATHER'S / GUARDIAN'S NAME", parentage, icon: Icons.family_restroom_outlined),
              Row(
                children: [
                  Expanded(child: _buildAuditCard('AGE', age, icon: Icons.cake_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildAuditCard('GENDER', gender, icon: Icons.people_outline)),
                ],
              ),
              if (dob.isNotEmpty && dob != 'N/A')
                _buildAuditCard('DATE OF BIRTH', dob, icon: Icons.calendar_today_outlined),

              _buildAuditCard(
                '$idType NUMBER',
                cnic,
                icon: Icons.credit_card_outlined,
                badgeColor: hasCnic ? const Color(0xFFE8F5E9) : const Color(0xFFFFEAEA),
                badgeTextColor: hasCnic ? const Color(0xFF2E7D32) : const Color(0xFFC9250A),
              ),

              _buildAuditCard('OCCUPATION / LIVELIHOOD', occupation, icon: Icons.work_outline),
              if (origin.isNotEmpty && origin != 'N/A')
                _buildAuditCard('LOCALITY / ORIGIN', origin, icon: Icons.near_me_outlined),
              _buildAuditCard('DISTRICT & PROVINCE', '$district, $province', icon: Icons.location_on_outlined),
              _buildAuditCard('STARTING LITERACY LEVEL', startingLevel, icon: Icons.menu_book_outlined),

              const SizedBox(height: 24),

              // 4. Baseline Assessment Section
              const Text(
                'Baseline Assessment',
                style: TextStyle(
                  color: Color(0xFF303030),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              _buildDocumentPreviewCard(
                title: 'BASELINE DIAGNOSTIC PAPER',
                url: baselineUrl,
                icon: Icons.assignment_turned_in_outlined,
                subtitle: 'Official Initial Diagnostic Literacy Assessment Submitted by Teacher',
              ),

              const SizedBox(height: 32),

              // 5. Official Review Decisions (Only when Pending Review)
              if (isPendingReview)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC9250A),
                          side: const BorderSide(color: Color(0xFFC9250A), width: 1.8),
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                        ),
                        onPressed: _isProcessing ? null : _showRejectionDialog,
                        child: const Text(
                          'R E J E C T',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCCFF00),
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 54),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                        ),
                        onPressed: _isProcessing ? null : _approveLearner,
                        child: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Text(
                                'A P P R O V E',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.8),
                              ),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: isRejected
                        ? const Color(0xFFFFF1F2)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isRejected
                          ? const Color(0xFFFECDD3)
                          : const Color(0xFFBBF7D0),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isRejected
                            ? Icons.block_rounded
                            : Icons.verified_rounded,
                        size: 18,
                        color: isRejected
                            ? const Color(0xFFE11D48)
                            : const Color(0xFF15803D),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isRejected
                            ? 'APPLICATION REJECTED • ARCHIVED IN HISTORY'
                            : 'APPLICATION APPROVED • VERIFIED RECORD',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5,
                          letterSpacing: 0.5,
                          color: isRejected
                              ? const Color(0xFFBE123C)
                              : const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}