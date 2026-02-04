import '../../models/announcement_model.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/storage/storage_keys.dart';
import '../../../utils/app_logger.dart';

/// Local data source for announcements using Hive
class AnnouncementLocalDataSource {
  final LocalStorage _storage;

  AnnouncementLocalDataSource(this._storage);

  /// Cache list of announcements
  Future<void> cacheAnnouncements(List<AnnouncementModel> items) async {
    try {
      final jsonList = items.map((item) => item.toJson()).toList();
      await _storage.put(StorageKeys.announcementsBox, StorageKeys.cachedAnnouncements, jsonList);
      await _storage.put(
        StorageKeys.announcementsBox,
        StorageKeys.announcementsTimestamp,
        DateTime.now().toIso8601String(),
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error caching announcements', error: e, stackTrace: stackTrace);
    }
  }

  /// Get cached announcements
  Future<List<AnnouncementModel>?> getCachedAnnouncements() async {
    try {
      final jsonList = await _storage.get<List>(
        StorageKeys.announcementsBox,
        StorageKeys.cachedAnnouncements,
      );

      if (jsonList == null) return null;

      // Check expiry (24h)
      final timestamp = await _storage.get<String>(
        StorageKeys.announcementsBox,
        StorageKeys.announcementsTimestamp,
      );
      
      if (timestamp != null) {
        final cachedTime = DateTime.parse(timestamp);
        if (DateTime.now().difference(cachedTime).inHours > 24) {
          return null; // Expired
        }
      }

      return jsonList
          .map((json) => AnnouncementModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Error retrieving cached announcements', error: e, stackTrace: stackTrace);
      return null;
    }
  }
}
