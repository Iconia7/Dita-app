import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mime/mime.dart'; 
import 'dart:io';

class ApiService {
  // CRITICAL: Ensure this matches your running server
  static const String baseUrl = 'https://dita-app-backend.onrender.com/api';

  // --- 🔍 DEBUGGING HEADERS ---
  static Future<Map<String, String>> _getHeaders() async {
    print("\n🔍 --- DEBUG: GENERATING HEADERS ---");
    
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Check raw storage
    String? userStr = prefs.getString('user_data');
    print("1️⃣ Raw Storage ('user_data'): $userStr");

    String token = "";
    
    if (userStr != null) {
      try {
        final userData = json.decode(userStr);
        // 2. Check extracted token
        token = userData['access'] ?? ""; 
        print("2️⃣ Extracted Token: ${token.isNotEmpty ? '${token.substring(0, 10)}...' : 'EMPTY/NULL'}");
      } catch (e) {
        print("❌ Error parsing user data: $e");
      }
    } else {
      print("❌ CRITICAL: User data is NULL in SharedPrefs. User is likely logged out.");
    }

    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };

    print("3️⃣ Final Headers being sent: $headers");
    print("--------------------------------------\n");
    return headers;
  }

  // --- 🔍 DEBUGGING LOGIN ---
  static Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      print("🚀 Attempting Login for: $username");
      
      final response = await http.post(
        Uri.parse('$baseUrl/login/'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "username": username,
          "password": password
        }),
      );

      print("📡 Login Response Code: ${response.statusCode}");
      print("📡 Login Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Check if 'access' key actually exists
        if (data.containsKey('access')) {
           print("✅ Token found in response! Saving...");
           await saveUserLocally(data);
           return data;
        } else {
           print("⚠️ WARNING: Login successful but NO 'access' token found in response!");
        }
        return data;
      }
      return null;
    } catch (e) {
      print("❌ Login Network Error: $e");
      return null;
    }
  }

  // --- STANDARD METHODS (Unchanged but using the debug headers) ---

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
          return data[0]; 
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

  static Future<bool> rsvpEvent(int eventId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/events/$eventId/rsvp/'),
        headers: headers, 
      );
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<Map<String, dynamic>?> markAttendance(int eventId) async { 
    try {
      final headers = await _getHeaders(); 
      final response = await http.post(
        Uri.parse('$baseUrl/events/$eventId/check_in/'),
        headers: headers,
      );
      
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

  static Future<bool> postLostItem(Map<String, String> fields, File? imageFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/lost-found/'));
      
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      request.fields.addAll(fields);

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
      print("📝 Creating Post...");
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/community-posts/'),
        headers: headers,
        body: json.encode(data),
      );
      print("📝 Create Post Response: ${response.statusCode} - ${response.body}");
      return response.statusCode == 201;
    } catch (e) { 
      print("❌ Create Post Error: $e");
      return false; 
    }
  }

// Update Like to return the new count/status
  static Future<Map<String, dynamic>?> likePost(int postId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(Uri.parse('$baseUrl/community-posts/$postId/like/'), headers: headers);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> editPost(int postId, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/community-posts/$postId/'),
        headers: headers,
        body: json.encode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Edit Error: $e");
      return false;
    }
  }

  static Future<bool> deletePost(int postId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(Uri.parse('$baseUrl/community-posts/$postId/'), headers: headers);
      return response.statusCode == 204;
    } catch (_) { return false; }
  }

  static Future<bool> deleteComment(int commentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(Uri.parse('$baseUrl/community-comments/$commentId/'), headers: headers);
      return response.statusCode == 204;
    } catch (_) { return false; }
  }

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
          "user_id": userId,
          "old_password": oldPass,
          "new_password": newPass,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
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
    // ✅ NEW: Get the headers that include the "Bearer <token>"
    final headers = await _getHeaders(); 

    final response = await http.patch(
      Uri.parse('$baseUrl/users/$userId/'),
      headers: headers, // <--- Pass them here
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

static Future<void> saveUserLocally(Map<String, dynamic> newData) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Get the OLD data (which has the token)
    String? oldDataStr = prefs.getString('user_data');
    Map<String, dynamic> finalData = Map.from(newData); // Start with new data

    if (oldDataStr != null) {
      try {
        final oldData = json.decode(oldDataStr);
        
        // 2. If new data is missing the token, COPY it from old data
        if (!finalData.containsKey('access') && oldData.containsKey('access')) {
          finalData['access'] = oldData['access'];
          print("🛡️ Token preserved during update.");
        }
        
        // (Optional) Keep refresh token too
        if (!finalData.containsKey('refresh') && oldData.containsKey('refresh')) {
          finalData['refresh'] = oldData['refresh'];
        }
      } catch (e) {
        print("Error merging data: $e");
      }
    }

    // 3. Save the combined result
    await prefs.setString('user_data', json.encode(finalData));
  }

  static Future<Map<String, dynamic>?> getUserLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userData = prefs.getString('user_data');
    if (userData != null) {
      return json.decode(userData);
    }
    return null;
  }

  static Future<void> logout() async {
    print("🚪 Logging out and clearing data...");
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
  }  

  static Future<bool> uploadProfilePicture(int userId, File imageFile) async {
    try {
      print("📸 Uploading Profile Pic...");
      var request = http.MultipartRequest(
        'PATCH', 
        Uri.parse('$baseUrl/users/$userId/'),
      );

      final headers = await _getHeaders(); 
      request.headers.addAll(headers); 

      final mimeTypeData = lookupMimeType(imageFile.path)!.split('/');

      request.files.add(await http.MultipartFile.fromPath(
        'avatar', 
        imageFile.path,
        contentType: http.MediaType(mimeTypeData[0], mimeTypeData[1]),
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      print("📸 Upload Response: ${response.statusCode} - ${response.body}");
      return response.statusCode == 200;
    } catch (e) {
      print("Error uploading: $e");
      return false;
    }
  }

  static Future<bool> initiatePayment(String phone) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/pay/'),
        headers: headers,
        body: json.encode({
          "phone": phone,
        }),
      );
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

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
        Uri.parse('$baseUrl/users/$userId/'),
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

  static Future<String?> registerUser(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register/'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );

      if (response.statusCode == 201) { 
        return null;
      } else {
        try {
          final body = json.decode(response.body);
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