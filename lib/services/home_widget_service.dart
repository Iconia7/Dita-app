import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/timetable_model.dart';
import '../utils/app_logger.dart';
import 'package:intl/intl.dart';
import '../widgets/home_screen_widget.dart'; // New import
import 'package:flutter/material.dart';

class HomeWidgetService {
  static const String _groupId = 'group.dita_app'; // Required for iOS App Groups
  static const String _androidWidgetName = 'ScheduleWidgetProvider';
  static const String _iosWidgetName = 'ScheduleWidget';

  /// Updates the native widget with the current day's schedule
  static Future<void> updateWidget(List<TimetableModel> timetable) async {
    try {
      final now = DateTime.now();
      final todayName = DateFormat('EEEE').format(now);
      
      // Filter classes for today and sort by time
      final todayClasses = timetable
          .where((item) => item.dayOfWeek.toLowerCase() == todayName.toLowerCase())
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      // Filter for UPCOMING classes only
      final upcomingClasses = todayClasses.where((item) {
        try {
          final startParts = item.startTime.split(':');
          final startHour = int.parse(startParts[0]);
          final startMinute = int.parse(startParts[1]);
          final classTime = DateTime(now.year, now.month, now.day, startHour, startMinute);
          return classTime.isAfter(now);
        } catch (e) {
          return true; // Keep if parsing fails (fallback)
        }
      }).toList();

      final dateStr = DateFormat('EEE, d MMM').format(now);

      // Render the widget to an image
      await HomeWidget.renderFlutterWidget(
        HomeWidgetUI(
          upcomingClasses: upcomingClasses,
          dateStr: dateStr,
        ),
        key: 'widget_image',
        logicalSize: const Size(400, 400),
        pixelRatio: 2.5, // High resolution for sharp text
      );

      // Signal an update to the native widgets
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        iOSName: _iosWidgetName,
        androidName: _androidWidgetName,
      );
      
      AppLogger.success('Native widget updated with rendered image');
    } catch (e) {
      AppLogger.error('Error updating native widget', error: e);
    }
  }

  static Future<void> _sendToWidget(String key, String value) async {
    await HomeWidget.saveWidgetData(key, value);
  }

  // --- BACKGROUND UPDATE LOGIC ---
  static Future<void> backgroundFetch() async {
    try {
       // Initialize Environment for API URL if needed (or hardcode for robustness in background)
       // We can use ApiService directly if it handles its own env loading or defaults
       // but ApiService relies on dotenv. 
       // For background, let's try to load .env if not loaded or fallback to hardcoded prod URL
       
       // Note: In background isolate, dotenv might not be initialized.
       // It's safer to use the direct API call logic here purely for the widget.
       const String apiUrl = "https://api.dita.co.ke/api"; 
       
       // We need to get the user token. SharedPrefs works in background isolates on Android.
       final prefs = await SharedPreferences.getInstance();
       final userStr = prefs.getString('user_data');
       if (userStr == null) {
         print("Widget Background: No user logged in");
         return;
       }
       
       final userData = json.decode(userStr);
       final token = userData['access'];
       
       // Fetch Timetable
       final response = await http.get(
         Uri.parse('$apiUrl/timetable/'),
         headers: {
           "Content-Type": "application/json",
           "Authorization": "Bearer $token",
         }
       );
       
       if (response.statusCode == 200) {
         final List<dynamic> data = json.decode(response.body);
         final timetable = data.map((json) => TimetableModel.fromJson(json)).toList();
         await updateWidget(timetable);
         print("Widget Background: Updated successfully");
       } else {
         print("Widget Background: Failed to fetch timetable ${response.statusCode}");
       }
    } catch (e) {
      print("Widget Background Error: $e");
    }
  }
}
