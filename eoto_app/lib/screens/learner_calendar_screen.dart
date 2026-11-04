import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../controllers/registration_controller.dart';
import 'class_logging_screen.dart';
import 'midterm_assessment_screen.dart';
import 'baseline_assessment_screen.dart';
import 'final_exam_ticket_widget.dart';
import 'learner_pending_status_screen.dart';

class LearnerCalendarScreen extends StatefulWidget {
  final Map<String, dynamic> learner;

  const LearnerCalendarScreen({Key? key, required this.learner}) : super(key: key);

  @override
  State<LearnerCalendarScreen> createState() => _LearnerCalendarScreenState();
}

class _LearnerCalendarScreenState extends State<LearnerCalendarScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Extracts completed days of the given [year] and [month] from sessionLogs,
  /// and if classesTaught > parsed logs in the current month, distributes past
  /// completed days visually across earlier days of the month so the calendar
  /// matches the learner's classesTaught count.
  Set<int> _resolveCompletedDaysInMonth({
    required Map<String, dynamic> currentLearner,
    required int year,
    required int month,
    required int todayDay,
    required int classesTaught,
  }) {
    final Set<int> completedDays = {};
    final String todayIso =
        '$year-${month.toString().padLeft(2, '0')}-${todayDay.toString().padLeft(2, '0')}';

    // Check lastLoggedDate or lastSession
    final String lastLoggedDate = (currentLearner['lastLoggedDate'] ?? '').toString();
    final String lastSession = (currentLearner['lastSession'] ?? '').toString();
    if (lastLoggedDate == todayIso || lastSession.startsWith('Today')) {
      if (classesTaught > 0) {
        completedDays.add(todayDay);
      }
    }

    // Parse sessionLogs array
    final rawLogs = currentLearner['sessionLogs'];
    if (rawLogs is List) {
      for (final entry in rawLogs) {
        String dateStr = '';
        if (entry is Map) {
          dateStr = (entry['date'] ?? '').toString().trim();
        } else {
          try {
            dateStr = (entry.date ?? '').toString().trim();
          } catch (_) {}
        }
        if (dateStr.isEmpty) continue;

        if (dateStr.toLowerCase().startsWith('today')) {
          completedDays.add(todayDay);
          continue;
        }

        // Try ISO YYYY-MM-DD
        final parsedIso = DateTime.tryParse(dateStr);
        if (parsedIso != null && parsedIso.year == year && parsedIso.month == month) {
          completedDays.add(parsedIso.day);
          continue;
        }

        // Try "May 28, 2026" style
        for (int m = 0; m < 12; m++) {
          if (dateStr.toLowerCase().startsWith(_shortMonthNames[m].toLowerCase()) ||
              dateStr.toLowerCase().startsWith(_monthNames[m].toLowerCase())) {
            if (m + 1 == month) {
              final match = RegExp(r'\b(\d{1,2})\b').firstMatch(dateStr);
              if (match != null) {
                final d = int.tryParse(match.group(1)!);
                if (d != null && d >= 1 && d <= 31) {
                  completedDays.add(d);
                }
              }
            }
          }
        }
      }
    }

    // If classesTaught is greater than the number of parsed days in this month,
    // populate past teaching days (prior to todayDay) so the visual checkmarks
    // reflect classesTaught accurately.
    int remainingToShow = classesTaught - completedDays.length;
    if (remainingToShow > 0 && todayDay > 1) {
      // Pick past days in reverse from (todayDay - 1) down to 1, skipping every 2nd day for a realistic cadence
      for (int d = todayDay - 1; d >= 1 && remainingToShow > 0; d -= 2) {
        if (!completedDays.contains(d)) {
          completedDays.add(d);
          remainingToShow--;
        }
      }
      // If still remaining (e.g., early in the month), fill remaining past days
      for (int d = todayDay - 1; d >= 1 && remainingToShow > 0; d--) {
        if (!completedDays.contains(d)) {
          completedDays.add(d);
          remainingToShow--;
        }
      }
    }

    return completedDays;
  }

  @override
  Widget build(BuildContext context) {
    final String learnerId = (widget.learner['id'] ?? '').toString();

    return StreamBuilder<DocumentSnapshot>(
      stream: learnerId.isNotEmpty
          ? FirebaseFirestore.instance.collection('learners').doc(learnerId).snapshots()
          : null,
      builder: (context, firestoreSnap) {
        return Consumer<RegistrationController>(
          builder: (context, controller, child) {
            // Merge controller state + live Firestore snapshot so updates are instant
            Map<String, dynamic> currentLearner = controller.learners.firstWhere(
              (l) => l['id'] == learnerId,
              orElse: () => widget.learner,
            );
            if (firestoreSnap.hasData && firestoreSnap.data!.exists) {
              final liveData = firestoreSnap.data!.data() as Map<String, dynamic>;
              currentLearner = {
                ...currentLearner,
                ...liveData,
                'id': learnerId,
              };
            }

            final String learnerName = (currentLearner['name'] ?? 'Learner').toString();
            final String status = (currentLearner['status'] ?? 'Active').toString();
            final String statusLower = status.toLowerCase();

            final bool isPendingReview =
                statusLower.contains('review') || statusLower.contains('pending');
            final bool isRejected =
                statusLower.contains('reject') || statusLower.contains('suspend');
            final bool isAwaitingBaseline = statusLower == 'awaiting baseline';

            if (isPendingReview) {
              return LearnerPendingStatusScreen(learner: currentLearner);
            }

            final int classesTaught =
                (currentLearner['classesTaught'] as num?)?.toInt() ?? 0;
            final int currentWeek =
                classesTaught == 0 ? 1 : ((classesTaught / 3).ceil()).clamp(1, 12);

            final bool isAwaitingMidterm = status == 'Awaiting Mid-Term' ||
                (classesTaught == 18 &&
                    (currentLearner['midtermStatus'] ?? '').toString().toLowerCase() !=
                        'approved' &&
                    (currentLearner['midtermStatus'] ?? '').toString().toLowerCase() !=
                        'submitted');
            final bool isWeek12Completed = status == 'Week 12 Completed';
            final bool isExamScheduled = status == 'Exam Scheduled';
            final bool isCompleted = status == 'Completed';
            final bool isCertified = status == 'Certified';

            final DateTime now = DateTime.now();
            final int year = now.year;
            final int month = now.month;
            final int todayDay = now.day;
            final String monthTitle = '${_monthNames[month - 1]} $year';
            final String shortTodayStr = '${_shortMonthNames[month - 1]} $todayDay';

            final Set<int> completedDays = _resolveCompletedDaysInMonth(
              currentLearner: currentLearner,
              year: year,
              month: month,
              todayDay: todayDay,
              classesTaught: classesTaught,
            );

            final bool isTodayLogged = completedDays.contains(todayDay);
            final bool isClassInProgress =
                controller.isClassActive && controller.activeLearnerId == learnerId;

            return Scaffold(
              backgroundColor: Colors.white,
              // 1. Header Navigation & Identification
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      learnerName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Class Progress Tracker',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              body: SafeArea(
                child: isRejected
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _buildRejectedCard(context, currentLearner),
                      )
                    : isAwaitingBaseline
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: _buildAwaitingBaselineCard(context, currentLearner),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 22.0, vertical: 6.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 2. Active Cycle & Classes Taught Card
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F4F6),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 2.5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.06),
                                                      borderRadius:
                                                          BorderRadius.circular(8),
                                                    ),
                                                    child: const Text(
                                                      'ACTIVE CYCLE',
                                                      style: TextStyle(
                                                        fontSize: 8.5,
                                                        fontWeight: FontWeight.w900,
                                                        color: Colors.black87,
                                                        letterSpacing: 0.8,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'Learner: $learnerName',
                                                    style: const TextStyle(
                                                      fontSize: 16.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFF1F2937),
                                                      height: 1.15,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    'Week $currentWeek of 12',
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      color: Colors.grey[600],
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Vibrant Neon Lime-Yellow Badge (#CCFF00)
                                            Container(
                                              padding: const EdgeInsets.all(3.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFCCFF00)
                                                    .withOpacity(0.32),
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFCCFF00),
                                                  borderRadius:
                                                      BorderRadius.circular(26),
                                                ),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      '$classesTaught',
                                                      style: const TextStyle(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.w900,
                                                        color: Colors.black,
                                                        height: 1.05,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 1),
                                                    const Text(
                                                      'CLASSES TAUGHT',
                                                      style: TextStyle(
                                                        fontSize: 8,
                                                        fontWeight: FontWeight.w900,
                                                        color: Colors.black,
                                                        letterSpacing: 0.4,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      // 3. Monthly Attendance Calendar Grid
                                      Text(
                                        monthTitle,
                                        style: const TextStyle(
                                          fontSize: 18.5,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // 7-Column Day Headers
                                      const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          SizedBox(
                                            width: 40,
                                            child: Center(
                                              child: Text(
                                                'MO',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 40,
                                            child: Center(
                                              child: Text(
                                                'TU',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 40,
                                            child: Center(
                                              child: Text(
                                                'WE',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 40,
                                            child: Center(
                                              child: Text(
                                                'TH',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 40,
                                            child: Center(
                                              child: Text(
                                                'FR',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 40,
                                            child: Center(
                                              child: Text(
                                                'SA',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 40,
                                            child: Center(
                                              child: Text(
                                                'SU',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // Dynamic Monthly Calendar Rows
                                      ..._buildCalendarRows(
                                        context: context,
                                        year: year,
                                        month: month,
                                        todayDay: todayDay,
                                        completedDays: completedDays,
                                        isExamWindowActive:
                                            isAwaitingMidterm || isWeek12Completed || isExamScheduled,
                                        currentLearner: currentLearner,
                                      ),

                                      const SizedBox(height: 12),

                                      // 4. Calendar Legend (Completed, Today, Locked, Exam Window)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4.0),
                                        child: Wrap(
                                          alignment: WrapAlignment.center,
                                          spacing: 16,
                                          runSpacing: 10,
                                          children: [
                                            // Completed
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 14,
                                                  height: 14,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFF1F2937),
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
                                                const SizedBox(width: 6),
                                                const Text(
                                                  'Completed',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF4B5563),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            // Today
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFFCCFF00),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                const Text(
                                                  'Today',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF4B5563),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            // Locked
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  '#',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF9CA3AF),
                                                  ),
                                                ),
                                                const SizedBox(width: 5),
                                                const Text(
                                                  'Locked',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF4B5563),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            // Exam Window
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFFFF8C00),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                const Text(
                                                  'Exam Window',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF4B5563),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Special Lifecycle Banners (Exam Scheduled / Certificate Logistics)
                                      if (isExamScheduled) ...[
                                        const SizedBox(height: 24),
                                        FinalExamTicketWidget(learner: currentLearner),
                                      ],
                                      if (isCompleted || isCertified) ...[
                                        const SizedBox(height: 24),
                                        _buildCertificateTimelineCard(currentLearner, isCertified),
                                      ],
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                ),
                              ),

                              // 5. Action CTA: "Log Today's Class" Button at Bottom
                              Padding(
                                padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                                child: _buildBottomActionCTA(
                                  context: context,
                                  currentLearner: currentLearner,
                                  shortTodayStr: shortTodayStr,
                                  isTodayLogged: isTodayLogged,
                                  isClassInProgress: isClassInProgress,
                                  isAwaitingMidterm: isAwaitingMidterm,
                                  isWeek12Completed: isWeek12Completed,
                                  isExamScheduled: isExamScheduled,
                                  isCompleted: isCompleted,
                                  isCertified: isCertified,
                                ),
                              ),
                            ],
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
    required int year,
    required int month,
    required int todayDay,
    required Set<int> completedDays,
    required bool isExamWindowActive,
    required Map<String, dynamic> currentLearner,
  }) {
    final int daysInMonth = DateUtils.getDaysInMonth(year, month);
    final int firstWeekday = DateTime(year, month, 1).weekday; // 1 = Mon .. 7 = Sun
    final int leadingEmptyCells = firstWeekday - 1;

    final List<Widget?> cells = [];
    for (int i = 0; i < leadingEmptyCells; i++) {
      cells.add(const SizedBox(width: 40, height: 40));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final bool isCompleted = completedDays.contains(day);
      final bool isToday = day == todayDay;
      final bool isFuture = day > todayDay;
      final bool isExamDay =
          isExamWindowActive && (day >= todayDay && day <= (todayDay + 3).clamp(1, daysInMonth));

      if (isCompleted) {
        cells.add(_buildCompletedDayCell(day));
      } else if (isExamDay) {
        cells.add(_buildExamWindowDayCell(context, day, isToday, currentLearner));
      } else if (isToday) {
        cells.add(_buildTodayDayCell(context, day, currentLearner));
      } else if (isFuture) {
        cells.add(_buildLockedFutureDayCell(day));
      } else {
        cells.add(_buildRestDayCell(day));
      }
    }

    while (cells.length % 7 != 0) {
      cells.add(const SizedBox(width: 40, height: 40));
    }

    final List<Widget> rows = [];
    for (int r = 0; r < cells.length; r += 7) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 7.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: cells.sublist(r, r + 7).map((c) => c!).toList(),
          ),
        ),
      );
    }
    return rows;
  }

  /// Completed Class (Past Days or Today if Logged):
  /// Soft grey circle (#E5E7EB) with bottom-right black checkmark badge (✓)
  Widget _buildCompletedDayCell(int day) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFE5E7EB),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$day',
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: const Center(
                child: Icon(
                  Icons.check,
                  color: Color(0xFFCCFF00),
                  size: 8.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Today (Active Day):
  /// Glowing, pulsing bright lime-yellow circle (#CCFF00)
  Widget _buildTodayDayCell(
      BuildContext context, int day, Map<String, dynamic> currentLearner) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClassLoggingScreen(learner: currentLearner),
          ),
        );
      },
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFCCFF00),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFCCFF00).withOpacity(0.65),
                  blurRadius: _pulseAnimation.value,
                  spreadRadius: 1.5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$day',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Exam Window Day: Orange highlight circle
  Widget _buildExamWindowDayCell(BuildContext context, int day, bool isToday,
      Map<String, dynamic> currentLearner) {
    return GestureDetector(
      onTap: () {
        if ((currentLearner['status'] ?? '') == 'Awaiting Mid-Term' ||
            ((currentLearner['classesTaught'] as num?)?.toInt() ?? 0) == 18) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MidtermAssessmentScreen(learner: currentLearner),
            ),
          );
        }
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isToday ? const Color(0xFFFF8C00) : const Color(0xFFFFEDD5),
          shape: BoxShape.circle,
          boxShadow: isToday
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF8C00).withOpacity(0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(
              color: isToday ? Colors.white : const Color(0xFFC2410C),
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
  }

  /// Rest Day (Past day where no class was conducted)
  Widget _buildRestDayCell(int day) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: Text(
          '$day',
          style: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }

  /// Locked Future Days: Subtle greyed-out numbers
  Widget _buildLockedFutureDayCell(int day) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: Text(
          '$day',
          style: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w500,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }

  /// 5. Dynamic Bottom Action CTA Button
  Widget _buildBottomActionCTA({
    required BuildContext context,
    required Map<String, dynamic> currentLearner,
    required String shortTodayStr,
    required bool isTodayLogged,
    required bool isClassInProgress,
    required bool isAwaitingMidterm,
    required bool isWeek12Completed,
    required bool isExamScheduled,
    required bool isCompleted,
    required bool isCertified,
  }) {
    // Mid-Term Gate CTA
    if (isAwaitingMidterm) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF8C00),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MidtermAssessmentScreen(learner: currentLearner),
              ),
            );
          },
          icon: const Icon(Icons.file_upload_outlined, size: 20),
          label: const Text(
            'Upload Mid Assessment (Week 7 Gate)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    // Week 12 Completed / Final Exam / Certified states
    if (isWeek12Completed || isExamScheduled || isCompleted || isCertified) {
      return Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(27),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 20),
            const SizedBox(width: 8),
            Text(
              isCertified
                  ? '12-WEEK COURSE OFFICIALLY CERTIFIED'
                  : 'ALL 36 CLASSES COMPLETED • EXAM PIPELINE',
              style: const TextStyle(
                color: Color(0xFF065F46),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final controller = Provider.of<RegistrationController>(context, listen: false);
    final bool isAnotherLearnerRunning =
        controller.isClassActive && !isClassInProgress;

    // State 2: When a Class is Currently Running for this Learner
    if (isClassInProgress) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, _) {
          return Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFCCFF00), width: 2.0),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFCCFF00).withOpacity(0.32),
                  blurRadius: _pulseAnimation.value,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF171717),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClassLoggingScreen(learner: currentLearner),
                  ),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3B30),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      'CLASS IN PROGRESS • [${controller.formattedRemainingTime} LEFT] - TAP TO RESUME',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFCCFF00),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // Accidental Termination Prevention: Another learner already has an active session
    if (isAnotherLearnerRunning) {
      return Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_clock_rounded, color: Color(0xFFDC2626), size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'LIVE SESSION RUNNING FOR ${(controller.activeLearnerName ?? "ANOTHER LEARNER").toUpperCase()}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // State 3: When Today's Class is Already Completed
    if (isTodayLogged) {
      return Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xFF059669),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 10),
            Text(
              'LOGGED ($shortTodayStr) • 1 CLASS/DAY COMPLETED',
              style: const TextStyle(
                color: Color(0xFF065F46),
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    }

    // State 1: When Today's Class is not yet started
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFCCFF00),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClassLoggingScreen(learner: currentLearner),
            ),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, size: 22, color: Colors.black),
            const SizedBox(width: 6),
            Text(
              'Log Today\'s Class ($shortTodayStr)',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateTimelineCard(
      Map<String, dynamic> currentLearner, bool isCertified) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PHYSICAL CERTIFICATE TIMELINE',
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
              ),
              Text(
                (currentLearner['examGrade'] ?? 'Graded').toString(),
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildTimelineStep(
            'Approved by NCHD Head Office',
            true,
            false,
            subtitle: 'Attendance, GPS coordinates, & midterm cleared.',
          ),
          _buildTimelineStep(
            'Dispatched by NCHD Head Office',
            currentLearner['certificateLogistics']?['dispatched'] == true,
            currentLearner['certificateLogistics']?['dispatched'] == false,
            subtitle: 'Physical printed seal forwarded to focal person.',
          ),
          _buildTimelineStep(
            'Received by Focal Person',
            currentLearner['certificateLogistics']?['receivedByFocal'] == true,
            currentLearner['certificateLogistics']?['dispatched'] == true &&
                currentLearner['certificateLogistics']?['receivedByFocal'] == false,
            subtitle: 'Arrived at institutional/district office.',
          ),
          _buildTimelineStep(
            'Handover Confirmed (Certified)',
            currentLearner['certificateLogistics']?['handoverConfirmed'] == true ||
                isCertified,
            currentLearner['certificateLogistics']?['receivedByFocal'] == true &&
                currentLearner['certificateLogistics']?['handoverConfirmed'] == false,
            subtitle: 'Handed physically to Volunteer & Learner.',
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String label, bool isCompleted, bool isPending,
      {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green
                  : (isPending ? AppTheme.primaryLime : const Color(0xFFE5E5EA)),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 13)
                  : (isPending
                      ? const Icon(Icons.hourglass_empty_rounded,
                          color: Colors.black, size: 11)
                      : null),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: isCompleted ? Colors.black : Colors.grey[600],
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedCard(
      BuildContext context, Map<String, dynamic> currentLearner) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enrollment Rejected',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentLearner['remarks']?.isNotEmpty == true
                ? currentLearner['remarks']
                : 'Documentation or baseline diagnostic criteria was not fulfilled.',
            style: const TextStyle(
                color: Color(0xFF991B1B), fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('RE-SUBMIT BASELINE ASSESSMENT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        BaselineAssessmentScreen(learner: currentLearner),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAwaitingBaselineCard(
      BuildContext context, Map<String, dynamic> currentLearner) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Baseline Assessment Pending',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please administer the foundational diagnostic assessment paper to the learner and upload the solved assessment sheet to unlock the 12-week attendance calendar.',
            style: TextStyle(color: AppTheme.textGrey, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('UPLOAD BASELINE DIAGNOSTIC PAPER',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        BaselineAssessmentScreen(learner: currentLearner),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
