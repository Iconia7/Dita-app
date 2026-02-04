/// Custom exceptions for the DITA App
/// 
/// These exceptions provide better error handling and user feedback
/// compared to generic exceptions.

/// Base class for all API-related exceptions
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

/// Exception thrown when there's no internet connection
class NetworkException implements Exception {
  final String message;

  NetworkException([this.message = 'No internet connection']);

  @override
  String toString() => 'NetworkException: $message';
}

/// Exception thrown when authentication fails
class AuthenticationException implements Exception {
  final String message;

  AuthenticationException([this.message = 'Authentication failed']);

  @override
  String toString() => 'AuthenticationException: $message';
}

/// Exception thrown when there's a server error
class ServerException implements Exception {
  final String message;
  final int? statusCode;

  ServerException(this.message, {this.statusCode});

  @override
  String toString() => 'ServerException: $message (Status: $statusCode)';
}

/// Exception thrown when data is not in cache
class CacheException implements Exception {
  final String message;

  CacheException([this.message = 'Data not found in cache']);

  @override
  String toString() => 'CacheException: $message';
}

/// Exception thrown when validation fails
class ValidationException implements Exception {
  final String message;
  final Map<String, dynamic>? errors;

  ValidationException(this.message, {this.errors});

  @override
  String toString() => 'ValidationException: $message';
}

/// Exception thrown when a timeout occurs
class TimeoutException implements Exception {
  final String message;

  TimeoutException([this.message = 'Request timed out']);

  @override
  String toString() => 'TimeoutException: $message';
}

/// Exception thrown when data parsing fails
class DataParsingException implements Exception {
  final String message;

  DataParsingException([this.message = 'Failed to parse data']);

  @override
  String toString() => 'DataParsingException: $message';
}
