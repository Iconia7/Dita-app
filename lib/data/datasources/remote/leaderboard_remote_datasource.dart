import '../../models/leaderboard_model.dart';
import '../../../services/api_service.dart';
import '../../../core/errors/exceptions.dart';
import '../../../utils/app_logger.dart';

/// Remote data source for leaderboard
class LeaderboardRemoteDataSource {
  /// Fetch leaderboard rankings from the API
  Future<List<LeaderboardModel>> getLeaderboard() async {
    try {
      final jsonList = await ApiService.getLeaderboard();
      
      // Add rank to each entry
      final leaderboard = <LeaderboardModel>[];
      for (int i = 0; i < jsonList.length; i++) {
        final json = jsonList[i] as Map<String, dynamic>;
        
        // Add rank if not present
        if (!json.containsKey('rank')) {
          json['rank'] = i + 1;
        }
        
        leaderboard.add(LeaderboardModel.fromJson(json));
      }
      
      AppLogger.success('Parsed ${leaderboard.length} leaderboard entries');
      return leaderboard;
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error parsing leaderboard', error: e, stackTrace: stackTrace);
      throw DataParsingException('Failed to parse leaderboard data');
    }
  }
}
