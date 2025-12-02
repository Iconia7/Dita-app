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
  
  // Colors
  final Color _primaryDark = const Color(0xFF003366);
  final Color _bgOffWhite = const Color(0xFFF4F6F9);

  String _selectedDay = "MON";
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);

  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate()) return;

    // 1. Format Data (Same format as Portal Scraper)
    // Note: We format time as "08:00" (24h) for consistency
    final String startStr = "${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}";
    final String endStr = "${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}";
    
    final newClass = {
      "code": _codeController.text.trim().toUpperCase(),
      "title": "Class: ${_codeController.text.trim().toUpperCase()}",
      "venue": _venueController.text.trim(),
      "day": _selectedDay,
      "startTime": startStr,
      "endTime": endStr,
      "lecturer": "Manual Entry", // Placeholder since we don't know
      "id": (DateTime.now().millisecondsSinceEpoch / 1000).round(),
    };

    // 2. Save to Shared Preferences
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> classes = [];
    if (prefs.containsKey('my_classes')) {
      classes = json.decode(prefs.getString('my_classes')!);
    }
    // Remove duplicates if editing same code
    classes.removeWhere((c) => c['code'] == newClass['code']);
    classes.add(newClass);
    
    await prefs.setString('my_classes', json.encode(classes));

    // 3. SCHEDULE NOTIFICATION
    // Map day string to int (MON=1 ... SUN=7)
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
        const SnackBar(content: Text("Class Added Successfully!"), backgroundColor: Colors.green)
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgOffWhite,
      appBar: AppBar(
        title: const Text("Add Class", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), 
        backgroundColor: _primaryDark,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Unit Code
            _buildLabel("Unit Code"),
            TextFormField(
              controller: _codeController,
              decoration: _buildInputDeco("e.g. ACS 401"),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 20),

            // Venue
            _buildLabel("Venue"),
            TextFormField(
              controller: _venueController,
              decoration: _buildInputDeco("e.g. DAC 201"),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 20),

            // Day Selector
            _buildLabel("Day of Week"),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDay,
                  isExpanded: true,
                  items: ["MON", "TUE", "WED", "THU", "FRI", "SAT"].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setState(() => _selectedDay = v.toString()),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Time Pickers Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Start Time"),
                      _buildTimeButton(_startTime, (t) => setState(() => _startTime = t)),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("End Time"),
                      _buildTimeButton(_endTime, (t) => setState(() => _endTime = t)),
                    ],
                  ),
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
                  backgroundColor: _primaryDark, 
                  foregroundColor: Colors.white,
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                child: const Text("Save Class", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 5),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  InputDecoration _buildInputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
    );
  }

  Widget _buildTimeButton(TimeOfDay time, Function(TimeOfDay) onPicked) {
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: time);
        if (t != null) onPicked(t);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Icon(Icons.access_time, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}