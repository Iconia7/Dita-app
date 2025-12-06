import 'dart:convert';
import 'package:dita_app/widgets/dita_loader.dart';
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
  // --- MODERN THEME COLORS ---
  final Color _primaryDark = const Color(0xFF0F172A); // Midnight Blue
  final Color _primaryBlue = const Color(0xFF003366); // Daystar Blue
  final Color _accentGold = const Color(0xFFFFD700);
  final Color _bgLight = const Color(0xFFF1F5F9);     // Slate 100
  final Color _textMain = const Color(0xFF1E293B);    // Slate 800
  final Color _textSub = const Color(0xFF64748B);     // Slate 500
  final Color _urgentRed = const Color(0xFFEF4444);   // Red for "Tomorrow/Today"
  
  final TextEditingController _codeController = TextEditingController();
  List<String> _myCodes = [];
  List<dynamic> _myExams = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  // --- DATA LOGIC (UNCHANGED) ---
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    _myCodes = prefs.getStringList('my_course_codes') ?? [];
  
  // Load cached exams (The most recent successful data)
  String? cachedExams = prefs.getString('cached_exams');
    setState(() {
      _myCodes = _myCodes;
      if (cachedExams != null) {
        _myExams = json.decode(cachedExams);
      }
    });
  }

  Future<void> _addCourseCode(String code) async {
    if (code.isEmpty) return;
    String cleanCode = code.trim().toUpperCase().replaceAll(' ', '');
    if (!_myCodes.contains(cleanCode)) {
      setState(() => _myCodes.add(cleanCode));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('my_course_codes', _myCodes);
      _fetchExamsFromBackend(); 
    }
    _codeController.clear();
  }
  
  Future<void> _removeCourseCode(String code) async {
    await NotificationService.cancelNotification(code.hashCode);
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
      String queryCodes = _myCodes.join(',');
      final response = await http.get(Uri.parse('${ApiService.baseUrl}/exams/?codes=$queryCodes'));

      if (response.statusCode == 200) {
        final List<dynamic> fetchedExams = json.decode(response.body);
        
        // Sort by date
        fetchedExams.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));

        setState(() {
          _myExams = fetchedExams;
          _isLoading = false;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_exams', response.body);
        _scheduleExamReminders(fetchedExams);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not sync exams. Showing cached.")));
      }
    }
  }

  void _scheduleExamReminders(List<dynamic> exams) {
    for (var exam in exams) {
      String rawDate = exam['date'];
      if (rawDate.endsWith('Z')) rawDate = rawDate.substring(0, rawDate.length - 1);
      DateTime examDate = DateTime.parse(rawDate);
      int notifId = exam['course_code'].hashCode; 
      
      // Schedule logic (omitted for brevity, same as before)
      _scheduleSpecificExamAlarm(notifId, exam['course_code'], exam['venue'], examDate);
    }
  }

    Future<void> _scheduleSpecificExamAlarm(int id, String code, String venue, DateTime examTime) async {
      // Logic: 30 mins before
      DateTime reminderTime = examTime.subtract(const Duration(minutes: 30));
      
      // Safety: If exam is VERY soon (e.g. starts in 10 mins), ring in 5 seconds
      if (reminderTime.isBefore(DateTime.now())) {
          // Only if the exam hasn't actually STARTED yet
          if (examTime.isAfter(DateTime.now())) {
             reminderTime = DateTime.now().add(const Duration(seconds: 5));
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

  // --- HELPER: Days Remaining Logic ---
  String _getDaysRemaining(DateTime examDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDay = DateTime(examDate.year, examDate.month, examDate.day);
    final diff = examDay.difference(today).inDays;

    if (diff < 0) return "Done";
    if (diff == 0) return "Today";
    if (diff == 1) return "Tomorrow";
    return "in $diff Days";
  }

  Color _getStatusColor(String status) {
    if (status == "Today" || status == "Tomorrow") return _urgentRed;
    if (status == "Done") return Colors.grey;
    return _primaryBlue;
  }

  // --- UI ---
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
                title: const Text("Exams", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_primaryDark, _primaryBlue]),
                      ),
                    ),
                    Positioned(right: -30, top: -50, child: Container(width: 150, height: 150, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle))),
                  ],
                ),
              ),
              actions: [
                IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _fetchExamsFromBackend)
              ],
            ),
          ];
        },
        body: Column(
          children: [
            // 1. INPUT AREA (Collapsible logic handled by NestedScrollView body)
            _buildInputArea(),
            
            // 2. TIMELINE LIST
            Expanded(
              child: _isLoading 
                ? Center(child: const LogoSpinner()) 
                : _buildExamList(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Add Your Units", style: TextStyle(fontWeight: FontWeight.bold, color: _primaryDark, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    hintText: "e.g. ACS401",
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    isDense: true,
                    filled: true,
                    fillColor: _bgLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(14)
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _addCourseCode(_codeController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16)
                ),
                child: const Icon(Icons.add, size: 20),
              )
            ],
          ),
          if (_myCodes.isNotEmpty) ...[
            const SizedBox(height: 15),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _myCodes.map((code) => _buildChip(code)).toList(),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _bgLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!)
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _textMain)),
          const SizedBox(width: 5),
          InkWell(
            onTap: () => _removeCourseCode(label),
            child: Icon(Icons.close, size: 14, color: _textSub),
          )
        ],
      ),
    );
  }

  Widget _buildExamList() {
    if (_myExams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_late_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 15),
            Text(
              _myCodes.isEmpty ? "Add units above to see exams." : "No exams found for these codes.", 
              style: TextStyle(color: _textSub),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
      itemCount: _myExams.length,
      itemBuilder: (context, index) {
        final exam = _myExams[index];
        // Parse Date safely
        String rawDate = exam['date'];
        if (rawDate.endsWith('Z')) rawDate = rawDate.substring(0, rawDate.length - 1);
        final DateTime date = DateTime.parse(rawDate);
        
        final String status = _getDaysRemaining(date);
        final Color statusColor = _getStatusColor(status);
        final bool isLast = index == _myExams.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. DATE COLUMN
              SizedBox(
                width: 50,
                child: Column(
                  children: [
                    Text(DateFormat('MMM').format(date).toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textSub)),
                    Text(DateFormat('dd').format(date), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textMain)),
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
                      color: Colors.white,
                      border: Border.all(color: statusColor, width: 3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast) 
                    Expanded(child: Container(width: 2, color: Colors.grey[200])),
                ],
              ),

              // 3. EXAM CARD
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // HEADER
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _primaryBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6)
                                ),
                                child: Text(exam['course_code'], style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _primaryBlue)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6)
                                ),
                                child: Text(status, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: statusColor)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(exam['title'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textMain)),
                          const SizedBox(height: 8),
                          
                          // DETAILS
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 14, color: _textSub),
                              const SizedBox(width: 4),
                              Text(DateFormat('h:mm a').format(date), style: TextStyle(fontSize: 13, color: _textSub)),
                              const SizedBox(width: 15),
                              Icon(Icons.location_on, size: 14, color: _accentGold),
                              const SizedBox(width: 4),
                              Text(exam['venue'], style: TextStyle(fontSize: 13, color: _textSub, fontWeight: FontWeight.w500)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}