import 'package:dita_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
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

  // Colors
  final Color _primaryBlue = const Color(0xFF003366);
  final Color _bgWhite = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
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
      
      if (_currentUser['is_paid_member'] == true) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text("Membership Active! Features Unlocked."),
                ],
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isPaid = _currentUser['is_paid_member'] ?? false;

    final List<Widget> pages = [
      _buildHomeTab(isPaid),
      _buildEventsTab(),
      _buildResourcesTab(isPaid),
      _buildNewsTab(),
    ];

    return Scaffold(
      backgroundColor: _bgWhite,
      body: pages[_currentIndex],
      bottomNavigationBar: _buildModernBottomNav(),
    );
  }

  // --- MODERN BOTTOM NAV ---
  Widget _buildModernBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.dashboard_rounded, 'Home'),
              _buildNavItem(1, Icons.calendar_month_rounded, 'Events'),
              _buildNavItem(2, Icons.menu_book_rounded, 'Resources'),
              _buildNavItem(3, Icons.notifications_rounded, 'News'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? _primaryBlue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? _primaryBlue : Colors.grey[400],
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: _primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- TAB 1: DASHBOARD ---
  Widget _buildHomeTab(bool isPaid) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: _primaryBlue,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Styled App Bar
          SliverAppBar(
            expandedHeight: 80,
            floating: true,
            pinned: true,
            backgroundColor: _bgWhite,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: CircleAvatar(
                backgroundColor: _primaryBlue.withOpacity(0.1),
                child: Icon(Icons.school_rounded, color: _primaryBlue),
              ),
            ),
            title: Text(
              "Dashboard",
              style: TextStyle(
                color: _primaryBlue,
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
            centerTitle: false,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: IconButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  icon: Icon(Icons.logout_rounded, color: Colors.red[300]),
                  tooltip: "Logout",
                ),
              )
            ],
          ),

          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Text
                    Text(
                      "Hello, ${(_currentUser['username'] ?? 'Student')}",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500
                      ),
                    ),
                    const SizedBox(height: 15),

                    // ID Card
                    _buildModernIDCard(isPaid),
                    
                    const SizedBox(height: 25),

                    // Action Area
                    if (!isPaid) _buildUpgradePrompt() else _buildQuickStats(),
                    
                    const SizedBox(height: 25),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernIDCard(bool isPaid) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isPaid ? _primaryBlue.withOpacity(0.4) : Colors.black.withOpacity(0.2),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Gradient Background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPaid 
                    ? [_primaryBlue, const Color(0xFF0055AA)] 
                    : [const Color(0xFF424242), const Color(0xFF212121)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            // Decorative Circles
            Positioned(
              top: -50,
              right: -50,
              child: CircleAvatar(radius: 100, backgroundColor: Colors.white.withOpacity(0.05)),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withOpacity(0.05)),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(isPaid ? Icons.verified : Icons.timelapse, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              isPaid ? "ACTIVE MEMBER" : "PENDING",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.nfc, color: Colors.white38, size: 30),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      // QR Code Container
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QrImageView(
                          data: _currentUser['admission_number'] ?? 'Unknown',
                          version: QrVersions.auto,
                          size: 70,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (_currentUser['username'] ?? "").toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentUser['admission_number'] ?? "",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradePrompt() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_open_rounded, color: Colors.orange.shade700, size: 30),
          ),
          const SizedBox(height: 15),
          const Text(
            "Complete Registration",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Unlock resources and voting rights by paying the membership fee.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PayFeesScreen(
                      phoneNumber: _currentUser['phone_number'] ?? '',
                      user: _currentUser,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: const Text("Pay KES 500 Now", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Your Activity",
            style: TextStyle(
              color: _primaryBlue,
              fontWeight: FontWeight.bold,
              fontSize: 16
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(Icons.event_note_rounded, "0", "Events", Colors.purple),
              _buildStatItem(Icons.download_rounded, "0", "Downloads", Colors.blue),
              _buildStatItem(Icons.star_rounded, "0", "Points", Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String val, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 10),
        Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryBlue)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  // --- TAB 2: EVENTS ---
  Widget _buildEventsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            "No Events Yet",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: RESOURCES ---
  Widget _buildResourcesTab(bool isPaid) {
    if (!isPaid) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20)],
                ),
                child: Icon(Icons.lock_rounded, size: 50, color: Colors.grey[400]),
              ),
              const SizedBox(height: 20),
              const Text("Access Locked", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                "Pay your membership fee to access learning materials.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 30),
              TextButton(
                onPressed: () => setState(() => _currentIndex = 0),
                child: Text("Go to Dashboard", style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: _primaryBlue,
          title: const Text("Resources"),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,4))],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(15),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    ),
                    title: Text("Python Guide Part ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("PDF • 2.5 MB"),
                    trailing: Icon(Icons.download_rounded, color: Colors.grey[400]),
                  ),
                );
              },
              childCount: 5,
            ),
          ),
        ),
      ],
    );
  }

  // --- TAB 4: NEWS ---
  Widget _buildNewsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            "No Announcements",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}