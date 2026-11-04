import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_logos.dart';
import 'focal_learner_progress_overview_screen.dart';
import 'learner_review_detail_screen.dart';
import '../notifications_center_screen.dart';

class FocalActiveClassesScreen extends StatefulWidget {
  final String effectiveFocalEmail;

  const FocalActiveClassesScreen({Key? key, required this.effectiveFocalEmail}) : super(key: key);

  @override
  State<FocalActiveClassesScreen> createState() => _FocalActiveClassesScreenState();
}

class _FocalActiveClassesScreenState extends State<FocalActiveClassesScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar with avatar, EOTO, and notification bell matching 1 (2).png
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF1C2D37),
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  AppLogos.wordmark(height: 24),
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFFC0E800), size: 26),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationsCenterScreen(
                            isFocalPerson: true,
                            focalEmail: widget.effectiveFocalEmail,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Active Classes Heading matching 1 (2).png
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
              child: Text(
                'Active Classes',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar matching 1 (2).png
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F2),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.black45, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search student, teacher, ID, district...',
                          hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.black54),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Responsive Full-Width Filter Chips Bar (Eliminates empty whitespace)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 650;
                  if (isMobile) {
                    // Mobile: 2 perfectly balanced full-width rows of 3 equal pills - 0 empty space!
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildPill('All', 'All')),
                            const SizedBox(width: 8),
                            Expanded(child: _buildPill('On Track', 'On Track')),
                            const SizedBox(width: 8),
                            Expanded(child: _buildPill('Inactive', 'Inactive')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildPill('Final Exam', 'Final Exam')),
                            const SizedBox(width: 8),
                            Expanded(child: _buildPill('Mid Term', 'Mid Term')),
                            const SizedBox(width: 8),
                            Expanded(child: _buildPill('In Session', 'In Session')),
                          ],
                        ),
                      ],
                    );
                  }

                  // Desktop / Tablet wide display: 6 pills with right-aligned live indicator
                  return Row(
                    children: [
                      _buildPill('All', 'All'),
                      const SizedBox(width: 8),
                      _buildPill('On Track', 'On Track'),
                      const SizedBox(width: 8),
                      _buildPill('In Session', 'In Session'),
                      const SizedBox(width: 8),
                      _buildPill('Mid Term', 'Mid Term'),
                      const SizedBox(width: 8),
                      _buildPill('Final Exam', 'Final Exam'),
                      const SizedBox(width: 8),
                      _buildPill('Inactive', 'Inactive'),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE5E5EA)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00E676),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Live Class Monitor',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // Real-time Active Classes Stream
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('learners')
                    .where('assignedFocalPersonEmail', isEqualTo: widget.effectiveFocalEmail)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00)));
                  }

                  List<Map<String, dynamic>> learnersList = [];
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    learnersList = snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return {
                        'id': doc.id,
                        ...data,
                      };
                    }).toList();
                  }

                  if (learnersList.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF2F2F7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.school_outlined,
                                size: 38,
                                color: Colors.black45,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'No Active Classes Found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Classes will appear here in real-time as registered learners are approved and start their 12-week cycles.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Apply search and filter tabs
                  final filtered = learnersList.where((l) {
                    final name = (l['name'] ?? '').toString().toLowerCase();
                    final teacher = (l['teacherName'] ?? l['assignedTeacherName'] ?? '').toString().toLowerCase();
                    final id = (l['id'] ?? '').toString().toLowerCase();
                    final parentage = (l['parentage'] ?? '').toString().toLowerCase();
                    final district = (l['district'] ?? '').toString().toLowerCase();
                    final status = (l['status'] ?? '').toString().toLowerCase();
                    final phone = (l['phone'] ?? l['contactNumber'] ?? '').toString().toLowerCase();
                    final cnic = (l['idNumber'] ?? l['cnic'] ?? '').toString().toLowerCase();
                    final midterm = (l['midtermStatus'] ?? '').toString().toLowerCase();
                    final classes = (l['classesTaught'] as num?)?.toInt() ?? 0;

                    final q = _searchQuery.trim().toLowerCase();
                    final matchesSearch = q.isEmpty || 
                        name.contains(q) || 
                        teacher.contains(q) || 
                        id.contains(q) || 
                        parentage.contains(q) || 
                        district.contains(q) || 
                        status.contains(q) || 
                        phone.contains(q) || 
                        cnic.contains(q);
                    if (!matchesSearch) return false;

                    final bool isPending = status.contains('pending') || status.contains('review') || status == 'awaiting baseline';
                    final bool isRejected = status.contains('reject') || status.contains('delist');
                    final bool isCertifiedHistory = status == 'certified';

                    // Active Classes screen ONLY shows approved learners currently in their 12-week course
                    if (isPending || isRejected || isCertifiedHistory) {
                      return false;
                    }

                    final bool isLiveSession = l['isLiveSessionActive'] == true;
                    final bool isInactive = !isLiveSession && (status.contains('inactive') || status.contains('no class') || classes == 0);
                    final bool isMidTerm = (classes >= 18 && classes < 36) || midterm.contains('submit') || status.contains('mid');
                    final bool isFinalExam = classes >= 36 || status.contains('final') || status.contains('exam') || status.contains('week 12') || status == 'completed';

                    if (_selectedFilter == 'All') {
                      // Shows ALL approved learners in the 12-week course (On Track, In Session, Mid Term, Final Exam, Inactive)
                      return true;
                    }
                    if (_selectedFilter == 'On Track') {
                      return !isInactive || isLiveSession;
                    }
                    if (_selectedFilter == 'In Session') {
                      return isLiveSession || (classes > 0 && classes < 36 && !isInactive);
                    }
                    if (_selectedFilter == 'Mid Term') {
                      return isMidTerm;
                    }
                    if (_selectedFilter == 'Final Exam') {
                      return isFinalExam;
                    }
                    if (_selectedFilter == 'Inactive') {
                      return isInactive;
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 14),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No records matching "$_searchQuery"'
                                  : 'No classes matching "$_selectedFilter"',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            if (_searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text('Clear search'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildActiveClassCard(context, item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(String filterKey, String label) {
    final bool isSelected = _selectedFilter == filterKey;

    Color bgColor;
    Color textColor;

    switch (filterKey) {
      case 'All':
        bgColor = const Color(0xFFE5E7EB);
        textColor = Colors.black;
        break;
      case 'On Track':
        bgColor = const Color(0xFFCCFF00); // Original solid neon lime
        textColor = Colors.black;
        break;
      case 'Inactive':
        bgColor = const Color(0xFFFF3B30); // Original solid vibrant red
        textColor = Colors.white;
        break;
      case 'Final Exam':
        bgColor = const Color(0xFF00E5FF); // Original solid bright cyan
        textColor = Colors.black;
        break;
      case 'Mid Term':
        bgColor = const Color(0xFFFFD180); // Original solid warm peach
        textColor = const Color(0xFFB43B00); // Deep rich orange
        break;
      case 'In Session':
        bgColor = const Color(0xFF00E676); // Original solid vibrant green
        textColor = Colors.black;
        break;
      default:
        bgColor = const Color(0xFFF3F4F6);
        textColor = Colors.black;
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = filterKey;
        });
      },
      borderRadius: BorderRadius.circular(22),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: isSelected ? 1.0 : 0.78,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8.5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(22),
            border: isSelected
                ? Border.all(color: Colors.black87, width: 1.8)
                : Border.all(color: Colors.transparent, width: 1.8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(
                  Icons.check_circle_rounded,
                  size: 13.5,
                  color: textColor,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveClassCard(BuildContext context, Map<String, dynamic> item) {
    final String teacherName = item['teacherName'] ?? item['assignedTeacherName'] ?? 'Volunteer Teacher';
    final String learnerName = item['name'] ?? 'Learner';
    final int classesTaught = (item['classesTaught'] as num?)?.toInt() ?? 0;
    final int totalClasses = (item['totalClasses'] as num?)?.toInt() ?? 36;
    final double progress = totalClasses > 0 ? (classesTaught / totalClasses).clamp(0.0, 1.0) : 0.0;
    final String rawStatus = (item['status'] ?? 'Active').toString();
    final String statusLower = rawStatus.toLowerCase();
    final String midtermStatus = (item['midtermStatus'] ?? '').toString().toLowerCase();

    Color weekBadgeColor;
    Color weekBadgeTextColor = Colors.black;
    String weekBadgeText;

    Color statusIconColor;
    IconData statusIcon;
    String statusText;

    final bool isPending = statusLower.contains('pending') || statusLower.contains('review') || statusLower == 'awaiting baseline';
    final bool isRejected = statusLower.contains('reject');
    final bool isLiveSession = item['isLiveSessionActive'] == true;
    final bool isInactive = !isLiveSession && (statusLower.contains('inactive') || statusLower.contains('no class'));
    final bool geofenceMatched = item['geofenceMatched'] != false;
    final String liveTopic = (item['liveSessionTopic'] ?? '').toString();
    final double? liveLat = (item['liveSessionLat'] as num?)?.toDouble();
    final double? liveLng = (item['liveSessionLng'] as num?)?.toDouble();

    if (isLiveSession) {
      weekBadgeColor = const Color(0xFF00E676);
      weekBadgeTextColor = Colors.black;
      weekBadgeText = 'IN SESSION • LIVE';
      statusIconColor = const Color(0xFF15803D);
      statusIcon = Icons.sensors_rounded;
      statusText = geofenceMatched
          ? 'Geofence Matched (≤ 150m) • Live Timer Active'
          : 'Alert: Geofence Deviation Flagged';
    } else if (isRejected) {
      weekBadgeColor = const Color(0xFFEF4444);
      weekBadgeTextColor = Colors.white;
      weekBadgeText = 'REJECTED';
      statusIconColor = const Color(0xFFEF4444);
      statusIcon = Icons.cancel_outlined;
      statusText = 'Status: Application Rejected';
    } else if (isPending) {
      weekBadgeColor = const Color(0xFFFF9500);
      weekBadgeTextColor = Colors.white;
      weekBadgeText = 'PENDING REVIEW';
      statusIconColor = const Color(0xFFFF9500);
      statusIcon = Icons.hourglass_top_rounded;
      statusText = 'Status: Pending Baseline Review';
    } else if (isInactive) {
      weekBadgeColor = const Color(0xFFD32F2F);
      weekBadgeTextColor = Colors.white;
      weekBadgeText = 'INACTIVE';
      statusIconColor = const Color(0xFFD32F2F);
      statusIcon = Icons.warning_amber_rounded;
      statusText = 'Status: Inactive';
    } else if (classesTaught >= 36 || statusLower.contains('completed') || statusLower.contains('certified')) {
      weekBadgeColor = const Color(0xFF00E676);
      weekBadgeTextColor = Colors.black;
      weekBadgeText = 'COMPLETED';
      statusIconColor = const Color(0xFF2E7D32);
      statusIcon = Icons.verified;
      statusText = 'Status: 12-Week Cycle Completed ($classesTaught/$totalClasses)';
    } else if (midtermStatus == 'submitted' || statusLower.contains('mid')) {
      weekBadgeColor = const Color(0xFFFFD180);
      weekBadgeTextColor = const Color(0xFFE65100);
      weekBadgeText = 'MID-TERM';
      statusIconColor = const Color(0xFFF57C00);
      statusIcon = Icons.notifications_active;
      statusText = 'Status: Mid-Term Submitted';
    } else if (classesTaught == 0) {
      weekBadgeColor = const Color(0xFFE5E7EB);
      weekBadgeTextColor = Colors.black87;
      weekBadgeText = 'NOT STARTED';
      statusIconColor = Colors.blueGrey;
      statusIcon = Icons.pending_actions;
      statusText = 'Status: Enrolled (0/$totalClasses Classes Taught)';
    } else {
      final int currentWeek = (classesTaught / 3).ceil().clamp(1, 12);
      weekBadgeColor = const Color(0xFFCCFF00); // Solid neon lime
      weekBadgeTextColor = Colors.black;
      weekBadgeText = 'WEEK $currentWeek OF 12';
      statusIconColor = const Color(0xFF2E7D32);
      statusIcon = Icons.check_circle_outline;
      statusText = 'Status: Active ($classesTaught/$totalClasses Classes)';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (isPending || isRejected) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LearnerReviewDetailScreen(learner: item),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FocalLearnerProgressOverviewScreen(learner: item),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Teacher Name and Week Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Teacher',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        teacherName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: weekBadgeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      weekBadgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: weekBadgeTextColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Learner Name
              Text(
                'Learner',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                learnerName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              if (isLiveSession) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: geofenceMatched
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: geofenceMatched
                          ? const Color(0xFF6EE7B7)
                          : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            geofenceMatched
                                ? Icons.verified_user_rounded
                                : Icons.warning_amber_rounded,
                            size: 14,
                            color: geofenceMatched
                                ? const Color(0xFF047857)
                                : const Color(0xFFB45309),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              geofenceMatched
                                  ? 'Geofence Matched (≤ 150m) • ${liveLat?.toStringAsFixed(4) ?? "31.5204"}° N, ${liveLng?.toStringAsFixed(4) ?? "74.3587"}° E'
                                  : 'Geofence Deviation Alert • Officer Review Required',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: geofenceMatched
                                    ? const Color(0xFF047857)
                                    : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (liveTopic.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Topic: "$liveTopic"',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Lime Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFCCFF00)),
                ),
              ),
              const SizedBox(height: 14),

              // Bottom Status Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(statusIcon, color: statusIconColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusIconColor,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.chevron_right, color: Colors.black38, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
