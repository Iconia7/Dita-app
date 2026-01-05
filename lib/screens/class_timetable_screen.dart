import 'dart:async';
import 'dart:convert';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:dita_app/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    if (mounted) {
      setState(() {}); // Updates the UI
      _checkAndShowProgress(); // 🟢 Check for notification updates
    }
  });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

// Run this inside your Timer loop
void _checkAndShowProgress() {
  final now = DateTime.now();
  final dayClasses = _classes.where((c) => c['day'] == _days[now.weekday - 1]).toList();

  bool activeNotificationFound = false;

  for (var c in dayClasses) {
    final startMinutes = _timeToMinutes(c['startTime']);
    final endMinutes = _timeToMinutes(c['endTime']);
    final currentMinutes = now.hour * 60 + now.minute;

    // 1. IS CLASS LIVE? (Start < Now < End)
    if (currentMinutes >= startMinutes && currentMinutes < endMinutes) {
      _updateProgressNotification(c);
      activeNotificationFound = true;
      break; // Only show one live class at a time
    }
    
    // 2. DID CLASS JUST FINISH? (End < Now < End + 5 mins)
    // This catches the moment the class ends so we can show "Done"
    else if (currentMinutes >= endMinutes && currentMinutes < endMinutes + 5) {
      _showCompletionNotification(c);
      activeNotificationFound = true;
    }
  }

  // 3. CLEANUP
  // If no classes are live or just finished, ensure we don't have stuck notifications
  if (!activeNotificationFound) {
    // You might want to cancel specific IDs or all from this channel
    AwesomeNotifications().cancelNotificationsByChannelKey('live_class_monitor');
  }
}

// 🟢 HELPER: Calculates percentage (0.0 to 1.0)
  double _calculateProgress(String start, String end) {
    try {
      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;
      final startMinutes = _timeToMinutes(start);
      final endMinutes = _timeToMinutes(end);

      if (endMinutes <= startMinutes) return 0.0;

      final totalDuration = endMinutes - startMinutes;
      final elapsed = currentMinutes - startMinutes;

      // Return value between 0.0 and 1.0
      return (elapsed / totalDuration).clamp(0.0, 1.0);
    } catch (e) {
      return 0.0;
    }
  }

Future<void> _updateProgressNotification(Map<String, dynamic> classData) async {
  double progress = _calculateProgress(classData['startTime'], classData['endTime']);
  int progressInt = (progress * 100).toInt();

  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: classData['id'], 
      channelKey: 'live_class_monitor',
      title: 'Ongoing: ${classData['code']}',
      body: 'Ends at ${classData['endTime']} • ${classData['venue']}',
      
      // PROGRESS LAYOUT
      notificationLayout: NotificationLayout.ProgressBar,
      progress: progressInt.toDouble(), 
      
      // STICKY BEHAVIOR
      locked: true,             // User cannot swipe away
      autoDismissible: false,   // Tap does not dismiss
      category: NotificationCategory.Progress,
      payload: {'class_id': classData['id'].toString()},
    ),
    actionButtons: [
      NotificationActionButton(
        key: 'STOP_MONITOR', 
        label: 'End Monitor', 
        actionType: ActionType.DismissAction
      ),
    ],
  );
}

