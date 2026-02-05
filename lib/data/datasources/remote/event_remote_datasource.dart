import '../../models/event_model.dart';
import '../../../services/api_service.dart';
import '../../../core/errors/exceptions.dart';
import '../../../utils/app_logger.dart';

/// Remote data source for events
/// Wraps ApiService methods and returns EventModel objects
class EventRemoteDataSource {
  /// Fetch all events from the API
  Future<List<EventModel>> getEvents({int? attendedBy}) async {
    try {
      final jsonList = await ApiService.getEvents(attendedBy: attendedBy);
      final events = jsonList
          .map((json) => EventModel.fromJson(json as Map<String, dynamic>))
          .toList();
      AppLogger.success('Parsed ${events.length} events');
      return events;
    } on NetworkException {
      AppLogger.error('Network error fetching events');
      rethrow;
    } on TimeoutException {
      AppLogger.error('Timeout fetching events');
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error parsing events', error: e, stackTrace: stackTrace);
      throw DataParsingException('Failed to parse events data');
    }
  }

  /// RSVP to an event
  Future<Map<String, dynamic>?> rsvpEvent(int eventId) async {
    try {
      return await ApiService.rsvpEvent(eventId);
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error RSVP to event', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to RSVP to event');
    }
  }

  /// Mark attendance for an event
  Future<Map<String, dynamic>?> markAttendance(int eventId) async {
    try {
      return await ApiService.markAttendance(eventId);
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error marking attendance', error: e, stackTrace: stackTrace);
      throw ApiException('Failed to mark attendance');
    }
  }
}
