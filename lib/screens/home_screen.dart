import 'dart:convert';
import 'dart:ui'; // Required for BackdropFilter (Glassmorphism)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dita_app/screens/ai_assistant_screen.dart';
import 'package:dita_app/screens/attendance_history_screen.dart';
import 'package:dita_app/screens/class_timetable_screen.dart';
import 'package:dita_app/screens/community_screen.dart';
import 'package:dita_app/screens/exam_timetable_screen.dart';
import 'package:dita_app/screens/gamelist_screen.dart';
import 'package:dita_app/screens/leaderboard_screen.dart';
import 'package:dita_app/screens/profile_screen.dart';
import 'package:dita_app/screens/qr_scanner_screen.dart';
import 'package:dita_app/screens/search_screen.dart';
import 'package:dita_app/screens/study_groups_screen.dart';
import 'package:dita_app/screens/tasks_screen.dart';
import 'package:dita_app/widgets/dita_loader.dart';
import 'package:dita_app/widgets/empty_state_widget.dart';
import 'package:dita_app/widgets/promo_popup.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models/event_model.dart';
import '../data/models/announcement_model.dart'; // NEW
import '../data/models/resource_model.dart';
import '../providers/event_provider.dart';
import '../providers/announcement_provider.dart'; // NEW
import '../providers/resource_provider.dart';
import '../services/api_service.dart';
import 'pay_fees_screen.dart';
import 'package:dita_app/providers/network_provider.dart';
import 'package:dita_app/widgets/skeleton_loader.dart';
import 'package:dita_app/widgets/bouncing_button.dart';
import 'dart:io';
import '../data/models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import '../utils/app_logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/timetable_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {

  int _currentIndex = 0;
  
  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  

  @override
  void initState() {
    super.initState();

    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    );
    _animationController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptPayment();});
      _syncNotificationToken();
    WidgetsBinding.instance.addPostFrameCallback((_) {
     PromoPopup.checkAndShow(context);
     ref.read(timetableProvider.notifier).loadTimetable(); // Pre-load for widget
  });  
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    // Pick from gallery
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uploading profile picture...")),
      );

      File file = File(image.path);
      bool success = await ref.read(authProvider.notifier).uploadProfilePicture(file);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.green, content: Text("Profile updated!")),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.red, content: Text("Upload failed.")),
          );
        }
      }
    }
  }

  void _syncNotificationToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ref.read(authProvider.notifier).updateFcmToken(token);
      }
    } catch (e) {
      AppLogger.error('FCM Sync Error', error: e);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    await ref.read(authProvider.notifier).refresh();
    ref.read(timetableProvider.notifier).loadTimetable(); // Update widget
    
    final userModel = ref.read(currentUserProvider);
    if (userModel?.isPaidMember == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: const Row(
            children: [
              Icon(Icons.verified, color: Colors.white),
              SizedBox(width: 10),
              Text("Membership Verified", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }
  }



// --- 1. STYLISH ANNOUNCEMENT DIALOG ---
void _showNotificationsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Announcements",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor, // 🟢 Dynamic BG
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("📢 Announcements", 
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, 
                          color: isDark ? Colors.white : primaryColor)), // 🟢 Dynamic Text
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final announcementsAsync = ref.watch(announcementProvider);
                        
                        return announcementsAsync.when(
                          loading: () => const SkeletonList(
                            skeleton: AnnouncementSkeleton(),
                            itemCount: 4,
                          ),
                          error: (error, stack) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                                const SizedBox(height: 10),
                                Text("Failed to load announcements", style: TextStyle(color: Colors.grey[500])),
                                TextButton(
                                  onPressed: () => ref.refresh(announcementProvider),
                                  child: const Text("Retry"),
                                )
                              ],
                            ),
                          ),
                          data: (announcements) {
                            if (announcements.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey[300]),
                                    const SizedBox(height: 10),
                                    Text("All caught up!", style: TextStyle(color: Colors.grey[500])),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: announcements.length,
                              itemBuilder: (context, index) {
                                final item = announcements[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 15),
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF4F6F9), // 🟢 Dynamic Item BG
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white10 : primaryColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(item.category?.toUpperCase() ?? "NEWS", 
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, 
                                                color: isDark ? Colors.white : primaryColor)),
                                          ),
                                          const Spacer(),
                                          Text(
                                            DateFormat('MMM d, h:mm a').format(item.datePosted),
                                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(item.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                      const SizedBox(height: 5),
                                      Text(item.messageBody, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600], height: 1.4)),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack), child: child);
      },
    );
  }

  // --- 3. STYLISH RSVP DIALOG ---
  void _showRSVPDialog(bool isJoining, String eventTitle) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "RSVP",
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, a1, a2) => Container(),
      transitionBuilder: (ctx, a1, a2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: a1, curve: Curves.elasticOut),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(20),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Circle (Green for Join, Orange for Leave)
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isJoining ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isJoining ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                    color: isJoining ? Colors.green : Colors.orange,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 15),
                
                // Title
                Text(
                  isJoining ? "RSVP Confirmed!" : "RSVP Cancelled",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(height: 10),
                
                // Message
                Text(
                  isJoining
                      ? "You are all set for \"$eventTitle\".\nSee you there!"
                      : "You have been removed from the guest list for \"$eventTitle\".",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.5),
                ),
                
                const SizedBox(height: 20),
                
                // Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text("Okay", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 2. ATTRACTIVE SUCCESS DIALOG (REPLACES OLD DIALOG) ---
