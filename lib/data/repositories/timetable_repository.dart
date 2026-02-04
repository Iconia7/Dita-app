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
    if (await networkInfo.isConnected) {
      try {
        final remoteItems = await remoteDataSource.getTimetable();
        await localDataSource.cacheTimetable(remoteItems);
        return Either.right(remoteItems);
      } catch (e) {
        AppLogger.error('Remote fetch failed, checking cache', error: e);
        try {
          final localItems = await localDataSource.getLastTimetable();
          return Either.right(localItems);
        } catch (cacheError) {
          return Either.left(CacheFailure('Failed to retrieve cached timetable'));
        }
      }
    } else {
      try {
        final localItems = await localDataSource.getLastTimetable();
        return Either.right(localItems);
      } catch (cacheError) {
        return Either.left(CacheFailure('No internet and no cached timetable'));
      }
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

  /// Get exams filtered by course codes
  Future<Either<Failure, List<TimetableModel>>> getExamsByCodes(List<String> codes) async {
    if (await networkInfo.isConnected) {
      try {
        final remoteItems = await remoteDataSource.getExamsByCodes(codes);
        return Either.right(remoteItems);
      } catch (e) {
        return Either.left(ServerFailure('Failed to fetch personalized exams'));
      }
    } else {
      return Either.left(NetworkFailure('No internet connection'));
    }
  }
}
