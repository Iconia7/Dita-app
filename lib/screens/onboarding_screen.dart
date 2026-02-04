import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dita_app/core/storage/local_storage.dart';
import 'package:dita_app/core/storage/storage_keys.dart';
import 'package:dita_app/screens/login_screen.dart';
import 'package:dita_app/widgets/bouncing_button.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  bool _isLastPage = false;

  void _completeOnboarding() async {
    // Save flag locally using core storage (Hive)
    await LocalStorage.setItem(StorageKeys.settingsBox, StorageKeys.hasSeenOnboarding, true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // PAGE VIEW
            PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _isLastPage = index == 2);
              },
              children: [
                _buildSlide(
                  title: "Your Pocket Campus",
                  description: "Access your timetable, exam schedules, and attendance in real-time. Sync directly with the student portal.",
                  image: Icons.school_rounded,
                  isDark: isDark,
                  primaryColor: primaryColor,
                  context: context,
                ),
                _buildSlide(
                  title: "Stay Connected",
                  description: "Join the Daystar community. Share updates, market your hustle, and see what's trending on campus.",
                  image: Icons.forum_rounded,
                  isDark: isDark,
                  primaryColor: Colors.orange,
                  context: context,
                ),
                _buildSlide(
                  title: "Ace Your Studies",
                  description: " Manage tasks, earn leaderboard points, and access past papers and resources. All in one place.",
                  image: Icons.emoji_events_rounded,
                  isDark: isDark,
                  primaryColor: Colors.purple,
                  context: context,
                ),
              ],
            ),

            // CONTROLS
            Container(
              alignment: const Alignment(0, 0.85),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // SKIP
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: textColor?.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // INDICATOR
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: 3,
                    effect: ExpandingDotsEffect(
                      activeDotColor: primaryColor,
                      dotColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                      dotHeight: 8,
                      dotWidth: 8,
                    ),
                  ),

                  // NEXT/DONE
                  BouncingButton(
                    onTap: () {
                      if (_isLastPage) {
                        _completeOnboarding();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        _isLastPage ? "Get Started" : "Next",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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

  Widget _buildSlide({
    required String title,
    required String description,
    required IconData image,
    required bool isDark,
    required Color primaryColor,
    required BuildContext context,
  }) {
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(image, size: 100, color: primaryColor),
          ),
          const SizedBox(height: 50),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: subTextColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
