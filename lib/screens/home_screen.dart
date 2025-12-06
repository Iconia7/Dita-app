import 'dart:convert';
import 'dart:ui'; // Required for BackdropFilter (Glassmorphism)
import 'package:dita_app/screens/ai_assistant_screen.dart';
import 'package:dita_app/screens/attendance_history_screen.dart';
import 'package:dita_app/screens/class_timetable_screen.dart';
import 'package:dita_app/screens/exam_timetable_screen.dart';
import 'package:dita_app/screens/profile_screen.dart';
import 'package:dita_app/screens/qr_scanner_screen.dart';
import 'package:dita_app/screens/search_screen.dart';
import 'package:dita_app/screens/tasks_screen.dart';
import 'package:dita_app/widgets/dita_loader.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'pay_fees_screen.dart';
import 'dart:io';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _currentUser;
  int _currentIndex = 0;
  
  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // --- DESIGN SYSTEM COLORS ---
  final Color _primaryDark = const Color(0xFF003366); // DITA Blue
  final Color _primaryLight = const Color(0xFF004C99); // Lighter Blue for gradients
  final Color _accentGold = const Color(0xFFFFD700); // Gold
  final Color _bgOffWhite = const Color(0xFFF4F6F9); // Clean Grey-White
  

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
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
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        // Show a SnackBar at the bottom
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _primaryDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message.notification!.title ?? "New Notification", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                Text(message.notification!.body ?? "", style: const TextStyle(color: Colors.white70)),
              ],
            ),
            action: SnackBarAction(
              label: "VIEW", 
              textColor: _accentGold,
              onPressed: _showNotificationsDialog, // Open your news dialog
            ),
          )
        );
      }
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
      bool success = await ApiService.uploadProfilePicture(_currentUser['id'], file);

      if (success) {
        await _refreshData(); // Reload user data from server to get new URL
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
      // Get the token from Firebase
      String? token = await FirebaseMessaging.instance.getToken();
      
      print("My Device Token: $token"); // Debug print
      // Send it to Django
      await ApiService.updateFcmToken(_currentUser['id'], token!);
        } catch (e) {
      print("Notification Init Error: $e");
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final updatedData = await ApiService.getUserDetails(_currentUser['id']);
    if (updatedData != null) {
      await ApiService.saveUserLocally(updatedData);
      setState(() {
        _currentUser = updatedData;
      });

      print("New Avatar URL: ${_currentUser['avatar']}");
      
      if (_currentUser['is_paid_member'] == true && mounted) {
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
  }

  Future<List<dynamic>> _fetchAnnouncements() async {
    try {
      final response = await http.get(Uri.parse('${ApiService.baseUrl}/announcements/'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("News Error: $e");
    }
    return [];
  }

// --- 1. STYLISH ANNOUNCEMENT DIALOG ---
  void _showNotificationsDialog() {
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("📢 Announcements", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark)),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const Divider(),
                  
                  // Content
                  Expanded(
                    child: FutureBuilder<List<dynamic>>(
                      future: _fetchAnnouncements(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: LogoSpinner());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            final item = snapshot.data![index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: _bgOffWhite,
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
                                          color: _primaryDark.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          "NEWS", 
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primaryDark)
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        DateFormat('MMM d, h:mm a').format(DateTime.parse(item['date_posted'])),
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item['title'],
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['message'],
                                    style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.4),
                                  ),
                                ],
                              ),
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
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: child,
        );
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark),
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
                      backgroundColor: _primaryDark,
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            contentPadding: EdgeInsets.zero,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Green Area
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
                      Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryDark), textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      Text(msg, style: TextStyle(color: Colors.grey[600], fontSize: 14), textAlign: TextAlign.center),
                      const SizedBox(height: 25),
                      
                      // Animated Points Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          color: _accentGold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _accentGold)
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stars_rounded, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Text("+20 Points Added", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800])),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 25),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryDark,
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: EdgeInsets.zero,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Colored Header
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
                      Text(
                        title, 
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryDark),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        msg, 
                        style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5), 
                        textAlign: TextAlign.center
                      ),
                      
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
        var response = await ApiService.markAttendance(eventId);

        if (mounted) {
          // 5. Handle Success
          if (response != null && response.containsKey('new_points')) {
            
            // Update Points locally
            setState(() {
              _currentUser['points'] = response['new_points'];
            });

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
    bool isPaid = _currentUser['is_paid_member'] ?? false;
    if (!isPaid) {
      // Show the Pay Sheet immediately
      showModalBottomSheet(
        context: context,
        isScrollControlled: true, // Allows full height
        backgroundColor: Colors.transparent,
        builder: (context) => PayFeesSheet(user: _currentUser),
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
    builder: (context) => PayFeesSheet(user: _currentUser),
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
    bool isPaid = _currentUser['is_paid_member'] ?? false;

    final List<Widget> pages = [
      _buildDesignerHomeTab(isPaid),
      _buildEventsTab(),
      _buildResourcesTab(isPaid),
      _buildNewsTab(),
    ];

    return Scaffold(
      backgroundColor: _bgOffWhite,
      // extendBody allows the content to flow behind the floating nav bar
      extendBody: true, 
      body: pages[_currentIndex],
      bottomNavigationBar: _buildFloatingBottomNav(),
      floatingActionButton: FloatingActionButton(
    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAssistantScreen())),
    backgroundColor: _primaryDark,
    child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
  ),
  // Adjust location so it doesn't overlap with bottom nav
  floatingActionButtonLocation: FloatingActionButtonLocation.endFloat, 
);
  }

  // --- 1. DESIGNER HOME TAB ---
  Widget _buildDesignerHomeTab(bool isPaid) {
    bool isExpiringSoon = false;
if (isPaid && _currentUser['membership_expiry'] != null) {
  final expiry = DateTime.parse(_currentUser['membership_expiry']);
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
                  colors: [_primaryDark, _primaryLight],
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
                            GestureDetector(
                              onTap: _pickAndUploadImage, // <--- TRIGGER UPLOAD
                              child: Hero(
                                tag: 'profile_pic',
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
  // 1. Check if avatar exists and is not empty
  backgroundImage: (_currentUser['avatar'] != null && _currentUser['avatar'].toString().isNotEmpty)
      ? NetworkImage(_currentUser['avatar']) 
      : null, // Set to null if no image, so child Icon shows
  child: (_currentUser['avatar'] == null || _currentUser['avatar'].toString().isEmpty)
      ? Icon(Icons.person, color: Colors.grey[400]) // Fallback Icon
      : null,
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
                                  (_currentUser['username'] ?? "Student").split(' ')[0], 
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
                      onTap: () {
                        // 1. Show loading indicator briefly if needed, or just fetch
                        // We fetch fresh data so search is up to date
                        showSearch(
      context: context, 
      delegate: DitaSearchDelegate(
        ApiService.getEvents(),     // <--- Pass the Future directly
        ApiService.getResources()   // <--- Pass the Future directly
      )
    );
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
  () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamTimetableScreen(user: _currentUser)))
),
const SizedBox(width: 20),
_buildQuickAction(
  Icons.school_rounded, 
  "Classes", 
  () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClassTimetableScreen()))
),
const SizedBox(width: 20),
                          _buildQuickAction(
         Icons.checklist_rtl_rounded, 
         "Planner", 
         () => Navigator.push(context, MaterialPageRoute(builder: (_) => TasksScreen(user: _currentUser)))
      ),
      const SizedBox(width: 20),
                          _buildQuickAction(Icons.payment, "Pay Fees", _showPaymentSheet),
                          const SizedBox(width: 20),
                          _buildQuickAction(Icons.qr_code_scanner, "Scan", _openScanner),
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
            color: _primaryDark,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 25),
                  
                  // Membership Section Header
                  Row(
                    children: [
                      const Text("My Membership", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
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
                  _buildPremiumIDCard(isPaid),

                  const SizedBox(height: 30),

                  // Analytics Grid
                  const Text("Dashboard", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
  child: GestureDetector( // <--- Wrap in GestureDetector
    onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => AttendanceHistoryScreen(userId: _currentUser['id']))
        );
    },
    child: _buildStatCard(
      "Attendance", 
      "${_currentUser['attendance_percentage'] ?? 0}%", 
      Icons.bar_chart, 
      Colors.purple
    ),
  ),
),
                      const SizedBox(width: 15),
                      Expanded(child: _buildStatCard("Points", "${_currentUser['points'] ?? 0}", Icons.stars, _accentGold)),
                    ],
                  ),

                  const SizedBox(height: 15),
                  // Feature Banner
                  // --- UPCOMING EVENTS SECTION (NEW) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Upcoming Events", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
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
                                color: Colors.white,
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
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryDark)
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 12, color: _accentGold),
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
    return GestureDetector(
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
            child: Icon(icon, color: _accentGold, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildPremiumIDCard(bool isPaid) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPaid 
            ? [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)] // Deep tech gradient
            : [Colors.grey[400]!, Colors.grey[600]!],
        ),
        boxShadow: [
          BoxShadow(
            color: isPaid ? const Color(0xFF2C5364).withOpacity(0.4) : Colors.grey.withOpacity(0.4),
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
                            _currentUser['username'] ?? "USER NAME", 
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentUser['admission_number'] ?? "00-0000", 
                            style: TextStyle(color: _accentGold, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.5),
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
                        data: _currentUser['admission_number'] ?? "000",
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
        color: Colors.white,
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
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFloatingBottomNav() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
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
            _buildNavItem(3, Icons.person_outline_rounded, "Profile"),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon, 
              color: isSelected ? _accentGold : Colors.grey[400], 
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
  Widget _buildEventsTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _primaryDark,
        elevation: 0,
        title: const Text("Upcoming Events", style: TextStyle(fontWeight: FontWeight.bold,color: Colors.white)),
        centerTitle: true,
        automaticallyImplyLeading: false, // Hides back button if it appears
      ),
      body: FutureBuilder<List<dynamic>>(
        future: ApiService.getEvents(), // Call the API
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LogoSpinner());
          }
          
          // 2. Error State
          if (snapshot.hasError) {
            return Center(child: Text("Error loading events", style: TextStyle(color: Colors.grey[600])));
          }

          // 3. Empty State
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy_rounded, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  Text("No Events Scheduled", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                ],
              ),
            );
          }

          // 4. Data State (The List)
          final events = snapshot.data!;
          
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: events.length,
            itemBuilder: (context, index) {
              return EventCard(
                event: snapshot.data![index],
                userId: _currentUser['id'],
                primaryDark: _primaryDark,
                onRsvpChanged: (bool isJoining, String title) {
                  _showRSVPDialog(isJoining, title);
                },
              );
            },
          );
        },
      ),
    );
  }

