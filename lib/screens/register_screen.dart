import 'package:dita_app/screens/privacy_policy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dita_app/providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _usernameController = TextEditingController(); 
  final _admController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _emailController = TextEditingController(); 
  
  // Dropdown Values
  String? _selectedProgram;
  int? _selectedYear;
  bool _agreedToTerms = false;

  final List<String> _programs = [
    "Applied Computer Science",
    "Information Technology",
    "Bio Medical Science",
    "Acturial Science",
    "Management Information Systems",
    "Diploma in Infomation & Communiation Technology",
    "Education",
    "Communication",
    "Community Development",
    "International Relations & Peace Studies",
    "Nursing",
    "Psychology",
    "Law"
  ];

  bool _isLoading = false;
  bool _obscurePassword = true;

  // Animations
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _admController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPassController.dispose();
    _emailController.dispose();
    super.dispose();
  }


void _showRegistrationErrorDialog(String? errorMsg) {
    final cardColor = Theme.of(context).cardColor;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: const BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: const Icon(Icons.error_outline, color: Colors.white, size: 50),
            ),
            Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                children: [
                  const Text(
                    "Registration Failed",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    errorMsg ?? "An unknown error occurred.",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
                    textAlign: TextAlign.center
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12)
                      ),
                      child: const Text("Got it", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please agree to the Terms & Privacy Policy to continue."),
          backgroundColor: Colors.orange,
        )
      );
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    final data = {
      "username": _usernameController.text.trim(), 
      "admission_number": _admController.text.trim(),
      "phone_number": _phoneController.text.trim(),
      "email": _emailController.text.trim(),
      "password": _passwordController.text,
      "program": _selectedProgram ?? "Applied Computer Science", 
      "year_of_study": _selectedYear ?? 1 
    };

    // Use Riverpod Provider for Registration
    final success = await ref.read(authProvider.notifier).register(data);

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text("Account Created! Please Login."))
      );
      Navigator.pop(context); // Go back to login
    } else if (mounted) {
      // Get error from provider state
      final error = ref.read(authProvider).error;
      _showRegistrationErrorDialog(error?.toString() ?? "Registration failed");
    }
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return "Phone number is required";
    }
    String cleanedValue = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanedValue.length != 10) {
      return "Phone number must be exactly 10 digits";
    }
    
    if (!cleanedValue.startsWith('07') && !cleanedValue.startsWith('01')) {
      return "Number must start with 07 or 01";
    }
    
    return null;
  }

  String? _validateAdmission(String? value) {
    if (value == null || value.isEmpty) {
      return "Admission number is required";
    }
    final RegExp admRegex = RegExp(r'^\d{2}-\d{4}[A-Za-z]?$');
    if (!admRegex.hasMatch(value)) {
      return "Invalid Daystar admission format (e.g., 00-0000)";
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return "Email is required";
    }
    final RegExp emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return "Invalid email address format";
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Confirm password is required";
    }
    if (value != _passwordController.text) {
      return "Passwords do not match";
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final fillColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA);

    final gradientColors = isDark 
        ? [const Color(0xFF0F172A), const Color(0xFF003366)] 
        : [const Color(0xFF003366), const Color(0xFF004C99)];
    
    return Scaffold(
      backgroundColor: gradientColors[0], 
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -50, top: -50,
                  child: Icon(Icons.hub, size: 300, color: Colors.white.withValues(alpha: 0.05)),
                ),
              ],
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        Hero(
                          tag: 'logo',
                          child: Container(
                            height: 60, width: 60,
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]
                            ),
                            child: Image.asset('assets/icon/icon.png'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Create Account",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          "Join the DITA Community",
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                        ),
                        
                        const SizedBox(height: 30),

                        Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: cardColor, 
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, 15))
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                _buildStylishInput(
                                  controller: _usernameController, 
                                  hint: "Username (e.g. Newton)", 
                                  icon: Icons.person_outline_rounded,
                                  inputFill: fillColor, textColor: textColor, isDark: isDark
                                ),
                                const SizedBox(height: 15),
                                _buildStylishInput(
                                  controller: _admController, 
                                  hint: "Admission Number", 
                                  icon: Icons.badge_outlined,
                                  validator: _validateAdmission,
                                  inputFill: fillColor, textColor: textColor, isDark: isDark
                                ),
                                const SizedBox(height: 15),
                                _buildStylishInput(
                                  controller: _phoneController, 
                                  hint: "M-Pesa Number", 
                                  icon: Icons.phone_iphone_rounded, 
                                  keyboardType: TextInputType.phone,
                                  validator: _validatePhoneNumber,
                                  inputFill: fillColor, textColor: textColor, isDark: isDark
                                ),
                                const SizedBox(height: 15),
                                _buildStylishInput(
                                  controller: _emailController,
                                  hint: "Email Address",
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: _validateEmail,
                                  inputFill: fillColor, textColor: textColor, isDark: isDark
                                ),
                                const SizedBox(height: 15),
                                _buildDropdown(
                                  hint: "Select Program",
                                  icon: Icons.school_outlined,
                                  value: _selectedProgram,
                                  items: _programs,
                                  onChanged: (val) => setState(() => _selectedProgram = val as String?),
                                  inputFill: fillColor, textColor: textColor, isDark: isDark, primaryColor: primaryColor
                                ),
                                const SizedBox(height: 15),
                                _buildDropdown(
                                  hint: "Year of Study",
                                  icon: Icons.calendar_today_outlined,
                                  value: _selectedYear,
                                  items: [1, 2, 3, 4],
                                  onChanged: (val) => setState(() => _selectedYear = val as int?),
                                  inputFill: fillColor, textColor: textColor, isDark: isDark, primaryColor: primaryColor
                                ),
                                const SizedBox(height: 15),
                                _buildStylishInput(
                                  controller: _passwordController, 
                                  hint: "Password", 
                                  icon: Icons.lock_outline_rounded, 
                                  isPassword: true,
                                  inputFill: fillColor, textColor: textColor, isDark: isDark
                                ),
                                const SizedBox(height: 15),
                                _buildStylishInput(
                                  controller: _confirmPassController, 
                                  hint: "Confirm Password", 
                                  icon: Icons.lock_reset_rounded, 
                                  isPassword: true,
                                  validator: _validateConfirmPassword,
                                  inputFill: fillColor, textColor: textColor, isDark: isDark
                                ),

                                const SizedBox(height: 30),
                                
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 24, width: 24,
                                      child: Checkbox(
                                        value: _agreedToTerms,
                                        activeColor: primaryColor,
                                        onChanged: (bool? value) {
                                          setState(() => _agreedToTerms = value ?? false);
                                        },
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                                        child: Wrap(
                                          children: [
                                            Text("I agree to the ", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.black54, fontSize: 14)),
                                            GestureDetector(
                                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                                              child: Text("Terms & Privacy Policy", 
                                                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontSize: 14)
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                SizedBox(
                                  width: double.infinity,
                                  height: 55,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleRegister,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark ? const Color(0xFFFFD700) : primaryColor,
                                      foregroundColor: isDark ? primaryColor : Colors.white,
                                      elevation: 5,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    ),
                                    child: _isLoading
                                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text("SIGN UP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Already a member? ", style: TextStyle(color: Colors.white70)),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text("Login", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStylishInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color inputFill,
    required Color? textColor,
    required bool isDark,
    bool isPassword = false,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: keyboardType,
      validator: validator ?? (v) => v!.isEmpty ? "Required" : null,
      style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
      decoration: InputDecoration(
        filled: true,
        fillColor: inputFill,
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey[500]),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey[400], size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: isDark ? const Color(0xFFFFD700) : const Color(0xFF004C99), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required IconData icon,
    required dynamic value,
    required List<dynamic> items,
    required Function(dynamic) onChanged,
    required Color inputFill,
    required Color? textColor,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(15)), 
      child: DropdownButtonFormField(
        initialValue: value,
        dropdownColor: Theme.of(context).cardColor, 
        style: TextStyle(fontWeight: FontWeight.w600, color: textColor), 
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[500]),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400], fontSize: 14), 
        ),
        icon: Icon(Icons.arrow_drop_down_circle, color: primaryColor),
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(item.toString()));
        }).toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? "Required" : null,
      ),
    );
  }
}