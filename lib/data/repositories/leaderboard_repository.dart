import '../models/leaderboard_model.dart';
import '../datasources/remote/leaderboard_remote_datasource.dart';
import '../datasources/local/leaderboard_local_datasource.dart';
import '../../core/network/network_info.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../utils/app_logger.dart';

/// Repository for leaderboard with offline-first capabilities
/// Note: Leaderboard has shorter cache expiry (1 hour) due to frequent updates
class LeaderboardRepository {
  final LeaderboardRemoteDataSource remoteDataSource;
  final LeaderboardLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  LeaderboardRepository({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  /// Get leaderboard rankings (offline-first)
  Future<Either<Failure, List<LeaderboardModel>>> getLeaderboard() async {
    try {
      final isConnected = await networkInfo.isConnected;

      if (isConnected) {
        try {
          // Fetch from remote
          final leaderboard = await remoteDataSource.getLeaderboard();
          
          // Cache locally
          await localDataSource.cacheLeaderboard(leaderboard);
          
          AppLogger.success('Fetched ${leaderboard.length} leaderboard entries from remote');
          return Right(leaderboard);
        } catch (e) {
          AppLogger.warning('Remote fetch failed, falling back to cache');
          
          // Fallback to cache
          final cachedLeaderboard = await localDataSource.getCachedLeaderboard();
          if (cachedLeaderboard != null && cachedLeaderboard.isNotEmpty) {
            return Right(cachedLeaderboard);
          }
          
          return Left(ServerFailure('Failed to fetch leaderboard'));
        }
      } else {
        // Offline: return cached data
        AppLogger.info('Offline mode: using cached leaderboard');
        final cachedLeaderboard = await localDataSource.getCachedLeaderboard();
        
        if (cachedLeaderboard != null && cachedLeaderboard.isNotEmpty) {
          return Right(cachedLeaderboard);
        }
        
        return Left(NetworkFailure('No internet connection and no cached data'));
      }
    } catch (e, stackTrace) {
      AppLogger.error('Repository error getting leaderboard', error: e, stackTrace: stackTrace);
      return Left(UnknownFailure('Unexpected error: $e'));
    }
  }

  /// Clear local cache
  Future<void> clearCache() async {
    await localDataSource.clearCache();
  }
}
