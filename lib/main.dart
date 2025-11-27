import 'package:dita_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const DitaApp());
}

class DitaApp extends StatelessWidget {
  const DitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DITA App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Daystar-ish Blue Theme
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
        textTheme: GoogleFonts.poppinsTextTheme(), // Modern font
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}