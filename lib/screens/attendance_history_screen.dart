import 'package:dita_app/widgets/dita_loader.dart';
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
  final Color _primaryDark = const Color(0xFF003366);

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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("My Attendance Log", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: LogoSpinner())
        : _events.isEmpty
           ? Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[300]),
                   const SizedBox(height: 10),
                   Text("No events attended yet.", style: TextStyle(color: Colors.grey[500])),
                   const SizedBox(height: 5),
                   const Text("Scan a QR code to get started!", style: TextStyle(fontWeight: FontWeight.bold)),
                 ],
               ),
             )
           : ListView.builder(
               padding: const EdgeInsets.all(20),
               itemCount: _events.length,
               itemBuilder: (context, index) {
                 final event = _events[index];
                 return Container(
                   margin: const EdgeInsets.only(bottom: 15),
                   decoration: BoxDecoration(
                     color: Colors.white, 
                     borderRadius: BorderRadius.circular(15),
                     boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]
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
                     title: Text(event['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                     subtitle: Text("Venue: ${event['venue']}"),
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