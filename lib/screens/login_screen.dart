import 'package:dita_app/screens/forgot_password_modal.dart';
import 'package:dita_app/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dita_app/providers/auth_provider.dart';
import 'package:dita_app/core/storage/local_storage.dart';
import 'package:dita_app/core/storage/storage_keys.dart';
import 'home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final bool showMigrationAlert;
  const LoginScreen({super.key, this.showMigrationAlert = false});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
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

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();

    if (widget.showMigrationAlert) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("⚠️ Account Update Required"),
            content: const Text(
              "We have upgraded our security! 🚀\n\n"
              "Please Create a New Account to continue using the app.\n"
              "Your old data (Chat, Study Groups) is safe, but you need to re-register.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Save flag so this dialog won't appear again
                  LocalStorage.setItem(
                    StorageKeys.settingsBox,
                    StorageKeys.hasDismissedMigrationAlert,
                    true,
                  );
                  Navigator.pop(context);
                },
                child: const Text("OK, I'll Register"),
              ),
            ],
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    TextInput.finishAutofillContext();
    
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    // Use Riverpod Provider for Login
    final success = await ref.read(authProvider.notifier).login(
      _usernameController.text,
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      // Clear migration alert flag since successful login means they've re-registered
      LocalStorage.setItem(
        StorageKeys.settingsBox,
        StorageKeys.hasDismissedMigrationAlert,
        false,
      );
      
      // Get the user from the provider state
      final user = ref.read(currentUserProvider);
      if (user != null) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => const HomeScreen()) 
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text('Invalid credentials. Check username or password.'),
            ],
          ),
          backgroundColor: Colors.red[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          margin: const EdgeInsets.all(20),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors = isDark 
        ? [const Color(0xFF0F172A), const Color(0xFF003366)] 
        : [const Color(0xFF003366), const Color(0xFF004C99)];

    final scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFF003366);
    final cardColor = Theme.of(context).cardColor;
    
    return Scaffold(
      backgroundColor: scaffoldBg,
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
                  child: Icon(Icons.hub, size: 300, color: Colors.white.withOpacity(0.05)),
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
                        Hero(
                          tag: 'logo',
                          child: Container(
                            height: 100, 
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                )
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(15.0),
                              child: Image.asset(
                                'assets/icon/icon.png', 
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Welcome Back",
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Sign in to continue",
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                        ),
                        
                        const SizedBox(height: 40),

                        Container(
                          padding: const EdgeInsets.all(50),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: AutofillGroup(
                              child: Column(
                                children: [
                                  _buildStylishInput(
                                    controller: _usernameController,
                                    hint: "Admission / Username",
                                    icon: Icons.person_outline_rounded,
                                    validator: (v) => v!.isEmpty ? "Username is required" : null,
                                    isDark: isDark,
                                    autofillHints: const [AutofillHints.username],
                                  ),

                                  const SizedBox(height: 20),

                                  _buildStylishInput(
                                    controller: _passwordController,
                                    hint: "Password",
                                    icon: Icons.lock_outline_rounded,
                                    isPassword: true,
                                    validator: (v) => v!.isEmpty ? "Password is required" : null,
                                    isDark: isDark,
                                    autofillHints: const [AutofillHints.password],
                                  ),

                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: (){showModalBottomSheet(
                                        context: context,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) => const ForgotPasswordModal(),
                                      );},
                                      child: Text("Forgot Password?", style: TextStyle(color: isDark ? Colors.blue[200] : const Color(0xFF004C99), fontWeight: FontWeight.bold)),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 55,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                       backgroundColor: isDark ? const Color(0xFFFFD700) : const Color(0xFF003366),
                                        foregroundColor: isDark ? const Color(0xFF003366) : Colors.white,
                                        elevation: 5,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text("LOGIN", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                                SizedBox(width: 8),
                                                Icon(Icons.arrow_forward, size: 18)
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("New here? ", style: TextStyle(color: Colors.white70)),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context, 
                                  MaterialPageRoute(builder: (_) => const RegisterScreen())
                                );
                              },
                              child: const Text(
                                "Create Account",
                                style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  decorationColor:Color(0xFFFFD700),
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

  Widget _buildStylishInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
    required bool isDark,
    Iterable<String>? autofillHints,
  }) {
    final fillColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA);
    final iconColor = isDark ? Colors.white54 : Colors.grey[500];
    final textColor = isDark ? Colors.white : Colors.black87;
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      validator: validator,
      autofillHints: autofillHints,
      style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
      decoration: InputDecoration(
        filled: true,
        fillColor: fillColor,
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: iconColor),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: iconColor,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.transparent)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: isDark ? const Color(0xFFFFD700) : const Color(0xFF004C99), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.red, width: 1.5)),  
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      ),
    );
  } 
}