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
    // Handle keyboard covering input
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              _step == 1 ? 'Forgot Password?' : 'Reset Password',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _step == 1 
                ? 'Enter your registered email to receive a code.' 
                : 'Enter the 6-digit code sent to your email.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // --- STEP 1: EMAIL INPUT ---
            if (_step == 1)
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

            // --- STEP 2: OTP & NEW PASS ---
            if (_step == 2) ...[
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '6-Digit OTP',
                  prefixIcon: const Icon(Icons.pin),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPassController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Error/Success Message
            if (_message != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _isError ? Colors.red[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _isError ? Colors.red : Colors.green),
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
                  backgroundColor: const Color(0xFF003366),
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
}