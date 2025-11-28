import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // CRITICAL: 
  // If using Android Emulator, use 'http://10.0.2.2:8000/api'
  // If using Physical Device, use your Laptop's IP (e.g., 'http://192.168.100.x:8000/api')
  static const String baseUrl = 'http://10.8.33.172:8000/api';

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
  static Future<Map<String, dynamic>?> markAttendance(int eventId, int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/events/$eventId/check_in/'),
        headers: {"Content-Type": "application/json"}, // Needed for JSON
        body: json.encode({"user_id": userId}),        // Send ID
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) { print("Check-in Error: $e"); }
    return null;
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
static Future<Map<String, dynamic>?> login(String username, String password) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/users/?username=$username'),
    );

    if (response.statusCode == 200) {
      final List users = json.decode(response.body);
      if (users.isNotEmpty) {
         // Return the first user found (JSON object)
         return users[0]; 
      }
    }
    return null; // Login failed
  } catch (e) {
    print("Error connecting to server: $e");
    return null;
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