// services/update_service.dart
import 'package:in_app_update/in_app_update.dart';

Future<void> checkForUpdate() async {
  try {
    AppUpdateInfo info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability == UpdateAvailability.updateAvailable) {
      await InAppUpdate.performImmediateUpdate(); 
    }
  } catch (e) {
    print("Update check failed: $e");
  }
}