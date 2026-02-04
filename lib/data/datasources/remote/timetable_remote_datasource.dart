import 'dart:async';
import '../../models/timetable_model.dart';
import '../../../services/api_service.dart';
import '../../../core/errors/exceptions.dart';
import '../../../utils/app_logger.dart';

/// Remote data source for Timetable features
class TimetableRemoteDataSource {
  /// Fetch all timetable entries (classes and exams)
  Future<List<TimetableModel>> getTimetable() async {
    try {
      final jsonList = await ApiService.get('timetable/');
      final items = (jsonList as List)
          .map((json) => TimetableModel.fromJson(json as Map<String, dynamic>))
          .toList();
      AppLogger.success('Parsed ${items.length} timetable entries');
      return items;
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error parsing timetable', error: e, stackTrace: stackTrace);
      throw DataParsingException('Failed to parse timetable data');
    }
  }

  /// Fetch exams filtered by course codes
  Future<List<TimetableModel>> getExamsByCodes(List<String> codes) async {
    try {
      final codesParam = codes.join(',');
      final jsonList = await ApiService.get('exams/?codes=$codesParam');
      final items = (jsonList as List)
          .map((json) => TimetableModel.fromJson(json as Map<String, dynamic>))
          .toList();
      AppLogger.success('Fetched ${items.length} personalized exams');
      return items;
    } on NetworkException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching exams', error: e, stackTrace: stackTrace);
      throw DataParsingException('Failed to fetch personalized exams');
    }
  }

  // Note: Add/Edit/Delete methods can be added here if the API supports it
  // Currently assuming read-only or managed elsewhere based on student portal data
}
