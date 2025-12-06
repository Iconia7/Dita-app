import 'package:dita_app/services/update_service.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'maintenance_screen.dart'; // <--- 1. IMPORT YOUR MAINTENANCE SCREEN HERE

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> with SingleTickerProviderStateMixin {
  final LocalAuthentication auth = LocalAuthentication();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final Color _primaryDark = const Color(0xFF003366);
  final Color _primaryLight = const Color(0xFF004C99);

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

    // 2. CHANGE THIS LINE: Call the App Status check INSTEAD of Login Status
    _checkAppStatus(); 
  }

  // 3. ADD THIS NEW FUNCTION HERE
  Future<void> _checkAppStatus() async {
    // Artificial delay for splash effect (optional, moved here)
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
      print("Status check failed (Offline?): $e");
      // If check fails, we assume app is online and proceed
    }

    // ✅ SYSTEM ONLINE: Now trigger the original login check
    _checkLoginStatus();
  }

  // 4. UPDATE THIS FUNCTION (Remove the delay since we did it above)
  Future<void> _checkLoginStatus() async {
    // (Delay removed because _checkAppStatus already waited)

    // 1. Check if we have saved data
    final userData = await ApiService.getUserLocally();

    if (userData != null) {
      // ... (Rest of your existing login logic stays exactly the same) ...
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
    // ... (Your existing build method stays exactly the same) ...
    return Scaffold(
      backgroundColor: _primaryDark,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryDark, _primaryLight],
              ),
            ),
          ),
          Positioned(
            right: -50, top: -50,
            child: Icon(Icons.school, size: 300, color: Colors.white.withOpacity(0.05)),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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