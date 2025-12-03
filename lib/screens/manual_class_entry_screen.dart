import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification.dart';

class ManualClassEntryScreen extends StatefulWidget {
  const ManualClassEntryScreen({super.key});

  @override
  State<ManualClassEntryScreen> createState() => _ManualClassEntryScreenState();
}

class _ManualClassEntryScreenState extends State<ManualClassEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _venueController = TextEditingController();
  
  // --- MODERN THEME COLORS ---
  final Color _primaryDark = const Color(0xFF0F172A); // Midnight Blue
  final Color _primaryBlue = const Color(0xFF003366); // Daystar Blue
  final Color _accentGold = const Color(0xFFFFD700);
  final Color _bgLight = const Color(0xFFF1F5F9);     // Slate 100
  final Color _textMain = const Color(0xFF1E293B);    // Slate 800
  final Color _textSub = const Color(0xFF64748B);     // Slate 500

  String _selectedDay = "MON";
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);

  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate()) return;

    // 1. Format Data
    final String startStr = "${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}";
    final String endStr = "${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}";
    
    final newClass = {
      "code": _codeController.text.trim().toUpperCase(),
      "title": "Class: ${_codeController.text.trim().toUpperCase()}",
      "venue": _venueController.text.trim(),
      "day": _selectedDay,
      "startTime": startStr,
      "endTime": endStr,
      "lecturer": "Manual Entry",
      "id": (DateTime.now().millisecondsSinceEpoch / 1000).round(),
    };

    // 2. Save to Shared Preferences
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> classes = [];
    if (prefs.containsKey('my_classes')) {
      classes = json.decode(prefs.getString('my_classes')!);
    }
    classes.removeWhere((c) => c['code'] == newClass['code']);
    classes.add(newClass);
    
    await prefs.setString('my_classes', json.encode(classes));

    // 3. Schedule Notification
    int dayIndex = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"].indexOf(_selectedDay) + 1;
    
    await NotificationService.scheduleClassNotification(
      id: newClass['id'] as int,
      title: newClass['code'] as String,
      venue: newClass['venue'] as String,
      dayOfWeek: dayIndex,
      startTime: _startTime,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Class '${newClass['code']}' added successfully!"), backgroundColor: _primaryBlue)
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: const Text("Add New Class", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), 
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryDark, _primaryBlue],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Decorative Header Background extension
            Container(
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_primaryDark, _primaryBlue]),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SECTION 1: DETAILS ---
                    _buildSectionHeader("Class Details", Icons.class_outlined),
                    const SizedBox(height: 15),
                    
                    // Unit Code Input
                    _buildInputCard(
                      child: TextFormField(
                        controller: _codeController,
                        style: TextStyle(fontWeight: FontWeight.bold, color: _textMain),
                        decoration: _buildInputDeco("Unit Code", "e.g. ACS 401", Icons.qr_code),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Venue Input
                    _buildInputCard(
                      child: TextFormField(
                        controller: _venueController,
                        style: TextStyle(fontWeight: FontWeight.bold, color: _textMain),
                        decoration: _buildInputDeco("Venue", "e.g. DAC 201", Icons.location_on_outlined),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                    ),
                    
                    const SizedBox(height: 30),

                    // --- SECTION 2: SCHEDULE ---
                    _buildSectionHeader("Schedule", Icons.access_time),
                    const SizedBox(height: 15),

                    // Day Selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDay,
                          isExpanded: true,
                          icon: Icon(Icons.keyboard_arrow_down, color: _primaryBlue),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textMain),
                          items: ["MON", "TUE", "WED", "THU", "FRI", "SAT"].map((d) => DropdownMenuItem(
                            value: d, 
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 16, color: _textSub),
                                const SizedBox(width: 10),
                                Text(d),
                              ],
                            )
                          )).toList(),
                          onChanged: (v) => setState(() => _selectedDay = v.toString()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Time Pickers Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimePickerCard("Start Time", _startTime, (t) => setState(() => _startTime = t)),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildTimePickerCard("End Time", _endTime, (t) => setState(() => _endTime = t)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _saveClass,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue, 
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor: _primaryBlue.withOpacity(0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline),
                            SizedBox(width: 10),
                            Text("Save to Timetable", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _primaryBlue),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: _textSub, fontSize: 14, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildInputCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  InputDecoration _buildInputDeco(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _textSub),
      labelStyle: TextStyle(color: _textSub),
      hintStyle: TextStyle(color: Colors.grey[300]),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    );
  }

  Widget _buildTimePickerCard(String label, TimeOfDay time, Function(TimeOfDay) onPicked) {
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: time);
        if (t != null) onPicked(t);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: _textSub, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(time.format(context), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _primaryDark)),
                Icon(Icons.access_time_filled, size: 20, color: _accentGold),
              ],
            ),
          ],
        ),
      ),
    );
  }
}