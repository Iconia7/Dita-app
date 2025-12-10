import 'dart:ui'; 
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationService {
  // 1. Firebase Instance
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  // --- NEW: GLOBAL TOGGLE STATE ---
  static bool _notificationsEnabled = true;
  static bool get isEnabled => _notificationsEnabled;

  static Future<void> toggleNotifications(bool isEnabled) async {
    _notificationsEnabled = isEnabled;
    if (!isEnabled) {
      // If turning off, cancel all pending schedules immediately
      await AwesomeNotifications().cancelAllSchedules();
      print("🚫 All scheduled notifications cancelled.");
    } else {
      print("✅ Notifications enabled.");
    }
  }

  // --- INITIALIZATION ---
  static Future<void> initialize() async {
    // A. Initialize Awesome Notifications
    await AwesomeNotifications().initialize(
      'resource://drawable/ic_notification', 
      [
        NotificationChannel(
          // CHANGED: Version 4 to force update settings on device
          channelKey: 'dita_planner_channel_v4', 
          channelName: 'Student Planner',
          channelDescription: 'Reminders for upcoming tasks',
          defaultColor: const Color(0xFF003366),
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
          // CHANGED: Defines a standard single long vibration (Wait 0ms, Vibrate 1000ms)
          vibrationPattern: highVibrationPattern, 
        ),
        // Add a separate channel for backend announcements
        NotificationChannel(
          channelKey: 'dita_announcements',
          channelName: 'DITA Announcements',
          channelDescription: 'News and updates from the backend',
          defaultColor: const Color(0xFF003366),
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          playSound: true,
        )
      ],
      debug: true, 
    );

    // B. Initialize Firebase Permissions
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // C. START LISTENING TO FIREBASE MESSAGES
    _listenToFirebaseMessages();
  }

  // --- NEW: HANDLE BACKEND MESSAGES ---
  static void _listenToFirebaseMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔥 FCM Message Received: ${message.data['title']}');
      
      if (message.data['type'] == 'announcement') {
        _showCustomFirebaseNotification(message);
      }
    });
  }

  static Future<void> _showCustomFirebaseNotification(RemoteMessage message) async {
    // Always show backend announcements even if planner reminders are off? 
    // Usually yes, but if you want to silence EVERYTHING, check _notificationsEnabled here too.
    
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: message.messageId.hashCode,
        channelKey: 'dita_announcements',
        title: message.data['title'] ?? 'DITA Update', 
        body: message.data['message_body'] ?? 'New announcement available.',
        notificationLayout: NotificationLayout.BigText, 
        bigPicture: message.data['image'], 
        color: const Color(0xFF003366),
        backgroundColor: Colors.white,
        wakeUpScreen: true,
        category: NotificationCategory.Social,
      ),
    );
  }

  // --- HELPER: REQUEST PERMISSIONS ---
  static Future<void> requestLocalPermissions() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  // --- FEATURE: SCHEDULE TASK REMINDER ---
  static Future<void> scheduleTaskNotification({
    required int id,
    required String title,
    required DateTime deadline,
    String? venue, 
  }) async {
    // 🛑 CHECK TOGGLE BEFORE SCHEDULING
    if (!_notificationsEnabled) {
      print("🔕 Notification skipped: User has disabled reminders.");
      return;
    }
    
    // 1. Determine Type
    bool isExam = title.toLowerCase().contains("exam");
    
    // --- EXISTING LOGIC: Evening Before (or 15 min for tasks) ---
    DateTime primaryReminderTime;
    
    if (isExam) {
        // STRATEGY: "Evening Before" -> 8:00 PM (20:00) the previous day
        DateTime dayBefore = deadline.subtract(const Duration(days: 1));
        primaryReminderTime = DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 20, 0);
    } else {
        // STRATEGY: "Urgency" -> 15 minutes before the task
        primaryReminderTime = deadline.subtract(const Duration(minutes: 15));
    }

    // --- NEW LOGIC: 1 Hour Before Exam ---
    DateTime? secondaryReminderTime;
    if (isExam) {
       secondaryReminderTime = deadline.subtract(const Duration(hours: 1));
    }

    // 3. Safety Check: If the calculated time has passed, ring in 5 seconds (Only for primary)
    bool isShortNotice = false;
    if (primaryReminderTime.isBefore(DateTime.now())) {
       primaryReminderTime = DateTime.now().add(const Duration(seconds: 5));
       isShortNotice = true;
    }

    // 4. Tailor the Message (Primary)
    String bodyText;
    String timeString = DateFormat('h:mm a').format(deadline); // e.g. "8:30 AM"

    if (isExam) {
        if (isShortNotice) {
            bodyText = "⚠️ URGENT: Exam '$title' is at $timeString! Venue: ${venue ?? 'Run to the Exam Room'}.";
        } else {
            bodyText = "📅 Tomorrow you have: $title at $timeString.\n📍 Venue: ${venue ?? 'TBA'}.\nSuccess in your paper!";
        }
    } else {
        if (isShortNotice) {
            bodyText = "⏰ Task Due: '$title' is due right now!";
        } else {
            bodyText = "📝 Reminder: '$title' is due at $timeString.";
        }
    }

    print("\n🔔 --- SCHEDULING ALARM 1 ---");
    print("📌 Type: ${isExam ? 'EXAM (Night Before)' : 'TASK (15m Before)'}");
    print("📝 Title: '$title'");
    print("⏰ Ring Time: $primaryReminderTime");

    // 5. Schedule Primary Alarm
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'dita_planner_channel_v4', 
        title: isExam ? 'Exam Alert 🚨' : 'Task Reminder 📌', 
        body: bodyText, 
        notificationLayout: isExam ? NotificationLayout.BigText : NotificationLayout.Default, 
        wakeUpScreen: true, 
        // CHANGED: Use Reminder for tasks to avoid loop sound, Alarm for exams is okay if critical
        category: isExam ? NotificationCategory.Alarm : NotificationCategory.Reminder,
        fullScreenIntent: isExam, 
      ),
      schedule: NotificationCalendar.fromDate(
        date: primaryReminderTime,
        allowWhileIdle: true, 
        preciseAlarm: true,   
      ),
    );

    // 6. Schedule Secondary Alarm (1 Hour Before) - EXAMS ONLY
    if (isExam && secondaryReminderTime != null) {
       if (secondaryReminderTime.isAfter(DateTime.now())) {
          print("\n🔔 --- SCHEDULING ALARM 2 (1 Hour Before) ---");
          print("⏰ Ring Time: $secondaryReminderTime");
          
          int id1Hour = ("$id" + "_1hr").hashCode; 

          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: id1Hour,
              channelKey: 'dita_planner_channel_v4', 
              title: '⏳ Exam in 1 Hour!', 
              body: "Get ready! '$title' starts at $timeString in ${venue ?? 'your venue'}.", 
              notificationLayout: NotificationLayout.Default, 
              wakeUpScreen: true, 
              // Exam 1hr warning is critical, keeping Alarm but removing loop if possible via channel
              category: NotificationCategory.Alarm,
              fullScreenIntent: true, 
            ),
            schedule: NotificationCalendar.fromDate(
              date: secondaryReminderTime,
              allowWhileIdle: true, 
              preciseAlarm: true,   
            ),
          );
       }
    }
    print("-----------------------------------\n");
  }

  static Future<void> scheduleClassNotification({
    required int id,
    required String title,
    required String venue,
    required int dayOfWeek, // 1=Mon ... 7=Sun
    required TimeOfDay startTime,
  }) async {
    // 🛑 CHECK TOGGLE BEFORE SCHEDULING
    if (!_notificationsEnabled) {
      print("🔕 Notification skipped: User has disabled reminders.");
      return;
    }
    
    // FORMAT TIME STRING
    final String formattedTime = 
        "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}";

    // ==========================================
    // ALARM 1: The "Evening Before" (7:00 PM)
    // ==========================================
    
    int prevDay = dayOfWeek - 1;
    if (prevDay == 0) prevDay = 7; // Handle Sunday -> Monday wrap

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'dita_planner_channel_v4',
        title: '📅 Tomorrow: $title',
        body: 'Don\'t forget! Class at $formattedTime in $venue.',
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Reminder,
        wakeUpScreen: true,
      ),
      schedule: NotificationCalendar(
        weekday: prevDay,
        hour: 19, // 7 PM
        minute: 0,
        second: 0,
        repeats: true,
        allowWhileIdle: true,
        preciseAlarm: true,
      ),
    );

    // ==========================================
    // ALARM 2: The "30 Minutes Before"
    // ==========================================

    int totalMinutes = startTime.hour * 60 + startTime.minute;
    int reminderMinutes = totalMinutes - 30; // 30 minutes before
    int reminderWeekday = dayOfWeek;

    if (reminderMinutes < 0) {
      reminderMinutes += 1440; // Add 24 hours
      reminderWeekday -= 1;
      if (reminderWeekday == 0) reminderWeekday = 7;
    }

    int remHour = reminderMinutes ~/ 60;
    int remMinute = reminderMinutes % 60;

    int id30Min = ("$id" + "_30").hashCode; 

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id30Min,
        channelKey: 'dita_planner_channel_v4', // Ensure v4 is used
        title: '🔔 Upcoming Class: $title',
        body: 'Starts in 30 mins ($formattedTime) at $venue.',
        notificationLayout: NotificationLayout.Default,
        
        // --- CHANGED HERE ---
        // WAS: category: NotificationCategory.Alarm (Loops sound)
        // NOW: category: NotificationCategory.Reminder (One sound + vibration)
        category: NotificationCategory.Reminder, 
        
        wakeUpScreen: true,
        fullScreenIntent: false, // Set to false so it doesn't take over screen like a phone call
      ),
      schedule: NotificationCalendar(
        weekday: reminderWeekday,
        hour: remHour,
        minute: remMinute,
        second: 0,
        repeats: true,
        allowWhileIdle: true,
        preciseAlarm: true,
      ),
    );

    print("✅ Scheduled Dual Alarms for $title (IDs: $id & $id30Min)");
  }

  // --- FEATURE: CANCEL BOTH REMINDERS ---
  static Future<void> cancelNotification(int id) async {
    // 1. Cancel the 7 PM Alarm
    await AwesomeNotifications().cancel(id);
    
    // 2. Cancel the 30 Minute Alarm
    int id30Min = ("$id" + "_30").hashCode;
    await AwesomeNotifications().cancel(id30Min);
    
    print("🚫 Cancelled both alarms for Class ID: $id");
  }
}