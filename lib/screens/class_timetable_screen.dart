import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'manual_class_entry_screen.dart';
import 'portal_import_screen.dart';
import '../services/notification.dart';

class ClassTimetableScreen extends StatefulWidget {
  const ClassTimetableScreen({super.key});

  @override
  State<ClassTimetableScreen> createState() => _ClassTimetableScreenState();
}

class _ClassTimetableScreenState extends State<ClassTimetableScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _timer;
  
  // --- MODERN COLOR PALETTE ---
  final Color _primaryDark = const Color(0xFF0F172A); // Midnight Blue (Modern Dark)
  final Color _primaryBlue = const Color(0xFF003366); // Daystar Blue
  final Color _accentGold = const Color(0xFFFFD700);
  final Color _bgLight = const Color(0xFFF1F5F9);     // Slate 100
  final Color _cardWhite = Colors.white;
  final Color _textMain = const Color(0xFF1E293B);    // Slate 800
  final Color _textSub = const Color(0xFF64748B);     // Slate 500
  final Color _liveGreen = const Color(0xFF10B981);   // Emerald 500

  final List<String> _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  List<dynamic> _classes = [];

  @override
  void initState() {
    super.initState();
    int todayIndex = DateTime.now().weekday - 1; 
    _tabController = TabController(length: 7, initialIndex: todayIndex, vsync: this);
    _loadClasses();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('my_classes');
    if (data != null && mounted) {
      setState(() {
        _classes = json.decode(data);
      });
    } else {
      setState(() => _classes = []);
    }
  }

  Future<void> _clearAllClasses() async {
    for (var c in _classes) {
      if (c['id'] != null) await NotificationService.cancelNotification(c['id']);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('my_classes');
    _loadClasses();
  }

  // --- LOGIC ---
  bool _isClassLive(Map<String, dynamic> cls) {
    int currentDayIndex = DateTime.now().weekday;
    int classDayIndex = _days.indexOf(cls['day']) + 1;
    if (classDayIndex != currentDayIndex) return false;

    int nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    int startMinutes = _timeToMinutes(cls['startTime']);
    int endMinutes = _timeToMinutes(cls['endTime']);

    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }

  int _timeToMinutes(String timeStr) {
    try {
      var parts = timeStr.split(":");
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 120.0,
              floating: false,
              pinned: true,
              backgroundColor: _primaryBlue,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: const Text(
                  "Timetable",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18,color: Colors.white),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_primaryDark, _primaryBlue],
                        ),
                      ),
                    ),
                    // Decorative Circle
                    Positioned(
                      right: -30,
                      top: -50,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                 PopupMenuButton<String>(
                  icon: const Icon(Icons.tune, color: Colors.white), // Settings/Tune icon
                  onSelected: (value) {
                    if (value == 'manual') Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualClassEntryScreen())).then((_) => _loadClasses());
                    else if (value == 'sync') Navigator.push(context, MaterialPageRoute(builder: (_) => const PortalImportScreen())).then((_) => _loadClasses());
                    else if (value == 'clear') _clearAllClasses();
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(value: 'manual', child: Row(children: [Icon(Icons.add, size: 18), SizedBox(width: 8), Text("Add Class")])),
                    const PopupMenuItem(value: 'sync', child: Row(children: [Icon(Icons.sync, size: 18), SizedBox(width: 8), Text("Sync Portal")])),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'clear', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text("Clear All", style: TextStyle(color: Colors.red))])),
                  ],
                )
              ],
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicator: BoxDecoration(
                    color: _accentGold,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(color: _accentGold.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))
                    ]
                  ),
                  labelColor: _primaryDark,
                  unselectedLabelColor: _textSub,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  tabs: _days.map((d) => Tab(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(d),
                    ),
                  )).toList(),
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: _days.map((day) => _buildDayTimeline(day)).toList(),
        ),
      ),
    );
  }

  // --- EMPTY STATE WIDGET ---
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, spreadRadius: 5)]),
              child: Icon(Icons.calendar_month_outlined, size: 50, color: _primaryBlue.withOpacity(0.5)),
            ),
            const SizedBox(height: 25),
            Text("No Classes Yet", style: TextStyle(color: _primaryDark, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Sync your portal or add classes manually to get started.", textAlign: TextAlign.center, style: TextStyle(color: _textSub)),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PortalImportScreen())).then((_) => _loadClasses()),
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text("Sync Now"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TIMELINE BUILDER ---
  Widget _buildDayTimeline(String day) {
    if (_classes.isEmpty) return _buildEmptyState();

    final dayClasses = _classes.where((c) => c['day'] == day).toList();
    dayClasses.sort((a, b) => a['startTime'].compareTo(b['startTime'])); 

    if (dayClasses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.weekend_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 15),
            Text("Free Day!", style: TextStyle(color: _textSub, fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
      itemCount: dayClasses.length,
      itemBuilder: (context, index) {
        final c = dayClasses[index];
        bool isLive = _isClassLive(c);
        bool isLast = index == dayClasses.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TIME COLUMN
              SizedBox(
                width: 50,
                child: Column(
                  children: [
                    Text(
                      c['startTime'], 
                      style: TextStyle(fontWeight: FontWeight.bold, color: isLive ? _liveGreen : _textMain)
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c['endTime'], 
                      style: TextStyle(fontSize: 12, color: _textSub)
                    ),
                  ],
                ),
              ),

              // 2. TIMELINE LINE
              Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isLive ? _liveGreen : Colors.white,
                      border: Border.all(color: isLive ? _liveGreen : Colors.grey[300]!, width: 2),
                      shape: BoxShape.circle,
                      boxShadow: isLive ? [BoxShadow(color: _liveGreen.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)] : null
                    ),
                  ),
                  if (!isLast) 
                    Expanded(child: Container(width: 2, color: Colors.grey[200])),
                ],
              ),

              // 3. CARD CONTENT
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildClassCard(c, isLive),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClassCard(Map<String, dynamic> c, bool isLive) {
    return Container(
      decoration: BoxDecoration(
        color: isLive ? Colors.white : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isLive ? Border.all(color: _liveGreen, width: 1.5) : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: isLive ? _liveGreen.withOpacity(0.15) : Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
        gradient: isLive ? LinearGradient(colors: [Colors.white, _liveGreen.withOpacity(0.05)]) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onLongPress: () => _deleteSingleClass(c['id']), // Long press to delete
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER: Code & Live Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLive ? _liveGreen : _primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          c['code'], 
                          style: TextStyle(
                            color: isLive ? Colors.white : _primaryBlue, 
                            fontWeight: FontWeight.w800,
                            fontSize: 12
                          )
                        ),
                      ),
                      if (isLive)
                         Row(children: [
                           Icon(Icons.sensors, size: 14, color: _liveGreen),
                           const SizedBox(width: 4),
                           Text("LIVE", style: TextStyle(color: _liveGreen, fontWeight: FontWeight.bold, fontSize: 12))
                         ]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // TITLE (Venue as Title for now or Code if title missing)
                  Text(
                    "Class at ${c['venue']}",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textMain),
                  ),
                  const SizedBox(height: 8),

                  // DETAILS ROW
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: _textSub),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c['lecturer'] == "Unknown" ? "Lecturer N/A" : c['lecturer'], 
                          style: TextStyle(color: _textSub, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteSingleClass(int id) async {
    if (id != 0) await NotificationService.cancelNotification(id);
    final prefs = await SharedPreferences.getInstance(); 
    List<dynamic> current = json.decode(prefs.getString('my_classes') ?? '[]');
    current.removeWhere((item) => item['id'] == id);
    await prefs.setString('my_classes', json.encode(current));
    _loadClasses();
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Class removed")));
  }
}

// --- HELPER FOR STICKY TAB BAR ---
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFF1F5F9), // Match background color
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}