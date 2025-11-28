// lib/features/auth/widgets/forgot_password_modal.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ForgotPasswordModal extends StatelessWidget {
  const ForgotPasswordModal({super.key});

  // Function to open WhatsApp or Email
Future<void> _contactSupport() async {
    // Use the direct API link which is more reliable than wa.me
    final Uri whatsappUrl = Uri.parse("https://api.whatsapp.com/send?phone=254115332870&text=Hello%20Admin,%20I%20forgot%20my%20Dita%20App%20password.");
    
    Uri.parse("https://flutter.dev"); // Test URL

    try {
      // Force external launch for WhatsApp
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      print("Could not launch WhatsApp: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          
          const Icon(Icons.lock_reset_rounded, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          
          const Text(
            'Reset Password',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          
          const Text(
            'For security reasons, please contact our support team to reset your password.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _contactSupport,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Contact Admin via WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}