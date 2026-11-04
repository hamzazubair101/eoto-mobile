import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../controllers/registration_controller.dart';
import 'help_support_screen.dart';
import 'profile_sub_screens.dart';
import '../../utils/logout_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF171717), size: 19),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF171717),
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.black38,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<RegistrationController>(context);
    final String? uid =
        controller.currentTeacherUid ?? FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: (uid != null && uid.isNotEmpty)
          ? FirebaseFirestore.instance
              .collection('teachers')
              .doc(uid)
              .snapshots()
          : const Stream.empty(),
      builder: (context, snapshot) {
        final Map<String, dynamic> liveDoc =
            (snapshot.hasData && snapshot.data!.exists)
                ? (snapshot.data!.data() as Map<String, dynamic>? ?? {})
                : {};

        final String rawName =
            (liveDoc['fullName'] ?? controller.fullName ?? 'Ali Khan')
                .toString();
        final String fullName = _toTitleCase(rawName);
        final String instOrDistrict = (liveDoc['instituteName'] ??
                liveDoc['district'] ??
                controller.instituteName ??
                controller.district ??
                'Punjab University, Lahore')
            .toString();

        final String focalName = (liveDoc['assignedFocalPersonName'] ??
                controller.assignedFocalPersonName ??
                'Dr. Ahmed')
            .toString();
        final String focalEmail = (liveDoc['assignedFocalPersonEmail'] ??
                controller.assignedFocalPersonEmail ??
                'islamabad_officer@eoto.pk')
            .toString();

        final String initials = fullName
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .join()
            .toUpperCase();
        final String displayInitials =
            initials.length > 2 ? initials.substring(0, 2) : initials;

        // Live KPI Counters from learners assigned to this teacher:
        // 1. Current Learner: Active adult learners excluding disqualified/rejected or already-certified
        // 2. Learner Certified: Learners who have cleared exams and been awarded certificates
        int currentLearnersCount = 0;
        int certifiedLearnersCount = 0;
        for (final l in controller.learners) {
          final String st = (l['status'] ?? '').toString().toLowerCase();
          if (st == 'certified' || st == 'completed') {
            certifiedLearnersCount++;
          } else if (!st.contains('reject') && !st.contains('disqualif')) {
            currentLearnersCount++;
          }
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: const Text(
              'My Profile',
              style: TextStyle(
                color: Color(0xFF171717),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: const Color(0xFFF3F4F6),
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22.0, vertical: 18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1.1 Main Profile Card (#F5F5F7 Light Grey, rounded-[32px])
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Column(
                      children: [
                        // User Avatar: Circular initial badge
                        Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E232A),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            displayInitials.isNotEmpty ? displayInitials : 'AK',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Full Name
                        Text(
                          fullName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF171717),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Status Pill: ACTIVE STUDENT-TEACHER (#CCFF00)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCCFF00),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'ACTIVE STUDENT-TEACHER',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 10.5,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Institutional Affiliation
                        Text(
                          instOrDistrict,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Dynamic KPI Tiles (Side-by-Side)
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '$currentLearnersCount',
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF171717),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Current Learner',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '$certifiedLearnersCount',
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF171717),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Learner Certified',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 1.2 Menu Options & Interactive Flows
                  // ① Account Details
                  _buildMenuOption(
                    icon: Icons.person_outline_rounded,
                    title: 'Account Details',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AccountSettingsScreen(
                              isFocalPerson: false),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // ② Security and Login
                  _buildMenuOption(
                    icon: Icons.shield_outlined,
                    title: 'Security and Login',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SecurityAndLoginScreen(
                              isFocalPerson: false),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // ③ Notification Preferences
                  _buildMenuOption(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notification Preferences',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const NotificationPreferencesScreen(
                                  isFocalPerson: false),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // ④ Contact Focal Person (Interactive Bottom Sheet Drawer)
                  _buildMenuOption(
                    icon: Icons.support_agent_rounded,
                    title: 'Contact Focal Person',
                    onTap: () {
                      ContactFocalPersonSheet.show(
                        context,
                        focalEmail: focalEmail,
                        fallbackName: focalName,
                        fallbackInstitute: instOrDistrict,
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // ⑤ App Help & FAQs
                  _buildMenuOption(
                    icon: Icons.help_outline_rounded,
                    title: 'App Help & FAQs',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const HelpSupportScreen(isFocalPerson: false),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 26),

                  // ⑥ Log Out (#2C2D30 dark charcoal pill button, rounded-[30px])
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C2D30),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () =>
                          LogoutHelper.showLogoutConfirmation(context),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text(
                        'Log Out',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
