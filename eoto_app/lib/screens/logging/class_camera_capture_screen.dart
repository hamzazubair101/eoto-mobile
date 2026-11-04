import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class ClassCameraCaptureScreen extends StatefulWidget {
  const ClassCameraCaptureScreen({Key? key}) : super(key: key);

  @override
  State<ClassCameraCaptureScreen> createState() => _ClassCameraCaptureScreenState();
}

class _ClassCameraCaptureScreenState extends State<ClassCameraCaptureScreen> {
  bool _isCaptured = false;
  bool _recFlash = true;
  Timer? _flashTimer;
  int _timerSeconds = 0;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _startRecordingFeedback();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _recordTimer?.cancel();
    super.dispose();
  }

  void _startRecordingFeedback() {
    // Flashing REC light
    _flashTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _recFlash = !_recFlash;
      });
    });

    // Recording duration timer
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timerSeconds++;
      });
    });
  }

  String _formatDuration(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _capturePhoto() {
    _flashTimer?.cancel();
    _recordTimer?.cancel();
    setState(() {
      _isCaptured = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Camera screen is deep black
      body: SafeArea(
        child: Column(
          children: [
            // Top Camera Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  if (!_isCaptured)
                    Row(
                      children: [
                        Container(
                          height: 10,
                          width: 10,
                          decoration: BoxDecoration(
                            color: _recFlash ? Colors.red : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'REC',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatDuration(_timerSeconds),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace'),
                        ),
                      ],
                    )
                  else
                    const Text(
                      'PREVIEW',
                      style: TextStyle(color: AppTheme.primaryLime, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  const SizedBox(width: 48), // Spacer balance
                ],
              ),
            ),

            // Camera Viewfinder Frame Box
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.grey[950],
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _isCaptured ? AppTheme.primaryLime : Colors.white24, width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Grid overlays
                    if (!_isCaptured)
                      CustomPaint(
                        size: Size.infinite,
                        painter: GridPainter(),
                      ),

                    // Target Face outline guide
                    if (!_isCaptured)
                      Opacity(
                        opacity: 0.35,
                        child: Container(
                          height: 280,
                          width: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.primaryLime, width: 2),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      )
                    else
                      // Verification success panel (Folder 7 spec)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.primaryLime, width: 1.5),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, color: AppTheme.primaryLime, size: 48),
                            SizedBox(height: 12),
                            Text(
                              'VERIFICATION SUCCESS',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Student presence verified securely.',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                    // Top/Bottom overlay texts
                    if (!_isCaptured)
                      const Positioned(
                        bottom: 24,
                        child: Text(
                          'Align student face inside the marker',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom camera controls deck
            Container(
              padding: const EdgeInsets.all(40.0),
              child: _isCaptured
                  ? Row(
                      children: [
                        // Retake button
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24, width: 1.5),
                              minimumSize: const Size(double.infinity, 58),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(29)),
                            ),
                            onPressed: () {
                              setState(() {
                                _isCaptured = false;
                                _timerSeconds = 0;
                                _startRecordingFeedback();
                              });
                            },
                            child: const Text('RE-TAKE', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Confirm button
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryLime,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(double.infinity, 58),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(29)),
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('CONFIRM PHOTO', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Large capture circular button
                        GestureDetector(
                          onTap: _capturePhoto,
                          child: Container(
                            height: 84,
                            width: 84,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryLime,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.black, size: 36),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1.0;

    // Draw vertical lines
    canvas.drawLine(Offset(size.width * 1 / 3, 0), Offset(size.width * 1 / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);

    // Draw horizontal lines
    canvas.drawLine(Offset(0, size.height * 1 / 3), Offset(size.width, size.height * 1 / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
