import '../../models/resource_model.dart';
import '../../../services/api_service.dart';
import '../../../core/errors/exceptions.dart';
import '../../../utils/app_logger.dart';

/// Remote data source for academic resources
class ResourceRemoteDataSource {
  /// Fetch all resources from the API
  Future<List<ResourceModel>> getResources() async {
    try {
      final jsonList = await ApiService.getResources();
      final resources = jsonList
          .map((json) => ResourceModel.fromJson(json as Map<String, dynamic>))
          .toList();
      AppLogger.success('Parsed ${resources.length} resources');
      return resources;
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error parsing resources', error: e, stackTrace: stackTrace);
      throw DataParsingException('Failed to parse resources data');
    }
  }

  /// TODO: Add methods for:
  /// - uploadResource()
  /// - searchResources()
  /// - downloadResource()
  /// - rateResource()
  /// when backend endpoints are available
}
