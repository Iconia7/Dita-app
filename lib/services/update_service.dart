import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';

class UpdateService {
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      // 1. Get Current Version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      // Ensure your pubspec.yaml version is something like 1.0.0+5
      int currentVersionCode = int.parse(packageInfo.buildNumber);

      // 2. Check Server
      final response = await http.get(Uri.parse('${ApiService.baseUrl}/updates/latest/'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        int latestVersionCode = data['version_code'];

        // 3. Compare & Show Dialog
        if (latestVersionCode > currentVersionCode) {
          _showUpdateDialog(
             context, 
             data['download_url'], 
             data['release_notes'],
             data['is_mandatory'] ?? false
          );
        }
      }
    } catch (e) {
      print("Update Check Error: $e");
    }
  }

static void _showUpdateDialog(BuildContext context, String url, String notes, bool mandatory) {
    showDialog(
      context: context,
      barrierDismissible: !mandatory,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // Rounded corners
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Header Section (Blue Background with Icon)
              Container(
                height: 100,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF003366), // DITA Blue
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.rocket_launch_rounded, // Rocket Icon
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),

              // 2. Content Section
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      "Update Available!",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003366),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "A new version of DITA is ready. Please update to get the latest features.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),

                    // Release Notes Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "What's New:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            notes.isNotEmpty ? notes : "• Bug fixes and improvements.",
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Actions Section
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Update Button
                    ElevatedButton(
  onPressed: () async {
    Navigator.pop(context); // Close dialog first
    final uri = Uri.parse(url);

    try {
      // DIRECTLY TRY TO LAUNCH without checking "canLaunch" first
      bool launched = await launchUrl(
        uri, 
        mode: LaunchMode.externalApplication, // Forces it to open in Chrome/Browser
      );

      if (!launched) {
        throw 'Could not launch';
      }
    } catch (e) {
      print("❌ Launch Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not open link. Please enable browser permissions.")),
      );
    }
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF003366),
    padding: const EdgeInsets.symmetric(vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
  child: const Text(
    "Update Now",
    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
  ),
),
                    
                    // Later Button (Only if not mandatory)
                    if (!mandatory) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                           foregroundColor: Colors.grey,
                        ),
                        child: const Text("Maybe Later"),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}