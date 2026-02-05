import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dita_app/core/storage/local_storage.dart';
import 'package:dita_app/data/datasources/local/event_local_datasource.dart';
import 'package:dita_app/data/datasources/remote/event_remote_datasource.dart';
import 'package:dita_app/data/repositories/event_repository.dart';
import 'package:dita_app/data/models/event_model.dart';
import 'package:dita_app/providers/auth_provider.dart';
import 'package:dita_app/providers/network_provider.dart';
import 'package:dita_app/utils/app_logger.dart';

// ========== Dependency Injection Providers ==========

/// Event local data source provider
final eventLocalDataSourceProvider = Provider<EventLocalDataSource>((ref) {
  return EventLocalDataSource(LocalStorage());
});

/// Event remote data source provider
final eventRemoteDataSourceProvider = Provider<EventRemoteDataSource>((ref) {
  return EventRemoteDataSource();
});

/// Event repository provider
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(
    remoteDataSource: ref.watch(eventRemoteDataSourceProvider),
    localDataSource: ref.watch(eventLocalDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

// ========== State Providers ==========

/// Event state provider
/// Manages events list with offline-first capabilities
class EventNotifier extends StateNotifier<AsyncValue<List<EventModel>>> {
  final EventRepository _repository;

  EventNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadEvents();
  }

  /// Load events (offline-first)
  Future<void> loadEvents() async {
    try {
      state = const AsyncValue.loading();
      AppLogger.info('Loading events...');

      final result = await _repository.getEvents();

      result.fold(
        (failure) {
          AppLogger.warning('Failed to load events: ${failure.message}');
          state = AsyncValue.error(failure.message, StackTrace.current);
        },
        (events) {
          AppLogger.success('Loaded ${events.length} events');
          state = AsyncValue.data(events);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error loading events', error: e, stackTrace: stackTrace);
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// RSVP to an event
  Future<Map<String, dynamic>?> rsvpEvent(int eventId) async {
    try {
      AppLogger.info('RSVP to event $eventId');

      final result = await _repository.rsvpEvent(eventId);

      return result.fold(
        (failure) {
          AppLogger.warning('RSVP failed: ${failure.message}');
          return null;
        },
        (data) {
          AppLogger.success('RSVP action: ${data['status']}');
          // Refresh events list
          loadEvents();
          return data;
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('RSVP error', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Mark attendance for an event
  Future<Map<String, dynamic>?> markAttendance(int eventId) async {
    try {
      AppLogger.info('Marking attendance for event $eventId');

      final result = await _repository.markAttendance(eventId);

      return result.fold(
        (failure) {
          AppLogger.warning('Mark attendance failed: ${failure.message}');
          return null;
        },
        (data) {
          AppLogger.success('Attendance marked');
          // Refresh events list
          loadEvents();
          return data;
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Mark attendance error', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Refresh events
  Future<void> refresh() async {
    await loadEvents();
  }
}

/// Event provider
final eventProvider =
    StateNotifierProvider<EventNotifier, AsyncValue<List<EventModel>>>((ref) {
  final repository = ref.watch(eventRepositoryProvider);
  return EventNotifier(repository);
});

/// Helper provider to get upcoming events
final upcomingEventsProvider = Provider<List<EventModel>>((ref) {
  final eventsAsync = ref.watch(eventProvider);
  return eventsAsync.maybeWhen(
    data: (events) => events.where((event) => event.isUpcoming).toList(),
    orElse: () => [],
  );
});

/// Helper provider to get past events
final pastEventsProvider = Provider<List<EventModel>>((ref) {
  final eventsAsync = ref.watch(eventProvider);
  return eventsAsync.maybeWhen(
    data: (events) => events.where((event) => event.isPast).toList(),
    orElse: () => [],
  );
});

/// Attendance History Provider
final attendanceHistoryProvider = FutureProvider.family<List<EventModel>, int>((ref, userId) async {
  final repository = ref.watch(eventRepositoryProvider);
  final result = await repository.getAttendanceHistory(userId);
  
  return result.fold(
    (failure) => throw failure.message,
    (events) => events,
  );
});
