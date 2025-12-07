import 'package:dita_app/services/api_service.dart';
import 'package:flutter/material.dart';

class ChangePasswordSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final Color primaryDark;

  const ChangePasswordSheet({
    super.key, 
    required this.user, 
    required this.primaryDark,
  });

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final TextEditingController _oldController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  bool _isLoading = false;

  Future<void> _changePassword() async {
    final oldPass = _oldController.text;
    final newPass = _newController.text;

    if (oldPass.isEmpty || newPass.isEmpty) return;

    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters"), backgroundColor: Colors.orange)
      );
      return;
    }

    setState(() => _isLoading = true);
    
    // API Call
    bool success = await ApiService.changePassword( 
      widget.user['id'],
      oldPass, 
      newPass
    );
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.pop(context); // Close sheet
    
    // Show final feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? "Password changed successfully!" : "Error: Incorrect old password or server error."),
        backgroundColor: success ? Colors.green : Colors.red,
      )
    );
  }

@override
  Widget build(BuildContext context) {
    // 🟢 Theme Helpers
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.labelSmall?.color;
    final primaryColor = Theme.of(context).primaryColor;
    final inputFill = isDark ? Colors.white10 : Colors.white;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF5F7FA), // 🟢 Dynamic BG
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Change Password", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)), // 🟢
          const Divider(),
          
          _buildInput(_oldController, "Current Password", inputFill, textColor, subTextColor),
          const SizedBox(height: 15),
          _buildInput(_newController, "New Password", inputFill, textColor, subTextColor),
          
          const SizedBox(height: 30),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor, // 🟢
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                padding: const EdgeInsets.symmetric(vertical: 15)
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Update Password", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, Color fill, Color? text, Color? hint) {
    return TextField(
      controller: ctrl,
      obscureText: true,
      style: TextStyle(color: text), // 🟢
      decoration: InputDecoration(
        labelText: label, 
        labelStyle: TextStyle(color: hint), // 🟢
        filled: true,
        fillColor: fill, // 🟢
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)
      ),
    );
  }
}