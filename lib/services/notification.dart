import 'dart:ui'; 
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationService {
  // 1. Firebase Instance
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // --- INITIALIZATION ---
  static Future<void> initialize() async {
    // A. Initialize Awesome Notifications
    // We use 'resource://drawable/ic_notification' if you have a custom white icon.
    // If not, use null to default to the app icon.
    await AwesomeNotifications().initialize(
      'resource://drawable/ic_notification', 
      [
        NotificationChannel(
          channelKey: 'dita_planner_channel_v3', // New channel to be safe
          channelName: 'Student Planner',
          channelDescription: 'Reminders for upcoming tasks',
          defaultColor: const Color(0xFF003366), // DITA Blue
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        )
      ],
      // Debug: true allows you to see logs in the console automatically
      debug: true, 
    );

    // B. Initialize Firebase (Keep existing logic)
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // --- HELPER: REQUEST PERMISSIONS ---
  static Future<void> requestLocalPermissions() async {
    // Awesome Notifications handles the "Android 13+" check internally
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      // This opens a nice dialog asking the user
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  // --- FEATURE: SCHEDULE TASK REMINDER ---
// --- FEATURE: SCHEDULE TASK REMINDER ---
static Future<void> scheduleTaskNotification({
    required int id,
    required String title,
    required DateTime deadline,
    String? venue, // <--- NEW PARAMETER
  }) async {
    
    // 1. Determine Type
    bool isExam = title.toLowerCase().contains("exam");
    
    DateTime reminderTime;
    
    // 2. Calculate Reminder Time
    if (isExam) {
        // STRATEGY: "Evening Before" -> 8:00 PM (20:00) the previous day
        DateTime dayBefore = deadline.subtract(const Duration(days: 1));
        reminderTime = DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 19, 0);
    } else {
        // STRATEGY: "Urgency" -> 15 minutes before the task
        reminderTime = deadline.subtract(const Duration(minutes: 15));
    }

    bool isShortNotice = false;

    // 3. Safety Check: If the calculated time has passed, ring in 5 seconds
    // (e.g. You added the exam on the morning of the paper, so you missed the 8 PM reminder)
    if (reminderTime.isBefore(DateTime.now())) {
       reminderTime = DateTime.now().add(const Duration(seconds: 5));
       isShortNotice = true;
    }

    // 4. Tailor the Message
    String bodyText;
    String timeString = DateFormat('h:mm a').format(deadline); // e.g. "8:30 AM"

    if (isExam) {
        if (isShortNotice) {
            bodyText = "⚠️ URGENT: Exam '$title' is at $timeString! Venue: ${venue ?? 'Run to the Exam Room'}.";
        } else {
            // The "Evening Before" Message
            bodyText = "📅 Tomorrow you have: $title at $timeString.\n📍 Venue: ${venue ?? 'TBA'}.\nSuccess in your paper!";
        }
    } else {
        // Standard Task
        if (isShortNotice) {
            bodyText = "⏰ Task Due: '$title' is due right now!";
        } else {
            bodyText = "📝 Reminder: '$title' is due at $timeString.";
        }
    }

    print("\n🔔 --- SCHEDULING ALARM ---");
    print("📌 Type: ${isExam ? 'EXAM (Night Before)' : 'TASK (15m Before)'}");
    print("📝 Title: '$title'");
    print("💬 Body: '$bodyText'");
    print("⏰ Ring Time: $reminderTime");
    print("-----------------------------------\n");

    // 5. Schedule it
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'dita_planner_channel_v3', 
        title: isExam ? 'Exam Alert 🚨' : 'Task Reminder 📌', 
        body: bodyText, 
        notificationLayout: isExam ? NotificationLayout.BigText : NotificationLayout.Default, // Exams get more space
        wakeUpScreen: true, 
        category: isExam ? NotificationCategory.Alarm : NotificationCategory.Reminder,
        fullScreenIntent: isExam, 
      ),
      schedule: NotificationCalendar.fromDate(
        date: reminderTime,
        allowWhileIdle: true, 
        preciseAlarm: true,   
      ),
    );
  }


  // --- FEATURE: SCHEDULE WEEKLY CLASS REMINDER ---
// --- FEATURE: SCHEDULE WEEKLY CLASS REMINDER ---
  static Future<void> scheduleClassNotification({
    required int id,
    required String title,
    required String venue,
    required int dayOfWeek,
    required TimeOfDay startTime,
  }) async {
    
    // Logic: Remind at 7:00 PM (19:00) the PREVIOUS Evening
    int reminderDay = dayOfWeek - 1;
    if (reminderDay == 0) reminderDay = 7;

    // FIX: Format time manually to avoid 'context' error
    final String formattedTime = 
        "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}";

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'dita_planner_channel_v3',
        title: '📅 Tomorrow: $title',
        body: 'Don\'t forget! Class at $formattedTime in $venue.',
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Reminder,
      ),
      schedule: NotificationCalendar(
        weekday: reminderDay,
        hour: 19, // 7 PM
        minute: 0,
        second: 0,
        repeats: true, // Repeats every week
        allowWhileIdle: true,
        preciseAlarm: true,
      ),
    );
    print("⏰ Class Alarm set for Day $reminderDay at 19:00");
  }

  // --- FEATURE: CANCEL REMINDER ---
  static Future<void> cancelNotification(int id) async {
    await AwesomeNotifications().cancel(id);
    print("🚫 Awesome Notification cancelled for ID: $id");
  }
}