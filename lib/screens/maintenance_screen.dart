import 'package:dita_app/screens/auth_check_screen.dart';
import 'package:flutter/material.dart';
import 'package:dita_app/services/api_service.dart'; // Import your API service
// Or wherever you go after

class MaintenanceScreen extends StatefulWidget {
  final String title;
  final String message;

  const MaintenanceScreen({
    super.key, 
    this.title = "System Maintenance", 
    this.message = "We will be back shortly!"
  });

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Pulse animation for the icon
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    
    // Call your API (We will add this method in Part 3)
    final status = await ApiService.getSystemStatus();
    
    setState(() => _isLoading = false);

    if (status != null && status['maintenance_mode'] == false) {
      // Maintenance is OVER! Go to Login or Home
      if (mounted) {
         Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthCheckScreen()), // CHANGE THIS to your start screen
          (route) => false,
        );
      }
    } else {
      // Still in maintenance
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Still under maintenance. Please wait."),
            backgroundColor: Colors.orange,
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF003366), // DITA Dark Blue
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Animated Icon
              ScaleTransition(
                scale: Tween(begin: 0.9, end: 1.1).animate(
                  CurvedAnimation(parent: _controller, curve: Curves.easeInOut)
                ),
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.handyman_rounded, size: 80, color: Color(0xFFFFD700)), // Gold
                ),
              ),
              
              const SizedBox(height: 40),
              
              // 2. Title
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 3. Message
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  height: 1.5
                ),
              ),
              
              const SizedBox(height: 50),
              
              // 4. Retry Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _checkStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700), // Gold
                    foregroundColor: const Color(0xFF003366), // Blue Text
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("TRY AGAIN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}