void _showSuccessDialog(String title, String msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Success",
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, a1, a2) => Container(),
      transitionBuilder: (ctx, a1, a2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: a1, curve: Curves.elasticOut),
          child: AlertDialog(
            backgroundColor: cardColor, // 🟢 Dynamic BG
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            contentPadding: EdgeInsets.zero,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                  ),
                  child: const Icon(Icons.check_circle_outline, color: Colors.white, size: 60),
                ),
                Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    children: [
                      Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, 
                          color: isDark ? Colors.white : Theme.of(context).primaryColor), textAlign: TextAlign.center), // 🟢
                      const SizedBox(height: 10),
                      Text(msg, style: TextStyle(color: Colors.grey[600], fontSize: 14), textAlign: TextAlign.center),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            padding: const EdgeInsets.symmetric(vertical: 12)
                          ),
                          child: const Text("Continue", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 4. STYLISH ERROR/WARNING DIALOG ---
void _showResponseDialog({required bool isError, required String title, required String msg}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color headerColor = isError ? Colors.red : Colors.orange;
    IconData icon = isError ? Icons.error_outline : Icons.warning_amber_rounded;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Status",
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, a1, a2) => Container(),
      transitionBuilder: (ctx, a1, a2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: a1, curve: Curves.elasticOut),
          child: AlertDialog(
            backgroundColor: Theme.of(context).cardColor, // 🟢 Dynamic BG
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: EdgeInsets.zero,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: headerColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Icon(icon, color: Colors.white, size: 50),
                ),
                Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    children: [
                      Text(title, 
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, 
                        color: isDark ? Colors.white : Theme.of(context).primaryColor), textAlign: TextAlign.center), // 🟢
                      const SizedBox(height: 10),
                      Text(msg, style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5), textAlign: TextAlign.center),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: headerColor,
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
      },
    );
  }

  // --- LOGIC: QUICK ACTIONS ---
