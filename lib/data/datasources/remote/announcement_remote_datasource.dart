import '../../models/announcement_model.dart';
import '../../../services/api_service.dart';
import '../../../core/errors/exceptions.dart';
import '../../../utils/app_logger.dart';

/// Remote data source for announcements
class AnnouncementRemoteDataSource {
  /// Fetch all announcements
  Future<List<AnnouncementModel>> getAnnouncements() async {
    try {
      final jsonList = await ApiService.getAnnouncements();
      final announcements = jsonList
          .map((json) => AnnouncementModel.fromJson(json as Map<String, dynamic>))
          .toList();
      return announcements;
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error parsing announcements', error: e, stackTrace: stackTrace);
      throw DataParsingException('Failed to parse announcements');
    }
  }
}
