// services/update_service.dart
import 'package:in_app_update/in_app_update.dart';
import '../utils/app_logger.dart';

Future<void> checkForUpdate() async {
  try {
    AppUpdateInfo info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability == UpdateAvailability.updateAvailable) {
      await InAppUpdate.performImmediateUpdate(); 
    }
  } catch (e, stackTrace) {
    AppLogger.error("Update check failed", error: e, stackTrace: stackTrace);
  }
}