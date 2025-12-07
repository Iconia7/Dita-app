import 'package:dita_app/screens/privacy_policy_screen.dart';
import 'package:dita_app/sheets/ChangePasswordSheet.dart';
import 'package:dita_app/sheets/edit_profile_sheet.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Map<String, dynamic> _currentUser;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  // --- 1. EDIT PROFILE LOGIC ---
void _showEditDialog() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // Crucial for keyboard and full screen height
    backgroundColor: Colors.transparent, // Required for custom sheet shape
    builder: (context) => EditProfileSheet(
      user: _currentUser,
      // Pass a callback to handle state updates after save
      onProfileSaved: (updatedUser) {
        setState(() {
          _currentUser = updatedUser;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated Successfully!"), backgroundColor: Colors.green)
        );
      },
    ),
  );
}


void _showChangePasswordDialog() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // Crucial for keyboard
    backgroundColor: Colors.transparent, 
    builder: (context) => ChangePasswordSheet(
      user: _currentUser,
      primaryDark: Theme.of(context).primaryColor,
    ),
  );
}

  // --- 2. SUPPORT LOGIC ---
  Future<void> _launchContact(String scheme, String path) async {
    final Uri launchUri = Uri(scheme: scheme, path: path);
    try {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch $scheme: $e");
    }
  }

  Future<void> _openWhatsApp() async {
    const String adminPhone = "254115332870"; 
    const String message = "Hello, I need help with the DITA App.";
    final Uri whatsappUrl = Uri.parse("https://wa.me/$adminPhone?text=${Uri.encodeComponent(message)}");
    try {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch WhatsApp");
    }
  }

  // --- 3. UI BUILD ---
 @override
  Widget build(BuildContext context) {
    // 🟢 Theme Helpers
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: primaryColor, // 🟢 Matches the top blue area (Header)
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isUpdating)
             const Padding(
               padding: EdgeInsets.all(15.0),
               child: SizedBox(width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
             )
        ],
      ),
      body: Stack(
        children: [
          // 1. FIXED BACKGROUND (Top Blue Area)
          Container(
            height: MediaQuery.of(context).size.height * 0.3,
            color: primaryColor,
          ),

          // 2. SCROLLABLE CONTENT
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // --- AVATAR & HEADER ---
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 30),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4), 
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.2), 
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white,
                              backgroundImage: _currentUser['avatar'] != null 
                                  ? NetworkImage(_currentUser['avatar']) 
                                  : null,
                              child: _currentUser['avatar'] == null 
                                  ? Icon(Icons.person_rounded, size: 60, color: primaryColor)
                                  : null,
                            ),
                          ),
                          GestureDetector(
                            onTap: _showEditDialog,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                                border: Border.all(color: primaryColor, width: 2), 
                              ),
                              child: const Icon(Icons.edit, color: Colors.white, size: 16),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        (_currentUser['username'] ?? "Student").toUpperCase(),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        _currentUser['email'] ?? "No Email",
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),

                // --- SHEET CONTENT (White/Dark) ---
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height * 0.7
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: scaffoldBg, // 🟢 Dynamic: Light Grey or Dark Navy
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),

                      // DETAILS CARD
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor, // 🟢 Dynamic: White or Slate 800
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Personal Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)), // 🟢
                                IconButton(
                                  onPressed: _showEditDialog,
                                  icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                                  tooltip: "Edit Details",
                                )
                              ],
                            ),
                            Divider(color: isDark ? Colors.white10 : Colors.grey[200]), // 🟢 Dynamic Divider
                            _buildDetailRow(Icons.badge_outlined, "Admission No", _currentUser['admission_number'] ?? "-", Colors.blueAccent, textColor!),
                            const SizedBox(height: 25), // Replaced Dividers with spacing for cleaner dark mode look
                            _buildDetailRow(Icons.school_outlined, "Program", _currentUser['program'] ?? "-", Colors.blueAccent, textColor),
                            const SizedBox(height: 25),
                            _buildDetailRow(Icons.calendar_today_outlined, "Year of Study", "Year ${_currentUser['year_of_study'] ?? 1}", Colors.blueAccent, textColor),
                            const SizedBox(height: 25),
                            _buildDetailRow(Icons.phone_iphone_rounded, "Phone", _currentUser['phone_number'] ?? "-", Colors.blueAccent, textColor),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),
                      
                      // SUPPORT SECTION
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10, bottom: 10),
                          child: Text("Support & Help", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)), // 🟢
                        ),
                      ),
                      
                      Container(
                        decoration: BoxDecoration(
                          color: cardColor, // 🟢
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
                        ),
                        child: Column(
                          children: [
                            _buildActionTile(Icons.lock_outline, "Change Password", Colors.redAccent, _showChangePasswordDialog, textColor),
                            Divider(height: 1, indent: 60, color: isDark ? Colors.white10 : Colors.grey[200]),
                            _buildActionTile(Icons.chat_bubble_outline_rounded, "Chat on WhatsApp", Colors.green, _openWhatsApp, textColor),
                            Divider(height: 1, indent: 60, color: isDark ? Colors.white10 : Colors.grey[200]),
                            _buildActionTile(Icons.call_outlined, "Call Support", Colors.blue, () => _launchContact('tel', '0115332870'), textColor),
                            Divider(height: 1, indent: 60, color: isDark ? Colors.white10 : Colors.grey[200]),
                            _buildActionTile(Icons.email_outlined, "Email Issues", Colors.orange, () => _launchContact('mailto', 'dita@daystar.ac.ke'), textColor),
                            Divider(height: 1, indent: 60, color: isDark ? Colors.white10 : Colors.grey[200]),
                            _buildActionTile(Icons.privacy_tip_outlined, "Privacy & Terms", Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())), textColor),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // LOGOUT BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context, 
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.logout_rounded, color: Colors.red),
                          label: const Text("Log Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: Colors.red.withOpacity(0.1), // 🟢 0.1 works on both dark/light
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                          ),
                        ),
                      ),
                      const SizedBox(height: 100), 
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildDetailRow(IconData icon, String title, String value, Color iconColor, Color textColor) {
    // 🟢 Passed colors in
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textColor)), // 🟢 Dynamic Text
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(IconData icon, String title, Color color, VoidCallback onTap, Color textColor) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)), // 🟢 Dynamic Text
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[500]),
    );
  }
}