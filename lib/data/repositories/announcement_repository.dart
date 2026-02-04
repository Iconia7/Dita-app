import '../../../core/network/network_info.dart';
import '../../../core/utils/either.dart';
import '../../../core/errors/failures.dart';
import '../../../core/errors/exceptions.dart';
import '../../../utils/app_logger.dart';
import '../models/announcement_model.dart';
import '../datasources/local/announcement_local_datasource.dart';
import '../datasources/remote/announcement_remote_datasource.dart';

/// Repository for announcements
class AnnouncementRepository {
  final AnnouncementRemoteDataSource remoteDataSource;
  final AnnouncementLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  AnnouncementRepository({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  Future<Either<Failure, List<AnnouncementModel>>> getAnnouncements() async {
    try {
      // 1. Try local cache first (offline-first, or strict cache?)
      // For news, we might want fresh data if online.
      // Let's use: Local first if available and valid?
      // Or: Network first, then fallback to cache?
      // Pattern used in UserRepo: Cache check, if network -> fetch & cache.
      
      final cached = await localDataSource.getCachedAnnouncements();
      if (cached != null && cached.isNotEmpty) {
        // We have cache. If online, should we refresh?
        // Let's implement: Return cache immediately for speed,
        // BUT calling code might want to refresh.
        // For simplicity: If we have valid cache, return it. Background refresh is handled by provider?
        // Actually, typical flow: 
        // if (connected) -> fetch remote -> save local -> return remote
        // else -> return local
        // This ensures fresh news.
      }

      if (await networkInfo.isConnected) {
        try {
          final remoteData = await remoteDataSource.getAnnouncements();
          await localDataSource.cacheAnnouncements(remoteData);
          return Either.right(remoteData);
        } catch (e) {
          // Network failed but we thought we were connected?
          // Fallback to cache
          if (cached != null) {
            AppLogger.warning('Network call failed, using cache');
            return Either.right(cached);
          }
          if (e is ServerException) return Either.left(ServerFailure(e.message));
          return const Either.left(ServerFailure('Failed to fetch announcements'));
        }
      } else {
        // Offline
        if (cached != null) {
          return Either.right(cached);
        }
        return const Either.left(NetworkFailure('No internet and no cached announcements'));
      }
    } catch (e, stackTrace) {
      AppLogger.error('Repository error', error: e, stackTrace: stackTrace);
      return const Either.left(UnknownFailure('Unexpected error'));
    }
  }
}