// --- LOGIC: QUICK ACTIONS ---
void _openScanner() async {
    // 1. Open the Scanner Screen
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    // 2. If we got a code back
    if (result != null) {
      debugPrint('Scanned Code: $result');

      // 3. Parse Event ID
      int? eventId = int.tryParse(result.toString());

      if (eventId != null) {
        // Show subtle loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Verifying attendance..."),
              duration: Duration(seconds: 1),
            )
          );
        }

        // 4. Call Backend
        var response = await ref.read(eventProvider.notifier).markAttendance(eventId);

        if (mounted) {
          // 5. Handle Success
          if (response != null && response.containsKey('new_points')) {
            
            // Refresh user data to get new points
            ref.read(authProvider.notifier).refresh();

            _showSuccessDialog(
              "Check-in Complete! ✅", 
              "You earned +20 Points for attending this event."
            );
            
          } else {
            // 6. Handle Failure/Warning
            String message = response?['message'] ?? "Check-in Failed";
            
            // Check if it's an "Already checked in" message
            bool isAlreadyDone = message.toLowerCase().contains("already");

            _showResponseDialog(
              isError: !isAlreadyDone, // If already done, it's a warning (Orange), else Error (Red)
              title: isAlreadyDone ? "Oops!" : "Error",
              msg: message
            );
          }
        }
      } else {
        // 7. Invalid QR Format
        _showResponseDialog(
          isError: true,
          title: "Invalid Code",
          msg: "This QR code is not valid for DITA events."
        );
      }
    }
  }



  void _checkAndPromptPayment() {
    final user = ref.read(currentUserProvider);
    bool isPaid = user?.isPaidMember ?? false;
    if (!isPaid) {
      // Show the Pay Sheet immediately
      showModalBottomSheet(
        context: context,
        isScrollControlled: true, // Allows full height
        backgroundColor: Colors.transparent,
        builder: (context) => const PayFeesSheet(),
      ).then((result) {
        // If they paid successfully (result == true), refresh data
        if (result == true) {
          _refreshData();
        }
      });
    }
  }


  void _showPaymentSheet() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // IMPORTANT: Allows sheet to resize for keyboard
    backgroundColor: Colors.transparent, // Allows rounded corners to show
    builder: (context) => const PayFeesSheet(),
  ).then((value) {
    // This runs when the sheet closes
    // If we passed 'true' back from the sheet (meaning payment success), refresh data
    if (value == true) {
      _refreshData(); 
    }
  });
}

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    bool isPaid = user?.isPaidMember ?? false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
  final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
  final primaryDark = Theme.of(context).primaryColor;
  final accentGold = const Color(0xFFFFD700);

    final List<Widget> pages = [
      _buildDesignerHomeTab(user, isPaid),
      _buildEventsTab(user),
      _buildResourcesTab(user, isPaid),
      const CommunityScreen(),
      _buildNewsTab(),
    ];

    final isOnline = ref.watch(isOnlineProvider);

    // 🆕 Auto-Sync Logic: Refresh data when coming back online
    ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (next == true && (previous == false || previous == null)) {
        AppLogger.info('Back online! Auto-syncing data...');
        _refreshData(); // Refreshes Auth + Current User
        ref.read(announcementProvider.notifier).refresh();
        ref.read(communityProvider.notifier).refresh();
        ref.read(eventProvider.notifier).refresh();
        ref.read(resourceProvider.notifier).refresh();
      }
    });

    return Scaffold(
      backgroundColor: scaffoldBg,
      // extendBody allows the content to flow behind the floating nav bar
      extendBody: true, 
      body: Column(
        children: [
          // 🆕 Offline Banner
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: isOnline ? 0 : 30,
            width: double.infinity,
            color: Colors.redAccent,
            child: isOnline 
              ? const SizedBox.shrink()
              : const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off, color: Colors.white, size: 14),
                      SizedBox(width: 8),
                      Text(
                        "You are currently offline. Using cached data.",
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
          ),
          
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildFloatingBottomNav(),
      floatingActionButton: FloatingActionButton(
    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAssistantScreen())),
    backgroundColor: isDark ? accentGold : primaryDark,
    child: Icon(Icons.chat_bubble_outline, color: isDark ? primaryDark : Colors.white),
  ),
  // Adjust location so it doesn't overlap with bottom nav
  floatingActionButtonLocation: FloatingActionButtonLocation.endFloat, 
);
  }

  // --- 1. DESIGNER HOME TAB ---
  Widget _buildDesignerHomeTab(UserModel? user, bool isPaid) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
  // 🟢 Dark Mode Gradient: Deeper/Darker
  final gradientColors = isDark 
      ? [const Color(0xFF0F172A), const Color(0xFF003366)] 
      : [const Color(0xFF003366), const Color(0xFF004C99)];
    bool isExpiringSoon = false;
