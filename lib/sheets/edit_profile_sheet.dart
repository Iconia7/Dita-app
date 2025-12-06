// You will need to bring the _buildDialogInput method over or define it again.
// For simplicity, I'll keep the logic inline here.
import 'package:flutter/material.dart';
import '../services/api_service.dart';

// --- Widget Helper (from ProfileScreen) ---
Widget _buildDialogInput(TextEditingController controller, String label, IconData icon, Color primaryDark, {bool isPhone = false}) {
    return TextField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryDark),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      ),
    );
}

class EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onProfileSaved;

  const EditProfileSheet({
    super.key, 
    required this.user, 
    required this.onProfileSaved,
  });

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final Color _primaryDark = const Color(0xFF003366); 
  bool _isSaving = false;

  late final TextEditingController _admController;
  late final TextEditingController _programController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _admController = TextEditingController(text: widget.user['admission_number']);
    _programController = TextEditingController(text: widget.user['program']);
    _phoneController = TextEditingController(text: widget.user['phone_number']);
    _emailController = TextEditingController(text: widget.user['email']);
    _selectedYear = widget.user['year_of_study'] ?? 1;
  }

  Future<void> _updateProfile() async {
    if (!mounted) return;
    setState(() => _isSaving = true);

    Map<String, dynamic> data = {
      "admission_number": _admController.text,
      "program": _programController.text,
      "year_of_study": _selectedYear,
      "phone_number": _phoneController.text,
      "email": _emailController.text,
    };

    bool success = await ApiService.updateUser(widget.user['id'], data);
    if (!mounted) return;

    if (success) {
      final freshData = await ApiService.getUserDetails(widget.user['id']);
      if (freshData != null) {
        await ApiService.saveUserLocally(freshData);
        widget.onProfileSaved(freshData); // Use the callback
        if (mounted) Navigator.pop(context);
      }
    } else {
      setState(() => _isSaving = false);
      // Show error message on the main screen (SnackBar or Dialog)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update profile."), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Padding handles the keyboard pushing the sheet up
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA), // Light background color
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Edit Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryDark)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const Divider(),
          
          SingleChildScrollView(
            // Use Builder to allow dialog state update within the sheet
            child: StatefulBuilder(
              builder: (context, setStateDialog) {
                return Column(
                  children: [
                    _buildDialogInput(_admController, "Admission No", Icons.badge_outlined, _primaryDark),
                    const SizedBox(height: 15),
                    _buildDialogInput(_programController, "Program", Icons.school_outlined, _primaryDark),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedYear,
                      decoration: InputDecoration(
                        labelText: "Year of Study",
                        prefixIcon: Icon(Icons.calendar_today, color: _primaryDark),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: [1, 2, 3, 4].map((y) => DropdownMenuItem(value: y, child: Text("Year $y"))).toList(),
                      onChanged: (val) => setStateDialog(() => _selectedYear = val!),
                    ),
                    const SizedBox(height: 15),
                    _buildDialogInput(_phoneController, "Phone Number", Icons.phone_iphone_rounded, _primaryDark, isPhone: true),
                    const SizedBox(height: 15),
                    _buildDialogInput(_emailController, "Email Address", Icons.email_outlined, _primaryDark),
                    const SizedBox(height: 30),
                  ],
                );
              }
            ),
          ),
          
          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                padding: const EdgeInsets.symmetric(vertical: 15)
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}