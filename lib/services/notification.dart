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
    await AwesomeNotifications().initialize(
      'resource://drawable/ic_notification', 
      [
        NotificationChannel(
          channelKey: 'dita_planner_channel_v3',
          channelName: 'Student Planner',
          channelDescription: 'Reminders for upcoming tasks',
          defaultColor: const Color(0xFF003366),
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
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
      print('🔥 FCM Message Received: ${message.notification?.title}');

      // If the message has a notification payload, show it nicely
      if (message.notification != null) {
        _showCustomFirebaseNotification(message);
      }
    });
  }

  static Future<void> _showCustomFirebaseNotification(RemoteMessage message) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: message.messageId.hashCode, // Unique ID based on Firebase ID
        channelKey: 'dita_announcements',
        
        // 1. Map Title & Body (Description)
        title: message.notification?.title ?? 'DITA Update',
        body: message.notification?.body ?? 'New announcement available.',
        
        // 2. Make it look nice
        // BigText allows for longer descriptions
        notificationLayout: NotificationLayout.BigText, 
        
        // 3. Optional: Add a big image if sent from backend
        // (Backend must send "image" key in the data payload)
        bigPicture: message.data['image'], 
        
        // 4. Styling
        color: const Color(0xFF003366),
        backgroundColor: Colors.white,
        wakeUpScreen: true,
        category: NotificationCategory.Social,
      ),
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
// --- FEATURE: SCHEDULE WEEKLY CLASS REMINDERS (DUAL ALARMS) ---
  static Future<void> scheduleClassNotification({
    required int id,
    required String title,
    required String venue,
    required int dayOfWeek, // 1=Mon ... 7=Sun
    required TimeOfDay startTime,
  }) async {
    
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
        id: id, // Use the original ID
        channelKey: 'dita_planner_channel_v3',
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

    // 1. Calculate time logic (handle subtracting minutes)
    int totalMinutes = startTime.hour * 60 + startTime.minute;
    int reminderMinutes = totalMinutes - 30;
    int reminderWeekday = dayOfWeek;

    // Handle wrapping to previous day if class is e.g., at 00:15 AM
    if (reminderMinutes < 0) {
      reminderMinutes += 1440; // Add 24 hours
      reminderWeekday -= 1;
      if (reminderWeekday == 0) reminderWeekday = 7;
    }

    int remHour = reminderMinutes ~/ 60;
    int remMinute = reminderMinutes % 60;

    // 2. Create a unique ID for this second alarm
    // We can't use the same 'id' or it will overwrite the 7 PM one.
    // We generate a derived hash from the original ID.
    int id30Min = ("$id" + "_30").hashCode; 

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id30Min, // <--- DIFFERENT ID
        channelKey: 'dita_planner_channel_v3',
        title: '🔔 Upcoming Class: $title',
        body: 'Starts in 30 mins ($formattedTime) at $venue.',
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Alarm, // Higher urgency
        wakeUpScreen: true,
        fullScreenIntent: true, // Shows over lock screen on some devices
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
    
    // 2. Cancel the 30 Minute Alarm (using the same derived ID logic)
    int id30Min = ("$id" + "_30").hashCode;
    await AwesomeNotifications().cancel(id30Min);
    
    print("🚫 Cancelled both alarms for Class ID: $id");
  }
}