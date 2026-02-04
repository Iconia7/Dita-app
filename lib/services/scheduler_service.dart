import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:dita_app/data/models/timetable_model.dart';
import 'package:dita_app/utils/app_logger.dart';
import 'package:flutter/material.dart';

class SchedulerService {
  SchedulerService._();

  static const int _reminderMinutesBefore = 15;

  /// Schedules notifications for a list of timetable items
  static Future<void> scheduleTimetableNotifications(List<TimetableModel> items) async {
    // 1. Cancel existing schedule to avoid duplicates
    await AwesomeNotifications().cancelAllSchedules();
    AppLogger.info("Cleared previous schedules. Scheduling ${items.length} items...");

    int count = 0;
    for (final item in items) {
      if (item.isClass) {
        bool success = await _scheduleClass(item);
        if (success) count++;
      } else if (item.isExam) {
        bool success = await _scheduleExam(item);
        if (success) count++;
      }
    }
    
    AppLogger.success("Scheduled $count reminders for upcoming classes/exams.");
  }

  static Future<bool> _scheduleClass(TimetableModel item) async {
    try {
      final TimeOfDay? start = _parseTime(item.startTime);
      if (start == null) return false;

      // Calculate reminder time (15 mins before)
      int totalMinutes = start.hour * 60 + start.minute;
      int reminderMinutes = totalMinutes - _reminderMinutesBefore;
      
      if (reminderMinutes < 0) return false; // Should not happen for valid day classes

      int triggerHour = (reminderMinutes ~/ 60) % 24;
      int triggerMinute = reminderMinutes % 60;

      // Class reminders are weekly
      return await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: item.id.hashCode, // Unique ID based on item ID
          channelKey: 'dita_planner_channel_v4',
          title: 'Class Reminder: ${item.code ?? item.title}',
          body: 'Your class starts in $_reminderMinutesBefore minutes at ${item.venue ?? "Local"}',
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Reminder,
          wakeUpScreen: true,
        ),
        schedule: NotificationCalendar(
          weekday: item.dayNumber + 1, // dayNumber is 0-indexed (Mon=0), NotificationCalendar is 1-indexed (Mon=1)
          hour: triggerHour,
          minute: triggerMinute,
          allowWhileIdle: true,
          repeats: true,
        ),
      );
    } catch (e) {
      AppLogger.error("Failed to schedule class: ${item.title}", error: e);
      return false;
    }
  }

  static Future<bool> _scheduleExam(TimetableModel item) async {
    if (item.examDate == null) return false;

    // Exam reminders are one-time
    final triggerDate = item.examDate!.subtract(const Duration(hours: 1)); // 1 hour before

    if (triggerDate.isBefore(DateTime.now())) return false; // Don't schedule past exams

    return await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: item.id.hashCode,
        channelKey: 'dita_planner_channel_v4',
        title: 'Exam Alert: ${item.code ?? item.title}',
        body: 'Upcoming exam at ${item.venue ?? "Venue TBD"}. Good luck!',
        notificationLayout: NotificationLayout.BigText,
        category: NotificationCategory.Reminder,
        wakeUpScreen: true,
        backgroundColor: Colors.redAccent,
      ),
      schedule: NotificationCalendar.fromDate(date: triggerDate),
    );
  }

  static TimeOfDay? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return null;
    }
  }

  // Handle minute subtraction logic (e.g. 8:00 - 15m = 7:45)
  // Note: NotificationCalendar handles hour/minute rollover automatically if we pass valid Int, 
  // but let's be safe. Actually, AwesomeNotifications just takes hour/minute INTs.
  // Wait, no. NotificationCalendar takes separate fields.
  // If minute is negative, it does NOT automatically roll back hour in the simplified constructor.
  // We need to calculate the actual trigger time.
  static int _subtractMinutes(int minute, int sub) {
    // This simple helper is insufficient for the hour-rollover logic required for NotificationCalendar
    // BETTER APPROACH: Calculate specific trigger DateTime or just let the calendar handle it?
    // NotificationCalendar(hour: ..., minute: ...) expects valid 0-59.
    return minute; 
  }
}
