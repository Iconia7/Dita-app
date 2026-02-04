import '../../models/event_model.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/storage/storage_keys.dart';
import '../../../utils/app_logger.dart';

/// Local data source for events using Hive
class EventLocalDataSource {
  final LocalStorage _storage;

  EventLocalDataSource(this._storage);

  /// Cache list of events
  Future<void> cacheEvents(List<EventModel> events) async {
    try {
      final jsonList = events.map((event) => event.toJson()).toList();
      await _storage.put(StorageKeys.eventsBox, StorageKeys.cachedEvents, jsonList);
      await _storage.put(
        StorageKeys.eventsBox,
        StorageKeys.eventsTimestamp,
        DateTime.now().toIso8601String(),
      );
      AppLogger.success('Cached ${events.length} events locally');
    } catch (e, stackTrace) {
      AppLogger.error('Error caching events', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get cached events
  Future<List<EventModel>?> getCachedEvents() async {
    try {
      final jsonList = await _storage.get<List>(
        StorageKeys.eventsBox,
        StorageKeys.cachedEvents,
      );

      if (jsonList == null) {
        AppLogger.info('No cached events found');
        return null;
      }

      // Check if cache is expired
      if (await _isCacheExpired(StorageKeys.eventsTimestamp)) {
        AppLogger.info('Events cache expired');
        await clearCache();
        return null;
      }

      final events = jsonList
          .map((json) => EventModel.fromJson(json as Map<String, dynamic>))
          .toList();
      AppLogger.success('Retrieved ${events.length} cached events');
      return events;
    } catch (e, stackTrace) {
      AppLogger.error('Error retrieving cached events', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Clear events cache
  Future<void> clearCache() async {
    try {
      await _storage.delete(StorageKeys.eventsBox, StorageKeys.cachedEvents);
      await _storage.delete(StorageKeys.eventsBox, StorageKeys.eventsTimestamp);
      AppLogger.info('Events cache cleared');
    } catch (e, stackTrace) {
      AppLogger.error('Error clearing events cache', error: e, stackTrace: stackTrace);
    }
  }

  /// Check if cache is expired (24 hours)
  Future<bool> _isCacheExpired(String timestampKey) async {
    final timestamp = await _storage.get<String>(
      StorageKeys.eventsBox,
      timestampKey,
    );

    if (timestamp == null) return true;

    final cachedTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(cachedTime);

    return difference > const Duration(hours: 24);
  }
}
