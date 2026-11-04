import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../controllers/registration_controller.dart';
import 'learner_calendar_screen.dart';
import 'learner_pending_status_screen.dart';
import 'baseline_assessment_screen.dart';
import 'focal/teacher_review_detail_screen.dart';
import 'focal/learner_review_detail_screen.dart';
import 'focal_exam_scheduler_screen.dart';
import 'settings/profile_sub_screens.dart';

class NotificationsCenterScreen extends StatefulWidget {
  final bool isFocalPerson;
  final String? focalEmail;

  const NotificationsCenterScreen({
    Key? key,
    this.isFocalPerson = false,
    this.focalEmail,
  }) : super(key: key);

  @override
  State<NotificationsCenterScreen> createState() =>
      _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen> {
  String _selectedFilter = 'All';
  final Set<String> _locallyReadIds = {};
  bool _markedAllRead = false;

  Future<void> _markAllAsRead(List<String> allIds, String? docPath) async {
    setState(() {
      _markedAllRead = true;
      _locallyReadIds.addAll(allIds);
    });
    if (docPath != null && docPath.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.doc(docPath).set({
          'readNotificationIds': FieldValue.arrayUnion(allIds),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF171717),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: const Row(
          children: [
            Icon(Icons.done_all_rounded, color: Color(0xFFCCFF00), size: 18),
            SizedBox(width: 10),
            Text(
              'All notifications marked as read',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markSingleRead(String id, String? docPath) async {
    setState(() {
      _locallyReadIds.add(id);
    });
    if (docPath != null && docPath.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.doc(docPath).set({
          'readNotificationIds': FieldValue.arrayUnion([id]),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF171717),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Notification Preferences',
            icon: const Icon(Icons.tune_rounded, color: Colors.black87, size: 21),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationPreferencesScreen(
                    isFocalPerson: widget.isFocalPerson,
                    focalEmail: widget.focalEmail,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF3F4F6)),
        ),
      ),
      body: widget.isFocalPerson
          ? _buildFocalNotificationsBody(context)
          : _buildTeacherNotificationsBody(context),
    );
  }

  // ===========================================================================
  // 1. VOLUNTEER STUDENT-TEACHER NOTIFICATIONS STREAM
  // ===========================================================================
  Widget _buildTeacherNotificationsBody(BuildContext context) {
    final controller = Provider.of<RegistrationController>(context);
    final String? uid =
        controller.currentTeacherUid ?? FirebaseAuth.instance.currentUser?.uid;
    final String? docPath =
        (uid != null && uid.isNotEmpty) ? 'teachers/$uid' : null;

    return StreamBuilder<DocumentSnapshot>(
      stream: (uid != null && uid.isNotEmpty)
          ? FirebaseFirestore.instance
              .collection('teachers')
              .doc(uid)
              .snapshots()
          : const Stream.empty(),
      builder: (context, teacherSnap) {
        final Map<String, dynamic> teacherDoc =
            (teacherSnap.hasData && teacherSnap.data!.exists)
                ? (teacherSnap.data!.data() as Map<String, dynamic>? ?? {})
                : {};

        final Map<String, dynamic> prefs =
            (teacherDoc['notificationPreferences'] as Map<String, dynamic>?) ??
                {};
        final bool showDeadlines =
            prefs['deadlineWarnings120h'] as bool? ?? true;
        final bool showExams = prefs['examsAndGradingAlerts'] as bool? ?? true;
        final bool showEnrollments =
            prefs['learnerEnrollments'] as bool? ?? true;

        final List<dynamic> persistedRead =
            (teacherDoc['readNotificationIds'] as List<dynamic>?) ?? [];
        final Set<String> readIds = {
          ...persistedRead.map((e) => e.toString()),
          ..._locallyReadIds,
        };

        final List<_NotificationItem> items = [];

        // Build real-time notifications from teacher's account & learners
        final String teacherStatus =
            (teacherDoc['status'] ?? controller.teacherStatus ?? 'approved')
                .toString()
                .toLowerCase();
        if (teacherStatus == 'approved' || teacherStatus == 'active') {
          items.add(
            _NotificationItem(
              id: 'teacher_verified_${uid ?? "self"}',
              category: 'Enrollments',
              title: 'Volunteer Account Verified',
              body:
                  'Your Student-Teacher credentials have been approved by your Institutional Focal Person. You can register and teach adult learners.',
              timeLabel: 'Official Verification',
              icon: Icons.verified_user_rounded,
              accentColor: const Color(0xFF16A34A),
              badgeText: 'ACCOUNT ACTIVE',
            ),
          );
        } else if (teacherStatus == 'pending') {
          items.add(
            _NotificationItem(
              id: 'teacher_pending_${uid ?? "self"}',
              category: 'Enrollments',
              title: 'Account Verification in Progress',
              body:
                  'Your registration is in your Focal Person\'s verification queue (120-Hour SLA window).',
              timeLabel: 'Pending Review',
              icon: Icons.hourglass_top_rounded,
              accentColor: const Color(0xFFD97706),
              badgeText: 'IN QUEUE',
            ),
          );
        }

        for (final learner in controller.learners) {
          final String lId = (learner['id'] ?? '').toString();
          final String lName = (learner['name'] ?? 'Learner').toString();
          final String status =
              (learner['status'] ?? 'Awaiting Baseline').toString();
          final String statusLower = status.toLowerCase();
          final int classesTaught =
              (learner['classesTaught'] as num?)?.toInt() ?? 0;
          final String lastSession =
              (learner['lastSession'] ?? 'N/A').toString();

          // Category: Learner Enrollments
          if (showEnrollments) {
            if (statusLower == 'active') {
              items.add(
                _NotificationItem(
                  id: 'learner_active_$lId',
                  category: 'Enrollments',
                  title: 'Learner Approved: $lName',
                  body:
                      'Baseline assessment verified by your Focal Person. The 12-week teaching calendar for $lName is active ($classesTaught/36 classes logged).',
                  timeLabel: lastSession != 'N/A'
                      ? 'Last class: $lastSession'
                      : 'Active Cycle',
                  icon: Icons.how_to_reg_rounded,
                  accentColor: const Color(0xFF16A34A),
                  badgeText: 'APPROVED',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            LearnerCalendarScreen(learner: learner),
                      ),
                    );
                  },
                ),
              );
            } else if (statusLower.contains('pending') ||
                statusLower.contains('review')) {
              items.add(
                _NotificationItem(
                  id: 'learner_pending_$lId',
                  category: 'Enrollments',
                  title: 'Baseline Under Review: $lName',
                  body:
                      'Submitted baseline diagnostic paper for $lName is awaiting Focal Person verification.',
                  timeLabel: 'Awaiting Focal Review',
                  icon: Icons.pending_actions_rounded,
                  accentColor: const Color(0xFFD97706),
                  badgeText: 'PENDING REVIEW',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            LearnerPendingStatusScreen(learner: learner),
                      ),
                    );
                  },
                ),
              );
            } else if (statusLower.contains('reject')) {
              final String reason = (learner['rejectionRemarks'] ??
                      learner['remarks'] ??
                      'Please review diagnostic paper.')
                  .toString();
              items.add(
                _NotificationItem(
                  id: 'learner_rejected_$lId',
                  category: 'Enrollments',
                  title: 'Action Required — $lName Rejected',
                  body:
                      'Focal Person returned $lName\'s application. Remarks: "$reason". Tap to view details.',
                  timeLabel: 'Urgent Action',
                  icon: Icons.error_outline_rounded,
                  accentColor: const Color(0xFFEF4444),
                  badgeText: 'REJECTED',
                  isUrgent: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            LearnerPendingStatusScreen(learner: learner),
                      ),
                    );
                  },
                ),
              );
            } else if (status == 'Awaiting Baseline') {
              items.add(
                _NotificationItem(
                  id: 'learner_awaiting_baseline_$lId',
                  category: 'Enrollments',
                  title: 'Upload Baseline Assessment: $lName',
                  body:
                      'Administer and upload the initial diagnostic test for $lName to unlock their 12-week cycle.',
                  timeLabel: 'Step 1 Pending',
                  icon: Icons.upload_file_rounded,
                  accentColor: const Color(0xFF2563EB),
                  badgeText: 'BASELINE REQUIRED',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            BaselineAssessmentScreen(learner: learner),
                      ),
                    );
                  },
                ),
              );
            }
          }

          // Category: Exams & Grading Alerts
          if (showExams) {
            if (status == 'Certified' || status == 'Completed') {
              items.add(
                _NotificationItem(
                  id: 'learner_certified_$lId',
                  category: 'Exams & SLA',
                  title: 'Literacy Certificate Awarded: $lName',
                  body:
                      'Congratulations! $lName has cleared the Final Assessment (${learner['examGrade'] ?? "Passed"}) and earned official NCHD literacy certification.',
                  timeLabel: 'Cycle Graduated',
                  icon: Icons.workspace_premium_rounded,
                  accentColor: const Color(0xFF16A34A),
                  badgeText: 'CERTIFIED',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            LearnerCalendarScreen(learner: learner),
                      ),
                    );
                  },
                ),
              );
            } else if (status == 'Exam Scheduled' ||
                status == 'Week 12 Completed' ||
                classesTaught >= 36) {
              items.add(
                _NotificationItem(
                  id: 'learner_exam_$lId',
                  category: 'Exams & SLA',
                  title: 'Final Exam Window Open: $lName',
                  body:
                      '$lName has completed all 36 sessions (Week 12). Coordinate with your Focal Person for the Final Literacy Exam.',
                  timeLabel: 'Week 12 Milestone',
                  icon: Icons.event_available_rounded,
                  accentColor: const Color(0xFF7C3AED),
                  badgeText: 'EXAM WINDOW',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            LearnerCalendarScreen(learner: learner),
                      ),
                    );
                  },
                ),
              );
            } else if (classesTaught >= 18) {
              items.add(
                _NotificationItem(
                  id: 'learner_midterm_$lId',
                  category: 'Exams & SLA',
                  title: 'Mid-Term Milestone Reached: $lName',
                  body:
                      '$lName has completed $classesTaught/36 classes (Week 6+). Ensure Mid-Term Assessment progress is up to date.',
                  timeLabel: 'Week 6 Milestone',
                  icon: Icons.assignment_turned_in_rounded,
                  accentColor: const Color(0xFF2563EB),
                  badgeText: 'MID-TERM',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            LearnerCalendarScreen(learner: learner),
                      ),
                    );
                  },
                ),
              );
            }
          }

          // Category: 120-Hour Deadline Warnings
          if (showDeadlines && statusLower == 'active') {
            final now = DateTime.now();
            final String todayIso =
                '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
            final List<dynamic> logs =
                (learner['sessionLogs'] as List<dynamic>?) ?? [];
            final bool loggedToday = logs.any((e) =>
                e is Map &&
                (e['isoDate']?.toString() == todayIso ||
                    e['date']?.toString() == todayIso));

            if (!loggedToday) {
              items.add(
                _NotificationItem(
                  id: 'sla_reminder_${lId}_$todayIso',
                  category: 'Exams & SLA',
                  title: 'Daily 60-Min Class Reminder: $lName',
                  body:
                      'Today\'s geoverified class for $lName has not been logged yet. Maintain regular sessions to avoid 120-hour inactivity escalation.',
                  timeLabel: 'Today\'s Schedule',
                  icon: Icons.timer_outlined,
                  accentColor: const Color(0xFFD97706),
                  badgeText: '120H SLA WATCH',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            LearnerCalendarScreen(learner: learner),
                      ),
                    );
                  },
                ),
              );
            }
          }
        }

        // Category: Super Admin Broadcasts (Mandatory ON)
        items.add(
          _NotificationItem(
            id: 'super_admin_broadcast_gps_policy',
            category: 'Broadcasts',
            title: 'Super Admin Broadcast — NCHD Compliance',
            body:
                'All 60-minute teaching sessions must lock real-time GPS coordinates at the learner\'s registered locality. Focal officers conduct unannounced spot audits.',
            timeLabel: 'Mandatory Directive',
            icon: Icons.campaign_rounded,
            accentColor: const Color(0xFF171717),
            badgeText: 'OFFICIAL BROADCAST',
          ),
        );

        return _buildNotificationListScaffold(
          items: items,
          readIds: readIds,
          docPath: docPath,
          filterTabs: const [
            'All',
            'Unread',
            'Enrollments',
            'Exams & SLA',
            'Broadcasts',
          ],
        );
      },
    );
  }

  // ===========================================================================
  // 2. INSTITUTIONAL FOCAL PERSON NOTIFICATIONS STREAM
  // ===========================================================================
  Widget _buildFocalNotificationsBody(BuildContext context) {
    final String email = (widget.focalEmail ??
            FirebaseAuth.instance.currentUser?.email ??
            'cust_focal@eoto.pk')
        .toLowerCase()
        .trim();
    final String docPath = 'focal_persons/$email';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('focal_persons')
          .doc(email)
          .snapshots(),
      builder: (context, focalSnap) {
        final Map<String, dynamic> focalDoc =
            (focalSnap.hasData && focalSnap.data!.exists)
                ? (focalSnap.data!.data() as Map<String, dynamic>? ?? {})
                : {};

        final Map<String, dynamic> prefs =
            (focalDoc['notificationPreferences'] as Map<String, dynamic>?) ??
                {};
        final bool showQueue =
            prefs['newTeacherVerificationQueue'] as bool? ?? true;
        final bool showSlaAlerts =
            prefs['inactivityAlerts120h'] as bool? ?? true;
        final bool showFinalAssessments =
            prefs['finalAssessmentReady'] as bool? ?? true;

        final List<dynamic> persistedRead =
            (focalDoc['readNotificationIds'] as List<dynamic>?) ?? [];
        final Set<String> readIds = {
          ...persistedRead.map((e) => e.toString()),
          ..._locallyReadIds,
        };

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('teachers')
              .where('assignedFocalPersonEmail', isEqualTo: email)
              .snapshots(),
          builder: (context, teachersSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('learners')
                  .where('assignedFocalPersonEmail', isEqualTo: email)
                  .snapshots(),
              builder: (context, learnersSnap) {
                final List<_NotificationItem> items = [];
                final now = DateTime.now();

                // 1. Teachers Queue & 120-Hour SLA Warnings
                if (teachersSnap.hasData) {
                  for (final doc in teachersSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final String st =
                        (data['status'] ?? '').toString().toLowerCase();
                    if (st == 'pending') {
                      final String tName =
                          (data['fullName'] ?? 'Applicant').toString();
                      final String district = (data['instituteName'] ??
                              data['district'] ??
                              'Jurisdiction')
                          .toString();
                      final Timestamp? ts = data['createdAt'] as Timestamp?;
                      final int elapsedHours = ts != null
                          ? now.difference(ts.toDate()).inHours
                          : 12;
                      final bool isUrgent = elapsedHours >= 96;

                      final Map<String, dynamic> appPayload = {
                        'id': doc.id,
                        'name': tName,
                        'role': data['role'] == 'student'
                            ? 'Student Teacher'
                            : 'Community Volunteer',
                        'district': data['district'] ?? 'N/A',
                        ...data,
                      };

                      if (isUrgent && showSlaAlerts) {
                        items.add(
                          _NotificationItem(
                            id: 'focal_sla_teacher_${doc.id}',
                            category: 'SLA & Audits',
                            title: '120-Hour SLA Warning: $tName',
                            body:
                                'Teacher application from $district has been pending for ${elapsedHours}h (<24h left before Super Admin auto-escalation).',
                            timeLabel: 'Urgent • <24h Left',
                            icon: Icons.warning_amber_rounded,
                            accentColor: const Color(0xFFEF4444),
                            badgeText: 'SLA CRITICAL',
                            isUrgent: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      TeacherReviewDetailScreen(
                                          applicant: appPayload),
                                ),
                              );
                            },
                          ),
                        );
                      }

                      if (showQueue) {
                        items.add(
                          _NotificationItem(
                            id: 'focal_queue_teacher_${doc.id}',
                            category: 'Verification Queue',
                            title: 'New Teacher Verification: $tName',
                            body:
                                '$tName ($district) submitted CNIC and academic credentials for verification.',
                            timeLabel: '${elapsedHours}h in queue',
                            icon: Icons.person_add_alt_1_rounded,
                            accentColor: const Color(0xFF16A34A),
                            badgeText: 'TEACHER QUEUE',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      TeacherReviewDetailScreen(
                                          applicant: appPayload),
                                ),
                              );
                            },
                          ),
                        );
                      }
                    }
                  }
                }

                // 2. Learners Queue, Flagged Sessions & Final Assessments
                if (learnersSnap.hasData) {
                  for (final doc in learnersSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final String lName =
                        (data['name'] ?? 'Learner').toString();
                    final String tName = (data['teacherName'] ??
                            data['assignedTeacherName'] ??
                            'Volunteer Teacher')
                        .toString();
                    final String status =
                        (data['status'] ?? '').toString();
                    final String statusLower = status.toLowerCase();
                    final int classesTaught =
                        (data['classesTaught'] as num?)?.toInt() ?? 0;

                    final Map<String, dynamic> learnerPayload = {
                      'id': doc.id,
                      ...data,
                    };

                    // Pending Learner Baseline Review
                    if (statusLower == 'pending review' && showQueue) {
                      final Timestamp? ts = data['createdAt'] as Timestamp?;
                      final int elapsedHours = ts != null
                          ? now.difference(ts.toDate()).inHours
                          : 6;

                      items.add(
                        _NotificationItem(
                          id: 'focal_queue_learner_${doc.id}',
                          category: 'Verification Queue',
                          title: 'Baseline Review Pending: $lName',
                          body:
                              'Teacher $tName uploaded the diagnostic baseline assessment for learner $lName. Tap to inspect and approve.',
                          timeLabel: '${elapsedHours}h in queue',
                          icon: Icons.fact_check_rounded,
                          accentColor: const Color(0xFF2563EB),
                          badgeText: 'LEARNER QUEUE',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LearnerReviewDetailScreen(
                                  learner: learnerPayload,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }

                    // Final Assessment Ready (Week 12 / 36 Sessions / Exam Scheduled)
                    if (showFinalAssessments &&
                        (status == 'Week 12 Completed' ||
                            status == 'Exam Scheduled' ||
                            (status == 'Active' && classesTaught >= 36))) {
                      items.add(
                        _NotificationItem(
                          id: 'focal_exam_ready_${doc.id}',
                          category: 'Exams',
                          title: 'Final Assessment Ready: $lName',
                          body:
                              'Learner $lName (Teacher: $tName) has completed $classesTaught/36 classes. Ready for Final Exam scheduling & grading.',
                          timeLabel: status == 'Exam Scheduled'
                              ? 'Exam Scheduled'
                              : 'Week 12 Completed',
                          icon: Icons.school_rounded,
                          accentColor: const Color(0xFF7C3AED),
                          badgeText: 'FINAL EXAM',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FocalExamSchedulerScreen(
                                  learner: learnerPayload,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }

                    // Check for Flagged Sessions in sessionLogs
                    if (showSlaAlerts) {
                      final List<dynamic> logs =
                          (data['sessionLogs'] as List<dynamic>?) ?? [];
                      for (final log in logs) {
                        if (log is Map && log['flagged'] == true) {
                          final String dateStr =
                              (log['date'] ?? log['isoDate'] ?? 'Recent')
                                  .toString();
                          items.add(
                            _NotificationItem(
                              id: 'focal_flagged_${doc.id}_$dateStr',
                              category: 'SLA & Audits',
                              title: 'Flagged Session Audit: $lName',
                              body:
                                  'Session on $dateStr (Teacher: $tName) was flagged for GPS/content audit.',
                              timeLabel: 'Field Audit Flag',
                              icon: Icons.flag_rounded,
                              accentColor: const Color(0xFFEF4444),
                              badgeText: 'FLAGGED SESSION',
                              isUrgent: true,
                            ),
                          );
                        }
                      }
                    }
                  }
                }

                // 3. Super Admin Broadcasts (Mandatory ON)
                items.add(
                  _NotificationItem(
                    id: 'focal_super_admin_broadcast_sla',
                    category: 'Broadcasts',
                    title: 'Super Admin Directive — 120-Hour SLA',
                    body:
                        'All Student-Teacher and Learner Baseline verifications must be completed within 120 hours to prevent automatic escalation to NCHD Headquarters.',
                    timeLabel: 'Mandatory Policy',
                    icon: Icons.campaign_rounded,
                    accentColor: const Color(0xFF065F46),
                    badgeText: 'SUPER ADMIN',
                  ),
                );

                return _buildNotificationListScaffold(
                  items: items,
                  readIds: readIds,
                  docPath: docPath,
                  filterTabs: const [
                    'All',
                    'Unread',
                    'Verification Queue',
                    'SLA & Audits',
                    'Exams',
                    'Broadcasts',
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // SHARED UI BUILDER FOR NOTIFICATIONS FEED
  // ===========================================================================
  Widget _buildNotificationListScaffold({
    required List<_NotificationItem> items,
    required Set<String> readIds,
    required String? docPath,
    required List<String> filterTabs,
  }) {
    final List<String> allIds = items.map((e) => e.id).toList();
    final int unreadCount = _markedAllRead
        ? 0
        : items.where((item) => !readIds.contains(item.id)).length;

    final List<_NotificationItem> filteredItems = items.where((item) {
      final bool isRead = _markedAllRead || readIds.contains(item.id);
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Unread') return !isRead;
      return item.category == _selectedFilter;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Summary Banner + Mark All Read CTA
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: unreadCount > 0
                              ? const Color(0xFFCCFF00)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          unreadCount > 0
                              ? '$unreadCount NEW ALERTS'
                              : 'ALL CAUGHT UP',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${items.length} Total',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (unreadCount > 0)
                    GestureDetector(
                      onTap: () => _markAllAsRead(allIds, docPath),
                      child: const Row(
                        children: [
                          Icon(Icons.done_all_rounded,
                              size: 16, color: Color(0xFF171717)),
                          SizedBox(width: 4),
                          Text(
                            'Mark all read',
                            style: TextStyle(
                              color: Color(0xFF171717),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: filterTabs.map((tab) {
                    final bool isSelected = _selectedFilter == tab;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedFilter = tab),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF171717)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tab,
                            style: TextStyle(
                              color:
                                  isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: const Color(0xFFE5E7EB)),

        // Notifications List
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3F4F6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_off_outlined,
                            color: Color(0xFF9CA3AF),
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _selectedFilter == 'Unread'
                              ? 'No Unread Notifications'
                              : 'No Notifications in "$_selectedFilter"',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF171717),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'You are completely up to date with your EOTO alerts and official broadcasts.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF6B7280),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18.0, vertical: 14.0),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    final bool isRead =
                        _markedAllRead || readIds.contains(item.id);

                    return GestureDetector(
                      onTap: () {
                        _markSingleRead(item.id, docPath);
                        if (item.onTap != null) {
                          item.onTap!();
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isRead
                              ? Colors.white
                              : const Color(0xFFFDFEF9),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: item.isUrgent
                                ? const Color(0xFFFECACA)
                                : isRead
                                    ? const Color(0xFFE5E7EB)
                                    : const Color(0xFFCCFF00),
                            width: isRead ? 1.0 : 1.6,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon Badge
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: item.accentColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.icon,
                                color: item.accentColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Content Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: item.accentColor
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          item.badgeText,
                                          style: TextStyle(
                                            color: item.accentColor,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            item.timeLabel,
                                            style: const TextStyle(
                                              color: Color(0xFF9CA3AF),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (!isRead) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFEF4444),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      color: const Color(0xFF171717),
                                      fontSize: 14.5,
                                      fontWeight: isRead
                                          ? FontWeight.w700
                                          : FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.body,
                                    style: const TextStyle(
                                      color: Color(0xFF4B5563),
                                      fontSize: 12.5,
                                      height: 1.4,
                                    ),
                                  ),
                                  if (item.onTap != null) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Text(
                                          'Tap to open',
                                          style: TextStyle(
                                            color: item.accentColor,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 13,
                                          color: item.accentColor,
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _NotificationItem {
  final String id;
  final String category;
  final String title;
  final String body;
  final String timeLabel;
  final IconData icon;
  final Color accentColor;
  final String badgeText;
  final bool isUrgent;
  final VoidCallback? onTap;

  _NotificationItem({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.icon,
    required this.accentColor,
    required this.badgeText,
    this.isUrgent = false,
    this.onTap,
  });
}

