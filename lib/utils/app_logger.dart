import 'package:flutter/foundation.dart';

/// Centralized logging utility for the DITA App.
/// 
/// Use this instead of print() statements for better control over logging
/// in development vs production environments.
/// 
/// Example usage:
/// ```dart
/// AppLogger.log('User logged in successfully');
/// AppLogger.error('API call failed', error: e, stackTrace: stackTrace);
/// AppLogger.debug('Current user state: $userState');
/// ```
class AppLogger {
  static const String _appTag = 'DITA';
  
  /// Log general information messages
  /// Only prints in debug mode
  static void log(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[${tag ?? _appTag}] $message');
    }
  }
  
  /// Log debug messages (verbose logging)
  /// Only prints in debug mode
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[${tag ?? _appTag}] 🔍 DEBUG: $message');
    }
  }
  
  /// Log informational messages
  /// Only prints in debug mode
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[${tag ?? _appTag}] ℹ️ INFO: $message');
    }
  }
  
  /// Log warning messages
  /// Only prints in debug mode
  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[${tag ?? _appTag}] ⚠️ WARNING: $message');
    }
  }
  
  /// Log error messages with optional error object and stack trace
  /// Only prints in debug mode
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    if (kDebugMode) {
      debugPrint('[${tag ?? _appTag}] ❌ ERROR: $message');
      if (error != null) {
        debugPrint('  └─ Details: $error');
      }
      if (stackTrace != null) {
        debugPrint('  └─ Stack Trace:\n$stackTrace');
      }
    }
  }
  
  /// Log success messages
  /// Only prints in debug mode
  static void success(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[${tag ?? _appTag}] ✅ SUCCESS: $message');
    }
  }
  
  /// Log network-related messages
  /// Only prints in debug mode
  static void network(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[${tag ?? _appTag}] 🌐 NETWORK: $message');
    }
  }
  
  /// Log API call details
  /// Only prints in debug mode
  static void api(String method, String endpoint, {int? statusCode, String? tag}) {
    if (kDebugMode) {
      final status = statusCode != null ? ' → $statusCode' : '';
      debugPrint('[${tag ?? _appTag}] 🔌 API: $method $endpoint$status');
    }
  }
}
