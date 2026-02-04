import '../../models/resource_model.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/storage/storage_keys.dart';
import '../../../utils/app_logger.dart';

/// Local data source for resources using Hive
class ResourceLocalDataSource {
  final LocalStorage _storage;

  ResourceLocalDataSource(this._storage);

  /// Cache list of resources
  Future<void> cacheResources(List<ResourceModel> resources) async {
    try {
      final jsonList = resources.map((resource) => resource.toJson()).toList();
      await _storage.put(StorageKeys.resourcesBox, 'cached_resources', jsonList);
      await _storage.put(
        StorageKeys.resourcesBox,
        'resources_timestamp',
        DateTime.now().toIso8601String(),
      );
      AppLogger.success('Cached ${resources.length} resources locally');
    } catch (e, stackTrace) {
      AppLogger.error('Error caching resources', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get cached resources
  Future<List<ResourceModel>?> getCachedResources() async {
    try {
      final jsonList = await _storage.get<List>(
        StorageKeys.resourcesBox,
        'cached_resources',
      );

      if (jsonList == null) {
        AppLogger.info('No cached resources found');
        return null;
      }

      // Check if cache is expired
      if (await _isCacheExpired()) {
        AppLogger.info('Resources cache expired');
        await clearCache();
        return null;
      }

      final resources = jsonList
          .map((json) => ResourceModel.fromJson(json as Map<String, dynamic>))
          .toList();
      AppLogger.success('Retrieved ${resources.length} cached resources');
      return resources;
    } catch (e, stackTrace) {
      AppLogger.error('Error retrieving cached resources', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Clear resources cache
  Future<void> clearCache() async {
    try {
      await _storage.delete(StorageKeys.resourcesBox, 'cached_resources');
      await _storage.delete(StorageKeys.resourcesBox, 'resources_timestamp');
      AppLogger.info('Resources cache cleared');
    } catch (e, stackTrace) {
      AppLogger.error('Error clearing resources cache', error: e, stackTrace: stackTrace);
    }
  }

  /// Check if cache is expired (24 hours)
  Future<bool> _isCacheExpired() async {
    final timestamp = await _storage.get<String>(
      StorageKeys.resourcesBox,
      'resources_timestamp',
    );

    if (timestamp == null) return true;

    final cachedTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(cachedTime);

    return difference > const Duration(hours: 24);
  }
}
