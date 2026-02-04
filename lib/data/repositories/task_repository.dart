import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../../core/network/network_info.dart';
import '../../utils/app_logger.dart';
import '../datasources/local/task_local_datasource.dart';
import '../datasources/remote/task_remote_datasource.dart';
import '../models/task_model.dart';

/// Repository for Task features
class TaskRepository {
  final TaskRemoteDataSource remoteDataSource;
  final TaskLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  TaskRepository({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  /// Get all tasks
  Future<Either<Failure, List<TaskModel>>> getTasks() async {
    if (await networkInfo.isConnected) {
      try {
        final remoteTasks = await remoteDataSource.getTasks();
        await localDataSource.cacheTasks(remoteTasks);
        return Either.right(remoteTasks);
      } catch (e) {
        AppLogger.error('Remote fetch failed, checking cache', error: e);
        try {
          final localTasks = await localDataSource.getLastTasks();
          return Either.right(localTasks);
        } catch (cacheError) {
          return Either.left(CacheFailure('Failed to retrieve cached tasks'));
        }
      }
    } else {
      try {
        final localTasks = await localDataSource.getLastTasks();
        return Either.right(localTasks);
      } catch (cacheError) {
        return Either.left(CacheFailure('No internet and no cached tasks'));
      }
    }
  }

  /// Create a new task
  Future<Either<Failure, TaskModel>> createTask(Map<String, dynamic> taskData) async {
    if (await networkInfo.isConnected) {
      try {
        final newTask = await remoteDataSource.createTask(taskData);
        return Either.right(newTask);
      } catch (e) {
        return Either.left(ServerFailure('Failed to create task: ${e.toString()}'));
      }
    } else {
      return Either.left(NetworkFailure('No internet connection'));
    }
  }

  /// Update a task
  Future<Either<Failure, TaskModel>> updateTask(int id, Map<String, dynamic> updates) async {
    if (await networkInfo.isConnected) {
      try {
        final updatedTask = await remoteDataSource.updateTask(id, updates);
        return Either.right(updatedTask);
      } catch (e) {
        return Either.left(ServerFailure('Failed to update task: ${e.toString()}'));
      }
    } else {
      return Either.left(NetworkFailure('No internet connection'));
    }
  }

  /// Delete a task
  Future<Either<Failure, bool>> deleteTask(int id) async {
    if (await networkInfo.isConnected) {
      try {
        final success = await remoteDataSource.deleteTask(id);
        return Either.right(success);
      } catch (e) {
        return Either.left(ServerFailure('Failed to delete task: ${e.toString()}'));
      }
    } else {
      return Either.left(NetworkFailure('No internet connection'));
    }
  }
}
