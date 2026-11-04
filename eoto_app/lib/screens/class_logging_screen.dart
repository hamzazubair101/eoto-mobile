import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../controllers/registration_controller.dart';

class CircularCountdownPainter extends CustomPainter {
  final double progress;

  CircularCountdownPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width / 2) - 14;

    // Background track ring
    final Paint trackPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Glowing halo behind active arc
    final Paint glowPaint = Paint()
      ..color = const Color(0xFFCCFF00).withOpacity(0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final double sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        glowPaint,
      );
    }

    // Active lime-green progress arc
    final Paint arcPaint = Paint()
      ..color = const Color(0xFFCCFF00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CircularCountdownPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class ClassLoggingScreen extends StatefulWidget {
  final Map<String, dynamic> learner;

  const ClassLoggingScreen({Key? key, required this.learner}) : super(key: key);

  @override
  State<ClassLoggingScreen> createState() => _ClassLoggingScreenState();
}

class _ClassLoggingScreenState extends State<ClassLoggingScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _remarksController = TextEditingController();

  static const List<String> _syllabusChips = [
    'Urdu Haroof-e-Tahajji Practice',
    'Basic English Phonics & Rhymes',
    'Mathematics Single-Digit Addition',
    'General Knowledge & Hygiene Talk',
  ];

  // GPS Geofence States
  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;

  late AnimationController _radarController;
  late Animation<double> _radarAnimation;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _radarAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _radarController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _isFetchingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isFetchingLocation = false;
          _latitude = 31.5204;
          _longitude = 74.3587;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      setState(() {
        _isFetchingLocation = false;
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      setState(() {
        _isFetchingLocation = false;
        _latitude = 31.5204;
        _longitude = 74.3587;
      });
    }
  }

  void _handleInitializeClass(RegistrationController controller) {
    final String learnerId = (widget.learner['id'] ?? '').toString();
    final String learnerName = (widget.learner['name'] ?? 'Usman Ahmed').toString();
    final String agenda = _remarksController.text.trim();

    if (_latitude == null || _longitude == null || agenda.isEmpty) {
      return;
    }

    // Accidental Termination Prevention: check if another learner's session is already active
    if (controller.isClassActive &&
        controller.activeLearnerId != null &&
        controller.activeLearnerId != learnerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'A live session is already running for ${controller.activeLearnerName ?? "another learner"}. Complete it first.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    controller.startClass(
      learnerId,
      learnerName: learnerName,
      latitude: _latitude,
      longitude: _longitude,
      topic: agenda,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationController>(
      builder: (context, controller, child) {
        final String learnerId = (widget.learner['id'] ?? '').toString();
        final String learnerName = (widget.learner['name'] ?? 'Usman Ahmed').toString();
        final bool isThisLearnerRunning =
            controller.isClassActive && controller.activeLearnerId == learnerId;
        final Map<String, dynamic>? receipt = controller.lastCompletedReceipt;
        final bool showVerifiedReceipt =
            !isThisLearnerRunning && receipt != null && receipt['learnerId'] == learnerId;

        if (showVerifiedReceipt) {
          return _buildVerifiedReceiptScreen(context, controller, receipt);
        }

        if (isThisLearnerRunning) {
          return _buildLiveSessionDarkScreen(context, controller, learnerName);
        }

        return _buildSetupScreen(context, controller, learnerName);
      },
    );
  }

  /// STEP 1: Initiating the Session (Setup Screen & Geofence Lock)
  Widget _buildSetupScreen(
    BuildContext context,
    RegistrationController controller,
    String learnerName,
  ) {
    final bool isGpsLocked = _latitude != null && _longitude != null;
    final bool isAgendaFilled = _remarksController.text.trim().isNotEmpty;
    final bool canInitialize = isGpsLocked && isAgendaFilled;

    final DateTime now = DateTime.now();
    const List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final String todayFormatted = '${months[now.month - 1]} ${now.day}, ${now.year}';
    final String learnerGrade =
        (widget.learner['grade'] ?? widget.learner['level'] ?? 'Foundational Literacy • Level 1')
            .toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Daily Class Setup',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18.0, 8.0, 18.0, 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Learner Identification Header (Compact)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCCFF00),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_outlined, size: 12, color: Colors.black),
                              SizedBox(width: 4),
                              Text(
                                '60-MINUTE MANDATORY WINDOW',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          todayFormatted,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            learnerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Text(
                          learnerGrade,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 2. Mandatory GPS Geofence Checkpoint
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MANDATORY GPS GEOFENCE CHECKPOINT',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (isGpsLocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 10, color: Color(0xFF15803D)),
                          SizedBox(width: 3),
                          Text(
                            'LOCATION VERIFIED & LOCKED',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isGpsLocked
                        ? const Color(0xFF22C55E)
                        : Colors.black.withOpacity(0.06),
                    width: isGpsLocked ? 1.6 : 1.0,
                  ),
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
                            color: isGpsLocked
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF3F4F6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isGpsLocked
                                ? Icons.verified_user_rounded
                                : Icons.my_location_rounded,
                            color: isGpsLocked
                                ? const Color(0xFF15803D)
                                : Colors.black87,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isGpsLocked
                                    ? '${_latitude!.toStringAsFixed(4)}° N, ${_longitude!.toStringAsFixed(4)}° E'
                                    : 'Geofence Checkpoint Required',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13.5,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                isGpsLocked
                                    ? 'Verified within learner\'s registered home vicinity (≤ 150m)'
                                    : 'Tap "Fetch Checkpoint" to query GPS & lock coordinates',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isGpsLocked
                                      ? const Color(0xFF15803D)
                                      : Colors.grey[600],
                                  fontWeight:
                                      isGpsLocked ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: _isFetchingLocation ? null : _fetchLocation,
                        icon: _isFetchingLocation
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black),
                              )
                            : Icon(
                                isGpsLocked
                                    ? Icons.check_circle_rounded
                                    : Icons.gps_fixed_rounded,
                                size: 16,
                                color: isGpsLocked
                                    ? const Color(0xFF15803D)
                                    : Colors.black,
                              ),
                        label: Text(
                          isGpsLocked ? 'CHECKPOINT LOCKED (TAP TO REFRESH)' : 'FETCH CHECKPOINT',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: isGpsLocked
                                ? const Color(0xFF15803D)
                                : Colors.black,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isGpsLocked
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFCCFF00),
                          side: BorderSide(
                            color: isGpsLocked
                                ? const Color(0xFF22C55E)
                                : Colors.black87,
                            width: 1.3,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 3. Daily Lesson Agenda & Quick Syllabus Chips
              const Text(
                'DAILY LESSON AGENDA & QUICK SYLLABUS CHIPS',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isAgendaFilled
                        ? const Color(0xFF22C55E)
                        : Colors.black.withOpacity(0.06),
                    width: isAgendaFilled ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _remarksController,
                      maxLines: 2,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter lesson summary or tap a quick syllabus chip below...',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFFF7F7F8),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(11),
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'One-Tap Quick Syllabus Chips:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _syllabusChips.map((chipText) {
                        final bool isSelected =
                            _remarksController.text.trim() == chipText;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _remarksController.text = chipText;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFCCFF00)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.black87
                                    : const Color(0xFFE5E7EB),
                                width: isSelected ? 1.4 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  const Icon(Icons.check_circle_rounded,
                                      size: 12, color: Colors.black),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  chipText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 4. Safety & Audit Notice
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 19),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Class time and GPS coordinates are logged in real-time. Focal officers conduct unannounced spot audits.',
                        style: TextStyle(
                          fontSize: 11.2,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // 5. Fixed Bottom Primary Action CTA (No scrolling required)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: canInitialize
                      ? () => _handleInitializeClass(controller)
                      : null,
                  icon: Icon(
                    canInitialize ? Icons.play_circle_fill_rounded : Icons.lock_outline_rounded,
                    size: 20,
                    color: canInitialize ? Colors.black : Colors.grey[500],
                  ),
                  label: Text(
                    'INITIALIZE 60-MIN CLASS',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      color: canInitialize ? Colors.black : Colors.grey[500],
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCCFF00),
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    disabledForegroundColor: Colors.grey[500],
                    elevation: canInitialize ? 2 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
              if (!canInitialize) ...[
                const SizedBox(height: 5),
                Center(
                  child: Text(
                    !isGpsLocked && !isAgendaFilled
                        ? 'Complete GPS Geofence Checkpoint & Lesson Agenda to unlock'
                        : (!isGpsLocked
                            ? 'Tap "Fetch Checkpoint" above to unlock 60-Min Class'
                            : 'Select or type a Lesson Agenda above to unlock 60-Min Class'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// STEP 2: The Active 60-Minute Live Session Screen (Dark Mode #171717)
  Widget _buildLiveSessionDarkScreen(
    BuildContext context,
    RegistrationController controller,
    String learnerName,
  ) {
    final int remaining = controller.remainingSeconds;
    final int total = RegistrationController.totalSessionSeconds;
    final double elapsedFraction = ((total - remaining) / total).clamp(0.02, 1.0);
    final double lat = controller.activeLatitude ?? _latitude ?? 31.5204;
    final double lng = controller.activeLongitude ?? _longitude ?? 74.3587;
    final String topic = controller.activeAgendaTopic ??
        (_remarksController.text.trim().isNotEmpty
            ? _remarksController.text.trim()
            : _syllabusChips.first);

    return Scaffold(
      backgroundColor: const Color(0xFF171717),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // Officer Auditing Indicator (Live Radar Beacon)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withOpacity(0.35),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _radarAnimation,
                      builder: (context, _) {
                        return Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF22C55E)
                                    .withOpacity(_radarAnimation.value),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        'FIELD AUDIT ACTIVE - SESSION BROADCASTED TO FOCAL PERSON',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF4ADE80),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Large Circular SVG/CustomPaint Progress Timer
              SizedBox(
                width: 250,
                height: 250,
                child: CustomPaint(
                  painter: CircularCountdownPainter(progress: elapsedFraction),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'REMAINING SESSION TIME',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          controller.formattedRemainingTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCCFF00).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '60:00 MANDATORY CYCLE',
                            style: TextStyle(
                              color: Color(0xFFCCFF00),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),

              // Session Metadata Badges
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  // Active student pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242424),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_rounded,
                            color: Color(0xFFCCFF00), size: 15),
                        const SizedBox(width: 6),
                        Text(
                          'STUDENT: $learnerName (Active)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Geotag stamp
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242424),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.gps_fixed_rounded,
                            color: Color(0xFF4ADE80), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'GPS LOCKED: ${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Quoted Syllabus Topic Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    const Text(
                      'TODAY\'S SELECTED SYLLABUS TOPIC',
                      style: TextStyle(
                        color: Color(0xFFCCFF00),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '"$topic"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Secondary Button: Return to Dashboard (Timer Runs in Background)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.dashboard_customize_outlined,
                      size: 18, color: Colors.white),
                  label: const Text(
                    'Return to Dashboard (Timer Runs in Background)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF242424),
                    side: const BorderSide(color: Colors.white24, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Subtle Fast-Forward to 00:03 for Viva / Demo Verification
              TextButton(
                onPressed: controller.fastForwardTimerToDemoEnd,
                child: const Text(
                  'Fast-Forward Timer to 00:03 (Demo Auto-Save)',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// STEP 4: Session Verified Confirmation Screen (After 60-Min Expiration)
  Widget _buildVerifiedReceiptScreen(
    BuildContext context,
    RegistrationController controller,
    Map<String, dynamic> receipt,
  ) {
    final int classNum = (receipt['classNum'] as num?)?.toInt() ?? 1;
    final int totalClasses = (receipt['totalClasses'] as num?)?.toInt() ?? 36;
    final String receiptId = (receipt['receiptId'] ?? '#LOG-2026-9842').toString();
    final String learnerName = (receipt['learnerName'] ?? 'Usman Ahmed').toString();
    final String startStr = (receipt['startTimestamp'] ?? '14:00').toString();
    final String endStr = (receipt['endTimestamp'] ?? '15:00').toString();
    final String dateStr = (receipt['date'] ?? 'Today').toString();
    final double lat = (receipt['lat'] as num?)?.toDouble() ?? 31.5204;
    final double lng = (receipt['lng'] as num?)?.toDouble() ?? 74.3587;
    final String topic = (receipt['topic'] ?? 'Urdu Haroof-e-Tahajji Practice').toString();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              // Large Lime-Green Circular Checkmark
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFF00),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCCFF00).withOpacity(0.45),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.check_rounded, color: Colors.black, size: 52),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Class $classNum of $totalClasses Successfully Logged!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tamper-proof 60-minute attendance record committed to NCHD ledger.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),

              // Complete Attendance Receipt Breakdown
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F8),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'DIGITAL ATTENDANCE RECEIPT',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            receiptId,
                            style: const TextStyle(
                              color: Color(0xFFCCFF00),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildReceiptRow('Learner Name', learnerName),
                    const SizedBox(height: 10),
                    _buildReceiptRow('Date & Window', '$dateStr ($startStr – $endStr)'),
                    const SizedBox(height: 10),
                    _buildReceiptRow('Verified Duration', '60 Minutes (Full Cycle)'),
                    const SizedBox(height: 10),
                    _buildReceiptRow(
                      'Locked GPS Coordinates',
                      '${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E',
                    ),
                    const SizedBox(height: 10),
                    _buildReceiptRow('Geofence Status', 'Matched (≤ 150m Home Vicinity)'),
                    const SizedBox(height: 10),
                    _buildReceiptRow('Taught Syllabus Topic', topic),
                  ],
                ),
              ),
              const Spacer(),

              // Return to Learner Profile Button
              SizedBox(
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
                    controller.lastCompletedReceipt = null;
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Return to Learner Profile',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
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

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
