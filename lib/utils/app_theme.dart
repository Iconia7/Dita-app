import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- BRAND COLORS ---
  static const Color ditaBlue = Color(0xFF003366);
  static const Color ditaGold = Color(0xFFFFD700);

  // --- LIGHT MODE COLORS ---
  static const Color lightBg = Color(0xFFF5F7FA);
  static const Color lightSurface = Colors.white;
  static const Color lightText = Color(0xFF1E293B);
  static const Color lightTextSub = Color(0xFF64748B);

  // --- DARK MODE COLORS (Professional Navy) ---
  static const Color darkBg = Color(0xFF0F172A);      // Deep Slate Navy
  static const Color darkSurface = Color(0xFF1E293B); // Lighter Slate for Cards
  static const Color darkText = Color(0xFFF8FAFC);    // Off-White
  static const Color darkTextSub = Color(0xFF94A3B8); // Light Grey

  // 1. LIGHT THEME DEFINITION
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBg,
    primaryColor: ditaBlue,
    cardColor: lightSurface,
    
    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: ditaBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
    ),

    // Text (Automatic Colors)
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme).apply(
      bodyColor: const Color(0xFF1E293B), // Dark text for light mode
      displayColor: const Color(0xFF1E293B),
    ),

    // Icons
    iconTheme: const IconThemeData(color: ditaBlue),
    
    // Input Fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: lightTextSub),
      contentPadding: const EdgeInsets.all(15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
    ),
  );

  // 2. DARK THEME DEFINITION
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    primaryColor: ditaBlue,
    cardColor: darkSurface,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBg, // Dark background for AppBar in dark mode
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
    ),

    // Text
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: const Color(0xFFF1F5F9), // White/Grey text for dark mode
      displayColor: const Color(0xFFF1F5F9),
    ),

    // Icons
    iconTheme: const IconThemeData(color: ditaGold), // Gold icons pop on dark!

    // Input Fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface, // Inputs match cards
      hintStyle: const TextStyle(color: darkTextSub),
      contentPadding: const EdgeInsets.all(15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
    ),
    
    // Bottom Sheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: darkSurface,
      modalBackgroundColor: darkSurface,
    ),
  );
}