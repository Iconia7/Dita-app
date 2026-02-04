import 'package:hive_flutter/hive_flutter.dart';
import '../../utils/app_logger.dart';
import 'storage_keys.dart';

/// Centralized local storage service using Hive
/// Replaces scattered SharedPreferences calls with a unified interface
class LocalStorage {
  // Allow instantiation for dependency injection
  LocalStorage(); 
  
  // Static instance for direct access if needed
  static final LocalStorage _instance = LocalStorage();
  static LocalStorage get instance => _instance;

  // Instance method wrappers for backward compatibility/DI
  T? get<T>(String boxName, String key) => LocalStorage.getItem<T>(boxName, key);
  
  Future<void> put(String boxName, String key, dynamic value) => LocalStorage.setItem(boxName, key, value);

  Future<void> delete(String boxName, String key) => LocalStorage.deleteItem(boxName, key);
  
  Future<void> clearBox(String boxName) => LocalStorage.clearBoxItem(boxName);

  static bool _initialized = false;

  /// Initialize Hive and register adapters
  static Future<void> init() async {
    if (_initialized) return;

    try {
      await Hive.initFlutter();
      AppLogger.info('Hive initialized successfully');

      // Open boxes
      await _openBoxes();

      _initialized = true;
      AppLogger.success('Local storage initialized');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize local storage', 
        error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Open all Hive boxes
  static Future<void> _openBoxes() async {
    final boxes = [
      StorageKeys.userBox,
      StorageKeys.eventsBox,
      StorageKeys.announcementsBox, // NEW
      StorageKeys.postsBox,
      StorageKeys.tasksBox,
      StorageKeys.timetableBox,

      StorageKeys.settingsBox,
      StorageKeys.leaderboardBox,
      StorageKeys.resourcesBox,
    ];

    for (final boxName in boxes) {
      try {
        await Hive.openBox(boxName);
        AppLogger.debug('Opened box: $boxName');
      } catch (e) {
        AppLogger.warning('Failed to open box: $boxName'); // Removed error param if incompatible
      }
    }
  }

  /// Get a value from a specific box (Static)
  static T? getItem<T>(String boxName, String key) {
    try {
      final box = Hive.box(boxName);
      return box.get(key) as T?;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting value from $boxName:$key', 
        error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Put a value into a specific box (Static)
  static Future<void> setItem(String boxName, String key, dynamic value) async {
    try {
      final box = Hive.box(boxName);
      await box.put(key, value);
      AppLogger.debug('Saved to $boxName:$key');
    } catch (e, stackTrace) {
      AppLogger.error('Error saving to $boxName:$key', 
        error: e, stackTrace: stackTrace);
    }
  }

  /// Delete a value from a specific box (Static)
  static Future<void> deleteItem(String boxName, String key) async {
    try {
      final box = Hive.box(boxName);
      await box.delete(key);
      AppLogger.debug('Deleted from $boxName:$key');
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting from $boxName:$key', 
        error: e, stackTrace: stackTrace);
    }
  }

  /// Clear all data from a specific box (Static)
  static Future<void> clearBoxItem(String boxName) async {
    try {
      final box = Hive.box(boxName);
      await box.clear();
      AppLogger.info('Cleared box: $boxName');
    } catch (e, stackTrace) {
      AppLogger.error('Error clearing box: $boxName', 
        error: e, stackTrace: stackTrace);
    }
  }

  /// Check if a key exists in a box (Static)
  static bool hasKey(String boxName, String key) {
    try {
      final box = Hive.box(boxName);
      return box.containsKey(key);
    } catch (e) {
      AppLogger.error('Error checking key in $boxName:$key', error: e);
      return false;
    }
  }

  /// Get all keys from a box (Static)
  static Iterable<dynamic> getAllKeys(String boxName) {
    try {
      final box = Hive.box(boxName);
      return box.keys;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting keys from $boxName', 
        error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get all values from a box (Static)
  static Iterable<dynamic> getAllValues(String boxName) {
    try {
      final box = Hive.box(boxName);
      return box.values;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting values from $boxName', 
        error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Clear all boxes (Static)
  static Future<void> wipeAll() async {
    try {
      await Hive.deleteFromDisk();
      AppLogger.warning('Cleared all local storage');
    } catch (e, stackTrace) {
      AppLogger.error('Error clearing all storage', 
        error: e, stackTrace: stackTrace);
    }
  }

  /// Check if cache is expired (Static)
  static bool isCacheExpired(String timestampKey) {
    final timestamp = getItem<int>(StorageKeys.settingsBox, timestampKey);
    if (timestamp == null) return true;

    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(cacheTime).inHours;

    return difference >= StorageKeys.cacheExpiryHours;
  }

  /// Update cache timestamp (Static)
  static Future<void> updateCacheTimestamp(String timestampKey) async {
    await setItem(StorageKeys.settingsBox, timestampKey, 
      DateTime.now().millisecondsSinceEpoch);
  }
}
