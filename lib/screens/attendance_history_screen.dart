import 'package:dita_app/widgets/dita_loader.dart';
import 'package:dita_app/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final int userId;
  const AttendanceHistoryScreen({super.key, required this.userId});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<dynamic> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/events/?attended_by=${widget.userId}'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _events = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 Theme Helpers
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.labelSmall?.color;

    return Scaffold(
      backgroundColor: scaffoldBg, // 🟢 Dynamic BG
      appBar: AppBar(
        title: const Text("My Attendance Log", style: TextStyle(fontWeight: FontWeight.bold)),
        // AppBar colors are handled by AppTheme, but we can override if needed
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: DaystarSpinner(size: 120))
        : _events.isEmpty
           ? EmptyStateWidget(
              svgPath: 'assets/svgs/no_attendance.svg', // Ensure this SVG exists
              title: "No Attendance Yet",
              message: "You haven't checked in to any events. Look for the QR codes at DITA events to earn points!",
              actionLabel: "Scan Now",
              onActionPressed: () {
                 Navigator.of(context).pop(); 
              },
            )
           : ListView.builder(
               padding: const EdgeInsets.all(20),
               itemCount: _events.length,
               itemBuilder: (context, index) {
                 final event = _events[index];
                 return Container(
                   margin: const EdgeInsets.only(bottom: 15),
                   decoration: BoxDecoration(
                     color: cardColor, // 🟢 Dynamic Card Color
                     borderRadius: BorderRadius.circular(15),
                     boxShadow: [
                       BoxShadow(
                         color: Colors.black.withOpacity(0.05), 
                         blurRadius: 5
                       )
                     ]
                   ),
                   child: ListTile(
                     leading: Container(
                       padding: const EdgeInsets.all(10),
                       decoration: BoxDecoration(
                         color: Colors.green.withOpacity(0.1),
                         shape: BoxShape.circle
                       ),
                       child: const Icon(Icons.check_circle, color: Colors.green),
                     ),
                     title: Text(
                       event['title'], 
                       style: TextStyle(
                         fontWeight: FontWeight.bold,
                         color: textColor // 🟢 Dynamic Title Color
                       )
                     ),
                     subtitle: Text(
                       "Venue: ${event['venue']}",
                       style: TextStyle(color: subTextColor) // 🟢 Dynamic Subtitle Color
                     ),
                     trailing: Text(
                       "+20 pts",
                       style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[700])
                     ),
                   ),
                 );
               },
             ),
    );
  }
}