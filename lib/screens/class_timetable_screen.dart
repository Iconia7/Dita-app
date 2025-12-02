import 'dart:convert';
import 'package:dita_app/services/notification.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'manual_class_entry_screen.dart';
import 'portal_import_screen.dart';

class ClassTimetableScreen extends StatefulWidget {
  const ClassTimetableScreen({super.key});

  @override
  State<ClassTimetableScreen> createState() => _ClassTimetableScreenState();
}

class _ClassTimetableScreenState extends State<ClassTimetableScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Theme Colors
  final Color _primaryDark = const Color(0xFF003366);
  final Color _accentGold = const Color(0xFFFFD700);
  final Color _bgOffWhite = const Color(0xFFF4F6F9);

  final List<String> _days = ['MON', 'TUE', 'WED', 'THU', 'FRI'];
  List<dynamic> _classes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('my_classes');
    if (data != null && mounted) {
      setState(() {
        _classes = json.decode(data);
      });
    } else {
      setState(() {
        _classes = [];
      });
    }
  }

  // Helper to wipe data if user wants a fresh start
Future<void> _clearAllClasses() async {
  // Loop through all current classes and cancel their specific alarms
  for (var c in _classes) {
    if (c['id'] != null) {
      await NotificationService.cancelNotification(c['id']);
    }
  }

  // Now clear the data
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('my_classes');
  
  _loadClasses(); // Refresh UI
  
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Timetable cleared Successfully.")),
    );
  }
}

// 2. Updated Single Delete Method
Future<void> _deleteSingleClass(int id) async {
  // Cancel the alarm for this specific ID
  await NotificationService.cancelNotification(id);

  // Remove from the list and save
  final prefs = await SharedPreferences.getInstance();
  List<dynamic> currentList = json.decode(prefs.getString('my_classes') ?? '[]');
  
  currentList.removeWhere((item) => item['id'] == id);
  
  await prefs.setString('my_classes', json.encode(currentList));
  _loadClasses(); // Refresh UI

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Class deleted and alarm cancelled.")),
    );
  }
}

  void _navigateToManual() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualClassEntryScreen()))
        .then((_) => _loadClasses());
  }

  void _navigateToSync() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PortalImportScreen()))
        .then((_) => _loadClasses());
  }

  @override
  Widget build(BuildContext context) {
    // 1. EMPTY STATE: Show Large Option Cards
    if (_classes.isEmpty) {
      return Scaffold(
        backgroundColor: _bgOffWhite,
        appBar: AppBar(
          title: const Text("My Classes", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), 
          backgroundColor: _primaryDark,
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school_rounded, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 20),
              const Text("No classes added yet.", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Choose how you want to set up your timetable:", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              
              // OPTION 1: AUTOMATIC
              _buildOptionCard(
                icon: Icons.auto_mode,
                title: "Portal Sync",
                subtitle: "Login & extract automatically.",
                color: Colors.green,
                onTap: _navigateToSync,
              ),
              
              const SizedBox(height: 20),

              // OPTION 2: MANUAL
              _buildOptionCard(
                icon: Icons.edit_note,
                title: "Manual Entry",
                subtitle: "Type units yourself.",
                color: _primaryDark,
                onTap: _navigateToManual,
              ),
            ],
          ),
        ),
      );
    }

    // 2. FILLED STATE: Show Timetable with Menu Action
    return Scaffold(
      backgroundColor: _bgOffWhite,
      appBar: AppBar(
        title: const Text("Class Timetable", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: _primaryDark,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accentGold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: _days.map((d) => Tab(text: d)).toList(),
        ),
        actions: [
          // POPUP MENU REPLACES THE SINGLE ADD BUTTON
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'manual') {
                _navigateToManual();
              } else if (value == 'sync') {
                _navigateToSync();
              } else if (value == 'clear') {
                _confirmClear();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'manual',
                child: Row(children: [Icon(Icons.edit, color: Colors.black54), SizedBox(width: 10), Text("Add Manually")]),
              ),
              const PopupMenuItem(
                value: 'sync',
                child: Row(children: [Icon(Icons.sync, color: Colors.green), SizedBox(width: 10), Text("Sync from Portal")]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear',
                child: Row(children: [Icon(Icons.delete_forever, color: Colors.red), SizedBox(width: 10), Text("Clear Timetable")]),
              ),
            ],
          )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: _days.map((day) => _buildDayList(day)).toList(),
      ),
    );
  }

  // Helper dialog to prevent accidental deletion
  void _confirmClear() {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Clear Timetable?"),
        content: const Text("This will remove all classes. You can re-sync or add them manually again."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearAllClasses();
            }, 
            child: const Text("Clear All", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );
  }

  Widget _buildOptionCard({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28)),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 5), Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12))])),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildDayList(String day) {
    final dayClasses = _classes.where((c) => c['day'] == day).toList();
    dayClasses.sort((a, b) => a['startTime'].compareTo(b['startTime'])); 

    if (dayClasses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 50, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text("No classes on $day", style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: dayClasses.length,
      itemBuilder: (context, index) {
        final c = dayClasses[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border(left: BorderSide(color: _primaryDark, width: 4))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(c['code'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  // Optional: Add a small delete button for specific items
                  InkWell(
                    onTap: () => _deleteSingleClass(c['id']),
                    child: const Icon(Icons.close, size: 18, color: Colors.grey),
                  )
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                   Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                   const SizedBox(width: 5),
                   Text("${c['startTime']} - ${c['endTime']}", style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                   Icon(Icons.location_on, size: 14, color: _accentGold),
                   const SizedBox(width: 5),
                   Text(c['venue'], style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

}