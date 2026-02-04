import 'dart:async';
import 'package:intl/intl.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dita_app/widgets/dita_loader.dart';
import 'package:dita_app/widgets/skeleton_loader.dart';
import 'package:dita_app/widgets/empty_state_widget.dart';
import 'package:dita_app/providers/timetable_provider.dart';
import 'package:dita_app/data/models/timetable_model.dart';
import 'portal_import_screen.dart';

class ClassTimetableScreen extends ConsumerStatefulWidget {
  const ClassTimetableScreen({super.key});

  @override
  ConsumerState<ClassTimetableScreen> createState() => _ClassTimetableScreenState();
}

class _ClassTimetableScreenState extends ConsumerState<ClassTimetableScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _timer;
  final Color _liveGreen = const Color(0xFF10B981);   // Emerald 500

  final List<String> _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  void initState() {
    super.initState();
    int todayIndex = DateTime.now().weekday - 1; 
    _tabController = TabController(length: 7, initialIndex: todayIndex, vsync: this);
    
    // Timer for live class updates
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {}); // Updates the UI
        _checkAndShowProgress();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // Helper to get classes from provider
  List<TimetableModel> _getClasses() {
    final asyncData = ref.read(timetableProvider); // Use read for non-reactive access in timer
    return asyncData.value?.where((item) => item.isClass).toList() ?? [];
  }

  // Run this inside your Timer loop
  void _checkAndShowProgress() {
    final now = DateTime.now();
    final allClasses = _getClasses();
    // Assuming backend returns short day names (MON, TUE), need to match
    // Or if backend returns full names, need to truncate/map. 
    // TimetableModel tries to parse day, assuming model handles format.
    // For now assuming model.dayOfWeek matches _days format or is normalized.
    // Actually TimetableModel defaults dayOfWeek to 'Monday', 'Tuesday' etc.
    // We need to map 'MON' to 'Monday' or vice versa.
    // Let's assume standard 'Monday' in model and map _days to full names for comparison?
    // The previous code used _days=['MON'...] and dayClasses.where((c) => c['day'] == _days[...])
    
    // Fix: Map standard full day names from model to short names if needed, or vice-versa.
    // Let's use standard full names for logic.
    String currentDayName = DateFormat('EEEE').format(now); // Monday, Tuesday...
    
    final dayClasses = allClasses.where((c) => c.dayOfWeek == currentDayName).toList();

    bool activeNotificationFound = false;

    for (var c in dayClasses) {
      final startMinutes = _timeToMinutes(c.startTime);
      final endMinutes = _timeToMinutes(c.endTime);
      final currentMinutes = now.hour * 60 + now.minute;

      if (currentMinutes >= startMinutes && currentMinutes < endMinutes) {
        _updateProgressNotification(c);
        activeNotificationFound = true;
        break; 
      }
      else if (currentMinutes >= endMinutes && currentMinutes < endMinutes + 5) {
        _showCompletionNotification(c);
        activeNotificationFound = true;
      }
    }

    if (!activeNotificationFound) {
      AwesomeNotifications().cancelNotificationsByChannelKey('live_class_monitor');
    }
  }

  double _calculateProgress(String start, String end) {
    try {
      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;
      final startMinutes = _timeToMinutes(start);
      final endMinutes = _timeToMinutes(end);

      if (endMinutes <= startMinutes) return 0.0;
      final totalDuration = endMinutes - startMinutes;
      final elapsed = currentMinutes - startMinutes;
      return (elapsed / totalDuration).clamp(0.0, 1.0);
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _updateProgressNotification(TimetableModel c) async {
    double progress = _calculateProgress(c.startTime, c.endTime);
    int progressInt = (progress * 100).toInt();

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: c.id, 
        channelKey: 'live_class_monitor',
        title: 'Ongoing: ${c.code ?? c.title}',
        body: 'Ends at ${c.endTime} • ${c.venue ?? "Online"}',
        notificationLayout: NotificationLayout.ProgressBar,
        progress: progressInt.toDouble(), 
        locked: true,
        autoDismissible: false,
        category: NotificationCategory.Progress,
        payload: {'class_id': c.id.toString()},
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

  Future<void> _showCompletionNotification(TimetableModel c) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: c.id, 
        channelKey: 'live_class_monitor',
        title: 'Class Dismissed! 🎉', 
        body: '${c.code ?? c.title} has ended. Enjoy your break!',
        notificationLayout: NotificationLayout.Default,
        progress: null, 
        locked: false,
        autoDismissible: true,
        wakeUpScreen: true,
        category: NotificationCategory.Status,
      ),
    );
  }

  bool _isClassLive(TimetableModel cls) {
    int currentDayIndex = DateTime.now().weekday; // 1 = Mon, 7 = Sun
    // Map cls.dayOfWeek (e.g. 'Monday') to index
    int classDayIndex = cls.dayNumber + 1; // dayNumber is 0-indexed (0=Mon)
    
    if (classDayIndex != currentDayIndex) return false;

    int nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    int startMinutes = _timeToMinutes(cls.startTime);
    int endMinutes = _timeToMinutes(cls.endTime);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).primaryColor;
    final accentGold = const Color(0xFFFFD700);

    final timetableAsync = ref.watch(timetableProvider);

    return Scaffold(
      backgroundColor: scaffoldBg,
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
                  color: Theme.of(context).cardColor,
                  onSelected: (value) {
                    if (value == 'sync') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PortalImportScreen()))
                          .then((_) => ref.refresh(timetableProvider));
                    } else if (value == 'refresh') {
                      ref.read(timetableProvider.notifier).refresh();
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(value: 'sync', child: Row(children: [Icon(Icons.sync, size: 18), SizedBox(width: 8), Text("Sync Portal")])),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'refresh', child: Row(children: [Icon(Icons.refresh, size: 18), SizedBox(width: 8), Text("Refresh")])),
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
                  labelColor: const Color(0xFF003366),
                  unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  tabs: _days.map((d) => Tab(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(d), // Display strict 'MON' etc.
                    ),
                  )).toList(),
                ),
                scaffoldBg,
              ),
              pinned: true,
            ),
          ];
        },
        body: timetableAsync.when(
          loading: () => const TimetableSkeleton(),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (allData) {
            // Filter only classes
            final classes = allData.where((item) => item.isClass).toList();
            
            return TabBarView(
              controller: _tabController,
              children: _days.map((dayShort) => _buildDayTimeline(dayShort, classes)).toList(),
            );
          }
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      svgPath: 'assets/svgs/no_data.svg',
      title: "No Classes Yet",
      message: "Sync your portal or add classes manually to get started.",
      actionLabel: "Sync Now",
      onActionPressed: () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => const PortalImportScreen())
        ).then((_) => ref.refresh(timetableProvider));
      },
    );
  }

  Widget _buildDayTimeline(String dayShort, List<TimetableModel> allClasses) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.labelSmall?.color;

    if (allClasses.isEmpty) return _buildEmptyState();

    // Map 'MON' to 'Monday' for filtering
    // Helper map
    final map = {
      'MON': 'Monday', 'TUE': 'Tuesday', 'WED': 'Wednesday', 
      'THU': 'Thursday', 'FRI': 'Friday', 'SAT': 'Saturday', 'SUN': 'Sunday'
    };
    final dayFull = map[dayShort] ?? dayShort;

    // Filter classes for this day
    final dayClasses = allClasses.where((c) => c.dayOfWeek == dayFull).toList();
    dayClasses.sort((a, b) => a.startTime.compareTo(b.startTime)); 

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
              SizedBox(
                width: 50,
                child: Column(
                  children: [
                    Text(
                      c.startTime, 
                      style: TextStyle(fontWeight: FontWeight.bold, color: isLive ? _liveGreen : textColor)
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.endTime, 
                      style: TextStyle(fontSize: 12, color: subTextColor)
                    ),
                  ],
                ),
              ),

              Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isLive ? _liveGreen : (isDark ? Colors.grey[700] : Colors.white),
                      border: Border.all(color: isLive ? _liveGreen : (isDark ? Colors.grey[600]! : Colors.grey[300]!), width: 2),
                      shape: BoxShape.circle,
                      boxShadow: isLive ? [BoxShadow(color: _liveGreen.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)] : null
                    ),
                  ),
                  if (!isLast) 
                    Expanded(child: Container(width: 2, color: isDark ? Colors.grey[800] : Colors.grey[200])),
                ],
              ),

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

  Widget _buildClassCard(TimetableModel c, bool isLive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.labelSmall?.color;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
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
            onLongPress: () {
               // Deletion not yet implemented in provider for read-only timetable
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          c.code ?? c.title.substring(0, 3).toUpperCase(), 
                          style: TextStyle(
                            color: isLive ? Colors.white : Theme.of(context).primaryColor,
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
                  
                  Text(
                    "Class at ${c.venue ?? 'N/A'}",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: subTextColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          (c.lecturer == null || c.lecturer == "Unknown") ? "Lecturer N/A" : c.lecturer!,
                          style: TextStyle(color: subTextColor, fontSize: 13),
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
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, this._bgColor);
  final TabBar _tabBar;
  final Color _bgColor;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: _bgColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return _bgColor != oldDelegate._bgColor;
  }
}