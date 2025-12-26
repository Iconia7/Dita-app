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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor, // 🟢 Dynamic BG
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Check your Phone 📲", textAlign: TextAlign.center, 
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)), // 🟢
        content: Text("Enter your M-Pesa PIN to complete the transaction.", textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)), // 🟢
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
    // 🟢 Theme Helpers
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final inputFill = isDark ? Colors.white10 : Colors.grey[100];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: sheetColor, // 🟢 Dynamic BG
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, 
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
                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.wallet, color: primaryColor), // 🟢
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Membership Payment", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)), // 🟢
                      Text("Secure M-Pesa Checkout", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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
                  Text("KES 200", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: primaryColor)), // 🟢
                  const Text("Semester Membership Fee", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                  
                  const SizedBox(height: 30),

                  // Phone Input
                  Container(
                    decoration: BoxDecoration(
                      color: inputFill, // 🟢 Dynamic Input BG
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(fontWeight: FontWeight.bold, color: textColor), // 🟢
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.phone_android, color: Colors.grey[500]),
                        hintText: "M-Pesa Number",
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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