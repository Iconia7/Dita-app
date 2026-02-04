import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/local_storage.dart';
import '../../data/datasources/local/announcement_local_datasource.dart';
import '../../data/datasources/remote/announcement_remote_datasource.dart';
import '../../data/repositories/announcement_repository.dart';
import '../../data/models/announcement_model.dart';
import 'network_provider.dart';

// DI Providers
final announcementLocalDataSourceProvider = Provider<AnnouncementLocalDataSource>((ref) {
  return AnnouncementLocalDataSource(LocalStorage());
});

final announcementRemoteDataSourceProvider = Provider<AnnouncementRemoteDataSource>((ref) {
  return AnnouncementRemoteDataSource();
});

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository(
    remoteDataSource: ref.watch(announcementRemoteDataSourceProvider),
    localDataSource: ref.watch(announcementLocalDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

// State Provider
class AnnouncementNotifier extends StateNotifier<AsyncValue<List<AnnouncementModel>>> {
  final AnnouncementRepository _repository;

  AnnouncementNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadAnnouncements();
  }

  Future<void> loadAnnouncements() async {
    state = const AsyncValue.loading();
    final result = await _repository.getAnnouncements();
    result.fold(
      (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
      (data) => state = AsyncValue.data(data),
    );
  }
  
  Future<void> refresh() async {
    await loadAnnouncements();
  }
}

final announcementProvider = StateNotifierProvider<AnnouncementNotifier, AsyncValue<List<AnnouncementModel>>>((ref) {
  final repo = ref.watch(announcementRepositoryProvider);
  return AnnouncementNotifier(repo);
});
