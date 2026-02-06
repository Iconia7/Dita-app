import 'package:dita_app/screens/auth_check_screen.dart';
import 'package:dita_app/services/notification.dart';
import 'package:dita_app/utils/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:awesome_notifications/awesome_notifications.dart'; 
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:dita_app/utils/app_logger.dart';

// Phase 2: State Management & Offline Storage
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/storage/local_storage.dart';
import 'services/home_widget_service.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point') 
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Native called background task: $task"); 
    try {
      await HomeWidgetService.backgroundFetch();
    } catch (e) {
      print(e);
    }
    return Future.value(true);
  });
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

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
  
  print('🔔 Background FCM Received: ${message.messageId}');
  print('📦 Data: ${message.data}');
  print('🎯 Type: ${message.data['type']}');
  
  if (message.data['type'] == 'announcement') {
    print('✅ Creating announcement notification...');
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: message.messageId.hashCode, 
        channelKey: 'dita_announcements',
        title: message.data['title'] ?? 'DITA Update',
        body: message.data['message_body'] ?? 'New announcement available.',
        notificationLayout: NotificationLayout.BigPicture, 
        bigPicture: message.data['image'], 
        color: const Color(0xFF003366),
        backgroundColor: Colors.white,
        wakeUpScreen: true,
        category: NotificationCategory.Social,
      ),
    );
    print('✅ Background notification created!');
  } else {
    print('⚠️ Message type not "announcement": ${message.data['type']}');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    await MobileAds.instance.initialize();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize Workmanager for background widget updates
    Workmanager().initialize(
       callbackDispatcher, 
       isInDebugMode: false // TODO: Set to false in production
    );
    // Register periodic task (every 1 hour)
    Workmanager().registerPeriodicTask(
      "1", 
      "widgetUpdateTask", 
      frequency: const Duration(hours: 1),
      constraints: Constraints(networkType: NetworkType.connected),
    );

    await NotificationService.initialize();
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    try {
      await messaging.getToken();
    } catch (e) {
    }

  } catch (e) {
    AppLogger.error('Firebase initialization error', error: e);
  }
  
  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Phase 2: Initialize Hive for offline storage
  try {
    await LocalStorage.init();
    AppLogger.success('Phase 2 foundation initialized');
  } catch (e, stackTrace) {
    AppLogger.error('Failed to initialize local storage', 
      error: e, stackTrace: stackTrace);
  }

  // Phase 2: Wrap app with ProviderScope for Riverpod
  runApp(const ProviderScope(child: DitaApp()));
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