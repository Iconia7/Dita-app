import 'package:dita_app/screens/auth_check_screen.dart';
import 'package:dita_app/services/notification.dart';
import 'package:dita_app/utils/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:awesome_notifications/awesome_notifications.dart'; // Import this

// 1. DEFINE TOP-LEVEL BACKGROUND HANDLER
// This must be outside any class and outside main()
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  print("🌙 Handling a background message: ${message.messageId}");

  // We must initialize Awesome Notifications here again because 
  // background tasks run in a separate isolate.
  await AwesomeNotifications().initialize(
    'resource://drawable/ic_notification', 
    [
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

  // Manually trigger the notification if it's an announcement
  if (message.data['type'] == 'announcement') {
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
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
  
  // 2. REGISTER THE BACKGROUND HANDLER
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await NotificationService.initialize();
  
  // Get the token (keep your existing logic)
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  String? token = await messaging.getToken();
  print("MY FCM TOKEN: $token"); 
  
  await dotenv.load(fileName: ".env");

  runApp(const DitaApp());
}

class DitaApp extends StatelessWidget {
  const DitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DITA App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme, 
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthCheckScreen(),
    );
  }
}