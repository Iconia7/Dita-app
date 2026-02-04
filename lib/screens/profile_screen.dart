import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dita_app/providers/auth_provider.dart';
import 'package:dita_app/providers/achievement_provider.dart';
import 'package:dita_app/screens/privacy_policy_screen.dart';
import 'package:dita_app/services/notification.dart';
import 'package:dita_app/sheets/ChangePasswordSheet.dart';
import 'package:dita_app/sheets/edit_profile_sheet.dart';
import 'package:dita_app/screens/reminder_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'login_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // late Map<String, dynamic> _currentUser; // REMOVED: Use Provider
  final bool _isUpdating = false;
  // Initialize with the current state from the service
  bool _isNotificationsEnabled = NotificationService.isEnabled; 

  @override
  void initState() {
    super.initState();
    // _currentUser = widget.user; // REMOVED
  }

  // --- 1. EDIT PROFILE LOGIC ---
  void _showEditDialog() {
    // Get current user from provider to ensure it's fresh
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (context) => const EditProfileSheet(),
    );
  }

  void _showChangePasswordDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (context) => const ChangePasswordSheet(),
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

    // WATCH USER PROVIDER
    final user = ref.watch(currentUserProvider);
    final userMap = user?.toJson() ?? {};

    return Scaffold(
      backgroundColor: primaryColor, 
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
          // 1. FIXED BACKGROUND
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
                          Hero(
                            tag: 'profile_pic',
                            child: Container(
                              padding: const EdgeInsets.all(4), 
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.2), 
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.white,
                                backgroundImage: userMap['avatar'] != null 
                                    ? CachedNetworkImageProvider(userMap['avatar']) 
                                    : null,
                                child: userMap['avatar'] == null 
                                    ? Icon(Icons.person_rounded, size: 60, color: primaryColor)
                                    : null,
                              ),
                            ),
                          ),
                          Semantics(
                            label: "Edit Profile",
                            button: true,
                            child: GestureDetector(
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
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        (userMap['username'] ?? "Student").toUpperCase(),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        userMap['email'] ?? "No Email",
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),

                // --- SHEET CONTENT ---
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height * 0.7
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: scaffoldBg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),

                      // DETAILS CARD
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Personal Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)), 
                                IconButton(
                                  onPressed: _showEditDialog,
                                  icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                                  tooltip: "Edit Details",
                                )
                              ],
                            ),
                            Divider(color: isDark ? Colors.white10 : Colors.grey[200]), 
                            _buildDetailRow(Icons.badge_outlined, "Admission No", userMap['admission_number'] ?? "-", Colors.blueAccent, textColor!),
                            const SizedBox(height: 25), 
                            _buildDetailRow(Icons.school_outlined, "Program", userMap['program'] ?? "-", Colors.blueAccent, textColor),
                            const SizedBox(height: 25),
                            _buildDetailRow(Icons.calendar_today_outlined, "Year of Study", "Year ${userMap['year_of_study'] ?? 1}", Colors.blueAccent, textColor),
                            const SizedBox(height: 25),
                            _buildDetailRow(Icons.phone_iphone_rounded, "Phone", userMap['phone_number'] ?? "-", Colors.blueAccent, textColor),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ACHIEVEMENTS SECTION (Phase 4)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10, bottom: 10),
                          child: const Text("Achievements 🏆", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orangeAccent)), 
                        ),
                      ),
                      
                      Consumer(
                        builder: (context, ref, child) {
                          final achievementsAsync = ref.watch(userAchievementsProvider);

                          return achievementsAsync.when(
                            data: (achievements) {
                              if (achievements.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
                                  child: const Center(child: Text("Start completing tasks to earn badges!", style: TextStyle(fontSize: 12, color: Colors.grey))),
                                );
                              }

                              return SizedBox(
                                height: 100,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: achievements.length,
                                  itemBuilder: (context, index) {
                                    final ach = achievements[index];
                                    return Tooltip(
                                      message: ach.description,
                                      child: Container(
                                        width: 80,
                                        margin: const EdgeInsets.only(right: 15),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          borderRadius: BorderRadius.circular(15),
                                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            (ach.iconUrl != null && ach.iconUrl!.isNotEmpty)
                                              ? Image.network(ach.iconUrl!, height: 40, width: 40)
                                              : const Icon(Icons.stars, color: Color(0xFFFFD700), size: 40),
                                            const SizedBox(height: 5),
                                            Text(ach.name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (err, stack) => const Text("Failed to load achievements"),
                          );
                        },
                      ),

                      const SizedBox(height: 30),
                      
                      // SUPPORT SECTION
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10, bottom: 10),
                          child: const Text("Support & Settings", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)), 
                        ),
                      ),
                      
                      Container(
                        decoration: BoxDecoration(
                          color: cardColor, 
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
                        ),
                        child: Column(
                          children: [
                            // --- NEW: TOGGLE SWITCH ---
                            SwitchListTile(
                                title: Text("Enable Class Reminders", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                                subtitle: Text("Notify 30 mins before class", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                value: _isNotificationsEnabled,
                                activeThumbColor: Colors.blueAccent,
                                secondary: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.notifications_active_outlined, color: Colors.blueAccent, size: 20),
                                ),
                                onChanged: (value) async {
                                    if (mounted) {
                                      setState(() {
                                          _isNotificationsEnabled = value;
                                      });
                                    }
                                    // Call Service to toggle logic
                                    await NotificationService.toggleNotifications(value);
                                    
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                              content: Text(value ? "Reminders Enabled ✅" : "Reminders Disabled 🔕"),
                                              duration: const Duration(seconds: 1),
                                          )
                                      );
                                    }
                                },
                            ),
                            Divider(height: 1, indent: 60, color: isDark ? Colors.white10 : Colors.grey[200]),

                            _buildActionTile(Icons.notifications_active_outlined, "Reminder Settings", Colors.blueAccent, () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const ReminderSettingsScreen()));
                            }, textColor),
                            Divider(height: 1, indent: 60, color: isDark ? Colors.white10 : Colors.grey[200]),
                            _buildActionTile(Icons.lock_outline, "Change Password", Colors.redAccent, () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true, 
                                  backgroundColor: Colors.transparent, 
                                  builder: (context) => const ChangePasswordSheet(),
                                );
                            }, textColor),
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
                          onPressed: () async {
                            // Use Auth Provider Logout
                            await ref.read(authProvider.notifier).logout();
                            if (mounted) {
                              Navigator.pushAndRemoveUntil(
                                context, 
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            }
                          },
                          icon: const Icon(Icons.logout_rounded, color: Colors.red),
                          label: const Text("Log Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: Colors.red.withOpacity(0.1), 
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
              Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textColor)), 
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
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[500]),
    );
  }
}