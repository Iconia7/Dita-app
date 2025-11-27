import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // CRITICAL: 
  // If using Android Emulator, use 'http://10.0.2.2:8000/api'
  // If using Physical Device, use your Laptop's IP (e.g., 'http://192.168.100.x:8000/api')
  static const String baseUrl = 'http://192.168.1.139:8000/api';

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

static Future<bool> initiatePayment(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pay/'),
        headers: {
          "Content-Type": "application/json",
          // If you added token auth in Django, add "Authorization": "Token ..." here
          // For now, our endpoint assumes the user is logged in via session or we skipped auth for testing
        },
        body: json.encode({
          "phone": phone,
          // Amount is fixed at 500 in the backend, so we don't need to send it
        }),
      );

      if (response.statusCode == 200) {
        return true; // Success
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