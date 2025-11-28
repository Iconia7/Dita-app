import 'dart:convert';
import 'dart:ui'; // Required for BackdropFilter (Glassmorphism)
import 'package:dita_app/screens/profile_screen.dart';
import 'package:dita_app/screens/qr_scanner_screen.dart';
import 'package:dita_app/screens/search_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'pay_fees_screen.dart';

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

  void _syncNotificationToken() async {
    try {
      // Get the token from Firebase
      String? token = await FirebaseMessaging.instance.getToken();
      
      if (token != null) {
        print("My Device Token: $token"); // Debug print
        // Send it to Django
        await ApiService.updateFcmToken(_currentUser['id'], token);
      }
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
      setState(() {
        _currentUser = updatedData;
      });
      
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

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Announcements", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryDark)),
              const Divider(),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _fetchAnnouncements(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: _primaryDark));
                    if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No new announcements"));
                    
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final item = snapshot.data![index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(item['message'], maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: Text(DateFormat('MMM d').format(DateTime.parse(item['date_posted'])), style: const TextStyle(fontSize: 10)),
                        );
                      },
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- LOGIC: QUICK ACTIONS ---
// --- LOGIC: QUICK ACTIONS ---
  void _openScanner() async {
    // 1. Open the Scanner Screen and wait for a result (the QR string)
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    // 2. If we got a code back
    if (result != null) {
      debugPrint('Scanned Code: $result');

      // 3. Parse the Event ID from the string
      // We assume the QR code contains just the ID number (e.g., "1")
      int? eventId = int.tryParse(result.toString());

      if (eventId != null) {
        // Show a loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Verifying attendance..."),
              duration: Duration(seconds: 1),
            )
          );
        }

        // 4. Call the Backend
        var response = await ApiService.markAttendance(eventId, _currentUser['id']);

        if (mounted) {
          // 5. Handle Success
          if (response != null && response.containsKey('new_points')) {
            
            // --- LIVE UPDATE LOGIC ---
            setState(() {
              // Update the local user map with the new points from server
              _currentUser['points'] = response['new_points'];
            });
            // -------------------------

            _showSuccessDialog(
              "Check-in Complete! ✅", 
              "You earned +20 Points for attending this event."
            );
            
          } else {
            // 6. Handle Failure (e.g. "Already checked in")
            _showErrorDialog(response?['message'] ?? "Check-in Failed");
          }
        }
      } else {
        // QR Code wasn't a number
        _showErrorDialog("Invalid QR Code format.");
      }
    }
  }

  // --- DIALOG HELPERS ---

  void _showSuccessDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.stars_rounded, color: Colors.amber, size: 50),
            SizedBox(height: 10),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: _primaryDark, fontSize: 18)),
            const SizedBox(height: 10),
            Text(msg, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Awesome!")
          )
        ],
      )
    );
  }

  void _showErrorDialog(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      )
    );
  }

  void _openWebsite() async {
    const url = 'https://dita.co.ke';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(user: _currentUser))),
                              child: Hero(
                                tag: 'profile_pic',
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                                  ),
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundImage: const NetworkImage("https://i.pravatar.cc/150?img=12"), 
                                    child: _currentUser['avatar'] == null ? const Icon(Icons.person) : null,
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
                      onTap: () async {
                        // 1. Show loading indicator briefly if needed, or just fetch
                        // We fetch fresh data so search is up to date
                        final events = await ApiService.getEvents();
                        final resources = await ApiService.getResources();
                        
                        if (mounted) {
                          showSearch(
                            context: context, 
                            delegate: DitaSearchDelegate(events, resources)
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
                          _buildQuickAction(Icons.payment, "Pay Fees", _showPaymentSheet),
                          const SizedBox(width: 20),
                          _buildQuickAction(Icons.qr_code_scanner, "Scan", _openScanner),
                          const SizedBox(width: 20),
                          _buildQuickAction(Icons.language, "Website", _openWebsite),
                          const SizedBox(width: 20),
                          _buildQuickAction(Icons.support_agent, "Support", () => setState(() => _currentIndex = 3)),
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
                    child: _buildStatCard(
                      "Attendance", 
                      // LIVE DATA LOGIC:
                      "${_currentUser['attendance_percentage'] ?? 0}%", 
                      Icons.bar_chart, 
                      Colors.purple
                    )
                  ),
                      const SizedBox(width: 15),
                      Expanded(child: _buildStatCard("Points", "${_currentUser['points'] ?? 0}", Icons.stars, _accentGold)),
                    ],
                  ),

                  const SizedBox(height: 15),
                  // Feature Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                      image: const DecorationImage(
                        image: NetworkImage("https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?auto=format&fit=crop&q=80"),
                        fit: BoxFit.cover,
                        opacity: 0.4
                      )
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("NIRU Hackathon", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 5),
                        Text("DITA invites you to participate in the NIRU hackathon.", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: (){setState(() {
                          _currentIndex = 1; // Switch to Events Tab
                        });}, 
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentGold,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                          ),
                          child: const Text("Register Now")
                        )
                      ],
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
        title: const Text("Upcoming Events", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false, // Hides back button if it appears
      ),
      body: FutureBuilder<List<dynamic>>(
        future: ApiService.getEvents(), // Call the API
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _primaryDark));
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
              final event = events[index];
              return _buildEventCard(event);
            },
          );
        },
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    // Parse Date
    final DateTime date = DateTime.parse(event['date']);
    final String day = DateFormat('dd').format(date);
    final String month = DateFormat('MMM').format(date).toUpperCase();
    final String time = DateFormat('h:mm a').format(date);
    bool hasRsvped = event['has_rsvped'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Image / Color Banner (Top Half)
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: _primaryDark.withOpacity(0.1), // Placeholder color (or use event image url)
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              image: event['image'] != null 
                ? DecorationImage(
                    // USE DJANGO MEDIA URL
                    image: NetworkImage(event['image']), 
                    fit: BoxFit.cover
                  )
                : null,
            ),
            child: event['image'] == null 
              ? Center(child: Icon(Icons.image, color: Colors.grey[400], size: 40)) 
              : null,
          ),
          
          // Details (Bottom Half)
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                // Date Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  decoration: BoxDecoration(
                    color: _primaryDark.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: _primaryDark.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Text(day, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark)),
                      Text(month, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primaryDark.withOpacity(0.6))),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                
                // Text Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event['title'], 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(event['venue'], style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time_filled, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // RSVP Button
                ElevatedButton(
                  onPressed: () async {
                    // Call RSVP API
                    bool success = await ApiService.rsvpEvent(event['id'], _currentUser['id']);
                    if(success) {
                        setState(() {}); // Simple refresh (in real app, refresh list)
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("RSVP Updated!")));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryDark,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: Icon(hasRsvped ? Icons.check_circle : Icons.add_alert, color: Colors.white, size: 20),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
Widget _buildResourcesTab(bool isPaid) {
    if (!isPaid) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 20),
          const Text("Resources Locked", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          TextButton(onPressed: _showPaymentSheet, child: const Text("Pay to Unlock"))
        ]),
      );
    }
    

    return Scaffold(
      backgroundColor: _bgOffWhite,
      appBar: AppBar(title: const Text("Resources", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: _bgOffWhite, automaticallyImplyLeading: false),
      body: FutureBuilder<List<dynamic>>(
        future: ApiService.getResources(), // Call Backend
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: _primaryDark));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No Resources Available"));
          
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final res = snapshot.data![index];
              
              // Icon Logic based on Type
              IconData icon = Icons.description;
              Color color = Colors.blue;
              if (res['resource_type'] == 'PDF') { icon = Icons.picture_as_pdf; color = Colors.red; }
              if (res['resource_type'] == 'LINK') { icon = Icons.link; color = Colors.green; }

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
                child: ListTile(
                  leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color)),
                  title: Text(res['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(res['description'] ?? ""),
                  trailing: const Icon(Icons.download_rounded, color: Colors.grey),
                  onTap: () async {
                    // Open the link
                    if(res['link'] != null) await launchUrl(Uri.parse(res['link']));
                  },
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