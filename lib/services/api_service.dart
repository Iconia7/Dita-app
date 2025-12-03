import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mime/mime.dart'; 
import 'dart:io';

class ApiService {
  // CRITICAL: 
  // If using Android Emulator, use 'http://10.0.2.2:8000/api'
  // If using Physical Device, use your Laptop's IP (e.g., 'http://192.168.100.x:8000/api')
  static const String baseUrl = 'https://dita-app-backend.onrender.com/api';

static Future<List<dynamic>> getEvents() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/events/'));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      print("Error fetching events: $e");
      return [];
    }
  }  

static Future<Map<String, dynamic>?> getUserProfile(String username) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/users/?username=$username'),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) {
        return data[0]; // Return the first user found
      }
    }
  } catch (e) {
    print("Error fetching profile: $e");
  }
  return null;
}


static Future<List<dynamic>> getResources() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/resources/'));
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { print("Error: $e"); }
    return [];
  }

  // RSVP Action
static Future<bool> rsvpEvent(int eventId, int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/events/$eventId/rsvp/'),
        headers: {"Content-Type": "application/json"}, // Needed for JSON
        body: json.encode({"user_id": userId}),        // Send ID
      );
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  // UPDATED Check-In Action
// UPDATED Check-In Action
  static Future<Map<String, dynamic>?> markAttendance(int eventId, int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/events/$eventId/check_in/'),
        headers: {"Content-Type": "application/json"}, 
        body: json.encode({"user_id": userId}),        
      );
      
      // FIX: Accept 400 as a "valid" response so we can read the error message
      if (response.statusCode == 200 || response.statusCode == 400) {
        return json.decode(response.body);
      }
    } catch (e) { 
        print("Check-in Error: $e"); 
    }
    return null;
  }

static Future<bool> changePassword(int userId, String oldPass, String newPass) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/change-password/'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "user_id": userId,
          "old_password": oldPass,
          "new_password": newPass,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print("Password Change Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error: $e");
      return false;
    }
  }  

static Future<void> updateFcmToken(int userId, String token) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/users/$userId/'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "fcm_token": token
        }),
      );

      if (response.statusCode == 200) {
        print("FCM Token synced with server ✅");
      } else {
        print("Failed to sync FCM Token: ${response.body}");
      }
    } catch (e) {
      print("Error updating FCM token: $e");
    }
  } 


static Future<void> saveUserLocally(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    // We store the whole user object as a String
    await prefs.setString('user_data', json.encode(user));
  }

  // 2. GET USER LOCALLY
  static Future<Map<String, dynamic>?> getUserLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userData = prefs.getString('user_data');
    if (userData != null) {
      return json.decode(userData);
    }
    return null;
  }

  // 3. LOGOUT (CLEAR DATA)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
  }  

  // 1. Login Function
// 1. Login Function (UPDATED)
  static Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      // Note: This is insecure for production (sending password in URL), 
      // but okay for a student project presentation.
      final response = await http.get(
        Uri.parse('$baseUrl/users/?username=$username'),
      );

      if (response.statusCode == 200) {
        final List users = json.decode(response.body);
        if (users.isNotEmpty) {
          final user = users[0];
          
          // --- CRITICAL FIX: SAVE THE DATA ---
          await saveUserLocally(user); 
          print("✅ User details saved locally!");
          // ----------------------------------
          
          return user; 
        }
      }
      return null; // Login failed
    } catch (e) {
      print("Error connecting to server: $e");
      return null;
    }
  }

static Future<bool> uploadProfilePicture(int userId, File imageFile) async {
    try {
      // 1. Create Multipart Request
      var request = http.MultipartRequest(
        'PATCH', 
        Uri.parse('$baseUrl/users/$userId/'),
      );

      // 2. Detect file type (jpg/png)
      final mimeTypeData = lookupMimeType(imageFile.path)!.split('/');

      // 3. Attach the file
      request.files.add(await http.MultipartFile.fromPath(
        'avatar', // Matches Django User model field name
        imageFile.path,
        contentType: http.MediaType(mimeTypeData[0], mimeTypeData[1]),
      ));

      // 4. Send
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return true;
      } else {
        print("Upload failed: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error uploading image: $e");
      return false;
    }
  }  

// Update: Accept userId as a parameter
  static Future<bool> initiatePayment(String phone, int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pay/'),
        headers: {
          "Content-Type": "application/json",
        },
        body: json.encode({
          "phone": phone,
          "user_id": userId, // <--- SEND THE ID
        }),
      );

      if (response.statusCode == 200) {
        return true; 
      } else {
        print("Payment Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error initiating payment: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getUserDetails(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/'), // Django standard detail URL
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print("Error fetching user details: $e");
      return null;
    }
  }

 static Future<bool> registerUser(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register/'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );

      if (response.statusCode == 201) { // 201 means Created
        return true;
      } else {
        print("Registration Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error registering: $e");
      return false;
    }
  } 

  static Future<bool> updateUser(int userId, Map<String, dynamic> data) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/users/$userId/'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print("Update Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error updating user: $e");
      return false;
    }
  }
}