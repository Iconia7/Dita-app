import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dita_app/core/storage/local_storage.dart';
import 'package:dita_app/core/storage/storage_keys.dart';
import 'package:dita_app/data/models/user_model.dart';
import 'package:dita_app/utils/app_logger.dart';

/// Local data source for User data
/// Handles caching user data in Hive
class UserLocalDataSource {
  /// Cache user data
  Future<void> cacheUser(UserModel user) async {
    try {
      final userJson = user.toJson();
      await LocalStorage.setItem(
        StorageKeys.userBox,
        StorageKeys.currentUser,
        json.encode(userJson),
      );
      AppLogger.debug('User cached successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Error caching user', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get cached user
  Future<UserModel?> getCachedUser() async {
    try {
      final userString = LocalStorage.getItem<String>(
        StorageKeys.userBox,
        StorageKeys.currentUser,
      );

      if (userString == null) {
        AppLogger.debug('No cached user in Hive. Checking legacy storage...');
        return await _migrateLegacyData();
      }

      final userJson = json.decode(userString) as Map<String, dynamic>;
      final user = UserModel.fromJson(userJson);
      AppLogger.debug('Cached user retrieved: ${user.username}');
      return user;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting cached user', 
        error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Check for legacy data and migrate to Hive if exists
  Future<UserModel?> _migrateLegacyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('user_data');
      
      if (userStr != null) {
        AppLogger.info('Found legacy user data in SharedPreferences. Migrating to Hive...');
        final userJson = json.decode(userStr) as Map<String, dynamic>;
        final user = UserModel.fromJson(userJson);
        
        // Cache in Hive
        await cacheUser(user);
        
        // Migrate tokens if they exist in the map
        if (user.accessToken != null) await saveAccessToken(user.accessToken!);
        if (user.refreshToken != null) await saveRefreshToken(user.refreshToken!);
        
        AppLogger.success('Migration successful');
        return user;
      }
    } catch (e) {
      AppLogger.error('Error migrating legacy data', error: e);
    }
    return null;
  }

  /// Clear cached user (logout)
  Future<void> clearCache() async {
    try {
      await LocalStorage.deleteItem(StorageKeys.userBox, StorageKeys.currentUser);
      await LocalStorage.deleteItem(StorageKeys.userBox, StorageKeys.accessToken);
      await LocalStorage.deleteItem(StorageKeys.userBox, StorageKeys.refreshToken);
      AppLogger.info('User cache cleared');
    } catch (e, stackTrace) {
      AppLogger.error('Error clearing user cache', 
        error: e, stackTrace: stackTrace);
    }
  }

  /// Save access token
  Future<void> saveAccessToken(String token) async {
    await LocalStorage.setItem(StorageKeys.userBox, StorageKeys.accessToken, token);
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    return LocalStorage.getItem<String>(StorageKeys.userBox, StorageKeys.accessToken);
  }

  /// Save refresh token
  Future<void> saveRefreshToken(String token) async {
    await LocalStorage.setItem(StorageKeys.userBox, StorageKeys.refreshToken, token);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    return LocalStorage.getItem<String>(StorageKeys.userBox, StorageKeys.refreshToken);
  }
}
