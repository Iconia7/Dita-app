import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/notification.dart';

class ExamTimetableScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ExamTimetableScreen({super.key, required this.user});

  @override
  State<ExamTimetableScreen> createState() => _ExamTimetableScreenState();
}

class _ExamTimetableScreenState extends State<ExamTimetableScreen> {
  final Color _primaryDark = const Color(0xFF003366);
  final Color _accentGold = const Color(0xFFFFD700);
  
  final TextEditingController _codeController = TextEditingController();
  
  // We store 2 things:
  // 1. The list of codes the user entered (e.g., ["ACS401", "INS411"])
  List<String> _myCodes = [];
  
  // 2. The actual exam data fetched from server
  List<dynamic> _myExams = [];
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  // --- DATA LOGIC ---

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _myCodes = prefs.getStringList('my_course_codes') ?? [];
      
      String? cachedExams = prefs.getString('cached_exams');
      if (cachedExams != null) {
        _myExams = json.decode(cachedExams);
      }
    });
    
    if (_myCodes.isNotEmpty) {
      _fetchExamsFromBackend();
    }
  }

Future<void> _addCourseCode(String code) async {
    if (code.isEmpty) return;
    
    // FIX: Convert to Uppercase immediately
    // This handles "acs401" -> "ACS401" automatically
    String cleanCode = code.trim().toUpperCase();

    // Remove any accidental spaces inside the code (e.g. "ACS 401" -> "ACS401")
    // Optional but good for user error
    cleanCode = cleanCode.replaceAll(' ', '');
    
    if (!_myCodes.contains(cleanCode)) {
      setState(() {
        _myCodes.add(cleanCode);
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('my_course_codes', _myCodes);
      
      _fetchExamsFromBackend(); // Refresh list
    }
    _codeController.clear();
  }
  
Future<void> _removeCourseCode(String code) async {
    // 1. CANCEL THE NOTIFICATION FIRST
    // We use the same ID logic we used to schedule it: code.hashCode
    await NotificationService.cancelNotification(code.hashCode);
    print("🚫 Cancelled alarm for $code");

    // 2. Remove from UI and Storage (Existing Logic)
    setState(() {
      _myCodes.remove(code);
      _myExams.removeWhere((e) => e['course_code'] == code);
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('my_course_codes', _myCodes);
    prefs.setString('cached_exams', json.encode(_myExams));
  }

  Future<void> _fetchExamsFromBackend() async {
    setState(() => _isLoading = true);
    
    try {
      // Convert list to comma-separated string: "ACS401,INS411"
      String queryCodes = _myCodes.join(',');
      
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/exams/?codes=$queryCodes'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> fetchedExams = json.decode(response.body);
        
        setState(() {
          _myExams = fetchedExams;
          _isLoading = false;
        });

        // Save for offline
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_exams', response.body);

        // --- AUTO SCHEDULE ALARMS ---
        _scheduleExamReminders(fetchedExams);
      }
    } catch (e) {
      print("Error fetching exams: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not sync timetable. Showing cached.")));
      }
    }
  }

void _scheduleExamReminders(List<dynamic> exams) {
    for (var exam in exams) {
      // 1. Get the date string from server (e.g. "2025-12-01T02:53:00Z")
      String rawDate = exam['date'];

      // 2. FIX: Remove the 'Z' so Dart treats it as LOCAL time (not UTC)
      if (rawDate.endsWith('Z')) {
        rawDate = rawDate.substring(0, rawDate.length - 1);
      }
      
      // 3. Parse it. Now "02:53" means "02:53 Local Time"
      DateTime examDate = DateTime.parse(rawDate); 
      
      int notifId = exam['course_code'].hashCode; 
      
      _scheduleSpecificExamAlarm(notifId, exam['course_code'], exam['venue'], examDate);
    }
  }

  // Helper to schedule (You can move this to NotificationService later)
// Helper to schedule
  Future<void> _scheduleSpecificExamAlarm(int id, String code, String venue, DateTime examTime) async {
      // Logic: 30 mins before
      DateTime reminderTime = examTime.subtract(const Duration(minutes: 30));
      bool isShortNotice = false;
      
      // Safety: If exam is VERY soon (e.g. starts in 10 mins), ring in 5 seconds
      if (reminderTime.isBefore(DateTime.now())) {
          // Only if the exam hasn't actually STARTED yet
          if (examTime.isAfter(DateTime.now())) {
             reminderTime = DateTime.now().add(const Duration(seconds: 5));
             isShortNotice = true;
          } else {
             return; // Exam already started/finished, don't alarm
          }
      }

      await NotificationService.scheduleTaskNotification(
         id: id,
         title: "Exam: $code",
         deadline: examTime, 
         venue: venue,// The service calculates -15, but here we want -30 logic?
         // ACTUALLY: Your NotificationService is hardcoded to -15 mins.
         // Ideally, you should update NotificationService to accept 'exactTime' 
         // OR just rely on the service's 15-min logic.
      );
      
      // NOTE: Since your NotificationService has hardcoded logic inside it (deadline - 15),
      // passing 'examTime' as 'deadline' will ring 15 mins before the exam.
      // If you strictly want 30 mins, you need to update NotificationService to accept a 'scheduledTime' directly.
      
      print("📅 Exam Alarm set for $code");
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Exam Timetable", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
           IconButton(
             icon: const Icon(Icons.refresh),
             onPressed: _fetchExamsFromBackend,
           )
        ],
      ),
      body: Column(
        children: [
          // 1. INPUT AREA
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Manage Your Units", style: TextStyle(fontWeight: FontWeight.bold, color: _primaryDark, fontSize: 16)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          hintText: "Enter Code (e.g. ACS401)",
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF5F7FA),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.all(14)
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _addCourseCode(_codeController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentGold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16)
                      ),
                      child: const Text("Add"),
                    )
                  ],
                ),
                const SizedBox(height: 15),
                // Chips for added codes
                Wrap(
                  spacing: 8,
                  children: _myCodes.map((code) => Chip(
                    label: Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    backgroundColor: _primaryDark.withOpacity(0.1),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _removeCourseCode(code),
                  )).toList(),
                ),
              ],
            ),
          ),

          // 2. TIMETABLE LIST
          Expanded(
            child: _isLoading
              ? Center(child: CircularProgressIndicator(color: _primaryDark))
              : _myExams.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        Text(
                          _myCodes.isEmpty ? "Add unit codes to see exams" : "No exams found for these codes yet.",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _myExams.length,
                    itemBuilder: (context, index) {
                      final exam = _myExams[index];
                      final DateTime date = DateTime.parse(exam['date']);
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border(left: BorderSide(color: _primaryDark, width: 5)), // Left Accent
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 3))],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(exam['course_code'], style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _primaryDark)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 14, color: Colors.orange),
                                        const SizedBox(width: 5),
                                        Text(exam['venue'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 12)),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(exam['title'], style: const TextStyle(fontSize: 14, color: Colors.black87)),
                              const Divider(height: 20),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(DateFormat('EEEE, d MMM').format(date), style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 20),
                                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(DateFormat('h:mm a').format(date), style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}