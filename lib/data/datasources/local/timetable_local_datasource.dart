import 'dart:convert';
import '../../../core/storage/local_storage.dart';
import '../../../core/storage/storage_keys.dart';
import '../../models/timetable_model.dart';
import '../../../utils/app_logger.dart';

/// Local data source for Timetable features (Offline support)
class TimetableLocalDataSource {
  final LocalStorage _localStorage;
  static const String _timetableCacheKey = 'cached_timetable';

  TimetableLocalDataSource(this._localStorage);

  /// Get cached timetable
  Future<List<TimetableModel>> getLastTimetable() async {
    try {
      final jsonString = LocalStorage.getItem<String>(StorageKeys.timetableBox, _timetableCacheKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        return jsonList
            .map((json) => TimetableModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      AppLogger.error('Error reading cached timetable', error: e);
      return [];
    }
  }

  /// Cache timetable (Replaces entire cache)
  Future<void> cacheTimetable(List<TimetableModel> items) async {
    try {
      final jsonList = items.map((item) => item.toJson()).toList();
      await LocalStorage.setItem(StorageKeys.timetableBox, _timetableCacheKey, json.encode(jsonList));
    } catch (e) {
      AppLogger.error('Error caching timetable', error: e);
    }
  }

  /// Update/Sync specific items in the timetable
  Future<void> saveTimetable(List<TimetableModel> newItems) async {
    try {
      final existingItems = await getLastTimetable();
      final Map<int, TimetableModel> itemMap = {
        for (var item in existingItems) item.id: item
      };

      for (var newItem in newItems) {
        itemMap[newItem.id] = newItem;
      }

      await cacheTimetable(itemMap.values.toList());
    } catch (e) {
      AppLogger.error('Error saving timetable items', error: e);
    }
  }

  /// Clear cache
  Future<void> clearCache() async {
    await LocalStorage.deleteItem(StorageKeys.timetableBox, _timetableCacheKey);
  }
}