Future<void> _showCompletionNotification(Map<String, dynamic> classData) async {
  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: classData['id'], // Reuses ID to replace the progress bar
      channelKey: 'live_class_monitor', // Use same channel
      
      // SUCCESS MESSAGE
      title: 'Class Dismissed! 🎉', 
      body: '${classData['code']} has ended. Enjoy your break!',
      
      // STANDARD LAYOUT (Removes Progress Bar)
      notificationLayout: NotificationLayout.Default,
      progress: null, 
      
      // UNLOCKED BEHAVIOR (Key Change!)
      locked: false,            // User CAN swipe it away now
      autoDismissible: true,    // Tap dismisses it
      wakeUpScreen: true,       // Light up screen (optional)
      category: NotificationCategory.Status,
    ),
    // No action buttons needed, or add a "Open App" button
  );
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
    // 🟢 Theme Helpers
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).primaryColor;
    final accentGold = const Color(0xFFFFD700);

    return Scaffold(
      backgroundColor: scaffoldBg, // 🟢 Dynamic BG
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 100.0,
              floating: false,
              pinned: true,
              backgroundColor: primaryColor,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: const Text(
                  "Timetable",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          // 🟢 Dark Mode Gradient check (optional, or keep blue for brand)
                          colors: isDark 
                              ? [const Color(0xFF0F172A), const Color(0xFF003366)] 
                              : [const Color(0xFF003366), const Color(0xFF003366)], 
                        ),
                      ),
                    ),
                    Positioned(
                      right: -30,
                      top: -50,
                      child: Container(
                        width: 150, height: 150,
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
                  icon: const Icon(Icons.tune, color: Colors.white),
                  color: Theme.of(context).cardColor, // 🟢 Dynamic Menu BG
                  onSelected: (value) {
                    if (value == 'sync') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PortalImportScreen())).then((_) => _loadClasses());
                    } else if (value == 'clear') _clearAllClasses();
                  },
                  itemBuilder: (BuildContext context) => [
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
                    color: accentGold,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(color: accentGold.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))
                    ]
                  ),
                  labelColor: const Color(0xFF003366), // Selected text always Dark Blue (on Gold)
                  unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600], // 🟢 Dynamic Unselected
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  tabs: _days.map((d) => Tab(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(d),
                    ),
                  )).toList(),
                ),
                scaffoldBg, // 🟢 Pass the background color to the delegate
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

Widget _buildEmptyState() {
  return EmptyStateWidget(
    svgPath: 'assets/svgs/no_data.svg', // Ensure you add this SVG asset
    title: "No Classes Yet",
    message: "Sync your portal or add classes manually to get started.",
    actionLabel: "Sync Now",
    onActionPressed: () {
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => const PortalImportScreen())
      ).then((_) => _loadClasses());
    },
  );
}

  Widget _buildDayTimeline(String day) {
    // 🟢 Theme Helpers
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.labelSmall?.color;

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
            Text("Free Day!", style: TextStyle(color: subTextColor, fontSize: 16, fontWeight: FontWeight.w600)),
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
                      style: TextStyle(fontWeight: FontWeight.bold, color: isLive ? _liveGreen : textColor) // 🟢
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c['endTime'], 
                      style: TextStyle(fontSize: 12, color: subTextColor) // 🟢
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
                      color: isLive ? _liveGreen : (isDark ? Colors.grey[700] : Colors.white), // 🟢 Darker dot for dark mode
                      border: Border.all(color: isLive ? _liveGreen : (isDark ? Colors.grey[600]! : Colors.grey[300]!), width: 2),
                      shape: BoxShape.circle,
                      boxShadow: isLive ? [BoxShadow(color: _liveGreen.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)] : null
                    ),
                  ),
                  if (!isLast) 
                    Expanded(child: Container(width: 2, color: isDark ? Colors.grey[800] : Colors.grey[200])), // 🟢 Darker line
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
    // 🟢 Theme Helpers
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.labelSmall?.color;

    return Container(
      decoration: BoxDecoration(
        color: cardColor, // 🟢 Dynamic Card BG
        borderRadius: BorderRadius.circular(16),
        border: isLive ? Border.all(color: _liveGreen, width: 1.5) : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: isLive ? _liveGreen.withOpacity(0.15) : Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
        gradient: isLive ? LinearGradient(
            colors: isDark 
              ? [cardColor, _liveGreen.withOpacity(0.1)] 
              : [Colors.white, _liveGreen.withOpacity(0.05)]
        ) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onLongPress: () => _deleteSingleClass(c['id']), 
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
                          color: isLive ? _liveGreen : Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          c['code'], 
                          style: TextStyle(
                            color: isLive ? Colors.white : Theme.of(context).primaryColor, // 🟢
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
                  
                  // TITLE
                  Text(
                    "Class at ${c['venue']}",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor), // 🟢
                  ),
                  const SizedBox(height: 8),

                  // DETAILS ROW
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: subTextColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c['lecturer'] == "Unknown" ? "Lecturer N/A" : c['lecturer'], 
                          style: TextStyle(color: subTextColor, fontSize: 13), // 🟢
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
  _SliverAppBarDelegate(this._tabBar, this._bgColor); // 🟢 Accept BG Color
  final TabBar _tabBar;
  final Color _bgColor;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: _bgColor, // 🟢 Use Dynamic BG Color
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return _bgColor != oldDelegate._bgColor; // Rebuild if color changes (Dark Mode Switch)
  }
}