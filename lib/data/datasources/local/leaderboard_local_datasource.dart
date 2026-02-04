import '../../models/leaderboard_model.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/storage/storage_keys.dart';
import '../../../utils/app_logger.dart';

/// Local data source for leaderboard using Hive
class LeaderboardLocalDataSource {
  // LocalStorage is static, so we don't need an instance
  LeaderboardLocalDataSource();

  /// Cache leaderboard rankings
  Future<void> cacheLeaderboard(List<LeaderboardModel> leaderboard) async {
    try {
      final jsonList = leaderboard.map((entry) => entry.toJson()).toList();
      await LocalStorage.setItem(StorageKeys.leaderboardBox, StorageKeys.leaderboardCacheKey, jsonList);
      await LocalStorage.setItem(
        StorageKeys.leaderboardBox,
        'leaderboard_timestamp',
        DateTime.now().toIso8601String(),
      );
      AppLogger.success('Cached ${leaderboard.length} leaderboard entries locally');
    } catch (e, stackTrace) {
      AppLogger.error('Error caching leaderboard', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get cached leaderboard
  Future<List<LeaderboardModel>?> getCachedLeaderboard() async {
    try {
      final jsonList = LocalStorage.getItem<List>(
        StorageKeys.leaderboardBox,
        'cached_leaderboard',
      );

      if (jsonList == null) {
        AppLogger.info('No cached leaderboard found');
        return null;
      }

      // Check if cache is expired
      if (await _isCacheExpired()) {
        AppLogger.info('Leaderboard cache expired');
        await clearCache();
        return null;
      }

      final leaderboard = jsonList
          .map((json) => LeaderboardModel.fromJson(json as Map<String, dynamic>))
          .toList();
      AppLogger.success('Retrieved ${leaderboard.length} cached leaderboard entries');
      return leaderboard;
    } catch (e, stackTrace) {
      AppLogger.error('Error retrieving cached leaderboard', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Clear leaderboard cache
  Future<void> clearCache() async {
    try {
      await LocalStorage.deleteItem(StorageKeys.leaderboardBox, StorageKeys.leaderboardCacheKey);
      await LocalStorage.deleteItem(StorageKeys.leaderboardBox, StorageKeys.leaderboardTimestamp);
      AppLogger.info('Leaderboard cache cleared');
    } catch (e, stackTrace) {
      AppLogger.error('Error clearing leaderboard cache', error: e, stackTrace: stackTrace);
    }
  }

  /// Check if cache is expired (1 hour for leaderboard)
  Future<bool> _isCacheExpired() async {
    final timestamp = LocalStorage.getItem<String>(
      StorageKeys.leaderboardBox,
      'leaderboard_timestamp',
    );

    if (timestamp == null) return true;

    final cachedTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(cachedTime);

    // Leaderboard cache expires faster (1 hour) since it changes frequently
    return difference > const Duration(hours: 1);
  }
}
