import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../utils/app_theme.dart';
import '../../utils/file_downloader.dart';
import '../../utils/embedded_pdf_viewer.dart';

class TeacherReviewDetailScreen extends StatefulWidget {
  final Map<String, dynamic> applicant;

  const TeacherReviewDetailScreen({Key? key, required this.applicant}) : super(key: key);

  @override
  State<TeacherReviewDetailScreen> createState() => _TeacherReviewDetailScreenState();
}

class _TeacherReviewDetailScreenState extends State<TeacherReviewDetailScreen> {
  final TextEditingController _remarksController = TextEditingController();
  final _rejectFormKey = GlobalKey<FormState>();

  // Reject Checklist variables
  bool _blurryId = false;
  bool _mismatchedData = false;
  bool _unregisteredAcademic = false;
  bool _incompleteProfile = false;

  bool _isProcessing = false;
  Map<String, dynamic> _liveTeacherData = {};
  bool _isLoadingLive = true;

  String get _teacherDocId =>
      widget.applicant['id']?.toString() ??
      widget.applicant['uid']?.toString() ??
      widget.applicant['docId']?.toString() ??
      '';

  @override
  void initState() {
    super.initState();
    _liveTeacherData = Map<String, dynamic>.from(widget.applicant);
    _fetchLiveTeacherData();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveTeacherData() async {
    try {
      DocumentSnapshot<Map<String, dynamic>>? doc;

      // 1. Direct query by doc ID if known
      if (_teacherDocId.isNotEmpty) {
        final directDoc = await FirebaseFirestore.instance
            .collection('teachers')
            .doc(_teacherDocId)
            .get();
        if (directDoc.exists && directDoc.data() != null) {
          doc = directDoc;
        }
      }

      // 2. Fallback query by email or cnic to ensure accurate original data is loaded
      if (doc == null) {
        final email = (widget.applicant['email'] ?? '').toString().trim();
        final cnic = (widget.applicant['cnic'] ?? '').toString().trim();

        if (email.isNotEmpty) {
          final queryByEmail = await FirebaseFirestore.instance
              .collection('teachers')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          if (queryByEmail.docs.isNotEmpty) {
            doc = queryByEmail.docs.first;
          }
        }

        if (doc == null && cnic.isNotEmpty) {
          final queryByCnic = await FirebaseFirestore.instance
              .collection('teachers')
              .where('cnic', isEqualTo: cnic)
              .limit(1)
              .get();
          if (queryByCnic.docs.isNotEmpty) {
            doc = queryByCnic.docs.first;
          }
        }
      }

      if (doc != null && doc.exists && doc.data() != null) {
        if (mounted) {
          setState(() {
            _liveTeacherData = {
              ...widget.applicant,
              ...doc!.data()!,
              'id': doc.id,
              'uid': doc.id,
            };
            _isLoadingLive = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingLive = false);
      }
    } catch (e) {
      debugPrint('Error fetching live teacher data: $e');
      if (mounted) setState(() => _isLoadingLive = false);
    }
  }

  void _callVolunteer(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number recorded for this volunteer.')),
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
            title: const Text('Volunteer Phone', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SelectableText('Phone Number: $phone', style: const TextStyle(fontSize: 16)),
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

  void _emailVolunteer(String? email) async {
    if (email == null || email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email recorded for this volunteer.')),
      );
      return;
    }

    final Uri uri = Uri(
      scheme: 'mailto',
      path: email.trim(),
      queryParameters: {
        'subject': 'EOTO NCHD Volunteer Teacher Application Inquiry',
      },
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Volunteer Email: $email')),
        );
      }
    }
  }

  String _constructFileName(String docTitle) {
    final volunteerName = (_liveTeacherData['fullName'] ?? _liveTeacherData['name'] ?? 'Volunteer').toString().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final cnic = (_liveTeacherData['cnic'] ?? _liveTeacherData['idNumber'] ?? '').toString().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final cleanDoc = docTitle.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    if (cnic.isNotEmpty && cnic != 'N_A') {
      return '${cleanDoc}_${volunteerName}_$cnic';
    }
    return '${cleanDoc}_$volunteerName';
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
            isPdf ? 'Official PDF Document' : 'Document Attached',
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
    final volunteerName = _liveTeacherData['fullName'] ?? _liveTeacherData['name'] ?? 'Volunteer';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Reject Application: $volunteerName',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Form(
                key: _rejectFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Please specify audit checklist discrepancies before returning this application:',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 14),

                      CheckboxListTile(
                        activeColor: AppTheme.primaryLime,
                        checkColor: Colors.black,
                        title: const Text('Blurry/Unreadable ID Documents', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: _blurryId,
                        onChanged: (val) => setDialogState(() => _blurryId = val ?? false),
                      ),
                      CheckboxListTile(
                        activeColor: AppTheme.primaryLime,
                        checkColor: Colors.black,
                        title: const Text('Mismatched Personal Data (CNIC/Name)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: _mismatchedData,
                        onChanged: (val) => setDialogState(() => _mismatchedData = val ?? false),
                      ),
                      CheckboxListTile(
                        activeColor: AppTheme.primaryLime,
                        checkColor: Colors.black,
                        title: const Text('Unverified Academic/Student ID Credentials', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: _unregisteredAcademic,
                        onChanged: (val) => setDialogState(() => _unregisteredAcademic = val ?? false),
                      ),
                      CheckboxListTile(
                        activeColor: AppTheme.primaryLime,
                        checkColor: Colors.black,
                        title: const Text('Incomplete Profile/Application Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: _incompleteProfile,
                        onChanged: (val) => setDialogState(() => _incompleteProfile = val ?? false),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _remarksController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'MANDATORY AUDIT REMARKS',
                          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          hintText: 'Provide corrective actions for the volunteer...',
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
                      if (_blurryId) reasons.add('Blurry/Unreadable ID Documents');
                      if (_mismatchedData) reasons.add('Mismatched Personal Data');
                      if (_unregisteredAcademic) reasons.add('Unverified Academic Credentials');
                      if (_incompleteProfile) reasons.add('Incomplete Profile');
                      reasons.add(_remarksController.text.trim());

                      try {
                        final docIdToUpdate = _teacherDocId.isNotEmpty ? _teacherDocId : _liveTeacherData['id'];

                        // 1. Update Firestore teachers collection
                        if (docIdToUpdate != null && docIdToUpdate.toString().isNotEmpty) {
                          await FirebaseFirestore.instance
                              .collection('teachers')
                              .doc(docIdToUpdate.toString())
                              .update({
                            'status': 'rejected',
                            'rejectionRemarks': _remarksController.text.trim(),
                            'rejectionChecklist': {
                              'blurryId': _blurryId,
                              'mismatchedData': _mismatchedData,
                              'unregisteredAcademic': _unregisteredAcademic,
                              'incompleteProfile': _incompleteProfile,
                            },
                            'rejectedAt': FieldValue.serverTimestamp(),
                            'reviewedBy': focalEmail,
                          });
                        }

                        // 2. Commit audit log
                        await FirebaseFirestore.instance.collection('audit_logs').add({
                          'action': 'Teacher Application Rejected',
                          'teacherId': docIdToUpdate,
                          'teacherName': volunteerName,
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
                              content: Text('Volunteer $volunteerName Application Rejected'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isProcessing = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error rejecting application: $e')),
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

  void _approveVolunteer() async {
    final focalEmail = FirebaseAuth.instance.currentUser?.email ?? 'cust_focal@eoto.pk';
    final volunteerName = _liveTeacherData['fullName'] ?? _liveTeacherData['name'] ?? 'Volunteer';

    setState(() => _isProcessing = true);

    try {
      final docIdToUpdate = _teacherDocId.isNotEmpty ? _teacherDocId : _liveTeacherData['id'];

      // 1. Update Firestore status to 'approved'
      if (docIdToUpdate != null && docIdToUpdate.toString().isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('teachers')
            .doc(docIdToUpdate.toString())
            .update({
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'reviewedBy': focalEmail,
        });
      }

      // 2. Commit audit log
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action': 'Teacher Application Approved',
        'teacherId': docIdToUpdate,
        'teacherName': volunteerName,
        'reviewedBy': focalEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        AppTheme.showSuccessSnackBar(
          context,
          'Volunteer $volunteerName Approved Successfully!',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving volunteer: $e')),
        );
      }
    }
  }

  Widget _buildAuditCard(String label, String value, {IconData? icon, VoidCallback? onTapAction, String? actionLabel}) {
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
                  style: const TextStyle(color: Color(0xFF7A7A80), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                const SizedBox(height: 4),
                Text(
                  value.trim().isEmpty ? 'N/A' : value,
                  style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),
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
        border: Border.all(color: hasUrl ? AppTheme.primaryLime.withOpacity(0.5) : Colors.black.withOpacity(0.06), width: 1.5),
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
              borderRadius: BorderRadius.zero,
              onTap: () => _showDocumentViewerDialog(title, url),
              child: Container(
                height: 180,
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
                            Text('Tap to Inspect Full Size', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              child: const Text(
                'No file attachment recorded in database or cloud storage.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final String fullName = _liveTeacherData['fullName'] ?? _liveTeacherData['name'] ?? 'Volunteer Teacher';
    final String fatherName = _liveTeacherData['fatherName'] ?? _liveTeacherData['father_name'] ?? 'N/A';
    final String role = (_liveTeacherData['role'] ?? '').toString();
    final bool isStudent = role.toLowerCase() == 'student' || role.toLowerCase().contains('student');
    final String roleType = isStudent ? 'University Student Volunteer (VIS)' : 'Community Volunteer';
    final String qualification = _liveTeacherData['qualification'] ?? 'Bachelors / Undergraduate';
    final String institute = _liveTeacherData['instituteName'] ?? _liveTeacherData['institute'] ?? 'N/A';
    final String district = _liveTeacherData['district'] ?? 'N/A';
    final String province = _liveTeacherData['province'] ?? 'Punjab';
    final String cnic = _liveTeacherData['cnic'] ?? _liveTeacherData['idNumber'] ?? 'N/A';
    final String idType = _liveTeacherData['idType'] ?? 'CNIC';
    final String dob = _liveTeacherData['dob'] ?? _liveTeacherData['dateOfBirth'] ?? 'N/A';
    final String phone = _liveTeacherData['phone'] ?? _liveTeacherData['phoneNumber'] ?? '';
    final String email = _liveTeacherData['email'] ?? '';
    final String permanentAddress = _liveTeacherData['permanentAddress'] ?? _liveTeacherData['address'] ?? 'N/A';
    final String mailingAddress = _liveTeacherData['mailingAddress'] ?? 'N/A';
    final String postalCode = _liveTeacherData['postalCode'] ?? _liveTeacherData['zipCode'] ?? 'N/A';
    final String routingType = _liveTeacherData['routingType'] ?? 'Institutional Dynamic Allocation';
    final String assignedFocalName = _liveTeacherData['assignedFocalPersonName'] ?? '';
    final String assignedFocalEmail = _liveTeacherData['assignedFocalPersonEmail'] ?? '';

    final String? cnicFrontUrl = _liveTeacherData['cnicFrontUrl']?.toString();
    final String? cnicBackUrl = _liveTeacherData['cnicBackUrl']?.toString();
    final String? instituteIdUrl = _liveTeacherData['instituteIdUrl']?.toString();

    final dynamic createdAtRaw = _liveTeacherData['createdAt'] ?? _liveTeacherData['submittedAt'];
    String submittedDate = 'Just Now';
    if (createdAtRaw is Timestamp) {
      final dt = createdAtRaw.toDate();
      submittedDate = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } else if (createdAtRaw is String && createdAtRaw.isNotEmpty) {
      submittedDate = createdAtRaw;
    }

    final String status = (_liveTeacherData['status'] ?? 'pending').toString().toUpperCase();
    final bool isPending = status == 'PENDING';
    final bool isRejected = status.contains('REJECT');
    final String rejectionRemarks = (_liveTeacherData['rejectionRemarks'] ??
            _liveTeacherData['remarks'] ??
            'Application did not meet verification requirements.')
        .toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isPending
              ? 'Volunteer Profile Review'
              : (isRejected ? 'Rejected Volunteer Record' : 'Volunteer Record'),
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
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryLime))),
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
                            'DOSSIER: ${_teacherDocId.isEmpty ? "NEW" : _teacherDocId.substring(0, _teacherDocId.length > 14 ? 14 : _teacherDocId.length)}',
                            style: const TextStyle(color: Color(0xFF6C6C70), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
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
                        color: !isPending && !isRejected
                            ? const Color(0xFFD6F5D6)
                            : isRejected
                                ? const Color(0xFFFFD6D6)
                                : const Color(0xFFCCFF00),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isPending
                            ? 'Awaiting Review'
                            : (isRejected ? 'REJECTED' : status),
                        style: TextStyle(
                          color: !isPending && !isRejected
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
              const SizedBox(height: 20),

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

              // 2. Personal & Contact Information Section
              const Text(
                'PERSONAL IDENTIFICATION DETAILS',
                style: TextStyle(color: Color(0xFF6C6C70), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 10),

              _buildAuditCard('FULL NAME', fullName, icon: Icons.person_outline),
              _buildAuditCard("FATHER'S / GUARDIAN'S NAME", fatherName, icon: Icons.badge_outlined),
              _buildAuditCard('$idType NUMBER', cnic, icon: Icons.credit_card_outlined),
              _buildAuditCard('DATE OF BIRTH', dob, icon: Icons.calendar_today_outlined),
              if (phone.isNotEmpty)
                _buildAuditCard(
                  'PHONE NUMBER', 
                  phone, 
                  icon: Icons.phone_outlined,
                  onTapAction: () => _callVolunteer(phone),
                  actionLabel: 'Call',
                ),
              if (email.isNotEmpty)
                _buildAuditCard(
                  'EMAIL ADDRESS', 
                  email, 
                  icon: Icons.email_outlined,
                  onTapAction: () => _emailVolunteer(email),
                  actionLabel: 'Email',
                ),

              const SizedBox(height: 20),

              // 3. Residential & Postal Logistics Section
              const Text(
                'RESIDENTIAL & POSTAL LOGISTICS',
                style: TextStyle(color: Color(0xFF6C6C70), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 10),

              _buildAuditCard('PERMANENT ADDRESS', permanentAddress, icon: Icons.home_outlined),
              _buildAuditCard('MAILING / RESIDENTIAL ADDRESS', mailingAddress, icon: Icons.mark_as_unread_outlined),
              _buildAuditCard('POSTAL CODE', postalCode, icon: Icons.local_post_office_outlined),

              const SizedBox(height: 20),

              // 4. Academic & Institutional Affiliation Section
              const Text(
                'ACADEMIC & GEOGRAPHIC ALLOCATION',
                style: TextStyle(color: Color(0xFF6C6C70), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 10),

              _buildAuditCard('PRIMARY VOLUNTEER ROLE', roleType, icon: Icons.school_outlined),
              _buildAuditCard('EDUCATIONAL INSTITUTE', institute, icon: Icons.account_balance_outlined),
              _buildAuditCard('HIGHEST QUALIFICATION', qualification, icon: Icons.workspace_premium_outlined),
              _buildAuditCard('ASSIGNED DISTRICT & PROVINCE', '$district, $province', icon: Icons.location_on_outlined),
              _buildAuditCard('ROUTING STRATEGY', routingType, icon: Icons.alt_route_outlined),
              if (assignedFocalName.isNotEmpty || assignedFocalEmail.isNotEmpty)
                _buildAuditCard(
                  'ASSIGNED FOCAL OFFICER', 
                  '$assignedFocalName ($assignedFocalEmail)', 
                  icon: Icons.verified_user_outlined
                ),

              const SizedBox(height: 20),

              // 5. Cloud Verification Documents Section
              const Text(
                'SUBMITTED VERIFICATION DOCUMENTS (CLOUD STORAGE)',
                style: TextStyle(color: Color(0xFF6C6C70), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 12),

              _buildDocumentPreviewCard(
                title: '$idType FRONT PHOTO',
                url: cnicFrontUrl,
                icon: Icons.credit_card,
                subtitle: 'Government National Identity Card (Front Photo)',
              ),

              if (idType == 'CNIC' || (cnicBackUrl != null && cnicBackUrl.isNotEmpty))
                _buildDocumentPreviewCard(
                  title: '$idType BACK PHOTO',
                  url: cnicBackUrl,
                  icon: Icons.credit_card_outlined,
                  subtitle: 'Permanent Address & Identity Verification (Back Photo)',
                ),

              _buildDocumentPreviewCard(
                title: isStudent ? 'STUDENT ID CARD / ENROLLMENT PROOF' : 'ACADEMIC DEGREE / QUALIFICATION PROOF',
                url: instituteIdUrl,
                icon: Icons.badge_outlined,
                subtitle: isStudent 
                    ? 'Accredited Educational Institution Verification' 
                    : 'Higher Education Degree / Certificate Verification',
              ),

              const SizedBox(height: 32),

              // 6. Official Review Decisions (Only when Pending)
              if (isPending)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent, width: 1.8),
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                        ),
                        onPressed: _isProcessing ? null : _showRejectionDialog,
                        child: const Text('REJECT PROFILE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
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
                        onPressed: _isProcessing ? null : _approveVolunteer,
                        child: _isProcessing
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Text('APPROVE PROFILE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
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
                            ? 'PROFILE REJECTED • ARCHIVED IN HISTORY'
                            : 'PROFILE APPROVED & VERIFIED',
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
