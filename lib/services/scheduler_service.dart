import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:dita_app/data/models/timetable_model.dart';
import 'package:dita_app/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'notification.dart';

class SchedulerService {
  SchedulerService._();

  /// Schedules notifications for a list of timetable items
  static Future<void> scheduleTimetableNotifications(List<TimetableModel> items) async {
    // Cancel existing to avoid duplicates when resyncing entire timetable
    await AwesomeNotifications().cancelAllSchedules();
    
    AppLogger.info("Scheduling ${items.length} items via NotificationService...");

    int count = 0;
    for (final item in items) {
      if (item.isClass) {
        final start = _parseTime(item.startTime);
        if (start != null) {
          await NotificationService.scheduleClassNotification(
            id: item.id,
            title: item.code ?? item.title,
            venue: item.venue ?? "Local",
            dayOfWeek: item.dayNumber + 1, // 1=Mon, 7=Sun
            startTime: start,
          );
          count++;
        }
      } else if (item.isExam) {
        if (item.examDate != null) {
          await NotificationService.scheduleTaskNotification(
            id: item.id,
            title: "EXAM: ${item.code ?? item.title}",
            deadline: item.examDate!,
            venue: item.venue,
          );
          count++;
        }
      }
    }
    
    AppLogger.success("Processed $count reminders via NotificationService.");
  }

  static TimeOfDay? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return null;
    }
  }
}