Widget _buildResourcesTab(bool isPaid) {
    if (!isPaid) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.lock_outline, size: 60, color: Colors.grey[400]),
        const SizedBox(height: 20),
        const Text("Resources Locked",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 10),
        TextButton(
            onPressed: _showPaymentSheet, child: const Text("Pay to Unlock"))
      ]));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9), // _bgOffWhite
      appBar: AppBar(
        title: const Text("Resources",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF003366), // _primaryDark
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: ApiService.getResources(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LogoSpinner());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No Resources Available"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final res = snapshot.data![index];
              final type = res['resource_type'] ?? 'LINK';

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
                    color: Colors.white,
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
                          Text(res['title'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          if (res['description'] != null &&
                              res['description'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(res['description'],
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
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
                        String? urlToOpen = res['file'];
                        if (urlToOpen == null || urlToOpen.isEmpty) {
                          urlToOpen = res['link'];
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
                          backgroundColor: const Color(0xFFF4F6F9), // Matches bg
                          foregroundColor: const Color(0xFF003366), // Dark text
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
          );
        },
      ),
    );
  }
  Widget _buildNewsTab() =>  ProfileScreen(user: _currentUser);
}

class EventCard extends StatefulWidget {
  final Map<String, dynamic> event;
  final int userId;
  final Color primaryDark;
  final Function(bool, String) onRsvpChanged;

  const EventCard({
    super.key, 
    required this.event, 
    required this.userId, 
    required this.primaryDark,
    required this.onRsvpChanged
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  late bool _hasRsvped;
  bool _isProcessing = false; // Tracks loading for THIS button only

  @override
  void initState() {
    super.initState();
    _hasRsvped = widget.event['has_rsvped'] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final DateTime date = DateTime.parse(widget.event['date']);
    final String day = DateFormat('dd').format(date);
    final String month = DateFormat('MMM').format(date).toUpperCase();
    final String time = DateFormat('h:mm a').format(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: widget.primaryDark.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              image: widget.event['image'] != null ? DecorationImage(image: NetworkImage(widget.event['image']), fit: BoxFit.cover) : null,
            ),
            child: widget.event['image'] == null ? Center(child: Icon(Icons.image, color: Colors.grey[400], size: 40)) : null,
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  decoration: BoxDecoration(color: widget.primaryDark.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: widget.primaryDark.withOpacity(0.1))),
                  child: Column(children: [Text(day, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: widget.primaryDark)), Text(month, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.primaryDark.withOpacity(0.6)))]),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.event['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      Row(children: [Icon(Icons.location_on, size: 14, color: Colors.grey[500]), const SizedBox(width: 4), Text(widget.event['venue'], style: TextStyle(fontSize: 12, color: Colors.grey[500]))]),
                      const SizedBox(height: 4),
                      Row(children: [Icon(Icons.access_time_filled, size: 14, color: Colors.grey[500]), const SizedBox(width: 4), Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[500]))]),
                    ],
                  ),
                ),
                
                // --- BUTTON WITH LOADING STATE ---
                SizedBox(
                  width: 45, height: 45,
                  child: ElevatedButton(
                    onPressed: _isProcessing 
                        ? null // Disable if loading (Prevents multi-clicks)
                        : () async {
                            setState(() => _isProcessing = true); // Start Loading
                            
                            bool isNowJoining = !_hasRsvped;
                            bool success = await ApiService.rsvpEvent(widget.event['id']);
                            
                            if (mounted) {
                              setState(() => _isProcessing = false); // Stop Loading
                              
                              if(success) {
                                setState(() => _hasRsvped = isNowJoining); // Flip State
                                widget.onRsvpChanged(isNowJoining, widget.event['title']);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("Could not update RSVP.")));
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasRsvped ? Colors.white : widget.primaryDark,
                      foregroundColor: _hasRsvped ? widget.primaryDark : Colors.white,
                      side: _hasRsvped ? BorderSide(color: widget.primaryDark) : BorderSide.none,
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero, // Center icon
                    ),
                    child: _isProcessing 
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _hasRsvped ? widget.primaryDark : Colors.white))
                        : Icon(_hasRsvped ? Icons.check_circle : Icons.add_alert_rounded, size: 20),
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