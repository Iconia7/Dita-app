import 'dart:convert';
import '../../../core/storage/local_storage.dart';
import '../../../core/storage/storage_keys.dart';
import '../../models/task_model.dart';
import '../../../utils/app_logger.dart';

/// Local data source for Task features (Offline support)
class TaskLocalDataSource {
  final LocalStorage _localStorage;
  static const String _tasksCacheKey = 'cached_tasks';

  TaskLocalDataSource(this._localStorage);

  /// Get cached tasks
  Future<List<TaskModel>> getLastTasks() async {
    try {
      final jsonString = LocalStorage.getItem<String>(StorageKeys.tasksBox, _tasksCacheKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        return jsonList
            .map((json) => TaskModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      AppLogger.error('Error reading cached tasks', error: e);
      return [];
    }
  }

  /// Cache tasks
  Future<void> cacheTasks(List<TaskModel> tasks) async {
    try {
      final jsonList = tasks.map((task) => task.toJson()).toList();
      await LocalStorage.setItem(StorageKeys.tasksBox, _tasksCacheKey, json.encode(jsonList));
    } catch (e) {
      AppLogger.error('Error caching tasks', error: e);
    }
  }

  /// Clear task cache
  Future<void> clearCache() async {
    await LocalStorage.deleteItem(StorageKeys.tasksBox, _tasksCacheKey);
  }
}
