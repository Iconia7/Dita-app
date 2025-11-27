import 'package:dita_app/screens/pay_fees_screen.dart';
import 'package:dita_app/screens/register_screen.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Animations
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Daystar Colors
  final Color _primaryBlue = const Color(0xFF003366);
  final Color _lightFillColor = const Color(0xFFF2F6FA); // Very subtle blue-grey for inputs

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final userData = await ApiService.login(
      _usernameController.text,
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (userData != null) {
      if (mounted) {
        bool isPaid = userData['is_paid_member'] ?? false;
        if (isPaid) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(user: userData)));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PayFeesScreen(phoneNumber: userData['phone_number'] ?? '', user: userData)));
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Invalid credentials. Please try again.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen height to help centering
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --- 1. THE LOGO & BRANDING ---
                    Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _primaryBlue.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(Icons.school_rounded, size: 50, color: _primaryBlue),
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    Text(
                      "DITA",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: _primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Empowering Tech Leaders",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 50),

                    // --- 2. INPUT FIELDS (Pill Shaped) ---
                    _buildStylishInput(
                      controller: _usernameController,
                      hint: "Admission Number",
                      icon: Icons.person_outline_rounded,
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),

                    const SizedBox(height: 20),

                    _buildStylishInput(
                      controller: _passwordController,
                      hint: "Password",
                      icon: Icons.lock_outline_rounded,
                      isPassword: true,
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10, right: 10),
                        child: Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: _primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // --- 3. LOGIN BUTTON ---
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          foregroundColor: Colors.white,
                          shadowColor: _primaryBlue.withOpacity(0.4),
                          elevation: 10,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30), // Pill shape
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                "LOGIN",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // --- 4. FOOTER ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("New Student? ", style: TextStyle(color: Colors.grey[600])),
                        GestureDetector(
                          onTap: () {
                             Navigator.push(
                               context, 
                               MaterialPageRoute(builder: (_) => const RegisterScreen()) // Import RegisterScreen
                             );
                          },
                          child: Text(
                            "Register",
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
        ),
      ),
    );
  }

  Widget _buildStylishInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
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
          errorStyle: const TextStyle(height: 0, color: Colors.transparent), // Hide default error text to keep design clean (optional)
        ),
      ),
    );
  }
}