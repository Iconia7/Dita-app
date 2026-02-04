import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dita_app/core/storage/local_storage.dart';
import 'package:dita_app/data/datasources/local/resource_local_datasource.dart';
import 'package:dita_app/data/datasources/remote/resource_remote_datasource.dart';
import 'package:dita_app/data/repositories/resource_repository.dart';
import 'package:dita_app/data/models/resource_model.dart';
import 'package:dita_app/providers/auth_provider.dart';
import 'package:dita_app/providers/network_provider.dart';
import 'package:dita_app/utils/app_logger.dart';

// ========== Dependency Injection Providers ==========

/// Resource local data source provider
final resourceLocalDataSourceProvider = Provider<ResourceLocalDataSource>((ref) {
  return ResourceLocalDataSource(LocalStorage());
});

/// Resource remote data source provider
final resourceRemoteDataSourceProvider = Provider<ResourceRemoteDataSource>((ref) {
  return ResourceRemoteDataSource();
});

/// Resource repository provider
final resourceRepositoryProvider = Provider<ResourceRepository>((ref) {
  return ResourceRepository(
    remoteDataSource: ref.watch(resourceRemoteDataSourceProvider),
    localDataSource: ref.watch(resourceLocalDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

// ========== State Providers ==========

/// Resource state provider
/// Manages academic resources with offline-first capabilities
class ResourceNotifier extends StateNotifier<AsyncValue<List<ResourceModel>>> {
  final ResourceRepository _repository;

  ResourceNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadResources();
  }

  /// Load resources (offline-first)
  Future<void> loadResources() async {
    try {
      state = const AsyncValue.loading();
      AppLogger.info('Loading resources...');

      final result = await _repository.getResources();

      result.fold(
        (failure) {
          AppLogger.warning('Failed to load resources: ${failure.message}');
          state = AsyncValue.error(failure.message, StackTrace.current);
        },
        (resources) {
          AppLogger.success('Loaded ${resources.length} resources');
          state = AsyncValue.data(resources);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error loading resources', error: e, stackTrace: stackTrace);
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Refresh resources
  Future<void> refresh() async {
    await loadResources();
  }
}

/// Resource provider
final resourceProvider =
    StateNotifierProvider<ResourceNotifier, AsyncValue<List<ResourceModel>>>((ref) {
  final repository = ref.watch(resourceRepositoryProvider);
  return ResourceNotifier(repository);
});

/// Helper provider to get resources by category
final resourcesByCategoryProvider = Provider.family<List<ResourceModel>, String>((ref, category) {
  final resourcesAsync = ref.watch(resourceProvider);
  return resourcesAsync.maybeWhen(
    data: (resources) => resources
        .where((resource) => resource.category.toLowerCase() == category.toLowerCase())
        .toList(),
    orElse: () => [],
  );
});

/// Helper provider to get popular resources (> 50 downloads)
final popularResourcesProvider = Provider<List<ResourceModel>>((ref) {
  final resourcesAsync = ref.watch(resourceProvider);
  return resourcesAsync.maybeWhen(
    data: (resources) => resources.where((resource) => resource.isPopular).toList(),
    orElse: () => [],
  );
});

/// Helper provider to search resources by title
final searchResourcesProvider = Provider.family<List<ResourceModel>, String>((ref, query) {
  final resourcesAsync = ref.watch(resourceProvider);
  if (query.isEmpty) {
    return resourcesAsync.maybeWhen(
      data: (resources) => resources,
      orElse: () => [],
    );
  }
  
  return resourcesAsync.maybeWhen(
    data: (resources) => resources
        .where((resource) => 
            resource.title.toLowerCase().contains(query.toLowerCase()) ||
            (resource.description.toLowerCase().contains(query.toLowerCase())))
        .toList(),
    orElse: () => [],
  );
});
