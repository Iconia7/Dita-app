import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Assuming you have your base URL accessible
const String baseUrl = 'https://dita-app-backend.onrender.com/api';

class ForgotPasswordModal extends StatefulWidget {
  const ForgotPasswordModal({super.key});

  @override
  State<ForgotPasswordModal> createState() => _ForgotPasswordModalState();
}

class _ForgotPasswordModalState extends State<ForgotPasswordModal> {
  // Controllers
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPassController = TextEditingController();

  // State Variables
  int _step = 1; // 1 = Request OTP, 2 = Verify & Reset
  bool _isLoading = false;
  String? _message;
  bool _isError = false;

  // --- API LOGIC ---

  Future<void> _requestOtp() async {
    setState(() { _isLoading = true; _message = null; });

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage("Please enter your email", true);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/request-reset/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _step = 2; // Move to Step 2
          _isLoading = false;
        });
        _showMessage("OTP sent! Check your email.", false);
      } else {
        _showMessage("Failed to send OTP. Try again.", true);
      }
    } catch (e) {
      _showMessage("Connection error. Check internet.", true);
    }
  }

  Future<void> _resetPassword() async {
    setState(() { _isLoading = true; _message = null; });

    final otp = _otpController.text.trim();
    final newPass = _newPassController.text.trim();

    if (otp.isEmpty || newPass.isEmpty) {
      _showMessage("Please fill all fields", true);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/confirm-reset/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text.trim(),
          'otp': otp,
          'new_password': newPass
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if(mounted) {
          Navigator.pop(context); // Close modal
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Password Reset Successful! Login now."), backgroundColor: Colors.green),
          );
        }
      } else {
        _showMessage(data['error'] ?? "Reset failed", true);
      }
    } catch (e) {
      _showMessage("Connection error.", true);
    }
  }

  void _showMessage(String msg, bool isError) {
    setState(() {
      _isLoading = false;
      _message = msg;
      _isError = isError;
    });
  }

 @override
  Widget build(BuildContext context) {
    // 🟢 Theme Helpers
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.labelSmall?.color;
    final primaryColor = Theme.of(context).primaryColor;
    final inputFill = isDark ? Colors.white10 : const Color(0xFFF5F7FA);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: sheetColor, // 🟢 Dynamic BG
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300], // 🟢 Dynamic Grey
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              _step == 1 ? 'Forgot Password?' : 'Reset Password',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor), // 🟢
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _step == 1 
                ? 'Enter your registered email to receive a code.' 
                : 'Enter the 6-digit code sent to your email.',
              textAlign: TextAlign.center,
              style: TextStyle(color: subTextColor), // 🟢
            ),
            const SizedBox(height: 24),

            // --- STEP 1: EMAIL INPUT ---
            if (_step == 1)
              _buildInput(_emailController, 'Email Address', Icons.email_outlined, inputFill, textColor, subTextColor),

            // --- STEP 2: OTP & NEW PASS ---
            if (_step == 2) ...[
              _buildInput(_otpController, '6-Digit OTP', Icons.pin, inputFill, textColor, subTextColor, isNumber: true),
              const SizedBox(height: 16),
              _buildInput(_newPassController, 'New Password', Icons.lock_outline, inputFill, textColor, subTextColor, isPass: true),
            ],

            const SizedBox(height: 16),

            // Error/Success Message
            if (_message != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _isError ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1), // 🟢 Softer colors
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _isError ? Colors.red : Colors.green, fontWeight: FontWeight.bold),
                ),
              ),

            // Action Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading 
                  ? null 
                  : (_step == 1 ? _requestOtp : _resetPassword),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor, // 🟢
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_step == 1 ? "Send Code" : "Reset Password", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),

            // Back button (Only Step 2)
            if (_step == 2 && !_isLoading)
              TextButton(
                onPressed: () => setState(() => _step = 1),
                child: const Text("Change Email"),
              ),
          ],
        ),
      ),
    );
  }

  // Helper Widget to reduce clutter & enforce theme
  Widget _buildInput(TextEditingController ctrl, String label, IconData icon, Color fill, Color? text, Color? hint, {bool isPass = false, bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      obscureText: isPass,
      style: TextStyle(color: text), // 🟢
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: hint), // 🟢
        prefixIcon: Icon(icon, color: hint),
        filled: true,
        fillColor: fill, // 🟢
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}