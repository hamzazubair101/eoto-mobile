import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_logos.dart';
import '../utils/app_preferences.dart';
import '../controllers/registration_controller.dart';
import '../services/database_service.dart';
import 'onboarding/intro_slides_screen.dart';
import 'onboarding/get_started_screen.dart';
import 'teacher_dashboard.dart';

import 'focal_person_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // 1-second splash screen branding
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    // 1. Check if a Focal Person or Teacher is already logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final email = (currentUser.email ?? '').toLowerCase().trim();
      // Check if user is a Focal Person or Teacher
      final fpDoc = await FirebaseFirestore.instance.collection('focal_persons').doc(email).get();
      final bool isFocalPerson = fpDoc.exists || email.contains('focal') || email.endsWith('@eoto.pk');

      if (isFocalPerson) {
        final focalStatus = (fpDoc.data()?['status'] ?? 'active').toString().toLowerCase();
        if (focalStatus != 'suspended') {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => FocalPersonDashboard(focalEmail: email.isNotEmpty ? email : 'cust_focal@eoto.pk')),
          );
          return;
        }
      }

      try {
        final controller = Provider.of<RegistrationController>(context, listen: false);
        await controller.loadTeacherProfile(currentUser.uid);
        if (controller.teacherStatus == 'approved') {
          await controller.loadLearnersFromFirestore(currentUser.uid);
          controller.subscribeToLearners(currentUser.uid);
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const TeacherDashboard()),
          );
          return;
        }
      } catch (e) {
        debugPrint("Auto-login error: $e");
      }
    }

    // 2. Check if the user has already seen the onboarding intro slides
    final bool hasSeenOnboarding = AppPreferences.hasSeenOnboarding;
    if (!hasSeenOnboarding) {
      // First-time user: Show intro slides
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const IntroSlidesScreen()),
      );
    } else {
      // Returning user: Skip intro slides and go directly to Get Started
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const GetStartedScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Official EOTO Logo
            AppLogos.emblem(height: 100),
            const SizedBox(height: 8),
            Text(
              'Each One Teach One',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textBlack,
                    fontWeight: FontWeight.normal,
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: AppTheme.primaryLime,
            ),
          ],
        ),
      ),
    );
  }
}
