import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:dita_app/utils/dita_toast.dart';
import '../core/errors/exceptions.dart';

class ForgotPasswordModal extends StatefulWidget {
  const ForgotPasswordModal({super.key});

  @override
  State<ForgotPasswordModal> createState() => _ForgotPasswordModalState();
}

class _ForgotPasswordModalState extends State<ForgotPasswordModal> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPassController = TextEditingController();

  int _step = 1;
  bool _isLoading = false;
  String? _message;
  bool _isError = false;

  // ⏱️ TIMER VARIABLES
  Timer? _timer;
  int _start = 30;
  bool _canResend = false;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _newPassController.dispose();
    super.dispose();
  }

  // ⏱️ TIMER LOGIC
  void _startTimer() {
    setState(() {
      _start = 30;
      _canResend = false;
    });
    _timer?.cancel(); // Cancel any existing timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          timer.cancel();
          _canResend = true;
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  // 🚀 STEP 1: SEND SMS (Using Africa's Talking)
  Future<void> _verifyPhone() async {
    final phone = _phoneController.text.trim();
    
    // Basic validation
    if (phone.length < 10) {
      _showMessage("Enter a valid phone number", true);
      return;
    }

    setState(() { _isLoading = true; _message = null; });

    try {
      bool success = await ApiService.requestOtp(phone);
      if (success) {
        if (mounted) {
          setState(() {
            _step = 2;
            _isLoading = false;
            _message = "OTP sent via SMS";
            _isError = false;
          });
          _startTimer(); // Start the countdown
        }
      } else {
        _showMessage("Failed to send OTP. Please try again.", true);
      }
    } on ApiException catch (e) {
      _showMessage(e.message, true);
    } catch (e) {
      _showMessage("Error: $e", true);
    }
  }

  // 🔄 RESEND LOGIC
  Future<void> _resendCode() async {
    if (!_canResend) return;
    _verifyPhone();
  }

  // 🚀 STEP 2: VERIFY OTP & RESET
  Future<void> _submitOtpAndReset() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    final newPassword = _newPassController.text.trim();

    if (otp.isEmpty || newPassword.isEmpty) {
       _showMessage("Please fill all fields", true);
       return;
    }

    setState(() => _isLoading = true);

    try {
      bool success = await ApiService.resetPasswordWithOtp(phone, otp, newPassword);
      if (success && mounted) {
        Navigator.pop(context);
        DitaToast.success(context, "Password Reset Successful! Login now.");
      } else {
        _showMessage("Server Error: Could not update password.", true);
      }
    } on ApiException catch (e) {
      _showMessage(e.message, true);
    } catch (e) {
      _showMessage("Error: $e", true);
    }
  }

  void _showMessage(String msg, bool isError) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _message = msg;
      _isError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;
    final inputFill = isDark ? Colors.white10 : const Color(0xFFF5F7FA);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: sheetColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            
            Text(
              _step == 1 ? 'Reset via SMS' : 'Verify & Reset',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            if (_step == 1)
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone, color: primaryColor),
                  filled: true, fillColor: inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),

            if (_step == 2) ...[
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'SMS Code',
                  prefixIcon: Icon(Icons.sms, color: primaryColor),
                  filled: true, fillColor: inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPassController,
                obscureText: true,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock, color: primaryColor),
                  filled: true, fillColor: inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              
              // ⏱️ TIMER UI
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_canResend)
                    Text("Resend code in $_start s", style: const TextStyle(color: Colors.grey)),
                  if (_canResend)
                    TextButton(
                      onPressed: _resendCode,
                      child: Text("Resend Code", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            if (_message != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _isError ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_message!, textAlign: TextAlign.center, style: TextStyle(color: _isError ? Colors.red : Colors.green)),
              ),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : (_step == 1 ? _verifyPhone : _submitOtpAndReset),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_step == 1 ? "Send SMS Code" : "Verify & Reset", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}