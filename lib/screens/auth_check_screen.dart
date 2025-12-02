import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> with SingleTickerProviderStateMixin {
  final LocalAuthentication auth = LocalAuthentication();
  
  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Colors
  final Color _primaryDark = const Color(0xFF003366);
  final Color _primaryLight = const Color(0xFF004C99);

  @override
  void initState() {
    super.initState();
    
    // Setup Entrance Animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _animationController.forward();

    // Trigger Login Check
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    // Artificial delay so the splash screen doesn't flicker too fast
    await Future.delayed(const Duration(seconds: 1));

    // 1. Check if we have saved data
    final userData = await ApiService.getUserLocally();

    if (userData != null) {
      // 2. User found! Attempt Biometric Unlock
      bool authenticated = false;
      try {
        final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
        final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

        if (canAuthenticate) {
          authenticated = await auth.authenticate(
            localizedReason: 'Scan to enter DITA App',
            // --- v2 SYNTAX FIX ---
            options: const AuthenticationOptions(
              stickyAuth: true,
              biometricOnly: true,
              useErrorDialogs: true,
            ),
          );
        } else {
          authenticated = true; // No hardware -> Pass
        }
      } catch (e) {
        print("Biometric Error: $e");
        authenticated = false;
      }

      if (mounted) {
        if (authenticated) {
          _navigateToHome(userData);
        } else {
          _navigateToLogin();
        }
      }
    } else {
      _navigateToLogin();
    }
  }

  void _navigateToHome(Map<String, dynamic> user) {
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => HomeScreen(user: user))
    );
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => const LoginScreen())
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryDark,
      body: Stack(
        children: [
          // 1. GRADIENT BACKGROUND
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryDark, _primaryLight],
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
    color: Colors.white,
    shape: BoxShape.circle,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2), 
        blurRadius: 30, 
        offset: const Offset(0, 10)
      )
    ],
  ),
  // Replace the Icon with your Image
  child: SizedBox(
    height: 60,
    width: 60,
    child: Image.asset(
      'assets/icon/icon.png', // <--- YOUR NEW LOGO ASSET
      fit: BoxFit.contain,
    ),
  ),
),
                  
                  const SizedBox(height: 30),
                  
                  // App Name
                  const Text(
                    "DITA",
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
                "Verifying Identity...",
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
            ),
          )
        ],
      ),
    );
  }
}