import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_preferences.dart';
import 'get_started_screen.dart';

class IntroSlidesScreen extends StatefulWidget {
  const IntroSlidesScreen({Key? key}) : super(key: key);

  @override
  State<IntroSlidesScreen> createState() => _IntroSlidesScreenState();
}

class _IntroSlidesScreenState extends State<IntroSlidesScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _slides = [
    {
      'title': 'Learn & Transform',
      'description': 'Mobilize volunteer student teachers to spread basic literacy across Pakistan, transforming lives and communities.',
      'icon': 'school_outlined',
    },
    {
      'title': 'Diagnose Needs',
      'description': 'Administer diagnostic baseline tests to gauge learner literacy levels and configure custom lesson paths.',
      'icon': 'analytics_outlined',
    },
    {
      'title': 'Track Sessions',
      'description': 'Log active daily classes with verified location coordinates and countdown timers to build progress metrics.',
      'icon': 'timer_outlined',
    },
  ];

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'school_outlined':
        return Icons.school_outlined;
      case 'analytics_outlined':
        return Icons.analytics_outlined;
      case 'timer_outlined':
        return Icons.timer_outlined;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background theme
      body: SafeArea(
        child: Column(
          children: [
            // Top branding / Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'assets/images/eoto_logo_alt.png',
                    height: 26,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Row(
                        children: [
                          const Icon(Icons.school, color: AppTheme.primaryLime, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'EOTO',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.white,
                                  fontSize: 18,
                                  letterSpacing: 1.0,
                                ),
                          ),
                        ],
                      );
                    },
                  ),
                  TextButton(
                    onPressed: () {
                      AppPreferences.setHasSeenOnboarding(true);
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const GetStartedScreen()),
                      );
                    },
                    child: const Text(
                      'SKIP',
                      style: TextStyle(
                        color: AppTheme.primaryLime,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Onboarding slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Slide visual container
                        Container(
                          height: 180,
                          width: 180,
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.primaryLime, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryLime.withOpacity(0.15),
                                blurRadius: 30,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: Icon(
                            _getIcon(slide['icon']!),
                            color: AppTheme.primaryLime,
                            size: 80,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Title
                        Text(
                          slide['title']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Description
                        Text(
                          slide['description']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dot indicators & Bottom button
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                children: [
                  // Dot list
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => Container(
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        decoration: BoxDecoration(
                          color: _currentPage == index ? AppTheme.primaryLime : Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Dynamic action button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryLime,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 58),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(29),
                        ),
                      ),
                      onPressed: () {
                        if (_currentPage == _slides.length - 1) {
                          // Complete onboarding
                          AppPreferences.setHasSeenOnboarding(true);
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const GetStartedScreen()),
                          );
                        } else {
                          // Next page
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeIn,
                          );
                        }
                      },
                      child: Text(
                        _currentPage == _slides.length - 1 ? 'GET STARTED' : 'NEXT',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
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
