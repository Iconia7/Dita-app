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
  static Future<void> updateWidget(List<TimetableModel> timetable, {List<TimetableModel> exams = const []}) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayName = DateFormat('EEEE').format(now);
      
      // Filter classes for today and sort by time
      final todayClasses = timetable
          .where((item) => item.dayOfWeek.toLowerCase() == todayName.toLowerCase())
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      // Calculate Exam Season (from first exam day to last exam day)
      bool isExamSeason = false;
      TimetableModel? relevantExam;
      
      if (exams.isNotEmpty) {
        // Normalize dates to midnight for range comparison
        final examDates = exams
            .where((e) => e.examDate != null)
            .map((e) => DateTime(e.examDate!.year, e.examDate!.month, e.examDate!.day))
            .toList();
            
        if (examDates.isNotEmpty) {
          examDates.sort();
          final firstExamDate = examDates.first;
          final lastExamDate = examDates.last;
          
          isExamSeason = !today.isBefore(firstExamDate) && !today.isAfter(lastExamDate);
          
          // Find most relevant exam
          // 1. Check for exams today
          final todayExams = exams.where((e) {
            if (e.examDate == null) return false;
            final d = DateTime(e.examDate!.year, e.examDate!.month, e.examDate!.day);
            return d.isAtSameMomentAs(today);
          }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
          
          if (todayExams.isNotEmpty) {
            relevantExam = todayExams.first;
          } else {
            // 2. Find next upcoming exam
            final upcomingExams = exams.where((e) {
              if (e.examDate == null) return false;
              final d = DateTime(e.examDate!.year, e.examDate!.month, e.examDate!.day);
              return d.isAfter(today);
            }).toList()..sort((a, b) {
              final dateComp = a.examDate!.compareTo(b.examDate!);
              if (dateComp != 0) return dateComp;
              return a.startTime.compareTo(b.startTime);
            });
            
            if (upcomingExams.isNotEmpty) {
              relevantExam = upcomingExams.first;
            }
          }
        }
      }

      final dateStr = DateFormat('EEE, d MMM').format(now);

      // Render the widget to an image
      await HomeWidget.setAppGroupId(_groupId); // Required for iOS App Groups
      await HomeWidget.renderFlutterWidget(
        HomeWidgetUI(
          upcomingClasses: todayClasses,
          todayExams: relevantExam != null ? [relevantExam] : [],
          isExamSeason: isExamSeason,
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
      
      AppLogger.success('Native widget updated (Exam Season: $isExamSeason)');
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
      const String examsCacheKey = 'cached_exams';

      final jsonString = LocalStorage.getItem<String>(StorageKeys.timetableBox, timetableCacheKey);
      final examsJsonString = LocalStorage.getItem<String>(StorageKeys.timetableBox, examsCacheKey);
      
      List<TimetableModel> timetable = [];
      List<TimetableModel> exams = [];

      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        timetable = jsonList
            .map((item) => TimetableModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      if (examsJsonString != null) {
        final List<dynamic> examsJsonList = json.decode(examsJsonString);
        exams = examsJsonList
            .map((item) => TimetableModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
            
      await updateWidget(timetable, exams: exams);
      print("Widget Background: Updated successfully with ${timetable.length} classes and ${exams.length} exams");
    } catch (e) {
      print("Widget Background Error: $e");
    }
  }
}
