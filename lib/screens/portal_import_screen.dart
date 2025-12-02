import 'dart:convert';
import 'package:dita_app/services/notification.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PortalImportScreen extends StatefulWidget {
  const PortalImportScreen({super.key});

  @override
  State<PortalImportScreen> createState() => _PortalImportScreenState();
}

class _PortalImportScreenState extends State<PortalImportScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  final Color _primaryDark = const Color(0xFF003366);

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse('https://student.daystar.ac.ke/')); // Portal URL
  }

// REPLACE THE ENTIRE _extractTimetable FUNCTION WITH THIS:

Future<void> _extractTimetable() async {
  setState(() => _isLoading = true);

  try {
    // UPDATED SCRIPT: Scans specifically for the "My Timetable" section
    const String extractionScript = """
    (function() {
        var tables = document.getElementsByTagName('table');
        for (var i = 0; i < tables.length; i++) {
            var tableText = tables[i].innerText || tables[i].textContent;
            
            // Confirm this table has the headers we expect
            if (tableText.indexOf('Unit') > -1 && tableText.indexOf('Lecture Room') > -1) {
                
                var extractedData = [];
                var rows = tables[i].querySelectorAll('tr');
                var collecting = false; // FLAG: Are we inside 'My Timetable' yet?

                for (var j = 0; j < rows.length; j++) {
                    var rowText = rows[j].innerText || rows[j].textContent;

                    // 1. START TRIGGER
                    if (rowText.trim() === "My Timetable") {
                        collecting = true;
                        continue; // Skip this header row
                    }

                    // 2. STOP TRIGGER
                    if (rowText.indexOf("Courses in Timetable") > -1) {
                        break; // STOP immediately if we reach the next section
                    }

                    // 3. COLLECT DATA
                    if (collecting) {
                        var cells = rows[j].querySelectorAll('td');
                        // Ensure it's a valid data row (not a sub-header or empty)
                        if (cells.length >= 6) {
                             extractedData.push({
                                "code": cells[0].innerText.trim(),
                                "day": cells[2].innerText.trim(),
                                "time": cells[3].innerText.trim(),
                                "venue": cells[5].innerText.trim(),
                                "lecturer": cells.length > 6 ? cells[6].innerText.trim() : "Unknown"
                            });
                        }
                    }
                }
                
                // If we found data, return it. If not, maybe we didn't hit the flags.
                if (extractedData.length > 0) return JSON.stringify(extractedData);
            }
        }
        return "NOT_FOUND";
    })();
    """;

    // 1. Run the script
    final result = await _controller.runJavaScriptReturningResult(extractionScript);
    
    // 2. Clean Result
    String jsonString = result.toString();
    if (jsonString.startsWith('"') && jsonString.endsWith('"')) {
      jsonString = jsonString.substring(1, jsonString.length - 1);
      jsonString = jsonString.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
    }

    if (jsonString == "NOT_FOUND") {
      _showError("Table structure not recognized. Please wait for the page to fully load.");
      return;
    }

    // 3. Decode
    List<dynamic> rawData = [];
    try {
      rawData = json.decode(jsonString);
    } catch (e) {
      rawData = [];
    }

    if (rawData.isEmpty) {
      _showError("Found 'My Timetable', but it looks empty.");
      return;
    }

    // 4. Process Data (Same logic as before)
    List<Map<String, dynamic>> finalClasses = [];

    for (var item in rawData) {
      String code = item['code'];
      String dayRaw = item['day'];
      String timeRange = item['time'];
      String venue = item['venue'];
      String lecturer = item['lecturer'];

      if (code.isEmpty || code.length < 3) continue;

      // Clean Day
      String day = "MON";
      String d = dayRaw.toUpperCase();
      if (d.contains("MON")) day = "MON";
      else if (d.contains("TUE")) day = "TUE";
      else if (d.contains("WED")) day = "WED";
      else if (d.contains("THU")) day = "THU";
      else if (d.contains("FRI")) day = "FRI";
      else if (d.contains("SAT")) day = "SAT";

      // Clean Time
      String startTime = "08:00";
      String endTime = "10:00";
      if (timeRange.contains("-")) {
        var parts = timeRange.split("-");
        startTime = _convertTo24Hour(parts[0]);
        endTime = _convertTo24Hour(parts[1]);
      }

      finalClasses.add({
        "code": code,
        "title": "Class: $code",
        "venue": venue,
        "lecturer": lecturer,
        "day": day,
        "startTime": startTime,
        "endTime": endTime,
        "id": (code + day).hashCode
      });
    }

    if (finalClasses.isNotEmpty) {
      await _saveClasses(finalClasses);
    } else {
      _showError("No valid classes found in 'My Timetable'.");
    }

  } catch (e) {
    print("JS Extract Error: $e");
    _showError("Extraction failed: ${e.toString()}");
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

// Helper to convert "02:05 PM" -> "14:05"
  String _convertTo24Hour(String timeStr) {
    try {
      // 1. Clean the string (remove dots, extra spaces)
      timeStr = timeStr.toUpperCase().replaceAll(".", "").trim(); 
      
      bool isPM = timeStr.contains("PM");
      bool isAM = timeStr.contains("AM");
      
      // 2. Remove AM/PM text to get just the numbers "02:05"
      String cleanTime = timeStr.replaceAll("AM", "").replaceAll("PM", "").trim();
      List<String> parts = cleanTime.split(":");
      
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;

      // 3. Adjust for 24-hour format
      if (isPM && hour != 12) hour += 12; // e.g. 2 PM -> 14
      if (isAM && hour == 12) hour = 0;   // e.g. 12 AM -> 00

      // 4. Return formatted string
      return "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
    } catch (e) {
      print("Time convert error: $e");
      return "08:00"; // Fallback if parsing fails
    }
  }

Future<void> _saveClasses(List<Map<String, dynamic>> newClasses) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Merge with existing (optional, or overwrite)
    List<dynamic> existing = [];
    if (prefs.containsKey('my_classes')) {
       existing = json.decode(prefs.getString('my_classes')!);
    }
    
    for(var cls in newClasses) {
       // Remove duplicates based on code
       existing.removeWhere((e) => e['code'] == cls['code']);
       existing.add(cls);

       // 2. SCHEDULE WEEKLY NOTIFICATION
       // Map day string (MON) to int (1=Mon, ... 7=Sun)
       int dayIndex = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"].indexOf(cls['day']) + 1;
       
       // Parse "08:00" or "11:05 AM" to TimeOfDay
       // Your scraper output format is likely "11:05 AM" based on the code logic
       // We need to handle AM/PM parsing carefully or stripping it
       
       TimeOfDay t;
       try {
         // Standardize "08:00 AM" -> "08:00" for parsing if needed, 
         // or use a simple split if it's already 24h format from your previous logic.
         // Let's assume your scraper logic cleaned it to "11:05" or handled it.
         // If it has AM/PM, simple split won't work perfectly without offset.
         // Better approach: Use a DateFormat if available, or simple heuristic:
         
         var parts = cls['startTime'].split(":");
         int hour = int.parse(parts[0]);
         int minute = int.parse(parts[1].split(" ")[0]); // Handle "05 AM" part if present
         
         if (cls['startTime'].contains("PM") && hour != 12) hour += 12;
         if (cls['startTime'].contains("AM") && hour == 12) hour = 0;

         t = TimeOfDay(hour: hour, minute: minute);
         
         await NotificationService.scheduleClassNotification(
            id: cls['id'], // This is the hashCode we generated
            title: cls['code'],
            venue: cls['venue'],
            dayOfWeek: dayIndex,
            startTime: t,
         );
       } catch (e) {
         print("Time parsing error for ${cls['code']}: $e");
       }
    }

    await prefs.setString('my_classes', json.encode(existing));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Success! Imported ${newClasses.length} classes."), backgroundColor: Colors.green)
      );
      Navigator.pop(context); 
    }
  }

  void _showError(String msg) {
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login & Sync", style: TextStyle(color: Colors.white)),
        backgroundColor: _primaryDark,
        actions: [
          TextButton.icon(
            onPressed: _extractTimetable,
            icon: const Icon(Icons.download, color: Colors.white),
            label: const Text("EXTRACT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}