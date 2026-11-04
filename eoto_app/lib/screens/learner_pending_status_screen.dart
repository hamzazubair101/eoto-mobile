import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_theme.dart';
import 'add_learner_screen.dart';

class LearnerPendingStatusScreen extends StatelessWidget {
  final Map<String, dynamic>? learner;
  final bool isNewlySubmitted;

  const LearnerPendingStatusScreen({
    Key? key,
    this.learner,
    this.isNewlySubmitted = false,
  }) : super(key: key);

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is DateTime) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${timestamp.day} ${months[timestamp.month - 1]} ${timestamp.year}';
    }
    try {
      final dynamic ts = timestamp;
      final dt = ts.toDate();
      if (dt is DateTime) {
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
      }
    } catch (_) {}

    final str = timestamp.toString().trim();
    final match = RegExp(r'seconds=(\d+)').firstMatch(str);
    if (match != null) {
      final secs = int.tryParse(match.group(1)!);
      if (secs != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(secs * 1000);
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
      }
    }

    if (str.length >= 10 && !str.startsWith('Timestamp(')) {
      return str.substring(0, 10);
    }
    return str.isNotEmpty && !str.startsWith('Timestamp(') ? str : 'Recent';
  }

  @override
  Widget build(BuildContext context) {
    final String status = (learner?['status'] ?? '').toString();
    final bool isRejected = status.toLowerCase().contains('reject');
    final String rejectionRemarks = (learner?['rejectionRemarks'] ?? learner?['remarks'] ?? '').toString().trim();
    final String learnerName = (learner?['name'] ?? 'Learner').toString();
    final String parentage = (learner?['parentage'] ?? 'N/A').toString();
    final String focalOfficer = (learner?['assignedFocalPersonName'] ?? 'Focal Officer').toString();
    final String reviewDate = _formatDate(learner?['reviewedAt'] ?? learner?['createdAt']);
    final String baselinePaperUrl = (learner?['baselinePaperUrl'] ?? learner?['assessmentUrl'] ?? '').toString().trim();

    final checklist = learner?['rejectionChecklist'] as Map<String, dynamic>?;
    final bool blurryTest = checklist?['blurryTest'] == true;
    final bool incompleteTest = checklist?['incompleteTest'] == true;
    final bool mismatchedData = checklist?['mismatchedData'] == true;
    final bool incompleteForm = checklist?['incompleteForm'] == true;
    final bool failsIlliteracyCriteria = checklist?['failsIlliteracyCriteria'] == true || checklist?['alreadyLiterate'] == true;
    final bool hasChecklistIssues = blurryTest || incompleteTest || mismatchedData || incompleteForm || failsIlliteracyCriteria;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text(
              'EOTO',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 3),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isRejected ? const Color(0xFFEF4444) : const Color(0xFFCCFF00),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: isRejected
            ? SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),

                    // Red Circle Hero Visual
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 25,
                            left: 10,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.25),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 15,
                            right: 12,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.25),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFEF4444), width: 2.5),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.close_rounded,
                                size: 60,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Screen Heading
                    const Text(
                      'Application\nRejected',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        height: 1.15,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Reviewed by $focalOfficer on $reviewDate.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 1. Officer Remarks & Reason Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFEE2E2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.feedback_outlined,
                                  color: Color(0xFFDC2626),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Officer Rejection Remarks',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF991B1B),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Text(
                              rejectionRemarks.isNotEmpty
                                  ? '"$rejectionRemarks"'
                                  : '"No specific remarks given. Please review baseline test criteria below."',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF7F1D1D),
                                height: 1.35,
                              ),
                            ),
                          ),

                          if (hasChecklistIssues) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Specific Issues Flagged:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (blurryTest)
                              _buildIssueBullet('Blurry Test Paper', 'The uploaded baseline test scan/photo was not clear enough to grade.'),
                            if (incompleteTest)
                              _buildIssueBullet('Incomplete Test', 'Important questions or evaluation sections were left blank.'),
                            if (mismatchedData)
                              _buildIssueBullet('Mismatched Data', 'Submitted form details did not match test paper or profile.'),
                            if (incompleteForm)
                              _buildIssueBullet('Incomplete Form', 'Required registration or identification details were missing.'),
                            if (failsIlliteracyCriteria)
                              _buildIssueBullet('Fails Illiteracy Criteria (Already Literate)', 'Learner demonstrates prior reading/writing competence and is ineligible for the basic literacy program.'),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Submitted Learner Profile Data Card (Interactive Option)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.badge_outlined,
                                  color: Colors.purple,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Submitted Application Details',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black87,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Candidate profiling, test paper & registration info',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.visibility_outlined, size: 18),
                              label: const Text(
                                'View Submitted Details',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                              ),
                              onPressed: () => _showSubmittedDetailsBottomSheet(context, learner),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 5. Re-Register Learner Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCCFF00),
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 56),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.black),
                        label: const Text(
                          'Re-Apply / Register Again',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const AddLearnerScreen()),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Return to Dashboard Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 54),
                          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        child: const Text(
                          'Return to Dashboard',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  children: [
                    const Spacer(flex: 3),

                    // Pending Graphic Circle
                    SizedBox(
                      width: 260,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 15,
                            right: 65,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.35),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 40,
                            left: 45,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.35),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Container(
                            width: 145,
                            height: 145,
                            decoration: const BoxDecoration(
                              color: Color(0xFFCCFF00),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.check_rounded,
                                size: 78,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    const Text(
                      'Assessment\nSubmitted!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        height: 1.15,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Your learner’s Baseline assessment has been securely sent to NCHD team .',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Expected Response Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F5F7),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE5E7EB),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.access_time_rounded,
                              color: Colors.black87,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 18),
                          const Expanded(
                            child: Text(
                              'Expected response: 3-5\nWorking Days',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 4),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCCFF00),
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 58),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        child: const Text(
                          'Return to Dashboard',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildIssueBullet(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2.0),
            child: Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF7F1D1D), height: 1.3),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontSize: 12.5, color: Colors.black87, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSheetSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.grey[700],
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  void _showSubmittedDetailsBottomSheet(BuildContext context, Map<String, dynamic>? learner) {
    if (learner == null) return;

    final String name = (learner['name'] ?? 'Learner').toString();
    final String parentage = (learner['parentage'] ?? 'N/A').toString();
    final String idNumber = (learner['idNumber'] ?? learner['cnic'] ?? learner['bForm'] ?? 'N/A').toString();
    final String idType = (learner['idType'] ?? 'CNIC / B-Form').toString();
    final String phone = (learner['phone'] ?? learner['contactNumber'] ?? 'N/A').toString();
    final String age = (learner['age'] ?? 'N/A').toString();
    final String dob = _formatDate(learner['dob'] ?? learner['dateOfBirth']);
    final String gender = (learner['gender'] ?? 'N/A').toString();
    final String occupation = (learner['occupation'] ?? 'Labor').toString();
    final String province = (learner['province'] ?? 'N/A').toString();
    final String district = (learner['district'] ?? 'N/A').toString();
    final String origin = (learner['origin'] ?? learner['address'] ?? 'N/A').toString();
    final String startingLiteracy = (learner['startingLiteracy'] ?? 'Illiterate').toString();
    final String classCenter = (learner['assignedClass'] ?? learner['center'] ?? learner['location'] ?? 'N/A').toString();
    final String submittedDate = _formatDate(learner['createdAt'] ?? learner['submittedAt']);
    final String status = (learner['status'] ?? 'Rejected').toString();
    final String baselinePaperUrl = (learner['baselinePaperUrl'] ?? learner['assessmentUrl'] ?? '').toString().trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            top: 14,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sheet Header
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFF00).withOpacity(0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.assignment_ind_rounded, color: Colors.black87, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Submitted Registration Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Application record for $name',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.black54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 12),

              // Scrollable Details List
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Baseline Test Download Section
                      _buildSheetSectionTitle('Submitted Baseline Test'),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.assignment_outlined, color: Colors.blueAccent, size: 18),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Candidate Baseline Assessment Paper',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Review submitted evaluation document for audit discrepancies',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.download_rounded, size: 17, color: Colors.white),
                                label: const Text(
                                  'Download / View Baseline Paper',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                                onPressed: () async {
                                  if (baselinePaperUrl.isNotEmpty) {
                                    final uri = Uri.parse(baselinePaperUrl);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      return;
                                    }
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        baselinePaperUrl.isNotEmpty
                                            ? 'Opening $baselinePaperUrl'
                                            : 'Baseline document file is not accessible.',
                                      ),
                                      backgroundColor: Colors.black87,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),
                      _buildSheetSectionTitle('Personal Information'),
                      _buildDetailRow('Full Name', name),
                      _buildDetailRow('Father / Guardian', parentage),
                      _buildDetailRow('Gender', gender),
                      _buildDetailRow('Age & DOB', '$age yrs • $dob'),

                      const SizedBox(height: 12),
                      _buildSheetSectionTitle('Identification'),
                      _buildDetailRow('ID Document Type', idType),
                      if (idNumber.isNotEmpty && idNumber != 'N/A')
                        _buildDetailRow('ID / CNIC Number', idNumber),

                      const SizedBox(height: 12),
                      _buildSheetSectionTitle('Location & Origin'),
                      _buildDetailRow('District', district),
                      if (province.isNotEmpty && province != 'N/A')
                        _buildDetailRow('Province', province),
                      if (origin.isNotEmpty && origin != 'N/A')
                        _buildDetailRow('Origin / Address', origin),
                      if (phone.isNotEmpty && phone != 'N/A')
                        _buildDetailRow('Contact Phone', phone),

                      const SizedBox(height: 12),
                      _buildSheetSectionTitle('Livelihood & Literacy'),
                      _buildDetailRow('Occupation', occupation),
                      _buildDetailRow('Starting Literacy', startingLiteracy),
                      if (classCenter.isNotEmpty && classCenter != 'N/A')
                        _buildDetailRow('Center / Class', classCenter),

                      const SizedBox(height: 12),
                      _buildSheetSectionTitle('Application Status'),
                      _buildDetailRow('Current Status', status),
                      _buildDetailRow('Submission Date', submittedDate),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
