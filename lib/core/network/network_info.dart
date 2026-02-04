import 'package:connectivity_plus/connectivity_plus.dart';
import '../../utils/app_logger.dart';

/// Network connectivity checker
/// Used by repositories to determine online/offline mode
class NetworkInfo {
  final Connectivity _connectivity;

  NetworkInfo(this._connectivity);

  /// Check if device is connected to internet
  Future<bool> get isConnected async {
    try {
      final result = await _connectivity.checkConnectivity();
      
      // Check if connected to WiFi, mobile data, or ethernet
      final connected = result == ConnectivityResult.wifi || 
                       result == ConnectivityResult.mobile ||
                       result == ConnectivityResult.ethernet;

      if (connected) {
        AppLogger.debug('Network: Connected');
      } else {
        AppLogger.warning('Network: Offline');
      }

      return connected;
    } catch (e, stackTrace) {
      AppLogger.error('Error checking network connectivity', 
        error: e, stackTrace: stackTrace);
      // Assume connected if check fails to avoid blocking
      return true;
    }
  }

  /// Stream of connectivity changes
  Stream<ConnectivityResult> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged;
  }

  /// Get current connectivity status
  Future<ConnectivityResult> get connectivityStatus async {
    try {
      return await _connectivity.checkConnectivity();
    } catch (e, stackTrace) {
      AppLogger.error('Error getting connectivity status', 
        error: e, stackTrace: stackTrace);
      return ConnectivityResult.none;
    }
  }
}
