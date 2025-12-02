import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PayFeesSheet extends StatefulWidget {
  final Map<String, dynamic> user;

  const PayFeesSheet({super.key, required this.user});

  @override
  State<PayFeesSheet> createState() => _PayFeesSheetState();
}

class _PayFeesSheetState extends State<PayFeesSheet> {
  late TextEditingController _phoneController;
  bool _isLoading = false;
  Timer? _statusCheckTimer;

  // --- DESIGN SYSTEM COLORS ---
  final Color _primaryDark = const Color(0xFF003366);
  final Color _mpesaGreen = const Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.user['phone_number'] ?? "");
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  void _handlePayment() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();
    
    setState(() => _isLoading = true);
    // Simulate API Call or Real Call
    bool success = await ApiService.initiatePayment(_phoneController.text, widget.user['id']);
    setState(() => _isLoading = false);

    if (mounted && success) {
      _showInstructionDialog();
    }
  }

  void _startListeningForPayment() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final updatedUser = await ApiService.getUserDetails(widget.user['id']);
      if (updatedUser != null && updatedUser['is_paid_member'] == true) {
          timer.cancel();
          if (mounted) {
            Navigator.pop(context, true); // Close sheet and return TRUE
          }
      }
    });
  }

  void _showInstructionDialog() {
    // minimize the sheet slightly or show dialog on top
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Check your Phone 📲", textAlign: TextAlign.center),
        content: const Text("Enter your M-Pesa PIN to complete the transaction.", textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startListeningForPayment();
            },
            child: Text("Okay", style: TextStyle(color: _mpesaGreen, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This makes the sheet respect the keyboard height
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Wrap content height
          children: [
            // --- HANDLE BAR ---
            const SizedBox(height: 15),
            Container(
              height: 5, width: 50,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            ),
            
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _primaryDark.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.wallet, color: _primaryDark),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Membership Payment", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("Secure M-Pesa Checkout", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            
            const Divider(height: 1),

            // --- CONTENT ---
            Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                children: [
                  // Price Tag
                  Text("KES 200", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: _primaryDark)),
                  const Text("Semester Membership Fee", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                  
                  const SizedBox(height: 30),

                  // Phone Input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.phone_android),
                        hintText: "M-Pesa Number",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handlePayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mpesaGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: _isLoading 
                       ? const CircularProgressIndicator(color: Colors.white)
                       : const Text("PAY NOW", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 5),
                      Text("Secured by DITA", style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}