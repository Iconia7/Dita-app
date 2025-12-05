import 'package:dita_app/screens/privacy_policy_screen.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _usernameController = TextEditingController(); // New field for display name
  final _admController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _emailController = TextEditingController(); // Add this
  
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

  // Colors
  final Color _primaryDark = const Color(0xFF003366);
  final Color _primaryLight = const Color(0xFF004C99);
  final Color _bgInput = const Color(0xFFF5F7FA);
  final Color _accentGold = const Color(0xFFFFD700);

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
    super.dispose();
  }

void _handleRegister() async {
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

  // --- UPDATED LOGIC HERE ---
  // Returns NULL if success, or a String if failed
  String? errorMsg = await ApiService.registerUser(data);

  setState(() => _isLoading = false);

  if (errorMsg == null && mounted) {
    // SUCCESS
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: Colors.green, content: Text("Account Created! Please Login."))
    );
    Navigator.pop(context); // Go back to login
  } else if (mounted) {
    // FAILURE - Show the specific error from backend
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Registration Failed", style: TextStyle(color: Colors.red)),
        content: Text(errorMsg ?? "Unknown Error"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
        ],
      )
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryDark,
      body: Stack(
        children: [
          // 1. BACKGROUND GRADIENT
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryDark, _primaryLight],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
  right: -50, 
  top: -50,
  child: Opacity( // Use Opacity to make it subtle like the icon was
    opacity: 0.1, 
    child: Image.asset(
      'assets/icon/icon.png', // <--- YOUR LOGO
      height: 300,
      width: 300,
    ),
  ),
),
                // Back Button positioned safely
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, top: 10),
                  ),
                ),
              ],
            ),
          ),

          // 2. MAIN CONTENT
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
  tag: 'logo', // Smooth transition from Login screen!
  child: Container(
    height: 60, 
    width: 60,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 10)
      ]
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
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                        ),
                        
                        const SizedBox(height: 30),

                        // WHITE CARD FORM
                        Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 15))
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Username (Display Name)
                                _buildStylishInput(
                                  controller: _usernameController, 
                                  hint: "Username (e.g. Newton)", 
                                  icon: Icons.person_outline_rounded
                                ),
                                const SizedBox(height: 15),

                                // Admission Number
                                _buildStylishInput(
                                  controller: _admController, 
                                  hint: "Admission Number", 
                                  icon: Icons.badge_outlined
                                ),
                                const SizedBox(height: 15),

                                // Phone Number
                                _buildStylishInput(
                                  controller: _phoneController, 
                                  hint: "M-Pesa Number", 
                                  icon: Icons.phone_iphone_rounded, 
                                  keyboardType: TextInputType.phone
                                ),
                                const SizedBox(height: 15),
                                // Real Email Address
_buildStylishInput(
  controller: _emailController,
  hint: "Email Address (e.g. jane@gmail.com)",
  icon: Icons.email_outlined,
  keyboardType: TextInputType.emailAddress,
),
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
                                _buildStylishInput(
                                  controller: _passwordController, 
                                  hint: "Password", 
                                  icon: Icons.lock_outline_rounded, 
                                  isPassword: true
                                ),
                                const SizedBox(height: 15),
                                _buildStylishInput(
                                  controller: _confirmPassController, 
                                  hint: "Confirm Password", 
                                  icon: Icons.lock_reset_rounded, 
                                  isPassword: true
                                ),

                                const SizedBox(height: 30),
                                Row(
  crossAxisAlignment: CrossAxisAlignment.start, // Aligns checkbox with top of text
  children: [
    SizedBox(
      height: 24, 
      width: 24,
      child: Checkbox(
        value: _agreedToTerms,
        activeColor: _primaryDark, // Your blue color
        onChanged: (bool? value) {
          setState(() {
            _agreedToTerms = value ?? false;
          });
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
    const SizedBox(width: 10),
    Expanded( // Prevents overflow errors
      child: GestureDetector(
        onTap: () {
          // Allow tapping the text to toggle checkbox too!
          setState(() => _agreedToTerms = !_agreedToTerms);
        },
        child: Wrap(
          children: [
            const Text(
              "I agree to the ",
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            GestureDetector(
              onTap: () {
                // Navigate to Privacy Policy
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
              },
              child: Text(
                "Terms & Privacy Policy",
                style: TextStyle(
                  color: _primaryDark,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ],
),

const SizedBox(height: 10),

                                // SIGN UP BUTTON
                                SizedBox(
                                  width: double.infinity,
                                  height: 55,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleRegister,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primaryDark,
                                      foregroundColor: Colors.white,
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
                        
                        // Footer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Already a member? ", style: TextStyle(color: Colors.white70)),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Text(
                                "Login",
                                style: TextStyle(
                                  color: _accentGold,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  decorationColor: _accentGold
                                ),
                              ),
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

  // Helper for Text Inputs
  Widget _buildStylishInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: keyboardType,
      validator: (v) => v!.isEmpty ? "Required" : null,
      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
      decoration: InputDecoration(
        filled: true,
        fillColor: _bgInput,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey[500]),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey[400], size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: _bgInput, borderRadius: BorderRadius.circular(15)),
      child: DropdownButtonFormField(
        initialValue: value,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[500]),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        icon: Icon(Icons.arrow_drop_down_circle, color: _primaryDark),
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(item.toString(), style: const TextStyle(fontWeight: FontWeight.w600)));
        }).toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? "Required" : null,
      ),
    );
  }
}