if (isPaid && user?.membershipExpiry != null) {
  final expiry = DateTime.parse(user!.membershipExpiry!);
  final daysLeft = expiry.difference(DateTime.now()).inDays;
  if (daysLeft <= 7 && daysLeft >= 0) {
    isExpiringSoon = true;
  }
}
    return Column(
      children: [
        // --- CUSTOM APP BAR AREA ---
        Stack(
          children: [
            // Blue Background with Gradient
            Container(
              height: 310, // Extended height
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(35)),
              ),
            ),
            // Background Pattern (Subtle DITA branding)
            Positioned(
              right: -50,
              top: -50,
              child: Icon(Icons.hub, size: 250, color: Colors.white.withOpacity(0.05)),
            ),

            // Content
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                child: Column(
                  children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Semantics(
                              label: "Change profile picture",
                              button: true,
                              child: GestureDetector(
                                onTap: _pickAndUploadImage, // <--- TRIGGER UPLOAD
                                child: Hero(
                                  tag: 'home_profile_pic',
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                                    ),
                                    child: CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage: (user?.avatar != null && user!.avatar!.isNotEmpty)
                                          ? CachedNetworkImageProvider(user.avatar!) 
                                          : null,
                                      child: (user?.avatar == null || user!.avatar!.isEmpty)
                                          ? Icon(Icons.person, color: Colors.grey[400])
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Welcome back,", style: TextStyle(color: Colors.white70, fontSize: 14)),
                                  Text(
                                    (user?.username ?? "Student").split(' ')[0], 
                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                                  ),
                              ],
                            ),
                          ],
                        ),
                        // Notification Bell with Badge
                        Stack(
                          children: [
                            IconButton(
                              tooltip: "Notifications",
                              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                              onPressed: _showNotificationsDialog,
                            ),
                            Positioned(
                              right: 12, top: 12,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                    
                    const SizedBox(height: 25),

                    // Translucent Search Bar
                    GestureDetector(
                      onTap: () async { // 🛑 CHANGE: Made function async to await result
    final result = await showSearch( // 🛑 CAPTURE RESULT HERE
      context: context, 
      delegate: DitaSearchDelegate(
        ref.read(eventRepositoryProvider).getEvents().then((r) => r.fold((_) => [], (v) => v)), 
        ref.read(resourceRepositoryProvider).getResources().then((r) => r.fold((_) => [], (v) => v))
      )
    );
    
    // 🛑 NEW LOGIC: Check if the result requests a tab change
    if (result != null && result is Map && result.containsKey('tabIndex')) {
      final int newIndex = result['tabIndex'];
      
      // Update the state (and the UI)
      setState(() {
        _currentIndex = newIndex;
      });

      // Optional: Give feedback that the tab switched
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Switched to the ${newIndex == 1 ? 'Events' : 'Resources'} tab."),
          duration: const Duration(seconds: 1),
        )
      );
    }
  },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search, color: Colors.white70),
                                const SizedBox(width: 10),
                                Text(
                                  "Find events, resources...", 
                                  style: TextStyle(color: Colors.white.withOpacity(0.7))
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Quick Actions Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickAction(
  Icons.school_rounded, 
  "Exams", 
  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamTimetableScreen()))
),
const SizedBox(width: 15),
_buildQuickAction(
  Icons.school_rounded, 
  "Classes", 
  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClassTimetableScreen()))
),
const SizedBox(width: 15),
                          _buildQuickAction(
         Icons.checklist_rtl_rounded, 
         "Planner", 
         () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksScreen()))
      ),
      const SizedBox(width: 15),
                          _buildQuickAction(Icons.payment, "Pay Fees", _showPaymentSheet),
                          const SizedBox(width: 15),
                          _buildQuickAction(Icons.qr_code_scanner, "Scan", _openScanner),
                          const SizedBox(width: 15),
                          _buildQuickAction(
                              Icons.videogame_asset_rounded, 
                              "Play Games", 
                              () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => const GamesListScreen()));
                                _refreshData(); 
                              }
                          ),
                          const SizedBox(width: 15),
                          _buildQuickAction(
                              Icons.group_work_rounded, 
                              "Study Groups", 
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyGroupsScreen()))
                          ),

                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // --- SCROLLABLE CONTENT ---
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            color: Theme.of(context).primaryColor,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 25),
                  
                  // Membership Section Header
                  Row(
                    children: [
                      Text("My Membership", style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      if(!isPaid) 
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: const Text("Inactive", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                  const SizedBox(height: 15),

                  if (isExpiringSoon)
  Container(
    margin: const EdgeInsets.only(bottom: 15),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.orange.withOpacity(0.1),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.orange.withOpacity(0.3))
    ),
    child: Row(
      children: [
        const Icon(Icons.access_time_filled, color: Colors.orange),
        const SizedBox(width: 10),
        const Expanded(child: Text("Your membership expires in less than 7 days!", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
        TextButton(onPressed: _showPaymentSheet, child: const Text("Renew"))
      ],
    ),
  ),

                  // THE ID CARD
                  _buildPremiumIDCard(user, isPaid),

                  const SizedBox(height: 30),

                  // Analytics Grid
                   Text("Dashboard", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
  child: GestureDetector( // <--- Wrap in GestureDetector
    onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen())
        );
    },
    child: _buildStatCard(
      "Attendance", 
      "${user?.attendancePercentage ?? 0}%", 
      Icons.bar_chart, 
      Colors.purple
    ),
  ),
),
                      const SizedBox(width: 15),
                      Expanded(child: GestureDetector( // <--- Wrap in GestureDetector
    onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => LeaderboardScreen())
        );
    },child: _buildStatCard("Points", "${user?.points ?? 0}", Icons.stars, const Color(0xFFFFD700))),)
                    ],
                  ),

                  const SizedBox(height: 15),
                  // Feature Banner
                  // --- UPCOMING EVENTS SECTION (NEW) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Upcoming Events", style: Theme.of(context).textTheme.titleLarge),
                    TextButton(
                      onPressed: () => setState(() => _currentIndex = 1), // Switch to Events Tab
                      child: const Text("View All"),
                    ),
                  ],
                ),
                
                SizedBox(
                  height: 160, // Height for horizontal list
                  child: FutureBuilder<List<dynamic>>(
                    future: ApiService.getEvents(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 3,
                          itemBuilder: (context, index) => const Padding(
                            padding: EdgeInsets.only(right: 15),
                            child: CardSkeleton(),
                          ),
                        );
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15)),
                          child: const Center(child: Text("No upcoming events")),
                        );
                      }

                      // Show max 4 events
                      final events = snapshot.data!.take(4).toList();

                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return GestureDetector(
                            onTap: () => setState(() => _currentIndex = 1), // Go to tab on click
                            child: Container(
                              width: 200,
                              margin: const EdgeInsets.only(right: 15),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(15),
                                image: event['image'] != null 
                                  ? DecorationImage(image: NetworkImage(event['image']), fit: BoxFit.cover, opacity: 0.2)
                                  : null,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(15.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      event['title'], 
                                      maxLines: 2, 
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color)
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 12, color: const Color(0xFFFFD700)),
                                        const SizedBox(width: 5),
                                        Text(
                                          DateFormat('MMM d').format(DateTime.parse(event['date'])),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                  const SizedBox(height: 100), // Bottom spacer
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDGETS ---

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return BouncingButton(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2), // Translucent on blue
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(icon, color: const Color(0xFFFFD700), size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildPremiumIDCard(UserModel? user, bool isPaid) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPaid 
            ? [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)] 
          // 🟢 Inactive card: Darker grey in dark mode so it doesn't blind the user
          : (isDark ? [Colors.grey[800]!, Colors.grey[900]!] : [Colors.grey[400]!, Colors.grey[600]!]),
        ),
        boxShadow: [
          BoxShadow(
            color: isPaid ? const Color(0xFF2C5364).withOpacity(0.4) : Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Texture
          Positioned(
             right: -20, bottom: -40,
             child: Icon(Icons.fingerprint, size: 200, color: Colors.white.withOpacity(0.05)),
          ),
          
          Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Header (Chip + Logo)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     Icon(Icons.nfc, color: Colors.white.withOpacity(0.8), size: 30),
                     Text(isPaid ? "DITA GOLD MEMBER" : "DITA INACTIVE MEMBER", style: TextStyle(color: Colors.white.withOpacity(0.6), letterSpacing: 2, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                  ],
                ),
                const Spacer(),
                
                // Card Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.username ?? "USER NAME", 
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.admissionNumber ?? "00-0000", 
                            style: TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.5),
                          ),
                        ],
                      ),
                    ),
                    
                    // QR Code Container
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: QrImageView(
                        data: user?.admissionNumber ?? "000",
                        size: 50,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: accentColor.withOpacity(0.1),
            radius: 20,
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(height: 15),
          Text(value, style:  TextStyle(fontSize: 22, fontWeight: FontWeight.bold,color: Theme.of(context).textTheme.bodyLarge?.color)),
          const SizedBox(height: 5),
          Text(title, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _buildFloatingBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color:Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.grid_view_rounded, "Home"),
            _buildNavItem(1, Icons.calendar_month_outlined, "Events"),
            _buildNavItem(2, Icons.book_outlined, "Resources"),
            _buildNavItem(3, Icons.forum_rounded, "Community"),
            _buildNavItem(4, Icons.person_outline_rounded, "Profile"),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
  final primaryColor = Theme.of(context).primaryColor;
  final goldColor = const Color(0xFFFFD700);
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon, 
              color: isSelected ? goldColor : (isDark ? Colors.grey[400] : Colors.grey[400]), 
              size: 24
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label, 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // --- PLACEHOLDER TABS ---
// --- TAB 2: EVENTS (LIVE DATA) ---
  Widget _buildEventsTab(UserModel? user) {
    bool isPaid = user?.isPaidMember ?? false;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        title: const Text("Upcoming Events", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        automaticallyImplyLeading: false, 
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final eventsAsync = ref.watch(eventProvider);
          
          return eventsAsync.when(
            data: (events) {
              if (events.isEmpty) {
                return EmptyStateWidget(
                  svgPath: 'assets/svgs/no_events.svg',
                  title: "No Upcoming Events",
                  message: "Looks like the calendar is clear for now. Check back later for new activities!",
                  actionLabel: "Refresh",
                  onActionPressed: () => ref.read(eventProvider.notifier).refresh(),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await ref.read(eventProvider.notifier).refresh();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    return EventCard(
                      event: events[index],
                      userId: user?.id ?? 0,
                      primaryDark: Theme.of(context).primaryColor,
                      isPaid: isPaid, // 🟢 PASS PAYMENT STATUS
                      onUnlockPressed: _showPaymentSheet, // 🟢 Callback to open payment sheet
                      onRsvpChanged: (bool isJoining, String title) {
                        _showRSVPDialog(isJoining, title);
                      },
                    );
                  },
                ),
              );
            },
            loading: () => const SkeletonList(
              padding: EdgeInsets.all(20),
              skeleton: CardSkeleton(),
              itemCount: 3,
            ),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Failed to load events', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(eventProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      
    );
  }

Widget _buildResourcesTab(UserModel? user, bool isPaid) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cardColor = Theme.of(context).cardColor;
  final primaryDark = Theme.of(context).primaryColor;
    if (!isPaid) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.lock_outline, size: 60, color: Colors.grey[400]),
        const SizedBox(height: 20),
        Text("Resources Locked",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).textTheme.bodyLarge?.color)),
        const SizedBox(height: 10),
        TextButton(
            onPressed: _showPaymentSheet, child: const Text("Pay to Unlock"))
      ]));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // _bgOffWhite
      appBar: AppBar(
        title: const Text("Resources",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primaryDark, // _primaryDark
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final resourcesAsync = ref.watch(resourceProvider);
          
          return resourcesAsync.when(
            data: (resources) {
              if (resources.isEmpty) {
                return const EmptyStateWidget(
                  svgPath: 'assets/svgs/no_resources.svg',
                  title: "Library Empty",
                  message: "We couldn't find any resources. Please check your internet connection.",
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await ref.read(resourceProvider.notifier).refresh();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: resources.length,
                  itemBuilder: (context, index) {
                    final res = resources[index];
                    final type = res.fileExtension.toUpperCase();

                    // --- 1. DYNAMIC ICON LOGIC ---
                    IconData icon = Icons.description;
                    Color color = Colors.grey;
                    String actionLabel = "Open";

                    switch (type) {
                      case 'PDF':
                        icon = Icons.picture_as_pdf;
                        color = Colors.red;
                        actionLabel = "Download";
                        break;
                      case 'PPT':
                        icon = Icons.slideshow;
                        color = Colors.orange;
                        actionLabel = "Download";
                        break;
                      case 'DOC': // Word
                        icon = Icons.article;
                        color = Colors.blue[800]!;
                        actionLabel = "Download";
                        break;
                      case 'XLS': // Excel
                        icon = Icons.table_chart;
                        color = Colors.green[700]!;
                        actionLabel = "Download";
                        break;
                      case 'ZIP': // Archive
                        icon = Icons.folder_zip;
                        color = Colors.purple;
                        actionLabel = "Download";
                        break;
                      case 'IMG': // Image
                        icon = Icons.image;
                        color = Colors.teal;
                        actionLabel = "View";
                        break;
                      case 'LINK':
                        icon = Icons.link;
                        color = Colors.blue;
                        actionLabel = "Visit";
                        break;
                      default:
                        icon = Icons.insert_drive_file;
                        color = Colors.grey;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2))
                          ]),
                      child: Row(
                        children: [
                          // Icon Box
                          Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Icon(icon, color: color, size: 28)),
                          const SizedBox(width: 15),
                          
                          // Title & Desc
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(res.title,
                              style:  TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16,color: Theme.of(context).textTheme.bodyLarge?.color)),
                          if (res.description != null &&
                              res.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(res.description!,
                                  style: TextStyle(
                                      color: isDark ? Colors.grey[400] :Colors.grey[600], fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Action Button
                    ElevatedButton(
                      onPressed: () async {
                        String? urlToOpen = res.fileUrl;
                        if (type == 'LINK') {
                          urlToOpen = res.fileUrl;
                        }

                        if (urlToOpen != null && urlToOpen.isNotEmpty) {
                          final uri = Uri.parse(urlToOpen);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Could not open file")));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.white10 : const Color(0xFFF4F6F9), // 🟢 Lighter bg in dark mode
                        foregroundColor: isDark ? Colors.white : const Color(0xFF003366), // Dark text
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      child: Text(actionLabel,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              );
            },
          ),
          );
        },
        loading: () => const SkeletonList(
          padding: EdgeInsets.all(20),
          skeleton: CardSkeleton(hasImage: false),
          itemCount: 6,
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Failed to load resources', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.read(resourceProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    },
  ),
);
}
  Widget _buildNewsTab() => const ProfileScreen();
}

class EventCard extends ConsumerStatefulWidget {
  final EventModel event;
  final int userId;
  final Color primaryDark;
  final bool isPaid; // 🟢 New Parameter
  final VoidCallback onUnlockPressed; // 🟢 New Callback
  final Function(bool, String) onRsvpChanged;

  const EventCard({
    super.key, 
    required this.event, 
    required this.userId, 
    required this.primaryDark,
    required this.isPaid, // 🟢
    required this.onUnlockPressed, // 🟢
    required this.onRsvpChanged
  });

  @override
  ConsumerState<EventCard> createState() => _EventCardState();
}

class _EventCardState extends ConsumerState<EventCard> {
  late bool _hasRsvped;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _hasRsvped = widget.event.hasRsvpd;
  }

  @override
  Widget build(BuildContext context) {
    final DateTime date = widget.event.date;
    final String day = DateFormat('dd').format(date);
    final String month = DateFormat('MMM').format(date).toUpperCase();
    final String time = DateFormat('h:mm a').format(date);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]
      ),
      child: Column(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: widget.primaryDark.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              image: widget.event.image != null 
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(widget.event.image!), 
                      fit: BoxFit.cover
                    ) 
                  : null,
            ),
            child: widget.event.image == null ? Center(child: Icon(Icons.image, color: Colors.grey[400], size: 40)) : null,
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : widget.primaryDark.withOpacity(0.05), 
                    borderRadius: BorderRadius.circular(15), 
                    border: Border.all(color: widget.primaryDark.withOpacity(0.1))
                  ),
                  child: Column(children: [
                    Text(day, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : widget.primaryDark)), 
                    Text(month, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.primaryDark.withOpacity(0.6)))
                  ]),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.event.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      Row(children: [Icon(Icons.location_on, size: 14, color: Colors.grey[500]), const SizedBox(width: 4), Text(widget.event.location ?? 'TBA', style: TextStyle(fontSize: 12, color: Colors.grey[500]))]), // Changed from venue
                      const SizedBox(height: 4),
                      Row(children: [Icon(Icons.access_time_filled, size: 14, color: Colors.grey[500]), const SizedBox(width: 4), Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[500]))]),
                    ],
                  ),
                ),
                
                // --- RSVP BUTTON WITH LOCK LOGIC ---
                SizedBox(
                  width: 45, height: 45,
                  child: ElevatedButton(
                    onPressed: _isProcessing 
                        ? null 
                        : () async {
                            // 🟢 LOCK CHECK
                            if (!widget.isPaid) {
                              widget.onUnlockPressed(); // Open Payment Sheet
                              return;
                            }

                            setState(() => _isProcessing = true);
                            
                            bool isNowJoining = !_hasRsvped;
                            final result = await ref.read(eventProvider.notifier).rsvpEvent(widget.event.id);
                            
                            if (mounted) {
                              setState(() => _isProcessing = false);
                              
                              if(result != null) {
                                setState(() => _hasRsvped = isNowJoining);
                                widget.onRsvpChanged(isNowJoining, widget.event.title);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("Could not update RSVP.")));
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !widget.isPaid 
                          ? Colors.grey[300] // Locked Color
                          : (_hasRsvped ? Colors.white : widget.primaryDark),
                      foregroundColor: !widget.isPaid 
                          ? Colors.grey[600] 
                          : (_hasRsvped ? widget.primaryDark : Colors.white),
                      side: _hasRsvped && widget.isPaid ? BorderSide(color: widget.primaryDark) : BorderSide.none,
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero, 
                    ),
                    child: _isProcessing 
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _hasRsvped ? widget.primaryDark : Colors.white))
                        : Icon(
                            // 🟢 SHOW LOCK IF NOT PAID
                            !widget.isPaid ? Icons.lock : (_hasRsvped ? Icons.check_circle : Icons.add_alert_rounded), 
                            size: 20
                          ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}