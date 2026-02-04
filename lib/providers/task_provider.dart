import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dita_app/core/storage/local_storage.dart';
import 'package:dita_app/data/datasources/local/task_local_datasource.dart';
import 'package:dita_app/data/datasources/remote/task_remote_datasource.dart';
import 'package:dita_app/data/repositories/task_repository.dart';
import 'package:dita_app/data/models/task_model.dart';
import 'package:dita_app/providers/auth_provider.dart';
import 'package:dita_app/providers/network_provider.dart';
import 'package:dita_app/utils/app_logger.dart';

// ========== Dependency Injection ==========

final taskLocalDataSourceProvider = Provider<TaskLocalDataSource>((ref) {
  return TaskLocalDataSource(LocalStorage());
});

final taskRemoteDataSourceProvider = Provider<TaskRemoteDataSource>((ref) {
  return TaskRemoteDataSource();
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(
    remoteDataSource: ref.watch(taskRemoteDataSourceProvider),
    localDataSource: ref.watch(taskLocalDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

// ========== State Providers ==========

class TaskNotifier extends StateNotifier<AsyncValue<List<TaskModel>>> {
  final TaskRepository _repository;

  TaskNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadTasks();
  }

  Future<void> loadTasks() async {
    try {
      state = const AsyncValue.loading();
      final result = await _repository.getTasks();
      
      result.fold(
        (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
        (tasks) => state = AsyncValue.data(tasks),
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refresh() async {
    await loadTasks();
  }

  Future<bool> createTask(Map<String, dynamic> taskData) async {
    try {
      final result = await _repository.createTask(taskData);
      
      return result.fold(
        (failure) {
          AppLogger.error(failure.message);
          return false;
        },
        (newTask) {
          final currentList = state.value ?? [];
          state = AsyncValue.data([...currentList, newTask]);
          return true;
        },
      );
    } catch (e) {
      AppLogger.error('Create task error', error: e);
      return false;
    }
  }

  Future<bool> updateTask(int id, Map<String, dynamic> updates) async {
    try {
      // Optimistic update for checkbox toggles (is_completed)
      final currentState = state.value;
      if (currentState != null && updates.containsKey('is_completed')) {
        final index = currentState.indexWhere((t) => t.id == id);
        if (index != -1) {
          final updatedList = List<TaskModel>.from(currentState);
          updatedList[index] = updatedList[index].copyWith(
            isCompleted: updates['is_completed'] as bool,
          );
          state = AsyncValue.data(updatedList);
        }
      }

      final result = await _repository.updateTask(id, updates);
      
      return result.fold(
        (failure) {
          AppLogger.error(failure.message);
          // Revert optimistic update if needed? For now, just refresh
          refresh(); 
          return false;
        },
        (updatedTask) {
          // Confirm update with server data
          final currentList = state.value ?? [];
          final index = currentList.indexWhere((t) => t.id == id);
          if (index != -1) {
            final updatedList = List<TaskModel>.from(currentList);
            updatedList[index] = updatedTask;
            state = AsyncValue.data(updatedList);
          }
          return true;
        },
      );
    } catch (e) {
      AppLogger.error('Update task error', error: e);
      refresh(); // Revert on error
      return false;
    }
  }

  Future<bool> deleteTask(int id) async {
    try {
      final result = await _repository.deleteTask(id);
      
      return result.fold(
        (failure) {
          AppLogger.error(failure.message);
          return false;
        },
        (success) {
          if (success) {
            final currentList = state.value ?? [];
            state = AsyncValue.data(currentList.where((t) => t.id != id).toList());
          }
          return success;
        },
      );
    } catch (e) {
      AppLogger.error('Delete task error', error: e);
      return false;
    }
  }
}

final taskProvider = StateNotifierProvider<TaskNotifier, AsyncValue<List<TaskModel>>>((ref) {
  return TaskNotifier(ref.watch(taskRepositoryProvider));
});
