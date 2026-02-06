import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/timetable_model.dart';
import '../utils/app_logger.dart';
import 'package:intl/intl.dart';
import '../widgets/home_screen_widget.dart'; // New import
import 'package:flutter/material.dart';
import '../core/storage/local_storage.dart';
import '../core/storage/storage_keys.dart';

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

      final dateStr = DateFormat('EEE, d MMM').format(now);

      // Render the widget to an image (pass ALL today's classes for status detection)
      await HomeWidget.renderFlutterWidget(
        HomeWidgetUI(
          upcomingClasses: todayClasses, // Widget now handles in-session detection
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
      // Background isolates need Hive initialization
      await LocalStorage.init();
      
      // Get cached timetable data from Hive
      const String timetableCacheKey = 'cached_timetable';
      final jsonString = LocalStorage.getItem<String>(StorageKeys.timetableBox, timetableCacheKey);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        final timetable = jsonList
            .map((item) => TimetableModel.fromJson(item as Map<String, dynamic>))
            .toList();
            
        await updateWidget(timetable);
        print("Widget Background: Updated successfully from local cache");
      } else {
        print("Widget Background: No cached timetable found");
      }
    } catch (e) {
      print("Widget Background Error: $e");
    }
  }
}
