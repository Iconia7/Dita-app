import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  final Color _primaryDark = const Color(0xFF003366);
  final Color _bgOffWhite = const Color(0xFFF4F6F9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgOffWhite,
      appBar: AppBar(
        title: const Text("Privacy & Terms", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: _primaryDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("1. Privacy Policy"),
            _buildParagraph(
              "Your privacy is important to us. It is DITA's policy to respect your privacy regarding any information we may collect from you across our application.\n\n"
              "We only ask for personal information when we truly need it to provide a service to you. We collect it by fair and lawful means, with your knowledge and consent."
            ),
            const SizedBox(height: 20),
            
            _buildSectionTitle("2. Data Collection"),
            _buildParagraph(
              "We store your name, admission number, and email to identify you within the app. We also store your course codes to provide the personalized timetable service.\n\n"
              "We do not share any personally identifying information publicly or with third-parties, except when required to by law."
            ),
            const SizedBox(height: 20),

            _buildSectionTitle("3. Terms of Service"),
            _buildParagraph(
              "By accessing the DITA app, you agree to be bound by these terms of service, all applicable laws and regulations, and agree that you are responsible for compliance with any applicable local laws.\n\n"
              "Use License: Permission is granted to temporarily download one copy of the materials (information or software) on DITA's website for personal, non-commercial transitory viewing only."
            ),
            const SizedBox(height: 20),

            _buildSectionTitle("4. Disclaimer"),
            _buildParagraph(
              "The materials on DITA are provided on an 'as is' basis. DITA makes no warranties, expressed or implied, and hereby disclaims and negates all other warranties including, without limitation, implied warranties or conditions of merchantability."
            ),
            
            const SizedBox(height: 40),
            Center(
              child: Text(
                "Last updated: December 2025",
                style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18, 
        fontWeight: FontWeight.bold, 
        color: _primaryDark
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
      ),
    );
  }
}