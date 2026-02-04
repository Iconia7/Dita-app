import '../models/event_model.dart';
import '../datasources/remote/event_remote_datasource.dart';
import '../datasources/local/event_local_datasource.dart';
import '../../core/network/network_info.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../utils/app_logger.dart';

/// Repository for events with offline-first capabilities
/// 
/// Pattern:
/// 1. Check network connectivity
/// 2. If online: fetch from remote, cache locally
/// 3. If offline: return cached data
/// 4. Handle errors and return Either<Failure, Data>
class EventRepository {
  final EventRemoteDataSource remoteDataSource;
  final EventLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  EventRepository({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  /// Get all events (offline-first)
  Future<Either<Failure, List<EventModel>>> getEvents() async {
    try {
      final isConnected = await networkInfo.isConnected;

      if (isConnected) {
        try {
          // Fetch from remote
          final events = await remoteDataSource.getEvents();
          
          // Cache locally
          await localDataSource.cacheEvents(events);
          
          AppLogger.success('Fetched ${events.length} events from remote');
          return Right(events);
        } catch (e) {
          AppLogger.warning('Remote fetch failed, falling back to cache');
          
          // Fallback to cache if remote fails
          final cachedEvents = await localDataSource.getCachedEvents();
          if (cachedEvents != null && cachedEvents.isNotEmpty) {
            return Right(cachedEvents);
          }
          
          return Left(ServerFailure('Failed to fetch events'));
        }
      } else {
        // Offline: return cached data
        AppLogger.info('Offline mode: using cached events');
        final cachedEvents = await localDataSource.getCachedEvents();
        
        if (cachedEvents != null && cachedEvents.isNotEmpty) {
          return Right(cachedEvents);
        }
        
        return Left(NetworkFailure('No internet connection and no cached data'));
      }
    } catch (e, stackTrace) {
      AppLogger.error('Repository error getting events', error: e, stackTrace: stackTrace);
      return Left(UnknownFailure('Unexpected error: $e'));
    }
  }

  /// RSVP to an event (online only)
  Future<Either<Failure, bool>> rsvpEvent(int eventId) async {
    try {
      final isConnected = await networkInfo.isConnected;

      if (!isConnected) {
        return Left(NetworkFailure('Cannot RSVP while offline'));
      }

      final success = await remoteDataSource.rsvpEvent(eventId);
      
      if (success) {
        // Invalidate cache to force refresh
        await localDataSource.clearCache();
        return const Right(true);
      }
      
      return Left(ServerFailure('Failed to RSVP'));
    } catch (e, stackTrace) {
      AppLogger.error('Repository error RSVP event', error: e, stackTrace: stackTrace);
      return Left(UnknownFailure('Unexpected error: $e'));
    }
  }

  /// Mark attendance for event (online only)
  Future<Either<Failure, Map<String, dynamic>>> markAttendance(int eventId) async {
    try {
      final isConnected = await networkInfo.isConnected;

      if (!isConnected) {
        return Left(NetworkFailure('Cannot mark attendance while offline'));
      }

      final result = await remoteDataSource.markAttendance(eventId);
      
      if (result != null) {
        // Invalidate cache
        await localDataSource.clearCache();
        return Right(result);
      }
      
      return Left(ServerFailure('Failed to mark attendance'));
    } catch (e, stackTrace) {
      AppLogger.error('Repository error marking attendance', error: e, stackTrace: stackTrace);
      return Left(UnknownFailure('Unexpected error: $e'));
    }
  }

  /// Get attendance history for a user (online only for now)
  Future<Either<Failure, List<EventModel>>> getAttendanceHistory(int userId) async {
    try {
      final isConnected = await networkInfo.isConnected;

      if (!isConnected) {
        return Left(NetworkFailure('Internet connection required for history'));
      }

      final events = await remoteDataSource.getEvents(attendedBy: userId);
      return Right(events);
    } catch (e, stackTrace) {
      AppLogger.error('Repository error getting attendance history', error: e, stackTrace: stackTrace);
      return Left(UnknownFailure('Failed to load history'));
    }
  }

  /// Clear local cache
  Future<void> clearCache() async {
    await localDataSource.clearCache();
  }
}
