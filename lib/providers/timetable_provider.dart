import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dita_app/core/storage/local_storage.dart';
import 'package:dita_app/data/datasources/local/timetable_local_datasource.dart';
import 'package:dita_app/data/datasources/remote/timetable_remote_datasource.dart';
import 'package:dita_app/data/repositories/timetable_repository.dart';
import 'package:dita_app/data/models/timetable_model.dart';
import 'package:dita_app/providers/auth_provider.dart';
import 'package:dita_app/providers/network_provider.dart';
import 'package:dita_app/services/scheduler_service.dart';
import 'package:dita_app/services/home_widget_service.dart';

// ========== Dependency Injection ==========

final timetableLocalDataSourceProvider = Provider<TimetableLocalDataSource>((ref) {
  return TimetableLocalDataSource(LocalStorage());
});

final timetableRemoteDataSourceProvider = Provider<TimetableRemoteDataSource>((ref) {
  return TimetableRemoteDataSource();
});

final timetableRepositoryProvider = Provider<TimetableRepository>((ref) {
  return TimetableRepository(
    remoteDataSource: ref.watch(timetableRemoteDataSourceProvider),
    localDataSource: ref.watch(timetableLocalDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

// ========== State Providers ==========

class TimetableNotifier extends StateNotifier<AsyncValue<List<TimetableModel>>> {
  final TimetableRepository _repository;

  TimetableNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadTimetable();
  }

  Future<void> loadTimetable() async {
    try {
      state = const AsyncValue.loading();
      final result = await _repository.getTimetable();
      
      result.fold(
        (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
        (items) {
          state = AsyncValue.data(items);
          SchedulerService.scheduleTimetableNotifications(items);
          HomeWidgetService.updateWidget(items);
        },
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refresh() async {
    await loadTimetable();
  }

  Future<void> loadPersonalizedExams(List<String> codes) async {
    try {
      state = const AsyncValue.loading();
      final result = await _repository.getExamsByCodes(codes);
      
      result.fold(
        (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
        (items) => state = AsyncValue.data(items),
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> saveTimetable(List<TimetableModel> items) async {
    final result = await _repository.saveTimetable(items);
    return result.fold(
      (failure) {
        // AppLogger.error('Failed to save entries: ${failure.message}'); // Assuming AppLogger is defined elsewhere
        return false;
      },
      (_) {
        loadTimetable(); // Refresh local state
        return true;
      },
    );
  }
}

class ExamsNotifier extends StateNotifier<AsyncValue<List<TimetableModel>>> {
  final TimetableRepository _repository;

  ExamsNotifier(this._repository) : super(const AsyncValue.loading());

  Future<void> fetchExams(List<String> codes) async {
    if (codes.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      state = const AsyncValue.loading();
      final result = await _repository.getExamsByCodes(codes);
      
      result.fold(
        (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
        (items) => state = AsyncValue.data(items),
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final examsProvider = StateNotifierProvider<ExamsNotifier, AsyncValue<List<TimetableModel>>>((ref) {
  return ExamsNotifier(ref.watch(timetableRepositoryProvider));
});

final timetableProvider = StateNotifierProvider<TimetableNotifier, AsyncValue<List<TimetableModel>>>((ref) {
  return TimetableNotifier(ref.watch(timetableRepositoryProvider));
});
