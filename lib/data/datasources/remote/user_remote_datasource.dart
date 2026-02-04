import 'dart:async';
import 'dart:io';
import 'package:dita_app/core/errors/exceptions.dart';
import 'package:dita_app/data/models/user_model.dart';
import 'package:dita_app/services/api_service.dart';
import 'package:dita_app/utils/app_logger.dart';

/// Remote data source for User data
/// Wraps ApiService methods with type-safe models
class UserRemoteDataSource {
  /// Login user
  Future<UserModel> login(String username, String password) async {
    try {
      AppLogger.info('Attempting login for: $username');
      
      final response = await ApiService.login(username, password);
      
      if (response == null) {
        throw AuthenticationException('Invalid credentials');
      }

      final user = UserModel.fromJson(response);
      AppLogger.success('Login successful for: ${user.username}');
      return user;
    } on AuthenticationException {
      rethrow;
    } on SocketException {
      AppLogger.error('Network error during login');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Login timeout');
      throw TimeoutException('Login request timed out');
    } catch (e, stackTrace) {
      AppLogger.error('Login error', error: e, stackTrace: stackTrace);
      throw ServerException('Login failed');
    }
  }

  /// Get user profile
  Future<UserModel> getUserProfile(int userId) async {
    try {
      AppLogger.info('Fetching user profile: $userId');
      
      final response = await ApiService.getUserDetails(userId);
      
      if (response == null) {
        throw ServerException('Failed to fetch user profile');
      }

      final user = UserModel.fromJson(response);
      AppLogger.success('User profile fetched: ${user.username}');
      return user;
    } on SocketException {
      AppLogger.error('Network error fetching user profile');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('User profile fetch timeout');
      throw TimeoutException('Request timed out');
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching user profile', 
        error: e, stackTrace: stackTrace);
      throw ServerException('Failed to fetch user profile');
    }
  }

  /// Update user
  Future<UserModel> updateUser(int userId, Map<String, dynamic> data) async {
    try {
      AppLogger.info('Updating user: $userId');
      
      await ApiService.put('users/$userId/', data);

      // Fetch updated profile to return full model
      return await getUserProfile(userId);
    } on SocketException {
      AppLogger.error('Network error updating user');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('User update timeout');
      throw TimeoutException('Update request timed out');
    } catch (e, stackTrace) {
      AppLogger.error('Error updating user', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to update user');
    }
  }

  /// Register new user
  Future<UserModel> registerUser(Map<String, dynamic> registrationData) async {
    try {
      AppLogger.info('Registering new user');
      
      final error = await ApiService.registerUser(registrationData);
      
      if (error != null) {
        throw ServerException('Failed to register user: $error');
      }

      // Auto-login to get user model
      if (registrationData.containsKey('username') && registrationData.containsKey('password')) {
         return await login(registrationData['username'], registrationData['password']);
      }

      throw ServerException('Registration successful but could not auto-login');
    } on SocketException {
      AppLogger.error('Network error during registration');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Registration timeout');
      throw TimeoutException('Registration request timed out');
    } catch (e, stackTrace) {
      AppLogger.error('Registration error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to register user');
    }
  }

  /// Change password
  Future<bool> changePassword(int userId, String oldPassword, String newPassword) async {
    try {
      AppLogger.info('Changing password for user: $userId');
      final success = await ApiService.changePassword(userId, oldPassword, newPassword);
      
      if (!success) {
        throw ServerException('Failed to change password');
      }
      AppLogger.success('Password changed successfully');
      return true;
    } on SocketException {
      AppLogger.error('Network error changing password');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Change password timeout');
      throw TimeoutException('Request timed out');
    } catch (e, stackTrace) {
      AppLogger.error('Error changing password', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to change password');
    }
  }

  /// Initiate M-Pesa payment
  Future<bool> initiatePayment(String phoneNumber, int userId) async {
    try {
      AppLogger.info('Initiating payment for user: $userId');
      final success = await ApiService.initiatePayment(phoneNumber, userId);
      
      if (!success) {
        throw ServerException('Failed to initiate payment');
      }
      AppLogger.success('Payment initiated');
      return true;
    } on SocketException {
      AppLogger.error('Network error initiating payment');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Payment initiation timeout');
      throw TimeoutException('Request timed out');
    } catch (e, stackTrace) {
      AppLogger.error('Error initiating payment', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to initiate payment');
    }
  }

  /// Upload profile picture
  Future<bool> uploadProfilePicture(int userId, File imageFile) async {
    try {
      AppLogger.info('Uploading profile picture for user: $userId');
      final success = await ApiService.uploadProfilePicture(userId, imageFile);
      if (!success) {
        throw ServerException('Failed to upload profile picture');
      }
      AppLogger.success('Profile picture uploaded');
      return true;
    } on SocketException {
      AppLogger.error('Network error uploading profile picture');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Upload timeout');
      throw TimeoutException('Request timed out');
    } catch (e, stackTrace) {
      AppLogger.error('Error uploading profile picture', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to upload profile picture');
    }
  }

  /// Update FCM token
  Future<bool> updateFcmToken(int userId, String token) async {
    try {
      AppLogger.info('Updating FCM token for user: $userId');
      await ApiService.updateFcmToken(userId, token);
      AppLogger.success('FCM token updated');
      return true;
    } on SocketException {
      AppLogger.error('Network error updating FCM token');
      throw NetworkException();
    } on TimeoutException {
      AppLogger.error('Update FCM token timeout');
      throw TimeoutException('Request timed out');
    } catch (e, stackTrace) {
      AppLogger.error('Error updating FCM token', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to update FCM token');
    }
  }
}
