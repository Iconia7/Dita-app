import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../../core/network/network_info.dart';
import '../../utils/app_logger.dart';
import '../datasources/local/timetable_local_datasource.dart';
import '../datasources/remote/timetable_remote_datasource.dart';
import '../models/timetable_model.dart';

/// Repository for Timetable features
class TimetableRepository {
  final TimetableRemoteDataSource remoteDataSource;
  final TimetableLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  TimetableRepository({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  /// Get timetable (all entries)
  Future<Either<Failure, List<TimetableModel>>> getTimetable() async {
    // ALWAYS check local cache first (portal-synced data lives here)
    try {
      final localItems = await localDataSource.getLastTimetable();
      if (localItems.isNotEmpty) {
        AppLogger.success('Loaded ${localItems.length} items from cache');
        return Either.right(localItems);
      }
    } catch (e) {
      AppLogger.debug('No cached timetable found');
    }

    // If cache is empty AND we have internet, try backend
    if (await networkInfo.isConnected) {
      try {
        final remoteItems = await remoteDataSource.getTimetable();
        await localDataSource.cacheTimetable(remoteItems);
        return Either.right(remoteItems);
      } catch (e) {
        AppLogger.error('Remote fetch failed', error: e);
        return Either.left(ServerFailure('Failed to fetch timetable from server'));
      }
    } else {
      return Either.left(NetworkFailure('No internet and no cached timetable'));
    }
  }

  /// Save timetable items manually (e.g. from portal sync)
  Future<Either<Failure, void>> saveTimetable(List<TimetableModel> items) async {
    try {
      await localDataSource.saveTimetable(items);
      return const Either.right(null);
    } catch (e) {
      return Either.left(CacheFailure('Failed to save timetable locally'));
    }
  }

  /// Clear all timetable data from local cache
  Future<Either<Failure, void>> clearTimetable() async {
    try {
      await localDataSource.clearCache();
      return const Either.right(null);
    } catch (e) {
      return Either.left(CacheFailure('Failed to clear timetable'));
    }
  }

  /// Get exams filtered by course codes (Offline-First)
  Future<Either<Failure, List<TimetableModel>>> getExamsByCodes(List<String> codes) async {
    // 1. Check local cache first
    try {
      final localItems = await localDataSource.getCachedExams();
      if (localItems.isNotEmpty) {
        // If we have codes, filter by them
        if (codes.isNotEmpty) {
          final filtered = localItems.where((e) {
            final cleanCode = e.code?.replaceAll(' ', '').toUpperCase() ?? "";
            return codes.any((c) => cleanCode.contains(c.replaceAll(' ', '').toUpperCase()));
          }).toList();
          
          if (filtered.isNotEmpty) return Either.right(filtered);
        } else {
          return Either.right(localItems);
        }
      }
    } catch (e) {
      AppLogger.debug('No cached exams found');
    }

    // 2. Fetch from remote if connected
    if (await networkInfo.isConnected) {
      try {
        final remoteItems = await remoteDataSource.getExamsByCodes(codes);
        
        // Update cache with these personalized exams
        await localDataSource.cacheExams(remoteItems);
        
        return Either.right(remoteItems);
      } catch (e) {
        return Either.left(ServerFailure('Failed to fetch personalized exams'));
      }
    } else {
      return Either.left(NetworkFailure('No internet connection and no cached exams'));
    }
  }
}
