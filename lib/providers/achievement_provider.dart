import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../data/models/achievement_model.dart';

final userAchievementsProvider = StateNotifierProvider<AchievementNotifier, AsyncValue<List<AchievementModel>>>((ref) {
  return AchievementNotifier();
});

class AchievementNotifier extends StateNotifier<AsyncValue<List<AchievementModel>>> {
  AchievementNotifier() : super(const AsyncValue.loading()) {
    loadAchievements();
  }

  Future<void> loadAchievements() async {
    state = const AsyncValue.loading();
    try {
      final data = await ApiService.getUserAchievements();
      final achievements = data.map((json) => AchievementModel.fromJson(json)).toList();
      state = AsyncValue.data(achievements);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}
