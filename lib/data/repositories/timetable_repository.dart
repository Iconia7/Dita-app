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
    // 1. Always check local cache first
    List<TimetableModel> cachedExams = [];
    try {
      cachedExams = await localDataSource.getCachedExams();
    } catch (e) {
      AppLogger.debug('No cached exams found');
    }

    // 2. If online, fetch fresh data and merge into cache
    if (await networkInfo.isConnected) {
      try {
        final remoteItems = await remoteDataSource.getExamsByCodes(codes);

        // Merge: keep cached exams for other codes, update/add new ones
        final Map<String, TimetableModel> mergedMap = {
          for (var e in cachedExams) (e.code ?? e.id.toString()): e,
        };
        for (var e in remoteItems) {
          mergedMap[e.code ?? e.id.toString()] = e;
        }
        final merged = mergedMap.values.toList();
        await localDataSource.cacheExams(merged);

        // Return filtered to the requested codes
        if (codes.isNotEmpty) {
          final filtered = merged.where((e) {
            final cleanCode = e.code?.replaceAll(' ', '').toUpperCase() ?? '';
            final cleanTitle = e.title.replaceAll(' ', '').toUpperCase();
            return codes.any((c) {
              // Standardize: Remove spaces, dashes, etc.
              final check = c.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
              // Bidirectional check: handles NUR-120R vs NUR120 and ACS 441 A vs ACS441
              return cleanCode.contains(check) || check.contains(cleanCode) || cleanTitle.contains(check);
            });
          }).toList();
          return Either.right(filtered);
        }
        return Either.right(merged);
      } catch (e) {
        AppLogger.error('Remote exam fetch failed, falling back to cache', error: e);
        // Fall through to return cache below
      }
    }

    // 3. Offline (or remote failed) — return whatever we have in cache
    if (cachedExams.isNotEmpty) {
      if (codes.isNotEmpty) {
        final filtered = cachedExams.where((e) {
          final cleanCode = e.code?.replaceAll(' ', '').toUpperCase() ?? '';
          final cleanTitle = e.title.replaceAll(' ', '').toUpperCase();
          return codes.any((c) {
            final check = c.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
            return cleanCode.contains(check) || check.contains(cleanCode) || cleanTitle.contains(check);
          });
        }).toList();
        // Return filtered if we matched something, otherwise return full cache
        return Either.right(filtered.isNotEmpty ? filtered : cachedExams);
      }
      return Either.right(cachedExams);
    }

    return Either.left(NetworkFailure('No internet connection and no cached exams'));
  }
}
