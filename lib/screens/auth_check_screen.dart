import 'package:dita_app/services/update_service.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'maintenance_screen.dart';
import '../core/storage/local_storage.dart';
import '../core/storage/storage_keys.dart';
import '../core/errors/failures.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class AuthCheckScreen extends ConsumerStatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  ConsumerState<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends ConsumerState<AuthCheckScreen> with SingleTickerProviderStateMixin {
  final LocalAuthentication auth = LocalAuthentication();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _animationController.forward();
    checkForUpdate();
    _checkAppStatus(); 
  }

  Future<void> _checkAppStatus() async {
    await Future.delayed(const Duration(seconds: 1));

    try {
      // Check Maintenance Mode
      final status = await ApiService.getSystemStatus();
      
      // If widget was closed while waiting, stop
      if (!mounted) return;

      if (status != null && status['maintenance_mode'] == true) {
        // 🛑 STOP! Go to Maintenance Screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MaintenanceScreen(
              title: status['maintenance_title'] ?? "System Under Maintenance",
              message: status['maintenance_message'] ?? "We will be back shortly.",
            )
          )
        );
        return; // Important: Exit here so we don't try to login
      }
    } catch (e) {
    }
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // 1. Check local cache first
    final localUser = await ref.read(userLocalDataSourceProvider).getCachedUser();

    if (localUser != null) {
      // 2. Validate session with server (Check for Migration/Expiry)
      final result = await ref.read(userRepositoryProvider).getCurrentUser();
      
      await result.fold(
        (failure) async {
          if (failure is AuthFailure) { // Defined in core/errors/failures.dart
             // 🚔 Token Invalid = MIGRATION / LOGOUT
             await ref.read(userLocalDataSourceProvider).clearCache();
             
             // Check if user has already seen the migration alert
             final hasDismissed = LocalStorage.getItem<bool>(
               StorageKeys.settingsBox, 
               StorageKeys.hasDismissedMigrationAlert
             ) ?? false;
             
             // Only show migration alert if they haven't dismissed it before
             if (mounted) _navigateToLogin(showMigrationAlert: !hasDismissed);
          } else {
             // 🛑 Offline/Server Error -> Trust local cache & Proceed
             _doBiometricsAndLogin();
          }
        },
        (user) async {
           // ✅ Session Valid
           if (user != null) {
             _doBiometricsAndLogin();
           } else {
             // Should not occur if localUser != null unless repository cleared it
              if (mounted) _navigateToLogin();
           }
        }
      );
    } else {
      if (mounted) _checkOnboarding();
    }
  }

  Future<void> _doBiometricsAndLogin() async {
      bool authenticated = false;
      try {
        final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
        final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

        if (canAuthenticate) {
          authenticated = await auth.authenticate(
            localizedReason: 'Scan to enter DITA App',
            options: const AuthenticationOptions(
              stickyAuth: true,
              biometricOnly: true,
              useErrorDialogs: true,
            ),
          );
        } else {
          authenticated = true;
        }
      } catch (e) {
        authenticated = false;
      }

      if (mounted) {
        if (authenticated) {
          _navigateToHome();
        } else {
           // If biometrics failed, go to login (not onboarding, since user existed)
           // Or maybe just show login? Logic says _checkOnboarding in original code, 
           // but defaulting to Login is safer if user is cached.
           _navigateToLogin(); 
        }
      }
  }

  void _checkOnboarding() {
    final hasSeenOnboarding = LocalStorage.getItem<bool>(StorageKeys.settingsBox, StorageKeys.hasSeenOnboarding) ?? false;

    if (hasSeenOnboarding) {
      _navigateToLogin();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen())
      );
    }
  }
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => const HomeScreen())
    );
  }

  void _navigateToLogin({bool showMigrationAlert = false}) {
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => LoginScreen(showMigrationAlert: showMigrationAlert))
    );
  }

 @override
  Widget build(BuildContext context) {
    // 🟢 1. Theme Awareness
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 🟢 2. Dynamic Gradient (Matches Login Screen)
    final gradientColors = isDark 
        ? [const Color(0xFF0F172A), const Color(0xFF003366)]  // Midnight -> Navy
        : [const Color(0xFF003366), const Color(0xFF004C99)]; // Blue -> Light Blue

    return Scaffold(
      backgroundColor: gradientColors[0], // Match top color
      body: Stack(
        children: [
          // 1. GRADIENT BACKGROUND
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
            ),
          ),

          // 2. DECORATIVE ELEMENTS
          Positioned(
            right: -50, top: -50,
            child: Icon(Icons.school, size: 300, color: Colors.white.withOpacity(0.05)),
          ),

          // 3. CENTER CONTENT
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Container
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white, // Keep logo white for contrast
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2), 
                          blurRadius: 30, 
                          offset: const Offset(0, 10)
                        )
                      ],
                    ),
                    child: SizedBox(
                      height: 60,
                      width: 60,
                      child: Image.asset(
                        'assets/icon/icon.png', 
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // App Name
                  const Text(
                    "DITA APP",
                    style: TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.w900, 
                      color: Colors.white, 
                      letterSpacing: 4
                    ),
                  ),
                  Text(
                    "Empowering Tech Leaders",
                    style: TextStyle(
                      fontSize: 14, 
                      color: Colors.white.withOpacity(0.7), 
                      letterSpacing: 1
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Loading Indicator
                  const SizedBox(
                    width: 24, 
                    height: 24, 
                    child: CircularProgressIndicator(
                      color: Colors.white, 
                      strokeWidth: 2
                    )
                  ),
                ],
              ),
            ),
          ),
          
          // 4. FOOTER
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "Verifying Your Identity...",
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
            ),
          )
        ],
      ),
    );
  }
}