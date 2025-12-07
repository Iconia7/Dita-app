import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  // 🟢 Colors moved to Theme context

  @override
  Widget build(BuildContext context) {
    // 🟢 Theme Helpers
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.labelSmall?.color;

    return Scaffold(
      backgroundColor: scaffoldBg, // 🟢 Dynamic BG
      appBar: AppBar(
        title: const Text("Privacy & Terms", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("1. Privacy Policy", isDark, primaryColor),
            _buildParagraph(
              "Your privacy is important to us. It is DITA's policy to respect your privacy regarding any information we may collect from you across our application.\n\n"
              "We only ask for personal information when we truly need it to provide a service to you. We collect it by fair and lawful means, with your knowledge and consent.",
              textColor
            ),
            const SizedBox(height: 20),
            
            _buildSectionTitle("2. Data Collection", isDark, primaryColor),
            _buildParagraph(
              "We store your name, admission number, and email to identify you within the app. We also store your course codes to provide the personalized timetable service.\n\n"
              "We do not share any personally identifying information publicly or with third-parties, except when required to by law.",
              textColor
            ),
            const SizedBox(height: 20),

            _buildSectionTitle("3. Terms of Service", isDark, primaryColor),
            _buildParagraph(
              "By accessing the DITA app, you agree to be bound by these terms of service, all applicable laws and regulations, and agree that you are responsible for compliance with any applicable local laws.\n\n"
              "Use License: Permission is granted to temporarily download one copy of the materials (information or software) on DITA's website for personal, non-commercial transitory viewing only.",
              textColor
            ),
            const SizedBox(height: 20),

            _buildSectionTitle("4. Disclaimer", isDark, primaryColor),
            _buildParagraph(
              "The materials on DITA are provided on an 'as is' basis. DITA makes no warranties, expressed or implied, and hereby disclaims and negates all other warranties including, without limitation, implied warranties or conditions of merchantability.",
              textColor
            ),
            
            const SizedBox(height: 40),
            Center(
              child: Text(
                "Last updated: December 2025",
                style: TextStyle(color: subTextColor, fontStyle: FontStyle.italic), // 🟢 Dynamic Subtext
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark, Color primaryColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18, 
        fontWeight: FontWeight.bold, 
        // 🟢 In Dark Mode, White looks better than Dark Blue for headers
        color: isDark ? Colors.white : primaryColor 
      ),
    );
  }

  Widget _buildParagraph(String text, Color? textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, height: 1.5, color: textColor), // 🟢 Dynamic Text
      ),
    );
  }
}