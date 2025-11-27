import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _admController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPassController = TextEditingController();
  
  // DROPDOWN VALUES
  String? _selectedProgram;
  int? _selectedYear;

  final List<String> _programs = [
    "Applied Computer Science",
    "Business Information Tech (BIT)",
    "Computer Science",
    "Commerce",
    "Communication",
    "Nursing",
    "Psychology",
    "Law"
  ];

  bool _isLoading = false;
  bool _obscurePassword = true;

  final Color _primaryBlue = const Color(0xFF003366);
  final Color _lightFillColor = const Color(0xFFF2F6FA);

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final data = {
      "username": _admController.text.trim(), 
      "admission_number": _admController.text.trim(),
      "phone_number": _phoneController.text.trim(),
      "email": "${_admController.text.trim()}@daystar.ac.ke",
      "password": _passwordController.text,
      // SEND SELECTED VALUES
      "program": _selectedProgram ?? "Applied Computer Science", 
      "year_of_study": _selectedYear ?? 1 
    };

    bool success = await ApiService.registerUser(data);

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text("Account Created! Please Login."))
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.red, content: Text("Registration Failed. User may exist."))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Text(
                  "Create Account",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _primaryBlue, letterSpacing: 1),
                ),
                Text("Join the DITA Community", style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 30),

                // Admission Number
                _buildStylishInput(controller: _admController, hint: "Admission Number", icon: Icons.badge_outlined),
                const SizedBox(height: 15),

                // Phone Number
                _buildStylishInput(controller: _phoneController, hint: "M-Pesa Number", icon: Icons.phone_iphone_rounded, keyboardType: TextInputType.phone),
                const SizedBox(height: 15),

                // --- PROGRAM DROPDOWN ---
                _buildDropdown(
                  hint: "Select Program",
                  icon: Icons.school_outlined,
                  value: _selectedProgram,
                  items: _programs,
                  onChanged: (val) => setState(() => _selectedProgram = val as String?),
                ),
                const SizedBox(height: 15),

                // --- YEAR DROPDOWN ---
                _buildDropdown(
                  hint: "Year of Study",
                  icon: Icons.calendar_today_outlined,
                  value: _selectedYear,
                  items: [1, 2, 3, 4],
                  onChanged: (val) => setState(() => _selectedYear = val as int?),
                ),
                const SizedBox(height: 15),

                // Passwords
                _buildStylishInput(controller: _passwordController, hint: "Password", icon: Icons.lock_outline_rounded, isPassword: true),
                const SizedBox(height: 15),
                _buildStylishInput(controller: _confirmPassController, hint: "Confirm Password", icon: Icons.lock_reset_rounded, isPassword: true),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("SIGN UP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper for Text Inputs
  Widget _buildStylishInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(color: _lightFillColor, borderRadius: BorderRadius.circular(30)),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: keyboardType,
        validator: (v) => v!.isEmpty ? "Required" : null,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 20, right: 10), child: Icon(icon, color: _primaryBlue)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  // Helper for Dropdowns
  Widget _buildDropdown({
    required String hint,
    required IconData icon,
    required dynamic value,
    required List<dynamic> items,
    required Function(dynamic) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(color: _lightFillColor, borderRadius: BorderRadius.circular(30)),
      child: DropdownButtonFormField(
        value: value,
        decoration: InputDecoration(
          icon: Icon(icon, color: _primaryBlue),
          border: InputBorder.none,
        ),
        hint: Text(hint),
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(item.toString()));
        }).toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? "Required" : null,
      ),
    );
  }
}