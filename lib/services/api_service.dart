import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mime/mime.dart'; 
import 'dart:io';
import 'package:http_parser/http_parser.dart'; 

class ApiService {
  // CRITICAL: Ensure this matches your running server
  static const String baseUrl = 'https://dita-app-backend.onrender.com/api';

  // --- 🔍 DEBUGGING HEADERS (For Normal JWT Auth) ---
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    String? userStr = prefs.getString('user_data');
    String token = "";
    
    if (userStr != null) {
      try {
        final userData = json.decode(userStr);
        token = userData['access'] ?? ""; 
      } catch (e) {
        print("❌ Error parsing user data: $e");
      }
    }

    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // --- 🔐 NEW: SECURE RESET PASSWORD (Called by Firebase Modal) ---
  // UPDATED: Now takes 'idToken' (from Firebase) instead of just phone
  static Future<bool> resetPasswordByPhone(String idToken, String newPassword) async {
    try {
      print("🔐 Resetting Password securely...");
      
      // We send the Firebase ID Token in the Authorization header.
      // The backend will verify this token to extract the phone number securely.
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password-phone/'), 
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken" // <--- SEND FIREBASE TOKEN HERE
        },
        body: json.encode({
          // We don't need to send 'phone' anymore, the backend extracts it from the token
          "new_password": newPassword,
        }),
      );

      print("📡 Reset Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        return true;
      } else {
        print("❌ Reset Failed Body: ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Reset Network Error: $e");
      return false;
    }
  }

  // --- 🔍 LOGIN ---
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

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('access')) {
           await saveUserLocally(data);
           return data;
        }
        return data;
      }
      return null;
    } catch (e) {
      print("❌ Login Network Error: $e");
      return null;
    }
  }

  // --- STANDARD METHODS ---

  static Future<List<dynamic>> getEvents() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/events/'));
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { print("Error: $e"); }
    return [];
  }  

  static Future<Map<String, dynamic>?> getUserProfile(String username) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/?username=$username'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) return data[0]; 
      }
    } catch (e) { print("Error: $e"); }
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
    } catch (e) { print("Check-in Error: $e"); }
    return null;
  }

  static Future<List<dynamic>> getLeaderboard() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/leaderboard/'));
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { print("Leaderboard Error: $e"); }
    return [];
  }

  // --- COMMUNITY API ---
  static Future<List<dynamic>> getCommunityPosts() async {
    try {
      final headers = await _getHeaders(); 
      final response = await http.get(
        Uri.parse('$baseUrl/community-posts/'),
        headers: headers,
      );
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { print("Community Error: $e"); }
    return [];
  }

  static Future<List<dynamic>> getComments(int postId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/community-comments/?post_id=$postId'),
        headers: headers,
      );
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (_) {}
    return [];
  }

  static Future<bool> createPost(Map<String, String> fields, File? file) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/community-posts/'));
      final headers = await _getHeaders();
      request.headers.addAll(headers);
      request.fields.addAll(fields);

      if (file != null) {
        final mimeTypeData = lookupMimeType(file.path)?.split('/') ?? ['application', 'octet-stream'];
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          file.path,
          contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
        ));
      }

      final response = await request.send();
      return response.statusCode == 201;
    } catch (e) {
      print("❌ Create Post Error: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> likePost(int postId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(Uri.parse('$baseUrl/community-posts/$postId/like/'), headers: headers);
      if (response.statusCode == 200) return json.decode(response.body);
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
    } catch (e) { return false; }
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

  // --- 🔐 CHANGE PASSWORD (For Logged In Users) ---
  static Future<bool> changePassword(int userId, String oldPass, String newPass) async { 
    try {
      final headers = await _getHeaders(); // Uses JWT
      final response = await http.post(
        Uri.parse('$baseUrl/change-password/'),
        headers: headers,
        body: json.encode({
          // "user_id": userId, // Backend now extracts user from Token
          "old_password": oldPass,
          "new_password": newPass,
        }),
      );
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<void> updateFcmToken(int userId, String token) async {
    try {
      final headers = await _getHeaders(); 
      final response = await http.patch(
        Uri.parse('$baseUrl/users/$userId/'),
        headers: headers,
        body: json.encode({ "fcm_token": token }),
      );
      if (response.statusCode == 200) print("FCM Token synced ✅");
    } catch (e) { print("Error updating FCM: $e"); }
  }

  static Future<void> saveUserLocally(Map<String, dynamic> newData) async {
    final prefs = await SharedPreferences.getInstance();
    String? oldDataStr = prefs.getString('user_data');
    Map<String, dynamic> finalData = Map.from(newData);

    if (oldDataStr != null) {
      try {
        final oldData = json.decode(oldDataStr);
        if (!finalData.containsKey('access') && oldData.containsKey('access')) {
          finalData['access'] = oldData['access'];
        }
        if (!finalData.containsKey('refresh') && oldData.containsKey('refresh')) {
          finalData['refresh'] = oldData['refresh'];
        }
      } catch (e) {}
    }
    await prefs.setString('user_data', json.encode(finalData));
  }

  static Future<Map<String, dynamic>?> getUserLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userData = prefs.getString('user_data');
    if (userData != null) return json.decode(userData);
    return null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
  }  

  static Future<bool> uploadProfilePicture(int userId, File imageFile) async {
    try {
      var request = http.MultipartRequest('PATCH', Uri.parse('$baseUrl/users/$userId/'));
      final headers = await _getHeaders(); 
      request.headers.addAll(headers); 

      final mimeTypeData = lookupMimeType(imageFile.path)!.split('/');
      request.files.add(await http.MultipartFile.fromPath(
        'avatar', 
        imageFile.path,
        contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
      ));

      var streamedResponse = await request.send();
      return streamedResponse.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<bool> initiatePayment(String phone, int userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/pay/'),
        headers: headers,
        body: json.encode({
          "phone": phone,
          "user_id": userId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<Map<String, dynamic>?> getSystemStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/status/'));
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { print("Status Error: $e"); }
    return null;
  }

  static Future<Map<String, dynamic>?> getUserDetails(int userId) async {
    try {
      final headers = await _getHeaders(); 
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/'),
        headers: headers,
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) { return null; }
  }

  static Future<String?> registerUser(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register/'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );

      if (response.statusCode == 201) return null;
      return "Registration Failed: ${response.body}";
    } catch (e) { return "Connection Error."; }
  }

  static Future<List<dynamic>> getPromotions() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/promotions/'));
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) {}
    return [];
  }

  static Future<bool> updateUser(int userId, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders(); 
      final response = await http.patch(
        Uri.parse('$baseUrl/users/$userId/'),
        headers: headers,
        body: json.encode(data),
      );
      return response.statusCode == 200;
    } catch (e) { return false; }
  }
}