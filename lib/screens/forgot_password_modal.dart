import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';

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

  // 🔥 FIREBASE VARIABLES
  String? _verificationId;
  int? _resendToken;

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

  // 🚀 STEP 1: SEND SMS (Using Firebase)
  Future<void> _verifyPhone() async {
    final phone = _phoneController.text.trim();
    
    // Basic validation
    if (phone.length < 10) {
      _showMessage("Enter a valid phone number", true);
      return;
    }

    setState(() { _isLoading = true; _message = null; });

    try {
      // FORMAT: Ensure it has +254 (or your country code)
      String formattedPhone = phone.startsWith('0') 
          ? '+254${phone.substring(1)}' 
          : phone;

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        forceResendingToken: _resendToken, // Used for resend logic

        // 1. SILENT VERIFICATION (Android Only)
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-sign in the user
          await FirebaseAuth.instance.signInWithCredential(credential);
          
          // Proceed to update password on backend immediately
          await _updateBackendPassword(); 
        },

        // 2. ERROR HANDLING
        verificationFailed: (FirebaseAuthException e) {
          
          String errorMsg = "Verification Failed.";
          if (e.code == 'invalid-phone-number') errorMsg = "Invalid Phone Number.";
          if (e.code == 'too-many-requests') errorMsg = "Too many attempts. Try again later.";
          
          _showMessage(errorMsg, true);
        },

        // 3. CODE SENT (Standard Flow)
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken; // Save this for resending
              _step = 2;
              _isLoading = false;
              _message = "OTP sent via SMS";
              _isError = false;
            });
            _startTimer(); // Start the countdown
          }
        },

        // 4. TIMEOUT
        codeAutoRetrievalTimeout: (String verificationId) {
          // Just update the ID, don't stop the UI
          if (mounted) setState(() => _verificationId = verificationId);
        },
      );
    } catch (e) {
      _showMessage("Error: $e", true);
    }
  }

  // 🔄 RESEND LOGIC
  Future<void> _resendCode() async {
    if (!_canResend) return;
    _verifyPhone(); // Firebase handles the resend using the same function
  }

  // 🚀 STEP 2: VERIFY OTP & RESET
  Future<void> _submitOtpAndReset() async {
    if (_otpController.text.isEmpty || _newPassController.text.isEmpty) {
       _showMessage("Please fill all fields", true);
       return;
    }
    
    if (_verificationId == null) {
      _showMessage("Error: No Verification ID found.", true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create Credential
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!, 
        smsCode: _otpController.text.trim()
      );

      // 2. Verify with Firebase
      await FirebaseAuth.instance.signInWithCredential(credential);

      // 3. If successful, update Backend
      await _updateBackendPassword();

    } on FirebaseAuthException catch (e) {
      _showMessage(e.code == 'invalid-verification-code' ? "Invalid OTP Code" : "Error: ${e.message}", true);
    } catch (e) {
      _showMessage("An unknown error occurred.", true);
    }
  }

// 🔌 BACKEND CALL (Updated to send Token)
  Future<void> _updateBackendPassword() async {
    try {
      // 1. Get the current logged-in user (we just signed in with OTP)
      User? firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser == null) {
        _showMessage("Error: User not identified.", true);
        return;
      }

      // 2. GET THE SECURITY TOKEN
      String? idToken = await firebaseUser.getIdToken();

      if (idToken == null) {
        _showMessage("Error: Could not generate security token.", true);
        return;
      }

      // 3. Send the TOKEN (not the phone number) to the backend
      bool success = await ApiService.resetPasswordByPhone(
        idToken, // <--- SEND TOKEN HERE
        _newPassController.text.trim()
      );

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password Reset Successful! Login now."), backgroundColor: Colors.green)
        );
      } else {
        _showMessage("Server Error: Could not update password.", true);
      }
    } catch (e) {
      _showMessage("Network Error: $e", true);
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