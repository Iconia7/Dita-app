import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController(); // We map this to Username/Name
  final _admController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPassController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Colors
  final Color _primaryBlue = const Color(0xFF003366);
  final Color _lightFillColor = const Color(0xFFF2F6FA);

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Prepare Data for Django
    // Note: We use Admission Number as the 'username' for uniqueness
    final data = {
      "username": _admController.text.trim(), 
      "admission_number": _admController.text.trim(),
      "phone_number": _phoneController.text.trim(),
      "email": "${_admController.text.trim()}@daystar.ac.ke", // Auto-gen email
      "password": _passwordController.text,
      // You can add fields for Program/Year if you want, defaulting for now:
      "program": "Applied Computer Science", 
      "year_of_study": 1 
    };

    bool success = await ApiService.registerUser(data);

    setState(() => _isLoading = false);

    if (success && mounted) {
      // Show Success & Go Back to Login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text("Account Created! Please Login."),
        )
      );
      Navigator.pop(context); // Go back to Login Screen
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text("Registration Failed. Admission No may already exist."),
        )
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/Icon
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: _lightFillColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_add_rounded, size: 40, color: _primaryBlue),
                ),
                const SizedBox(height: 20),
                
                Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: _primaryBlue,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Join the DITA Community",
                  style: TextStyle(color: Colors.grey[500]),
                ),
                
                const SizedBox(height: 40),

                // --- INPUTS ---
                
                // Admission Number
                _buildStylishInput(
                  controller: _admController,
                  hint: "Admission Number (e.g., 21-1234)",
                  icon: Icons.badge_outlined,
                  validator: (v) => v!.length < 5 ? "Invalid Admission No" : null,
                ),
                const SizedBox(height: 15),

                // Phone Number
                _buildStylishInput(
                  controller: _phoneController,
                  hint: "M-Pesa Number (07...)",
                  icon: Icons.phone_iphone_rounded,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.length < 10 ? "Invalid Phone Number" : null,
                ),
                const SizedBox(height: 15),

                // Password
                _buildStylishInput(
                  controller: _passwordController,
                  hint: "Password",
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: (v) => v!.length < 6 ? "Min 6 characters" : null,
                ),
                const SizedBox(height: 15),

                // Confirm Password
                _buildStylishInput(
                  controller: _confirmPassController,
                  hint: "Confirm Password",
                  icon: Icons.lock_reset_rounded,
                  isPassword: true,
                  validator: (v) {
                    if (v != _passwordController.text) return "Passwords do not match";
                    return null;
                  },
                ),

                const SizedBox(height: 40),

                // REGISTER BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      shadowColor: _primaryBlue.withOpacity(0.4),
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "SIGN UP",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                          ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Already a member? ", style: TextStyle(color: Colors.grey[600])),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        "Login",
                        style: TextStyle(
                          color: _primaryBlue,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStylishInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _lightFillColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 20, right: 10),
            child: Icon(icon, color: _primaryBlue),
          ),
          suffixIcon: isPassword
              ? Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
          errorStyle: const TextStyle(height: 0, color: Colors.transparent), 
        ),
      ),
    );
  }
}