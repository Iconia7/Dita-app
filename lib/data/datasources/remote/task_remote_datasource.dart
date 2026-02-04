import 'dart:async';
import '../../models/task_model.dart';
import '../../../services/api_service.dart';
import '../../../core/errors/exceptions.dart';
import '../../../utils/app_logger.dart';

/// Remote data source for Task features
class TaskRemoteDataSource {
  /// Fetch all tasks
  Future<List<TaskModel>> getTasks() async {
    try {
      final jsonList = await ApiService.get('tasks/');
      final tasks = (jsonList as List)
          .map((json) => TaskModel.fromJson(json as Map<String, dynamic>))
          .toList();
      AppLogger.success('Parsed ${tasks.length} tasks');
      return tasks;
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error parsing tasks', error: e, stackTrace: stackTrace);
      throw DataParsingException('Failed to parse tasks data');
    }
  }

  /// Create a new task
  Future<TaskModel> createTask(Map<String, dynamic> taskData) async {
    try {
      final json = await ApiService.post('tasks/', taskData);
      return TaskModel.fromJson(json as Map<String, dynamic>);
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error creating task', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to create task');
    }
  }

  /// Update a task
  Future<TaskModel> updateTask(int id, Map<String, dynamic> updates) async {
    try {
      final json = await ApiService.put('tasks/$id/', updates);
      return TaskModel.fromJson(json as Map<String, dynamic>);
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error updating task', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to update task');
    }
  }

  /// Delete a task
  Future<bool> deleteTask(int id) async {
    try {
      await ApiService.delete('tasks/$id/');
      return true;
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting task', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to delete task');
    }
  }
}
