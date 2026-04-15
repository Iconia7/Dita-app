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
        (items) async {
          state = AsyncValue.data(items);
          SchedulerService.scheduleTimetableNotifications(items);
          
          // Get cached exams to ensure widget shows them if present
          final exams = await _repository.localDataSource.getCachedExams();
          HomeWidgetService.updateWidget(items, exams: exams);
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

  /// Clear all timetable data
  Future<void> clearTimetable() async {
    await _repository.clearTimetable();
    state = const AsyncValue.data([]);
    // Clear scheduled notifications and widget
    SchedulerService.scheduleTimetableNotifications([]);
    HomeWidgetService.updateWidget([], exams: []);
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
      // Seed immediately from cache so the screen is never blank
      final cached = await _repository.localDataSource.getCachedExams();
      if (cached.isNotEmpty) {
        final filteredCache = cached.where((e) {
          final cleanCode = e.code?.replaceAll(' ', '').toUpperCase() ?? '';
          return codes.any((c) => cleanCode.contains(c.replaceAll(' ', '').toUpperCase()));
        }).toList();
        // Show cache immediately (don't set loading — avoids spinner flash)
        if (filteredCache.isNotEmpty) {
          state = AsyncValue.data(filteredCache);
        } else {
          state = const AsyncValue.loading();
        }
      } else {
        state = const AsyncValue.loading();
      }

      // Fetch fresh data in the background (or offline fallback)
      final result = await _repository.getExamsByCodes(codes);

      result.fold(
        (failure) {
          // Only overwrite with error if we have nothing to show
          if (state is! AsyncData || (state as AsyncData).value.isEmpty) {
            state = AsyncValue.error(failure.message, StackTrace.current);
          }
        },
        (items) async {
          state = AsyncValue.data(items);

          // Trigger widget update with both classes and newest exams
          final timetable = await _repository.localDataSource.getLastTimetable();
          HomeWidgetService.updateWidget(timetable, exams: items);
        },
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
