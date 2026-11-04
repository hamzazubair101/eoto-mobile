import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_logos.dart';
import '../controllers/registration_controller.dart';
import 'add_learner_screen.dart';
import 'baseline_assessment_screen.dart';
import 'syllabus_library_screen.dart';
import 'learner_calendar_screen.dart';
import 'class_logging_screen.dart';
import 'learner_pending_status_screen.dart';
import 'notifications_center_screen.dart';
import 'settings/settings_screen.dart';
import 'settings/profile_sub_screens.dart';

class DashedRoundedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashLength;
  final double dashGap;

  DashedRoundedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.radius = 22.0,
    this.dashLength = 6.0,
    this.dashGap = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double next = distance + dashLength;
        final extractPath = metric.extractPath(distance, next > metric.length ? metric.length : next);
        canvas.drawPath(extractPath, paint);
        distance += dashLength + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRoundedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({Key? key}) : super(key: key);

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _historySearchController = TextEditingController();
  String _searchQuery = '';
  String _historySearchQuery = '';
  String _historyFilter = 'All Records';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Provider.of<RegistrationController>(context, listen: false);
      final uid = controller.currentTeacherUid;
      if (uid != null) {
        controller.loadTeacherProfile(uid);
        controller.loadLearnersFromFirestore(uid);
        controller.subscribeToLearners(uid);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _historySearchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
      case 'Awaiting Mid-Term':
      case 'Week 12 Completed':
      case 'Exam Scheduled':
      case 'Completed':
      case 'Certified':
        return AppTheme.primaryLime;
      case 'Pending Review':
        return AppTheme.statusPending;
      case 'Rejected':
        return AppTheme.statusRejected;
      case 'Awaiting Baseline':
        return Colors.blueAccent;
      default:
        return AppTheme.textGrey;
    }
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final isLime = color == AppTheme.primaryLime;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: isLime ? Colors.green[800] : color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'L';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, min(2, parts[0].length)).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Widget _buildSolidStatusBadge(String status) {
    Color bg;
    String label = status.toUpperCase();

    if (status == 'Active' || status == 'Week 12 Completed' || status == 'Certified' || status == 'Completed') {
      bg = const Color(0xFF00B67A); // Solid vibrant emerald as in image 1
      label = status == 'Active' ? 'ACTIVE' : status.toUpperCase();
    } else if (status == 'Pending Review') {
      bg = const Color(0xFFFF9500); // Solid vibrant orange as in image 1
      label = 'PENDING REVIEW';
    } else if (status == 'Awaiting Baseline') {
      bg = const Color(0xFFFF9500); // Orange badge
      label = 'AWAITING BASELINE';
    } else if (status == 'Awaiting Mid-Term') {
      bg = const Color(0xFF3B82F6);
      label = 'AWAITING MID-TERM';
    } else if (status == 'Rejected') {
      bg = const Color(0xFFEF4444);
      label = 'REJECTED';
    } else {
      bg = const Color(0xFF6B7280);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: bg.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildMockupLearnerCard(BuildContext context, Map<String, dynamic> learner) {
    final String name = learner['name'] ?? 'Learner';
    final String initials = _getInitials(name);
    final String status = learner['status'] ?? 'Awaiting Baseline';
    final String statusLower = status.toLowerCase();
    final bool isPending = statusLower.contains('pending') || 
                           statusLower.contains('review');
    final bool isRejected = statusLower.contains('reject');

    return GestureDetector(
      onTap: () {
        if (status == 'Awaiting Baseline') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BaselineAssessmentScreen(learner: learner),
            ),
          );
        } else if (isPending || isRejected) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LearnerPendingStatusScreen(learner: learner),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LearnerCalendarScreen(learner: learner),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5F7), // Soft modern card from Image 1
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withOpacity(0.03)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Dark Avatar Circle with Initials
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFF1E232A),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Name and Status Pill
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildSolidStatusBadge(status),
                ],
              ),
            ),

            // Chevron
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFB0B5BD),
              size: 26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterAnotherCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddLearnerScreen()),
        );
      },
      child: CustomPaint(
        painter: DashedRoundedBorderPainter(
          color: const Color(0xFFCBD5E1),
          strokeWidth: 1.5,
          radius: 22.0,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLime,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryLime.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.add, color: Colors.black, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Register Another Learner',
                style: TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateIllustration() {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft rounded grey card background
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F6),
              borderRadius: BorderRadius.circular(42),
            ),
          ),

          // White document sheet
          Positioned(
            left: 36,
            child: Container(
              width: 125,
              height: 155,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top lime header bar
                  Container(
                    width: double.infinity,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLime,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Grey line 1
                  Container(
                    width: 55,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6DCE5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Grey line 2
                  Container(
                    width: 75,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6DCE5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Grey line 3
                  Container(
                    width: 38,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6DCE5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const Spacer(),
                  // Signature box with mini edit icon
                  Container(
                    width: double.infinity,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Icon(Icons.edit_note_rounded, color: AppTheme.primaryLime, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Lime Highlighter / Stylus Pen
          Positioned(
            right: 28,
            child: Container(
              width: 32,
              height: 135,
              decoration: BoxDecoration(
                color: AppTheme.primaryLime,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryLime.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E232A),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearnerCard(BuildContext context, Map<String, dynamic> learner) {
    final String status = learner['status'] ?? 'Awaiting Baseline';
    final bool isAwaiting = status == 'Awaiting Baseline';
    final bool isRejected = status == 'Rejected';
    final bool isPendingReview = status.toLowerCase().contains('review') || status.toLowerCase().contains('pending');
    final bool isActive = status == 'Active' ||
        status == 'Awaiting Mid-Term' ||
        status == 'Week 12 Completed' ||
        status == 'Exam Scheduled' ||
        status == 'Completed' ||
        status == 'Certified';
    final double progress = learner['progress'] ?? 0.0;
    
    return Card(
      color: AppTheme.cardLight,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.05),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.04), width: 1),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: ID and Status Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  learner['id'] ?? 'L-0000',
                  style: const TextStyle(color: AppTheme.textGrey, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Avatar and Details
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _getStatusColor(status).withOpacity(0.15),
                  child: Icon(
                    Icons.person,
                    color: _getStatusColor(status) == AppTheme.primaryLime 
                        ? Colors.green[800] 
                        : _getStatusColor(status),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        learner['name'] ?? 'Unknown',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16, color: AppTheme.textBlack),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Parentage: ${learner['parentage'] ?? 'N/A'}',
                        style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Condition 1: Active teaching cycle progress bar
            if (isActive) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Course Progress',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Text(
                    '${learner['classesTaught']} of ${learner['totalClasses']} Classes',
                    style: const TextStyle(color: AppTheme.textBlack, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.inputFill,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryLime),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LearnerCalendarScreen(learner: learner),
                      ),
                    );
                  },
                  child: const Text('VIEW 12-WEEK CYCLE / LOG CLASS'),
                ),
              ),
            ],

            // Condition 1.5: Application Pending Review
            if (isPendingReview) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Application is under review. The 12-Week Teaching Cycle will unlock once approved by the focal person.',
                        style: TextStyle(color: Colors.amber[900], fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.amber[700]!),
                    foregroundColor: Colors.amber[900],
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LearnerPendingStatusScreen(learner: learner),
                      ),
                    );
                  },
                  child: const Text('VIEW APPLICATION STATUS'),
                ),
              ),
            ],

            // Condition 2: Awaiting Baseline Assessment Action
            if (isAwaiting) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.15)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Enrollment is locked. Please administer and upload the baseline assessment.',
                        style: TextStyle(color: Colors.blueAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BaselineAssessmentScreen(learner: learner),
                      ),
                    );
                  },
                  child: const Text('UPLOAD BASELINE PDF'),
                ),
              ),
            ],

            // Condition 3: Rejection Remarks Visible
            if (isRejected) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Rejection Reason:',
                          style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      learner['remarks'] ?? 'No remarks provided.',
                      style: TextStyle(color: Colors.red[900], fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        foregroundColor: Colors.redAccent,
                      ),
                      onPressed: () {
                        // Re-trigger baseline upload flow
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BaselineAssessmentScreen(learner: learner),
                          ),
                        );
                      },
                      child: const Text('Re-upload Assessment'),
                    ),
                  ),
                ],
              ),
            ],

            // Condition 4: Awaiting FP Review Message
            if (status == 'Pending Review') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.statusPending.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.statusPending.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_empty_rounded, color: AppTheme.statusPending, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Assessment is in review. Verification takes 3-5 working days.',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 360;
    final double horizontalPadding = isCompact ? 16.0 : 24.0;

    return Consumer<RegistrationController>(
      builder: (context, controller, child) {
        final String teacherName = controller.fullName ?? 'Ali';
        final String firstName = teacherName.trim().isNotEmpty 
            ? teacherName.trim().split(' ').first 
            : 'Ali';

        final allLearners = controller.learners;
        // Filter out completed, certified, rejected, terminated, inactive records from Home tab
        final activeLearners = allLearners.where((l) {
          final status = (l['status'] ?? '').toString().trim().toLowerCase();
          final bool isHistorical = status.contains('reject') ||
                                    status == 'completed' ||
                                    status == 'certified' ||
                                    status.contains('terminat') ||
                                    status.contains('suspend') ||
                                    status.contains('inactive');
          return !isHistorical;
        }).toList();

        final q = _searchQuery.trim().toLowerCase();
        final learners = activeLearners.where((l) {
          if (q.isEmpty) return true;
          final name = (l['name'] ?? '').toString().toLowerCase();
          final id = (l['id'] ?? '').toString().toLowerCase();
          final status = (l['status'] ?? '').toString().toLowerCase();
          final parentage = (l['parentage'] ?? '').toString().toLowerCase();
          return name.contains(q) || id.contains(q) || status.contains(q) || parentage.contains(q);
        }).toList();

        // Dynamic Status Badge connected to real database teacher status
        Color badgeColor = AppTheme.primaryLime;
        Color badgeTextColor = Colors.black;
        String badgeText = 'STATUS: ACTIVE VOLUNTEER';

        if (controller.teacherStatus == 'pending') {
          badgeColor = const Color(0xFFFF9500);
          badgeTextColor = Colors.white;
          badgeText = 'STATUS: PENDING REVIEW';
        } else if (controller.teacherStatus == 'rejected') {
          badgeColor = const Color(0xFFEF4444);
          badgeTextColor = Colors.white;
          badgeText = 'STATUS: APPLICATION REJECTED';
        }

        return RefreshIndicator(
          onRefresh: () async {
            final uid = controller.currentTeacherUid;
            if (uid != null) {
              await controller.loadTeacherProfile(uid);
              await controller.loadLearnersFromFirestore(uid);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Header (from Mockup)
              Padding(
                padding: EdgeInsets.only(
                  left: horizontalPadding,
                  right: horizontalPadding,
                  top: 16.0,
                  bottom: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $firstName',
                      style: TextStyle(
                        fontSize: isCompact ? 28 : 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: badgeColor.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeTextColor,
                          fontWeight: FontWeight.w900,
                          fontSize: isCompact ? 9 : 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Empty or Populated State
              if (activeLearners.isEmpty)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: isCompact ? 20.0 : 28.0),
                    child: Column(
                      children: [
                        SizedBox(height: isCompact ? 20 : 36),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _buildEmptyStateIllustration(),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'No Learner Added Yet',
                          style: TextStyle(
                            fontSize: isCompact ? 20 : 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'To begin your 12-week EOTO journey, please register the illiterate citizen you will be teaching.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AddLearnerScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryLime,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                            shadowColor: AppTheme.primaryLime.withOpacity(0.4),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, color: Colors.black, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Add New Learner',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    children: [
                      const SizedBox(height: 8),
                      // Search Bar for active learners
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F5F7),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                          style: const TextStyle(fontSize: 14, color: Colors.black),
                          decoration: InputDecoration(
                            hintText: 'Search my active learners...',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                            prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const Text(
                        'MY LEARNERS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (learners.isEmpty && _searchQuery.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.search_off_rounded, size: 40, color: Colors.grey),
                                const SizedBox(height: 10),
                                Text(
                                  'No active learner matches "$_searchQuery"',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  icon: const Icon(Icons.clear, size: 14),
                                  label: const Text('Clear search'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // Learner Cards
                        ...learners.map((learner) => _buildMockupLearnerCard(context, learner)).toList(),
                      ],

                      const SizedBox(height: 6),

                      // Dashed "Register Another Learner" card
                      _buildRegisterAnotherCard(context),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    final controller = Provider.of<RegistrationController>(context, listen: false);
    final String currentUid = controller.currentTeacherUid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('learners')
          .where('teacherUid', isEqualTo: currentUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryLime));
        }

        List<Map<String, dynamic>> realHistory = [];
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          realHistory = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Learner';
            final status = data['status'] ?? 'Active';
            final remarks = data['rejectionRemarks'] ?? data['remarks'] ?? '';
            final classes = data['classesTaught'] ?? 0;
            
            String subtitle = '';
            if (status == 'Certified') {
              subtitle = 'Earned Official Literacy Certificate.';
            } else if (status == 'Completed') {
              subtitle = 'Completed 36 sessions. Final exam graded.';
            } else if (status == 'Rejected') {
              subtitle = remarks.isNotEmpty ? 'Remarks: $remarks' : 'Baseline documentation rejected.';
            } else if (status.toString().toLowerCase().contains('inactive')) {
              subtitle = 'Exceeded allowable days without logged session.';
            } else {
              subtitle = '$classes of 36 sessions completed.';
            }

            return {
              'id': doc.id,
              'name': name,
              'initials': _getInitials(name),
              'status': status,
              'date': data['lastSession'] ?? 'Recent',
              'subtitle': subtitle,
              ...data,
            };
          }).where((l) {
            final status = (l['status'] ?? '').toString().trim().toLowerCase();
            final bool isHistorical = status.contains('reject') ||
                                      status == 'completed' ||
                                      status == 'certified' ||
                                      status.contains('terminat') ||
                                      status.contains('suspend') ||
                                      status.contains('inactive');
            return isHistorical;
          }).toList();
        }

        // Filter based on search query and sub-tab selection
        final filteredHistory = realHistory.where((l) {
          final name = (l['name'] ?? '').toString().toLowerCase();
          final id = (l['id'] ?? '').toString().toLowerCase();
          final status = (l['status'] ?? '').toString().toLowerCase();
          final remarks = (l['rejectionRemarks'] ?? l['remarks'] ?? '').toString().toLowerCase();
          final parentage = (l['parentage'] ?? '').toString().toLowerCase();
          final date = (l['date'] ?? l['lastSession'] ?? '').toString().toLowerCase();

          final q = _historySearchQuery.trim().toLowerCase();
          final matchesSearch = q.isEmpty || 
              name.contains(q) || 
              id.contains(q) ||
              status.contains(q) ||
              remarks.contains(q) ||
              parentage.contains(q) ||
              date.contains(q);
          
          if (!matchesSearch) return false;

          if (_historyFilter == 'All Records') {
            return true;
          } else if (_historyFilter == 'Certified') {
            return status == 'certified' || status == 'completed';
          } else if (_historyFilter == 'Terminated') {
            return status.contains('reject') || status.contains('terminat') || status.contains('inactive') || status.contains('suspend');
          }
          return status == _historyFilter.toLowerCase();
        }).toList();

        return Column(
          children: [
            // Pill Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _historySearchController,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Search past learners by name, ID, status...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _historySearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                            onPressed: () {
                              _historySearchController.clear();
                              setState(() {
                                _historySearchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _historySearchQuery = val;
                    });
                  },
                ),
              ),
            ),

            // Horizontal filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  _buildFilterChip('All Records'),
                  const SizedBox(width: 10),
                  _buildFilterChip('Certified'),
                  const SizedBox(width: 10),
                  _buildFilterChip('Terminated'),
                ],
              ),
            ),

            // History Card List
            Expanded(
              child: filteredHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off_rounded, color: Colors.grey[300], size: 64),
                          const SizedBox(height: 12),
                          Text(
                            _historySearchQuery.isNotEmpty
                                ? 'No past records matching "$_historySearchQuery"'
                                : 'No historical records found',
                            style: const TextStyle(color: AppTheme.textGrey, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          if (_historySearchQuery.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: () {
                                _historySearchController.clear();
                                setState(() => _historySearchQuery = '');
                              },
                              icon: const Icon(Icons.clear, size: 14),
                              label: const Text('Clear search'),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            'Completed or archived learner cycles will appear here.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filteredHistory.length,
                      itemBuilder: (context, index) {
                        final item = filteredHistory[index];
                        return _buildPixelHistoryCard(item);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label) {
    final bool isActive = _historyFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _historyFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFCCFF00) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(30),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFFCCFF00).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildPixelHistoryCard(Map<String, dynamic> item) {
    final String name = item['name'] ?? 'Learner';
    final String status = item['status'] ?? 'Active';
    final String initials = _getInitials(name);
    final int classesTaught = (item['classesTaught'] as num?)?.toInt() ?? 0;

    String dateStr = 'Enrolled Recently';
    if (item['lastSession'] != null && item['lastSession'] != 'N/A') {
      dateStr = 'Last Session: ${item['lastSession']}';
    } else if (item['createdAt'] != null) {
      dateStr = 'Registered: Cohort 2026';
    }

    String subtitle = '12-Week Teaching Cycle ($classesTaught/36 classes)';
    if (status == 'Certified' || status == 'Completed') {
      subtitle = 'Completed 36 Sessions • Verified & Certified';
    } else if (status == 'Rejected') {
      final reason = item['rejectionRemarks'] ?? item['remarks'] ?? 'Incomplete test';
      subtitle = 'Application Rejected. Reason: $reason';
    } else if (status == 'Pending Review') {
      subtitle = 'Application & baseline test submitted for focal review';
    }

    Color badgeBg;
    Color badgeText;

    if (status == 'Certified' || status == 'Completed' || status == 'Active') {
      badgeBg = const Color(0xFFCCFF00); // Lime Green
      badgeText = const Color(0xFF1E5A1E); // Dark Green Text
    } else if (status == 'Pending Review') {
      badgeBg = const Color(0xFFFF9500); // Orange
      badgeText = Colors.white;
    } else if (status == 'Rejected') {
      badgeBg = const Color(0xFFEF4444); // Red
      badgeText = Colors.white;
    } else {
      badgeBg = const Color(0xFF6B7280);
      badgeText = Colors.white;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (status.toLowerCase().contains('reject')) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LearnerPendingStatusScreen(learner: item),
                ),
              );
              return;
            }

            // Interactive audit detail preview
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              builder: (context) => Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['id'] ?? 'L-0000',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeBg.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(color: badgeText, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Archived Date: $dateStr',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Historical Record Audit:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    if (status == 'Rejected') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LearnerPendingStatusScreen(learner: item),
                              ),
                            );
                          },
                          child: const Text(
                            'VIEW REJECTION DETAILS & REMARKS',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('DISMISS AUDIT'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Initials Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFF2F2F7),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Name and Date Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: badgeText,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Chevron icon
                const Icon(
                  Icons.chevron_right,
                  color: Colors.black26,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return _buildHomeTab(context);
      case 1:
        return const SyllabusLibraryScreen();
      case 2:
        return _buildHistoryTab();
      case 3:
        return const SettingsScreen();
      default:
        return _buildHomeTab(context);
    }
  }

  Widget _buildCustomNavBarItem(int index, IconData inactiveIcon, IconData activeIcon, String label, [double? screenWidth]) {
    final bool isSelected = _selectedIndex == index;
    final bool isCompact = (screenWidth ?? 400) < 380;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0xFFCCFF00), // Lime Green active circle/pill
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFCCFF00).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? Colors.black : Colors.grey[500],
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.grey[500],
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget? _buildDynamicAppBar() {
    if (_selectedIndex == 3) {
      return null; // Let SettingsScreen render its own App Bar
    }

    if (_selectedIndex == 2) {
      return AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'History',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const NotificationsCenterScreen(isFocalPerson: false),
                ),
              );
            },
          ),
        ],
      );
    }

    if (_selectedIndex == 1) {
      return AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Syllabus Library',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      );
    }

    // Default Home Tab App Bar (Matching Mockup Image 2)
    return AppBar(
      backgroundColor: AppTheme.backgroundLight,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 18.0),
        child: Center(
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedIndex = 3); // Open profile
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF1E232A),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ),
      centerTitle: true,
      title: AppLogos.wordmark(height: 21),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 18.0),
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.notifications_none_rounded,
                        color: Colors.black, size: 20),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const NotificationsCenterScreen(
                                  isFocalPerson: false),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 8.5,
                    height: 8.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 600;

    final Widget scaffoldContent = Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildDynamicAppBar(),
      body: Column(
        children: [
          Consumer<RegistrationController>(
            builder: (context, controller, _) {
              if (!controller.isClassActive || controller.activeLearnerId == null) {
                return const SizedBox.shrink();
              }
              final activeLearner = controller.learners.firstWhere(
                (l) => l['id'] == controller.activeLearnerId,
                orElse: () => {
                  'id': controller.activeLearnerId,
                  'name': controller.activeLearnerName ?? 'Learner',
                },
              );
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ClassLoggingScreen(learner: activeLearner),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFCCFF00), width: 2.0),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFCCFF00).withOpacity(0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
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
                              color: Color(0xFFCCFF00),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _getPage(_selectedIndex),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 78,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildCustomNavBarItem(0, Icons.home_outlined, Icons.home_rounded, 'HOME', screenWidth),
            _buildCustomNavBarItem(1, Icons.menu_book_outlined, Icons.menu_book_rounded, 'BOOKS', screenWidth),
            _buildCustomNavBarItem(2, Icons.history_outlined, Icons.history_rounded, 'HISTORY', screenWidth),
            _buildCustomNavBarItem(3, Icons.person_outline_rounded, Icons.person_rounded, 'PROFILE', screenWidth),
          ],
        ),
      ),
    );

    if (isWideScreen) {
      return Container(
        color: const Color(0xFFE5E7EB), // Modern subtle desktop backdrop
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: scaffoldContent,
              ),
            ),
          ),
        ),
      );
    }

    return scaffoldContent;
  }
}
