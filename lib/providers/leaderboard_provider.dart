import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dita_app/core/storage/local_storage.dart';
import 'package:dita_app/data/datasources/local/leaderboard_local_datasource.dart';
import 'package:dita_app/data/datasources/remote/leaderboard_remote_datasource.dart';
import 'package:dita_app/data/repositories/leaderboard_repository.dart';
import 'package:dita_app/data/models/leaderboard_model.dart';
import 'package:dita_app/providers/auth_provider.dart';
import 'package:dita_app/providers/network_provider.dart';
import 'package:dita_app/utils/app_logger.dart';

// ========== Dependency Injection Providers ==========

/// Leaderboard local data source provider
final leaderboardLocalDataSourceProvider = Provider<LeaderboardLocalDataSource>((ref) {
  return LeaderboardLocalDataSource();
});

/// Leaderboard remote data source provider
final leaderboardRemoteDataSourceProvider = Provider<LeaderboardRemoteDataSource>((ref) {
  return LeaderboardRemoteDataSource();
});

/// Leaderboard repository provider
final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepository(
    remoteDataSource: ref.watch(leaderboardRemoteDataSourceProvider),
    localDataSource: ref.watch(leaderboardLocalDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

// ========== State Providers ==========

/// Leaderboard state provider
/// Manages leaderboard rankings with offline-first capabilities
/// Note: Cache expires in 1 hour due to frequent ranking changes
class LeaderboardNotifier extends StateNotifier<AsyncValue<List<LeaderboardModel>>> {
  final LeaderboardRepository _repository;

  LeaderboardNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadLeaderboard();
  }

  /// Load leaderboard (offline-first)
  Future<void> loadLeaderboard() async {
    try {
      state = const AsyncValue.loading();
      AppLogger.info('Loading leaderboard...');

      final result = await _repository.getLeaderboard();

      result.fold(
        (failure) {
          AppLogger.warning('Failed to load leaderboard: ${failure.message}');
          state = AsyncValue.error(failure.message, StackTrace.current);
        },
        (leaderboard) {
          AppLogger.success('Loaded ${leaderboard.length} leaderboard entries');
          state = AsyncValue.data(leaderboard);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error loading leaderboard', error: e, stackTrace: stackTrace);
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Refresh leaderboard
  Future<void> refresh() async {
    await loadLeaderboard();
  }
}

/// Leaderboard provider
final leaderboardProvider =
    StateNotifierProvider<LeaderboardNotifier, AsyncValue<List<LeaderboardModel>>>((ref) {
  final repository = ref.watch(leaderboardRepositoryProvider);
  return LeaderboardNotifier(repository);
});

/// Helper provider to get top 10 users
final top10Provider = Provider<List<LeaderboardModel>>((ref) {
  final leaderboardAsync = ref.watch(leaderboardProvider);
  return leaderboardAsync.maybeWhen(
    data: (leaderboard) => leaderboard.where((entry) => entry.isTopTen).toList(),
    orElse: () => [],
  );
});

/// Helper provider to get top 3 users (with medals)
final top3Provider = Provider<List<LeaderboardModel>>((ref) {
  final leaderboardAsync = ref.watch(leaderboardProvider);
  return leaderboardAsync.maybeWhen(
    data: (leaderboard) => leaderboard.take(3).toList(),
    orElse: () => [],
  );
});

/// Helper provider to find current user's rank
final currentUserRankProvider = Provider<LeaderboardModel?>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return null;

  final leaderboardAsync = ref.watch(leaderboardProvider);
  return leaderboardAsync.maybeWhen(
    data: (leaderboard) {
      try {
        return leaderboard.firstWhere(
          (entry) => entry.userId == currentUser.id,
        );
      } catch (e) {
        return null;
      }
    },
    orElse: () => null,
  );
});
