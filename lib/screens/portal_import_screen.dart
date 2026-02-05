import 'dart:async';
import 'dart:convert';
import 'package:dita_app/screens/class_timetable_screen.dart';
import 'package:dita_app/services/notification.dart'; 
import 'package:dita_app/widgets/dita_loader.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/timetable_model.dart';
import '../providers/timetable_provider.dart';

class PortalImportScreen extends ConsumerStatefulWidget {
  const PortalImportScreen({super.key});

  @override
  ConsumerState<PortalImportScreen> createState() => _PortalImportScreenState();
}

class _PortalImportScreenState extends ConsumerState<PortalImportScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasExtracted = false; 
  
  // URL CONSTANTS
  final String _targetUrl = 'https://student.daystar.ac.ke/Course/StudentTimetable';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
             // Always show loader when a page starts loading
             setState(() => _isLoading = true);
          },
          
          onPageFinished: (url) async {
            final String lowerUrl = url.toLowerCase();
            final Uri uri = Uri.parse(url);

            // LOGIC 1: WE ARE ON THE TIMETABLE PAGE
            if (lowerUrl.contains("studenttimetable")) {
                if (!_hasExtracted) {
                   // Keep loader ON while we extract
                   await Future.delayed(const Duration(seconds: 1)); // Wait for table render
                   _extractTimetable();
                } else {
                   setState(() => _isLoading = false);
                }
                return;
            }

            // LOGIC 2: WE ARE ON THE LOGIN PAGE OR HOME PAGE
            // FIX: Added check for root path ("/" or "") which is the login screen at student.daystar.ac.ke
            bool isRootPage = uri.path.isEmpty || uri.path == "/";
            
            if (lowerUrl.contains("login") || 
                lowerUrl.contains("account") || 
                isRootPage) {
                
                setState(() => _isLoading = false); // <--- HIDE LOADER HERE
                return;
            }

            // LOGIC 3: WE ARE SOMEWHERE ELSE (Likely Dashboard after successful login)
            // If we are logged in (not login page) but not on the timetable, force redirect.
            setState(() => _isLoading = true); // Show loader while redirecting
            _controller.loadRequest(Uri.parse(_targetUrl));
          },
        ),
      )
      ..loadRequest(Uri.parse(_targetUrl)); 
  }

  Future<void> _extractTimetable() async {
    // Flag to prevent double extraction
    setState(() {
      _hasExtracted = true;
    });

    try {
      // JS Injection to scrape the table
      const String extractionScript = """
      (function() {
          var extractedData = [];
          // Try specific class first
          var table = document.querySelector('table.table.table-hover');
          
          // Fallback: Search all tables for 'Unit' and 'Period' headers
          if (!table) {
              var tables = document.getElementsByTagName('table');
              for (var k = 0; k < tables.length; k++) {
                  if (tables[k].innerText.indexOf('Unit') > -1 && tables[k].innerText.indexOf('Period') > -1) {
                      table = tables[k];
                      break;
                  }
              }
          }

          if (!table) return "NOT_FOUND";

          var rows = table.querySelectorAll('tr');
          var collecting = false; 

          for (var i = 0; i < rows.length; i++) {
              var rowText = rows[i].innerText || rows[i].textContent;
              rowText = rowText.trim();

              // Start collecting after "My Timetable" header
              if (rowText === "My Timetable") {
                  collecting = true;
                  continue; 
              }

              // Stop if we hit the next section
              if (rowText.indexOf("Courses in Timetable") > -1) {
                  break; 
              }

              if (collecting) {
                  var cells = rows[i].querySelectorAll('td');
                  if (cells.length >= 7) {
                      var unit = cells[0].innerText.trim();
                      if (unit.toLowerCase() === "unit" || unit === "") continue;

                      extractedData.push({
                          "unit": unit,
                          "section": cells[1].innerText.trim(),
                          "day": cells[2].innerText.trim(),
                          "period": cells[3].innerText.trim(),
                          "campus": cells[4].innerText.trim(),
                          "room": cells[5].innerText.trim(),
                          "lecturer": cells[6].innerText.trim()
                      });
                  }
              }
          }
          
          return JSON.stringify(extractedData);
      })();
      """;

      final result = await _controller.runJavaScriptReturningResult(extractionScript);
      
      // Parse the result (WebView returns a JSON string, sometimes wrapped in quotes)
      String jsonString = result.toString();
      if (jsonString.startsWith('"') && jsonString.endsWith('"')) {
        jsonString = jsonString.substring(1, jsonString.length - 1);
        jsonString = jsonString.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
      }

      if (jsonString == "NOT_FOUND") {
        _hasExtracted = false; // Allow retry
        setState(() => _isLoading = false);
        _showError("Could not find timetable. Please navigate to the correct page.");
        return;
      }

      List<dynamic> rawData = [];
      try {
        rawData = json.decode(jsonString);
      } catch (e) {
        rawData = [];
      }

      if (rawData.isEmpty) {
        _showError("Found the table, but it looks empty.");
        setState(() => _isLoading = false);
        return;
      }

      // Process Data
      List<Map<String, dynamic>> finalClasses = [];

      for (var item in rawData) {
        String code = item['unit'];
        String dayRaw = item['day'];
        String timeRange = item['period']; 
        String venue = item['room'];
        String lecturer = item['lecturer'];

        String day = _cleanDay(dayRaw);
        
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
      }

    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Extraction failed. Please try again.");
      _hasExtracted = false;
    }
  }

  // --- HELPERS ---
  String _cleanDay(String dayRaw) {
    String d = dayRaw.toUpperCase();
    if (d.contains("MON")) return "Monday";
    if (d.contains("TUE")) return "Tuesday";
    if (d.contains("WED")) return "Wednesday";
    if (d.contains("THU")) return "Thursday";
    if (d.contains("FRI")) return "Friday";
    if (d.contains("SAT")) return "Saturday";
    if (d.contains("SUN")) return "Sunday";
    return "Monday"; 
  }

  String _convertTo24Hour(String timeStr) {
    try {
      timeStr = timeStr.toUpperCase().replaceAll(".", "").trim(); 
      bool isPM = timeStr.contains("PM");
      bool isAM = timeStr.contains("AM");
      String cleanTime = timeStr.replaceAll("AM", "").replaceAll("PM", "").trim();
      List<String> parts = cleanTime.split(":");
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      
      if (isPM && hour != 12) hour += 12;
      if (isAM && hour == 12) hour = 0;
      
      return "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "08:00";
    }
  }

  Future<void> _saveClasses(List<Map<String, dynamic>> newClassesData) async {
    List<TimetableModel> models = [];
    
    for(var data in newClassesData) {
       final model = TimetableModel(
         id: data['id'],
         type: 'class',
         title: data['title'],
         code: data['code'],
         venue: data['venue'],
         lecturer: data['lecturer'],
         dayOfWeek: data['day'],
         startTime: data['startTime'],
         endTime: data['endTime'],
       );
       models.add(model);

       // Schedule Notification
       TimeOfDay t = TimeOfDay(
         hour: int.parse(model.startTime.split(":")[0]), 
         minute: int.parse(model.startTime.split(":")[1])
       );
       
       await NotificationService.scheduleClassNotification(
         id: model.id,
         title: model.code ?? model.title,
         venue: model.venue ?? 'TBA',
         dayOfWeek: model.dayNumber + 1, // dayNumber is 0-indexed (Mon=0), scheduleClassNotification expects 1-indexed (Mon=1)
         startTime: t,
       );
    }

    final success = await ref.read(timetableProvider.notifier).saveTimetable(models);

    if (mounted) {
      if (success) {
        // Explicitly refresh the provider to load the saved data
        await ref.read(timetableProvider.notifier).loadTimetable();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Success! Imported ${models.length} classes."), backgroundColor: Colors.green)
          );
          
          // Small delay for UI feedback, then pop back
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save classes locally."), backgroundColor: Colors.red)
        );
      }
    }
  }

  void _showError(String msg) {
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 Theme Helpers
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayColor = isDark ? Colors.black.withOpacity(0.9) : Colors.white.withOpacity(0.9);
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Syncing...", style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: primaryColor,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          
          // LOADING OVERLAY (Theme Aware)
          if (_isLoading)
            Container(
              color: overlayColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const DaystarSpinner(size: 120),
                    const SizedBox(height: 20),
                    Text(
                      "Connecting to Portal...",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Please Login if requested.",
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}