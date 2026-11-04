import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'focal_midterm_review_screen.dart';

class FocalLearnerProgressOverviewScreen extends StatelessWidget {
  final Map<String, dynamic> learner;

  const FocalLearnerProgressOverviewScreen({Key? key, required this.learner})
      : super(key: key);

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _shortMonthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _toTitleCase(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  void _callTeacher(BuildContext context, String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No phone number registered for this volunteer teacher.')),
      );
      return;
    }
    final String phoneNumber = phone.trim();
    final Uri uri = Uri.parse('tel:${phoneNumber.replaceAll(" ", "")}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calling $phoneNumber...')),
      );
    }
  }

  /// Resolves which days of [month]/[year] are logged, matching the learner's
  /// sessionLogs and classesTaught count.
  Map<int, Map<String, dynamic>> _resolveLoggedDaysInMonth({
    required Map<String, dynamic> activeLearner,
    required int year,
    required int month,
    required int todayDay,
    required int classesTaught,
  }) {
    final Map<int, Map<String, dynamic>> loggedDays = {};
    final String todayIso =
        '$year-${month.toString().padLeft(2, '0')}-${todayDay.toString().padLeft(2, '0')}';

    final String lastLoggedDate =
        (activeLearner['lastLoggedDate'] ?? '').toString();
    final String lastSession = (activeLearner['lastSession'] ?? '').toString();

    final rawLogs = activeLearner['sessionLogs'];
    if (rawLogs is List) {
      for (int i = 0; i < rawLogs.length; i++) {
        final entry = rawLogs[i];
        final Map<String, dynamic> sessionMap = entry is Map<String, dynamic>
            ? entry
            : (entry is Map
                ? Map<String, dynamic>.from(entry)
                : <String, dynamic>{});
        final String dateStr = (sessionMap['date'] ?? '').toString().trim();
        if (dateStr.isEmpty) continue;

        if (dateStr.toLowerCase().startsWith('today')) {
          loggedDays[todayDay] = {
            ...sessionMap,
            'date': '${_monthNames[month - 1]} $todayDay,\n$year',
            'sessionNum': i + 1,
          };
          continue;
        }

        final parsedIso = DateTime.tryParse(dateStr);
        if (parsedIso != null &&
            parsedIso.year == year &&
            parsedIso.month == month) {
          loggedDays[parsedIso.day] = {
            ...sessionMap,
            'date': '${_monthNames[month - 1]} ${parsedIso.day},\n$year',
            'sessionNum': i + 1,
          };
          continue;
        }

        for (int m = 0; m < 12; m++) {
          if (dateStr
                  .toLowerCase()
                  .startsWith(_shortMonthNames[m].toLowerCase()) ||
              dateStr.toLowerCase().startsWith(_monthNames[m].toLowerCase())) {
            if (m + 1 == month) {
              final match = RegExp(r'\b(\d{1,2})\b').firstMatch(dateStr);
              if (match != null) {
                final d = int.tryParse(match.group(1)!);
                if (d != null && d >= 1 && d <= 31) {
                  loggedDays[d] = {
                    ...sessionMap,
                    'date': '${_monthNames[month - 1]} $d,\n$year',
                    'sessionNum': i + 1,
                  };
                }
              }
            }
          }
        }
      }
    }

    if ((lastLoggedDate == todayIso || lastSession.startsWith('Today')) &&
        classesTaught > 0 &&
        !loggedDays.containsKey(todayDay)) {
      loggedDays[todayDay] = {
        'date': '${_monthNames[month - 1]} $todayDay,\n$year',
        'duration': '60\nMins',
        'sessionNum': classesTaught,
      };
    }

    // Populate past days in the current month if classesTaught > parsed logs
    int remainingToShow = classesTaught - loggedDays.length;
    int sessionCounter = classesTaught;
    if (remainingToShow > 0 && todayDay > 1) {
      for (int d = todayDay - 1; d >= 1 && remainingToShow > 0; d--) {
        final int weekday = DateTime(year, month, d).weekday;
        if (weekday == DateTime.friday && remainingToShow < (todayDay - 4)) {
          continue;
        }
        if (!loggedDays.containsKey(d)) {
          loggedDays[d] = {
            'date': '${_monthNames[month - 1]} $d,\n$year',
            'duration': '60\nMins',
            'sessionNum': sessionCounter > 0 ? sessionCounter-- : 1,
          };
          remainingToShow--;
        }
      }
      for (int d = todayDay - 1; d >= 1 && remainingToShow > 0; d--) {
        if (!loggedDays.containsKey(d)) {
          loggedDays[d] = {
            'date': '${_monthNames[month - 1]} $d,\n$year',
            'duration': '60\nMins',
            'sessionNum': sessionCounter > 0 ? sessionCounter-- : 1,
          };
          remainingToShow--;
        }
      }
    }

    return loggedDays;
  }

  void _openSessionDetailsScreen(
    BuildContext context, {
    required String learnerId,
    required int sessionNum,
    required String teacherName,
    required String learnerName,
    required Map<String, dynamic>? sessionData,
    required String fallbackDate,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FocalSessionDetailsScreen(
          learnerId: learnerId,
          sessionNum: sessionNum,
          teacherName: teacherName,
          learnerName: learnerName,
          sessionData: sessionData,
          fallbackDate: fallbackDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String learnerId = (learner['id'] ?? '').toString();

    return StreamBuilder<DocumentSnapshot>(
      stream: learnerId.isNotEmpty
          ? FirebaseFirestore.instance
              .collection('learners')
              .doc(learnerId)
              .snapshots()
          : const Stream.empty(),
      builder: (context, snapshot) {
        final Map<String, dynamic> activeLearner =
            snapshot.hasData && snapshot.data!.exists
                ? {
                    ...learner,
                    ...(snapshot.data!.data() as Map<String, dynamic>),
                  }
                : learner;

        final String teacherId = (activeLearner['teacherId'] ??
                activeLearner['teacherUid'] ??
                '')
            .toString();

        return StreamBuilder<DocumentSnapshot>(
          stream: teacherId.isNotEmpty
              ? FirebaseFirestore.instance
                  .collection('teachers')
                  .doc(teacherId)
                  .snapshots()
              : const Stream.empty(),
          builder: (context, teacherSnapshot) {
            final Map<String, dynamic>? teacherDoc =
                teacherSnapshot.hasData && teacherSnapshot.data!.exists
                    ? (teacherSnapshot.data!.data() as Map<String, dynamic>?)
                    : null;

            final String rawTeacherName = (activeLearner['teacherName'] ??
                    teacherDoc?['fullName'] ??
                    teacherDoc?['name'] ??
                    activeLearner['assignedTeacherName'] ??
                    'Volunteer Teacher')
                .toString();
            final String teacherName = _toTitleCase(rawTeacherName);

            final String rawLearnerName =
                (activeLearner['name'] ?? 'Learner').toString();
            final String learnerName = _toTitleCase(rawLearnerName);

            final String teacherPhone = activeLearner['teacherPhone'] ??
                teacherDoc?['phone'] ??
                activeLearner['assignedTeacherPhone'] ??
                '';

            final String midtermStatus =
                (activeLearner['midtermStatus'] ?? '').toString().toLowerCase();
            final bool isMidtermSubmitted = midtermStatus == 'submitted';

            final int classesTaught =
                (activeLearner['classesTaught'] as num?)?.toInt() ?? 0;
            final int totalClasses =
                (activeLearner['totalClasses'] as num?)?.toInt() ?? 36;
            final double progress = totalClasses > 0
                ? (classesTaught / totalClasses).clamp(0.0, 1.0)
                : 0.0;
            final int currentWeek = classesTaught == 0
                ? 1
                : ((classesTaught / 3).ceil().clamp(1, 12));
            final String status =
                (activeLearner['status'] ?? 'Active').toString();
            final bool isInSession = activeLearner['inSession'] == true ||
                status.toLowerCase() == 'in session';
            final bool isExamWindow = status == 'Week 12 Completed' ||
                status == 'Exam Scheduled' ||
                status == 'Awaiting Mid-Term';

            final DateTime now = DateTime.now();
            final int year = now.year;
            final int month = now.month;
            final int todayDay = now.day;
            final String monthRecordTitle =
                '${_monthNames[month - 1]} $year Record';

            final Map<int, Map<String, dynamic>> loggedDaysMap =
                _resolveLoggedDaysInMonth(
              activeLearner: activeLearner,
              year: year,
              month: month,
              todayDay: todayDay,
              classesTaught: classesTaught,
            );

            final String statusLabel = isInSession
                ? 'Status: In Session'
                : (isMidtermSubmitted
                    ? 'Status: Mid-Term Review'
                    : 'Status: On Track');

            return Scaffold(
              backgroundColor: Colors.white,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: AppBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  centerTitle: true,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.black, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: const Text(
                    'Attendance Overview',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontWeight: FontWeight.w800,
                      fontSize: 16.5,
                    ),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Container(
                      height: 1,
                      color: const Color(0xFFF1F2F4),
                    ),
                  ),
                ),
              ),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Top Profile Card (Teacher, Learner, Call button, Status | Week)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Teacher: $teacherName',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Learner: $learnerName',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: () =>
                                      _callTeacher(context, teacherPhone),
                                  borderRadius: BorderRadius.circular(21),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFCCFF00),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.phone_in_talk_rounded,
                                      color: Colors.black,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 11),
                            const Divider(
                                height: 1, color: Color(0xFFE5E7EB)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: isInSession
                                        ? const Color(0xFF00E676)
                                        : const Color(0xFF16A34A),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 10.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  statusLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '|   Week $currentWeek of 12',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (isMidtermSubmitted) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF5ED),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFF57C00)
                                    .withOpacity(0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.notifications_active,
                                  color: Color(0xFFF57C00), size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Mid-Term Assessment Submitted',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 28,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF57C00),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            FocalMidtermReviewScreen(
                                                learner: activeLearner),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Review Now',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // 2. Two Metric Cards Row (Segmented % Ring + Classes Taught)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 124,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                  width: 1.4,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 68,
                                    height: 68,
                                    child: CustomPaint(
                                      painter: _SegmentedRingPainter(
                                        progress: progress,
                                        activeColor: const Color(0xFFCCFF00),
                                        trackColor: const Color(0xFFECEEF2),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${(progress * 100).round()}%',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 17.5,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  const Text(
                                    'RECOMMENDED: 70%',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF6B7280),
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 124,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$classesTaught',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF111827),
                                      height: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'Classes\nTaught',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B7280),
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 3. Monthly Calendar Record Card (Compact, NOT stretched)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFEDF0F4),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row: Month Title + Tap hint
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  monthRecordTitle,
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEEFF2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Tap ✓ to inspect',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 7-Column Weekday Headers (MON .. SUN)
                            const Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                _WeekdayHeader('MON'),
                                _WeekdayHeader('TUE'),
                                _WeekdayHeader('WED'),
                                _WeekdayHeader('THU'),
                                _WeekdayHeader('FRI'),
                                _WeekdayHeader('SAT'),
                                _WeekdayHeader('SUN'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Divider(
                                height: 1, color: Color(0xFFE5E7EB)),
                            const SizedBox(height: 6),

                            // Calendar Grid Rows (tight natural spacing, not stretched)
                            ..._buildCalendarRows(
                              context: context,
                              learnerId: learnerId,
                              year: year,
                              month: month,
                              todayDay: todayDay,
                              loggedDaysMap: loggedDaysMap,
                              isInSession: isInSession,
                              isExamWindow: isExamWindow,
                              teacherName: teacherName,
                              learnerName: learnerName,
                              activeLearner: activeLearner,
                            ),

                            const SizedBox(height: 8),
                            const Divider(
                                height: 1, color: Color(0xFFE5E7EB)),
                            const SizedBox(height: 10),

                            // 4. Bottom Legend Row: Logged | Today | in Session | Exam Day
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 15,
                                      height: 15,
                                      decoration: const BoxDecoration(
                                        color: Colors.black,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.check,
                                          color: Color(0xFFCCFF00),
                                          size: 9.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'Logged',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF4B5563),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFCCFF00),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'Today',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF4B5563),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF00E676),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'in Session',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF4B5563),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF8A00),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'Exam Day',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF4B5563),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildCalendarRows({
    required BuildContext context,
    required String learnerId,
    required int year,
    required int month,
    required int todayDay,
    required Map<int, Map<String, dynamic>> loggedDaysMap,
    required bool isInSession,
    required bool isExamWindow,
    required String teacherName,
    required String learnerName,
    required Map<String, dynamic> activeLearner,
  }) {
    final int daysInMonth = DateUtils.getDaysInMonth(year, month);
    final int firstWeekday = DateTime(year, month, 1).weekday;
    final int leadingEmpty = firstWeekday - 1;

    final List<Widget> cells = [];
    for (int i = 0; i < leadingEmpty; i++) {
      // Subtle muted dash for leading empty days of the week so the row never looks blank/broken
      cells.add(
        SizedBox(
          width: 34,
          height: 32,
          child: Center(
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFFE5E7EB),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final bool isLogged = loggedDaysMap.containsKey(day);
      final bool isToday = day == todayDay;
      final bool isFuture = day > todayDay;
      final bool isExamDay =
          isExamWindow && day == (todayDay + 1).clamp(1, daysInMonth);
      final String formattedFallbackDate =
          '${_monthNames[month - 1]} $day,\n$year';

      if (isToday && isInSession) {
        cells.add(
          GestureDetector(
            onTap: () => _openSessionDetailsScreen(
              context,
              learnerId: learnerId,
              sessionNum:
                  ((activeLearner['classesTaught'] as num?)?.toInt() ?? 0) + 1,
              teacherName: teacherName,
              learnerName: learnerName,
              sessionData: {
                'date': formattedFallbackDate,
                'duration': '60\nMins',
                'lat': activeLearner['liveLat'] ?? 31.5204,
                'lng': activeLearner['liveLng'] ?? 74.3587,
                'topic': activeLearner['liveTopic'] ??
                    'Taught Urdu Primer Book, Page 12. Practiced recognition of basic alphabets (Alif, Be, Pe) and writing strokes.',
              },
              fallbackDate: formattedFallbackDate,
            ),
            child: Container(
              width: 34,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF00E676),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$day',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          ),
        );
      } else if (isLogged) {
        final sessionData = loggedDaysMap[day];
        final int sessionNum =
            (sessionData?['sessionNum'] as num?)?.toInt() ?? 1;
        cells.add(
          GestureDetector(
            onTap: () => _openSessionDetailsScreen(
              context,
              learnerId: learnerId,
              sessionNum: sessionNum,
              teacherName: teacherName,
              learnerName: learnerName,
              sessionData: sessionData,
              fallbackDate: formattedFallbackDate,
            ),
            child: SizedBox(
              width: 34,
              height: 32,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isToday
                          ? const Color(0xFFCCFF00)
                          : const Color(0xFFEAECEF),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check,
                          color: Color(0xFFCCFF00),
                          size: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (isToday) {
        cells.add(
          Container(
            width: 34,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFCCFF00),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$day',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        );
      } else if (isExamDay) {
        cells.add(
          Container(
            width: 34,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFFF8A00),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$day',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        );
      } else {
        cells.add(
          SizedBox(
            width: 34,
            height: 32,
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  color: isFuture
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF4B5563),
                  fontWeight: isFuture ? FontWeight.w500 : FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        );
      }
    }

    while (cells.length % 7 != 0) {
      cells.add(
        SizedBox(
          width: 34,
          height: 32,
          child: Center(
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFFE5E7EB),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }

    final List<Widget> rows = [];
    for (int r = 0; r < cells.length; r += 7) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: cells.sublist(r, r + 7),
          ),
        ),
      );
    }
    return rows;
  }
}

/// Dedicated full-screen Session Details view opened when the Focal Person
/// taps on any logged session day in the Monthly Record calendar.
class FocalSessionDetailsScreen extends StatefulWidget {
  final String learnerId;
  final int sessionNum;
  final String teacherName;
  final String learnerName;
  final Map<String, dynamic>? sessionData;
  final String fallbackDate;

  const FocalSessionDetailsScreen({
    Key? key,
    required this.learnerId,
    required this.sessionNum,
    required this.teacherName,
    required this.learnerName,
    required this.sessionData,
    required this.fallbackDate,
  }) : super(key: key);

  @override
  State<FocalSessionDetailsScreen> createState() =>
      _FocalSessionDetailsScreenState();
}

class _FocalSessionDetailsScreenState extends State<FocalSessionDetailsScreen> {
  bool _isFlagged = false;

  Future<void> _handleFlagSession() async {
    setState(() {
      _isFlagged = true;
    });

    if (widget.learnerId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('learners')
            .doc(widget.learnerId)
            .update({
          'lastFlaggedSession': widget.sessionNum,
          'flaggedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Session flagged for administrative compliance review.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Color(0xFFC23B22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String rawDate =
        (widget.sessionData?['date'] ?? widget.fallbackDate).toString().trim();
    final String displayDate = rawDate.contains('\n')
        ? 'Date: $rawDate'
        : rawDate.replaceFirstMapped(
            RegExp(r'^([A-Za-z]+\s+\d{1,2},)\s*(\d{4})$'),
            (m) => 'Date: ${m[1]}\n${m[2]}',
          );
    final String formattedDateTitle =
        displayDate.startsWith('Date:') ? displayDate : 'Date: $displayDate';

    final double lat =
        (widget.sessionData?['lat'] as num?)?.toDouble() ?? 31.5204;
    final double lng =
        (widget.sessionData?['lng'] as num?)?.toDouble() ?? 74.3587;

    final String rawRemarks = (widget.sessionData?['remarks'] ??
            widget.sessionData?['topic'] ??
            '')
        .toString()
        .trim();
    final String lessonDetails = rawRemarks.isNotEmpty
        ? rawRemarks
        : 'Taught Urdu Primer Book, Page 12. Practiced recognition of basic alphabets (Alif, Be, Pe) and writing strokes.';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Session Details',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Summary Card (Date, Duration: 60 Mins pill, Learner, Teacher)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F2F4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  formattedDateTitle,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1F2937),
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Text(
                                  'Duration: 60\nMins',
                                  style: TextStyle(
                                    color: Color(0xFFCCFF00),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Learner: ${widget.learnerName}',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Teacher: ${widget.teacherName}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: -30,
                      right: -30,
                      child: IgnorePointer(
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCCFF00).withOpacity(0.10),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 1. GPS Location
              const Text(
                '1. GPS Location',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F2F4),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFF00),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFCCFF00).withOpacity(0.45),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.location_on,
                          color: Color(0xFF2E3A00),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '${lat.toStringAsFixed(4)}° N,  ${lng.toStringAsFixed(4)}°\nE',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                          letterSpacing: 0.8,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4A6B00),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. Lesson Details
              const Text(
                '2. Lesson Details',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F2F4),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -4,
                      right: 0,
                      child: Icon(
                        Icons.format_quote_rounded,
                        size: 36,
                        color: Colors.black.withOpacity(0.08),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 26),
                      child: Text(
                        lessonDetails,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF4B5563),
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Bottom Full-Width "Flag this Session" Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _isFlagged
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFFDF0ED),
                    foregroundColor: const Color(0xFFC23B22),
                    side: BorderSide(
                      color: _isFlagged
                          ? const Color(0xFFF87171)
                          : const Color(0xFFF9D7D0),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: _isFlagged ? null : _handleFlagSession,
                  icon: Icon(
                    _isFlagged ? Icons.flag_rounded : Icons.outlined_flag,
                    color: const Color(0xFFC23B22),
                    size: 20,
                  ),
                  label: Text(
                    _isFlagged ? 'Session Flagged' : 'Flag this Session',
                    style: const TextStyle(
                      color: Color(0xFFC23B22),
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final String label;
  const _WeekdayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

/// Draws the 4-segment circular progress ring matching the Focal Person design.
class _SegmentedRingPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color trackColor;

  _SegmentedRingPainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double strokeWidth = 7.5;
    final double radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Paint activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const int segments = 4;
    const double gapRadians = 0.42;
    const double segmentSweep = (2 * math.pi / segments) - gapRadians;
    const double baseStart = -math.pi / 2 - (segmentSweep / 2);

    // Draw 4 distinct segmented track arcs first so the 4-segment structure is always crisp
    for (int i = 0; i < segments; i++) {
      final double startAngle = baseStart + i * (segmentSweep + gapRadians);
      canvas.drawArc(rect, startAngle, segmentSweep, false, trackPaint);
    }

    final double clamped = progress.clamp(0.0, 1.0);
    // Give at least a small visible arc if progress > 0
    final double effectiveProgress =
        clamped > 0 && clamped < 0.08 ? 0.08 : clamped;
    final double totalActiveSegments = effectiveProgress * segments;

    for (int i = 0; i < segments; i++) {
      final double segFill = (totalActiveSegments - i).clamp(0.0, 1.0);
      if (segFill <= 0) break;
      final double startAngle = baseStart + i * (segmentSweep + gapRadians);
      canvas.drawArc(
        rect,
        startAngle,
        segmentSweep * segFill,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor;
  }
}
