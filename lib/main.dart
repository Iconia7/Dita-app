import 'package:dita_app/screens/auth_check_screen.dart';
import 'package:dita_app/services/notification.dart';
import 'package:dita_app/utils/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Start Firebase
  await NotificationService.initialize();
  
  // Get the token
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  String? token = await messaging.getToken();
  print("MY FCM TOKEN: $token"); 
  
  // TODO: Save this token to Django after login!
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