import 'dart:async';
import 'package:dita_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PayFeesScreen extends StatefulWidget {
  final String phoneNumber;
  final Map<String, dynamic> user;

  const PayFeesScreen({super.key, required this.phoneNumber, required this.user});

  @override
  State<PayFeesScreen> createState() => _PayFeesScreenState();
}

class _PayFeesScreenState extends State<PayFeesScreen> {
  late TextEditingController _phoneController;
  bool _isLoading = false;
  Timer? _statusCheckTimer;

  // Design Colors
  final Color _mpesaGreen = const Color(0xFF4CAF50);
  final Color _bgWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.phoneNumber);
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

void _startListeningForPayment() {
    print("Starting to poll server for payment status..."); // Debug print
    
    // Check every 3 seconds
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      print("Checking payment status..."); // See if this prints every 3s
      
      final updatedUser = await ApiService.getUserDetails(widget.user['id']);
      
      if (updatedUser != null) {
        print("Status on Server: ${updatedUser['is_paid_member']}"); // Debug print
        
        if (updatedUser['is_paid_member'] == true) {
          timer.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Colors.green, 
                content: Text("Payment Received! Welcome.")
              )
            );
            _goToHome(updatedUser);
          }
        }
      }
    });
  }

  void _goToHome(Map<String, dynamic> userData) {
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => HomeScreen(user: userData))
    );
  }

  void _handlePayment() async {
    setState(() => _isLoading = true);
    bool success = await ApiService.initiatePayment(_phoneController.text);
    setState(() => _isLoading = false);

    if (mounted && success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Column(
            children: [
              Icon(Icons.notification_important_rounded, size: 50, color: Colors.orange),
              SizedBox(height: 10),
              Text("Check your Phone 📲", textAlign: TextAlign.center),
            ],
          ),
          content: const Text(
            "We sent an M-Pesa request to your phone.\n\nEnter your PIN to complete the registration.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _startListeningForPayment();
              }, 
              style: ElevatedButton.styleFrom(
                backgroundColor: _mpesaGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
              ),
              child: const Text("I Entered my PIN")
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgWhite,
      // Minimal App Bar for the Skip Button
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Hide back button
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton(
              onPressed: () => _goToHome(widget.user),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Row(
                children: [
                  Text("Do this later"),
                  Icon(Icons.arrow_forward_ios, size: 14),
                ],
              ),
            ),
          )
        ],
      ),
      
      // Main Content centered vertically
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. VISUAL IDENTIFIER
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _mpesaGreen.withOpacity(0.2),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(Icons.monetization_on_rounded, size: 50, color: _mpesaGreen),
                ),
              ),
              const SizedBox(height: 30),

              // 2. TEXT HEADERS
              const Text(
                "Membership Fee",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w500
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "KES 500",
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  letterSpacing: -1,
                ),
              ),
              
              const SizedBox(height: 50),

              // 3. PHONE INPUT (Modern Pill Shape)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  decoration: const InputDecoration(
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(left: 20, right: 10),
                      child: Icon(Icons.phone_iphone_rounded, color: Colors.grey),
                    ),
                    labelText: "M-Pesa Number",
                    labelStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // 4. PAY BUTTON
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handlePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mpesaGreen,
                    foregroundColor: Colors.white,
                    shadowColor: _mpesaGreen.withOpacity(0.4),
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 20),
                          SizedBox(width: 10),
                          Text("PAY SECURELY", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                ),
              ),

              const SizedBox(height: 30),

              // 5. DISCLAIMER
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[400], size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Resources & Voting are locked until payment is complete.",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}