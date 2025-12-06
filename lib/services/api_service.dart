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

static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    // Retrieve the stored user object to find the token
    String? userStr = prefs.getString('user_data');
    String token = "";
    
    if (userStr != null) {
      final userData = json.decode(userStr);
      token = userData['access'] ?? ""; // Get the JWT 'access' token
    }

    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token", // <--- THE KEY PART
    };
  }


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
static Future<bool> rsvpEvent(int eventId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/events/$eventId/rsvp/'),
        headers: headers, // <--- Send Token
      );
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  // UPDATED Check-In Action
// UPDATED Check-In Action
static Future<Map<String, dynamic>?> markAttendance(int eventId) async { // Remove userId param
    try {
      final headers = await _getHeaders(); // <--- Get Token
      final response = await http.post(
        Uri.parse('$baseUrl/events/$eventId/check_in/'),
        headers: headers,
        // No body needed anymore, token identifies the user
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

  static Future<List<dynamic>> getLeaderboard() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/leaderboard/'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Leaderboard Error: $e");
    }
    return [];
  }

  // Get all items
  static Future<List<dynamic>> getLostFoundItems() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/lost-found/'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Lost/Found Error: $e");
    }
    return [];
  }

  // Post a new item (Multipart request for Image)
  static Future<bool> postLostItem(Map<String, String> fields, File? imageFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/lost-found/'));
      
      // Add Headers (Auth)
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      // Add Text Fields
      request.fields.addAll(fields);

      // Add Image
      if (imageFile != null) {
        final mimeTypeData = lookupMimeType(imageFile.path)!.split('/');
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: http.MediaType(mimeTypeData[0], mimeTypeData[1]),
        ));
      }

      final response = await request.send();
      return response.statusCode == 201;
    } catch (e) {
      print("Post Error: $e");
      return false;
    }
  }



  // --- COMMUNITY API ---
  static Future<List<dynamic>> getCommunityPosts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/community-posts/'));
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { print("Community Error: $e"); }
    return [];
  }

  static Future<bool> createPost(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/community-posts/'),
        headers: headers,
        body: json.encode(data),
      );
      return response.statusCode == 201;
    } catch (e) { return false; }
  }

  static Future<bool> likePost(int postId) async {
    try {
      final headers = await _getHeaders();
      await http.post(Uri.parse('$baseUrl/community-posts/$postId/like/'), headers: headers);
      return true;
    } catch (_) { return false; }
  }

  // Comments
  static Future<List<dynamic>> getComments(int postId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/community-comments/?post_id=$postId'));
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (_) {}
    return [];
  }

  static Future<bool> postComment(int postId, String text) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/community-comments/'),
        headers: headers,
        body: json.encode({'post': postId, 'text': text}),
      );
      return response.statusCode == 201;
    } catch (_) { return false; }
  }

static Future<bool> changePassword(int userId, String oldPass, String newPass) async { 
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/change-password/'),
        headers: headers,
        body: json.encode({
          // 🛑 CRITICAL FIX: Add the user_id field here
          "user_id": userId,
          "old_password": oldPass,
          "new_password": newPass,
        }),
      );

      // Check for success (200) or authorization failure (400 if wrong password)
      if (response.statusCode == 200) {
        return true;
      } else {
        // Print the detailed error message from Django for easier debugging
        print('Password Change Error: ${response.body}');
        return false;
      }
    } catch (e) { 
      print('Network Error: $e');
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
    await prefs.setString('user_data', json.encode(user));
  }

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
      final response = await http.post(
        Uri.parse('$baseUrl/login/'), // Updated Endpoint
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "username": username,
          "password": password
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Data now contains: { 'access': '...', 'refresh': '...', 'username': '...', 'id': ... }
        
        await saveUserLocally(data);
        return data;
      }
      return null;
    } catch (e) {
      print("Login Error: $e");
      return null;
    }
  }

static Future<bool> uploadProfilePicture(int userId, File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'PATCH', 
        Uri.parse('$baseUrl/users/$userId/'),
      );

      // --- ADD THIS BLOCK ---
      final headers = await _getHeaders(); 
      request.headers.addAll(headers); // <--- Authenticate the upload
      // ----------------------

      final mimeTypeData = lookupMimeType(imageFile.path)!.split('/');

      request.files.add(await http.MultipartFile.fromPath(
        'avatar', 
        imageFile.path,
        contentType: http.MediaType(mimeTypeData[0], mimeTypeData[1]),
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      return response.statusCode == 200;
    } catch (e) {
      print("Error uploading: $e");
      return false;
    }
}

// Update: Accept userId as a parameter
static Future<bool> initiatePayment(String phone) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/pay/'),
        headers: headers,
        body: json.encode({
          "phone": phone,
          // No user_id needed!
        }),
      );
      return response.statusCode == 200;
    } catch (e) { return false; }
  }


  // Check if system is in maintenance
  static Future<Map<String, dynamic>?> getSystemStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/status/'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Status Check Error: $e");
    }
    return null;
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

// Inside ApiService class

static Future<String?> registerUser(Map<String, dynamic> data) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/register/'),
      headers: {"Content-Type": "application/json"},
      body: json.encode(data),
    );

    if (response.statusCode == 201) { 
      return null; // Success! No error message.
    } else {
      // Try to parse the backend error
      try {
        final body = json.decode(response.body);
        // Backend might return {'username': ['Taken']} or {'error': 'Msg'}
        // We join all values to make a readable string
        if (body is Map) {
          String errors = "";
          body.forEach((key, value) {
            if (value is List) {
              errors += "$key: ${value.join(", ")}\n";
            } else {
              errors += "$value\n";
            }
          });
          return errors.trim();
        }
        return "Registration Failed: ${response.body}";
      } catch (_) {
        return "Registration Failed (Status ${response.statusCode})";
      }
    }
  } catch (e) {
    print("Error registering: $e");
    return "Connection Error. Please check internet.";
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