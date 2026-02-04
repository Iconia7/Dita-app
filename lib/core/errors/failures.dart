/// Base class for all failures in the data layer
/// Used with Either<Failure, Data> pattern in repositories
abstract class Failure {
  final String message;
  final int? statusCode;

  const Failure(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Network-related failures
class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'No internet connection']) 
    : super(message);
}

/// Server-related failures
class ServerFailure extends Failure {
  const ServerFailure([String message = 'Server error', int? statusCode]) 
    : super(message, statusCode: statusCode);
}

/// Cache-related failures
class CacheFailure extends Failure {
  const CacheFailure([String message = 'Cache error']) 
    : super(message);
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure([String message = 'Authentication failed']) 
    : super(message);
}

/// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure([String message = 'Validation error']) 
    : super(message);
}

/// Timeout failures
class TimeoutFailure extends Failure {
  const TimeoutFailure([String message = 'Request timeout']) 
    : super(message);
}

/// Unknown failures
class UnknownFailure extends Failure {
  const UnknownFailure([String message = 'Unknown error']) 
    : super(message);
}
