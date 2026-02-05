import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/app_logger.dart';
import '../core/errors/exceptions.dart';

class ApiService {
  //dotenv.env['API_BASE_URL'] ??
  // Load base URL from environment variables with fallback
  // Load base URL from environment variables with fallback
  static String get baseUrl {
    String url = dotenv.env['API_BASE_URL'] ?? 'https://api.dita.co.ke/api';
    // Fix potential typo from environment or cache
    if (url.startsWith('hhttps')) {
       url = url.replaceFirst('hhttps', 'https');
    }
    return url;
  }
  
  // Request timeout duration
  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _mediaTimeout = Duration(minutes: 2);

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
        AppLogger.error('Error parsing user data', error: e);
      }
    }

    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  static Future<bool> resetPasswordByPhone(String idToken, String newPassword) async {
    try {
      AppLogger.api('POST', '/auth/reset-password-phone/');
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password-phone/'), 
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken"
        },
        body: json.encode({
          "new_password": newPassword,
        }),
      ).timeout(_timeout);

      AppLogger.api('POST', '/auth/reset-password-phone/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) {
        AppLogger.success('Password reset successful');
        return true;
      } else {
        AppLogger.warning('Password reset failed: ${response.statusCode}');
        return false;
      }
    } on SocketException {
      AppLogger.error('Network error during password reset');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout during password reset');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error during password reset', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // --- 🔍 LOGIN ---
  static Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      AppLogger.api('POST', '/login/');
      final response = await http.post(
        Uri.parse('$baseUrl/login/'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "username": username,
          "password": password
        }),
      ).timeout(_timeout);

      AppLogger.api('POST', '/login/', statusCode: response.statusCode);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('access')) {
           await saveUserLocally(data);
           AppLogger.success('User logged in successfully');
           return data;
        }
        return data;
      } else if (response.statusCode == 401) {
        AppLogger.warning('Login failed: Invalid credentials');
        throw AuthenticationException('Invalid username or password');
      } else {
        AppLogger.warning('Login failed: ${response.statusCode}');
        return null;
      }
    } on SocketException {
      AppLogger.error('Network error during login');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout during login');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Login error', error: e, stackTrace: stackTrace);
      return null;
    }
  }


  // --- STANDARD METHODS ---

  static Future<List<dynamic>> getEvents({int? attendedBy, int? page, int? limit}) async {
    try {
      String url = '$baseUrl/events/';
      Map<String, String> queryParams = {};
      
      if (attendedBy != null) queryParams['attended_by'] = attendedBy.toString();
      if (page != null) queryParams['page'] = page.toString();
      if (limit != null) queryParams['limit'] = limit.toString();

      if (queryParams.isNotEmpty) {
        url += '?' + queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
      }
      
      AppLogger.api('GET', url);
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      
      AppLogger.api('GET', url, statusCode: response.statusCode);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle both direct list and paginated response { results: [] }
        final List<dynamic> list = data is List ? data : (data['results'] ?? []);
        AppLogger.success('Fetched ${list.length} events');
        return list;
      } else {
        AppLogger.warning('Failed to fetch events: ${response.statusCode}');
        throw ApiException('Failed to load events', statusCode: response.statusCode);
      }
    } on SocketException {
      AppLogger.error('Network error while fetching events');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while fetching events');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching events', error: e, stackTrace: stackTrace);
      return [];
    }
  }  

  static Future<List<dynamic>> getAnnouncements() async {
    try {
      AppLogger.api('GET', '/announcements/');
      final response = await http.get(Uri.parse('$baseUrl/announcements/')).timeout(_timeout);
      
      AppLogger.api('GET', '/announcements/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.success('Fetched ${data.length} announcements');
        return data;
      } else {
        AppLogger.warning('Failed to fetch announcements: ${response.statusCode}');
        throw ApiException('Failed to load announcements', statusCode: response.statusCode);
      }
    } on SocketException {
      AppLogger.error('Network error while fetching announcements');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while fetching announcements');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching announcements', error: e, stackTrace: stackTrace);
      return [];
    }
  }


  static Future<Map<String, dynamic>?> getUserProfile(String username) async {
    try {
      AppLogger.api('GET', '/users/?username=$username');
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/users/?username=$username'),
        headers: headers,
      ).timeout(_timeout);

      AppLogger.api('GET', '/users/', statusCode: response.statusCode);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          AppLogger.success('Fetched user profile for $username');
          return data[0];
        }
        AppLogger.warning('User profile not found for $username');
        return null;
      } else if (response.statusCode == 401) {
        throw AuthenticationException('Session expired');
      } else {
        AppLogger.warning('Failed to fetch user profile: ${response.statusCode}');
        return null;
      }
    } on SocketException {
      AppLogger.error('Network error while fetching user profile');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while fetching user profile');
      throw TimeoutException();
    } catch (e) {
      AppLogger.error('Error fetching user profile', error: e);
      rethrow;
    }
  }

  static Future<List<dynamic>> getResources() async {
    try {
      AppLogger.api('GET', '/resources/');
      final response = await http.get(Uri.parse('$baseUrl/resources/')).timeout(_timeout);
      
      AppLogger.api('GET', '/resources/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.success('Fetched ${data.length} resources');
        return data;
      } else {
        AppLogger.warning('Failed to fetch resources: ${response.statusCode}');
        throw ApiException('Failed to load resources', statusCode: response.statusCode);
      }
    } on SocketException {
      AppLogger.error('Network error while fetching resources');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while fetching resources');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching resources', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  static Future<Map<String, dynamic>?> rsvpEvent(int eventId) async {
    try {
      AppLogger.api('POST', '/events/$eventId/rsvp/');
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/events/$eventId/rsvp/'),
        headers: headers, 
      ).timeout(_timeout);
      
      AppLogger.api('POST', '/events/$eventId/rsvp/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.success('RSVP action successful for event $eventId: ${data['status']}');
        return data;
      } else {
        AppLogger.warning('RSVP failed: ${response.statusCode}');
        return null;
      }
    } on SocketException {
      AppLogger.error('Network error during RSVP');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout during RSVP');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Error during RSVP', error: e, stackTrace: stackTrace);
      return null;
    }
  }


  static Future<Map<String, dynamic>?> markAttendance(int eventId) async { 
    try {
      AppLogger.api('POST', '/events/$eventId/check_in/');
      final headers = await _getHeaders(); 
      final response = await http.post(
        Uri.parse('$baseUrl/events/$eventId/check_in/'),
        headers: headers,
      ).timeout(_timeout);
      
      AppLogger.api('POST', '/events/$eventId/check_in/', statusCode: response.statusCode);
      
      if (response.statusCode == 200 || response.statusCode == 400) {
        final data = json.decode(response.body);
        if (response.statusCode == 200) {
          AppLogger.success('Attendance marked for event $eventId');
        } else {
          AppLogger.warning('Attendance check-in issue: ${data['message'] ?? 'Unknown'}');
        }
        return data;
      }
    } on SocketException {
      AppLogger.error('Network error during check-in');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout during check-in');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Check-in error', error: e, stackTrace: stackTrace);
    }
    return null;
  }

  static Future<List<dynamic>> getLeaderboard() async {
    try {
      AppLogger.api('GET', '/leaderboard/');
      final response = await http.get(Uri.parse('$baseUrl/leaderboard/')).timeout(_timeout);
      
      AppLogger.api('GET', '/leaderboard/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.success('Fetched ${data.length} leaderboard entries');
        return data;
      } else {
        AppLogger.warning('Failed to fetch leaderboard: ${response.statusCode}');
        throw ApiException('Failed to load leaderboard', statusCode: response.statusCode);
      }
    } on SocketException {
      AppLogger.error('Network error while fetching leaderboard');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while fetching leaderboard');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Leaderboard error', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  // --- COMMUNITY API ---
  static Future<List<dynamic>> getCommunityPosts({int? page, int? limit}) async {
    try {
      String url = '$baseUrl/community-posts/';
      if (page != null || limit != null) {
        url += '?';
        if (page != null) url += 'page=$page&';
        if (limit != null) url += 'limit=$limit';
      }

      AppLogger.api('GET', url);
      final headers = await _getHeaders(); 
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(_timeout);
      
      AppLogger.api('GET', url, statusCode: response.statusCode);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle both direct list and paginated response { results: [] }
        final List<dynamic> list = data is List ? data : (data['results'] ?? []);
        AppLogger.success('Fetched ${list.length} community posts');
        return list;
      } else {
        AppLogger.warning('Failed to fetch community posts: ${response.statusCode}');
        throw ApiException('Failed to load community posts', statusCode: response.statusCode);
      }
    } on SocketException {
      AppLogger.error('Network error while fetching community posts');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while fetching community posts');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Community error', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  static Future<List<dynamic>> getComments(int postId) async {
    try {
      AppLogger.api('GET', '/community-comments/?post_id=$postId');
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/community-comments/?post_id=$postId'),
        headers: headers,
      ).timeout(_timeout);
      
      AppLogger.api('GET', '/community-comments/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.success('Fetched ${data.length} comments for post $postId');
        return data;
      } else {
        AppLogger.warning('Failed to fetch comments: ${response.statusCode}');
      }
    } on SocketException {
      AppLogger.error('Network error while fetching comments');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while fetching comments');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching comments', error: e, stackTrace: stackTrace);
    }
    return [];
  }

  static Future<bool> createPost(Map<String, String> fields, File? file) async {
    try {
      AppLogger.api('POST', '/community-posts/');
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

      final streamedResponse = await request.send().timeout(_mediaTimeout);
      final statusCode = streamedResponse.statusCode;
      
      AppLogger.api('POST', '/community-posts/', statusCode: statusCode);
      
      if (statusCode == 201) {
        AppLogger.success('Post created successfully');
        return true;
      } else {
        AppLogger.warning('Failed to create post: $statusCode');
        return false;
      }
    } on SocketException {
      AppLogger.error('Network error while creating post');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while creating post');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Create post error', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  static Future<bool> createStory(String? caption, File file) async {
    try {
      AppLogger.api('POST', '/stories/');
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/stories/'));
      final headers = await _getHeaders();
      request.headers.addAll(headers);
      
      if (caption != null && caption.isNotEmpty) {
        request.fields['caption'] = caption;
      }

      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      final mimeTypeData = mimeType.split('/');
      
      String fieldName = 'image';
      if (mimeTypeData[0] == 'video') {
        fieldName = 'video';
      }

      request.files.add(await http.MultipartFile.fromPath(
        fieldName,
        file.path,
        contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
      ));

      final streamedResponse = await request.send().timeout(_mediaTimeout);
      final statusCode = streamedResponse.statusCode;
      
      AppLogger.api('POST', '/stories/', statusCode: statusCode);
      
      if (statusCode == 201) {
        AppLogger.success('Story uploaded successfully');
        return true;
      } else {
        AppLogger.warning('Failed to upload story: $statusCode');
        return false;
      }
    } on SocketException {
      AppLogger.error('Network error while uploading story');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while uploading story');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Story upload error', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  static Future<bool> markStoryAsViewed(int storyId) async {
    try {
      AppLogger.api('POST', '/stories/$storyId/mark_as_viewed/');
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/stories/$storyId/mark_as_viewed/'),
        headers: headers,
      ).timeout(_timeout);
      
      AppLogger.api('POST', '/stories/$storyId/mark_as_viewed/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) {
        AppLogger.success('Story $storyId marked as viewed');
        return true;
      }
      return false;
    } on SocketException {
      AppLogger.error('Network error while marking story as viewed');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while marking story as viewed');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Error marking story as viewed', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  static Future<Map<String, dynamic>?> likePost(int postId) async {
    try {
      AppLogger.api('POST', '/community-posts/$postId/like/');
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/community-posts/$postId/like/'), 
        headers: headers
      ).timeout(_timeout);
      
      AppLogger.api('POST', '/community-posts/$postId/like/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) {
        AppLogger.success('Post $postId liked');
        return json.decode(response.body);
      }
    } on SocketException {
      AppLogger.error('Network error while liking post');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while liking post');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Error liking post', error: e, stackTrace: stackTrace);
    }
    return null;
  }

  static Future<bool> editPost(int postId, Map<String, dynamic> data) async {
    try {
      AppLogger.api('PATCH', '/community-posts/$postId/');
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/community-posts/$postId/'),
        headers: headers,
        body: json.encode(data),
      ).timeout(_timeout);
      
      AppLogger.api('PATCH', '/community-posts/$postId/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) {
        AppLogger.success('Post $postId edited successfully');
        return true;
      }
      return false;
    } on SocketException {
      AppLogger.error('Network error while editing post');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while editing post');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Error editing post', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  static Future<bool> deletePost(int postId) async {
    try {
      AppLogger.api('DELETE', '/community-posts/$postId/');
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/community-posts/$postId/'), 
        headers: headers
      ).timeout(_timeout);
      
      AppLogger.api('DELETE', '/community-posts/$postId/', statusCode: response.statusCode);
      
      if (response.statusCode == 204) {
        AppLogger.success('Post $postId deleted');
        return true;
      }
      return false;
    } on SocketException {
      AppLogger.error('Network error while deleting post');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while deleting post');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting post', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  static Future<bool> deleteComment(int commentId) async {
    try {
      AppLogger.api('DELETE', '/community-comments/$commentId/');
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/community-comments/$commentId/'), 
        headers: headers
      ).timeout(_timeout);
      
      AppLogger.api('DELETE', '/community-comments/$commentId/', statusCode: response.statusCode);
      
      if (response.statusCode == 204) {
        AppLogger.success('Comment $commentId deleted');
        return true;
      }
      return false;
    } on SocketException {
      AppLogger.error('Network error while deleting comment');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while deleting comment');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting comment', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  static Future<bool> postComment(int postId, String text) async {
    try {
      AppLogger.api('POST', '/community-comments/');
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/community-comments/'),
        headers: headers,
        body: json.encode({'post': postId, 'text': text}),
      ).timeout(_timeout);
      
      AppLogger.api('POST', '/community-comments/', statusCode: response.statusCode);
      
      if (response.statusCode == 201) {
        AppLogger.success('Comment posted on post $postId');
        return true;
      }
      return false;
    } on SocketException {
      AppLogger.error('Network error while posting comment');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while posting comment');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Error posting comment', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // --- 🔐 CHANGE PASSWORD (For Logged In Users) ---
  static Future<bool> changePassword(int userId, String oldPass, String newPass) async { 
    try {
      AppLogger.api('POST', '/change-password/');
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/change-password/'),
        headers: headers,
        body: json.encode({
          "old_password": oldPass,
          "new_password": newPass,
        }),
      ).timeout(_timeout);
      
      AppLogger.api('POST', '/change-password/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) {
        AppLogger.success('Password changed successfully');
        return true;
      }
      return false;
    } on SocketException {
      AppLogger.error('Network error while changing password');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while changing password');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Error changing password', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  static Future<void> updateFcmToken(int userId, String token) async {
    try {
      AppLogger.api('PATCH', '/users/$userId/');
      final headers = await _getHeaders(); 
      final response = await http.patch(
        Uri.parse('$baseUrl/users/$userId/'),
        headers: headers,
        body: json.encode({ "fcm_token": token }),
      ).timeout(_timeout);
      
      AppLogger.api('PATCH', '/users/$userId/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) {
        AppLogger.success('FCM Token synced');
      } else {
        AppLogger.warning('Failed to sync FCM token: ${response.statusCode}');
      }
    } on SocketException {
      AppLogger.error('Network error while updating FCM token');
    } on TimeoutException {
      AppLogger.error('Request timeout while updating FCM token');
    } catch (e, stackTrace) {
      AppLogger.error('Error updating FCM token', error: e, stackTrace: stackTrace);
    }
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
      AppLogger.api('PATCH', '/users/$userId/');
      var request = http.MultipartRequest('PATCH', Uri.parse('$baseUrl/users/$userId/'));
      final headers = await _getHeaders(); 
      request.headers.addAll(headers); 

      final mimeTypeData = lookupMimeType(imageFile.path)?.split('/') ?? ['image', 'jpeg'];
      request.files.add(await http.MultipartFile.fromPath(
        'avatar', 
        imageFile.path,
        contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
      ));

      var streamedResponse = await request.send().timeout(_mediaTimeout);
      final statusCode = streamedResponse.statusCode;
      
      AppLogger.api('PATCH', '/users/$userId/', statusCode: statusCode);
      
      if (statusCode == 200) {
        AppLogger.success('Profile picture uploaded successfully');
        return true;
      }
      return false;
    } on SocketException {
      AppLogger.error('Network error while uploading profile picture');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while uploading profile picture');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Error uploading profile picture', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  static Future<bool> initiatePayment(String phone, int userId) async {
    try {
      AppLogger.api('POST', '/pay/');
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/pay/'),
        headers: headers,
        body: json.encode({
          "phone": phone,
          "user_id": userId,
        }),
      ).timeout(_timeout);
      
      AppLogger.api('POST', '/pay/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) {
        AppLogger.success('Payment initiated for user $userId');
        return true;
      }
      return false;
    } on SocketException {
      AppLogger.error('Network error while initiating payment');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while initiating payment');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Error initiating payment', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getSystemStatus() async {
    try {
      AppLogger.api('GET', '/status/');
      final response = await http.get(Uri.parse('$baseUrl/status/')).timeout(_timeout);
      
      AppLogger.api('GET', '/status/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) {
        AppLogger.success('System status retrieved');
        return json.decode(response.body);
      }
    } on SocketException {
      AppLogger.error('Network error while checking system status');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while checking system status');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Status error', error: e, stackTrace: stackTrace);
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getUserDetails(int userId) async {
    try {
      AppLogger.api('GET', '/users/$userId/');
      final headers = await _getHeaders(); 
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/'),
        headers: headers,
      ).timeout(_timeout);
      
      AppLogger.api('GET', '/users/$userId/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) {
        AppLogger.success('User details retrieved for user $userId');
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw AuthenticationException('Session expired');
      }
      return null;
    } on SocketException {
      AppLogger.error('Network error while fetching user details');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while fetching user details');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching user details', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<String?> registerUser(Map<String, dynamic> data) async {
    try {
      AppLogger.api('POST', '/register/');
      final response = await http.post(
        Uri.parse('$baseUrl/register/'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      ).timeout(_timeout);

      AppLogger.api('POST', '/register/', statusCode: response.statusCode);

      if (response.statusCode == 201) {
        AppLogger.success('User registered successfully');
        return null;
      }
      AppLogger.warning('Registration failed: ${response.statusCode}');
      return "Registration Failed: ${response.body}";
    } on SocketException {
      AppLogger.error('Network error during registration');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout during registration');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Registration error', error: e, stackTrace: stackTrace);
      return "Connection Error.";
    }
  }

  static Future<List<dynamic>> getPromotions() async {
    try {
      AppLogger.api('GET', '/promotions/');
      final response = await http.get(Uri.parse('$baseUrl/promotions/')).timeout(_timeout);
      
      AppLogger.api('GET', '/promotions/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.success('Fetched ${data.length} promotions');
        return data;
      }
    } on SocketException {
      AppLogger.error('Network error while fetching promotions');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Request timeout while fetching promotions');
      throw TimeoutException();
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching promotions', error: e, stackTrace: stackTrace);
    }
    return [];
  }

  // --- GENERIC METHODS ---

  static Future<dynamic> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/$endpoint'),
        headers: headers,
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw AuthenticationException('Session expired');
      } else {
        throw ApiException('GET $endpoint failed', statusCode: response.statusCode);
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: headers,
        body: json.encode(data),
      ).timeout(_timeout);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw AuthenticationException('Session expired');
      } else {
        throw ApiException('POST $endpoint failed', statusCode: response.statusCode);
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/$endpoint'),
        headers: headers,
        body: json.encode(data),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw ApiException('PUT $endpoint failed', statusCode: response.statusCode);
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> delete(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/$endpoint'),
        headers: headers,
      ).timeout(_timeout);
      
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ApiException('DELETE $endpoint failed', statusCode: response.statusCode);
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- STUDY GROUPS ---

  static Future<Map<String, dynamic>?> createStudyGroup(String name, String courseCode, String description) async {
    try {
      AppLogger.api('POST', '/study-groups/');
      final response = await http.post(
        Uri.parse('$baseUrl/study-groups/'),
        headers: await _getHeaders(),
        body: json.encode({
          'name': name,
          'course_code': courseCode,
          'description': description,
        }),
      ).timeout(_timeout);

      AppLogger.api('POST', '/api/study-groups/', statusCode: response.statusCode);

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error creating study group', error: e);
      return null;
    }
  }

  static Future<List<dynamic>> getStudyGroups() async {
    try {
      AppLogger.api('GET', '/study-groups/');
      final response = await http.get(Uri.parse('$baseUrl/study-groups/'), headers: await _getHeaders()).timeout(_timeout);
      AppLogger.api('GET', '/study-groups/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) return json.decode(response.body);
      if (response.statusCode == 401) throw AuthenticationException('Session expired');
      
      throw ApiException('Failed to load study groups', statusCode: response.statusCode);
    } catch (e) {
      AppLogger.error('Error fetching study groups', error: e);
      rethrow;
    }
  }

  static Future<bool> joinStudyGroup(int groupId) async {
    try {
      AppLogger.api('POST', '/study-groups/$groupId/join/');
      final response = await http.post(Uri.parse('$baseUrl/study-groups/$groupId/join/'), headers: await _getHeaders()).timeout(_timeout);
      AppLogger.api('POST', '/study-groups/$groupId/join/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) return true;
      if (response.statusCode == 401) throw AuthenticationException('Session expired');
      
      return false;
    } catch (e) {
      AppLogger.error('Error joining study group', error: e);
      rethrow;
    }
  }

  static Future<bool> leaveStudyGroup(int groupId) async {
    try {
      AppLogger.api('POST', '/study-groups/$groupId/leave/');
      final response = await http.post(Uri.parse('$baseUrl/study-groups/$groupId/leave/'), headers: await _getHeaders()).timeout(_timeout);
      AppLogger.api('POST', '/study-groups/$groupId/leave/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) return true;
      if (response.statusCode == 401) throw AuthenticationException('Session expired');
      
      return false;
    } catch (e) {
      AppLogger.error('Error leaving study group', error: e);
      rethrow;
    }
  }

  static Future<List<dynamic>> getGroupMessages(int groupId) async {
    try {
      AppLogger.api('GET', '/study-groups/$groupId/messages/');
      final response = await http.get(Uri.parse('$baseUrl/study-groups/$groupId/messages/'), headers: await _getHeaders()).timeout(_timeout);
      AppLogger.api('GET', '/study-groups/$groupId/messages/', statusCode: response.statusCode);
      
      if (response.statusCode == 200) return json.decode(response.body);
      if (response.statusCode == 401) throw AuthenticationException('Session expired');
      
      return [];
    } catch (e) {
      AppLogger.error('Error fetching group messages', error: e);
      rethrow;
    }
  }

  static Future<List<dynamic>> getUserAchievements() async {
    try {
      AppLogger.api('GET', '/user-achievements/');
      final response = await http.get(Uri.parse('$baseUrl/user-achievements/'), headers: await _getHeaders()).timeout(_timeout);
      AppLogger.api('GET', '/user-achievements/', statusCode: response.statusCode);
      if (response.statusCode == 200) return json.decode(response.body);
      return [];
    } catch (e) {
      AppLogger.error('Error fetching achievements', error: e);
      return [];
    }
  }
}