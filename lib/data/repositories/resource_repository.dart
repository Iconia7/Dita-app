import '../models/resource_model.dart';
import '../datasources/remote/resource_remote_datasource.dart';
import '../datasources/local/resource_local_datasource.dart';
import '../../core/network/network_info.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../utils/app_logger.dart';

/// Repository for academic resources with offline-first capabilities
class ResourceRepository {
  final ResourceRemoteDataSource remoteDataSource;
  final ResourceLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  ResourceRepository({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  /// Get all resources (offline-first)
  Future<Either<Failure, List<ResourceModel>>> getResources() async {
    try {
      final isConnected = await networkInfo.isConnected;

      if (isConnected) {
        try {
          // Fetch from remote
          final resources = await remoteDataSource.getResources();
          
          // Cache locally
          await localDataSource.cacheResources(resources);
          
          AppLogger.success('Fetched ${resources.length} resources from remote');
          return Right(resources);
        } catch (e) {
          AppLogger.warning('Remote fetch failed, falling back to cache');
          
          // Fallback to cache
          final cachedResources = await localDataSource.getCachedResources();
          if (cachedResources != null && cachedResources.isNotEmpty) {
            return Right(cachedResources);
          }
          
          return Left(ServerFailure('Failed to fetch resources'));
        }
      } else {
        // Offline: return cached data
        AppLogger.info('Offline mode: using cached resources');
        final cachedResources = await localDataSource.getCachedResources();
        
        if (cachedResources != null && cachedResources.isNotEmpty) {
          return Right(cachedResources);
        }
        
        return Left(NetworkFailure('No internet connection and no cached data'));
      }
    } catch (e, stackTrace) {
      AppLogger.error('Repository error getting resources', error: e, stackTrace: stackTrace);
      return Left(UnknownFailure('Unexpected error: $e'));
    }
  }

  /// Clear local cache
  Future<void> clearCache() async {
    await localDataSource.clearCache();
  }
}
