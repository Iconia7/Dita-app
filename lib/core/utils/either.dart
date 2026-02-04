/// Simple Either type for error handling
/// Left = Failure, Right = Success
/// 
/// Similar to dartz package but simplified for our needs
sealed class Either<L, R> {
  const Either();

  /// Create a Left (failure) value
  const factory Either.left(L value) = Left;

  /// Create a Right (success) value
  const factory Either.right(R value) = Right;

  /// Check if this is a Left value
  bool get isLeft => this is Left<L, R>;

  /// Check if this is a Right value
  bool get isRight => this is Right<L, R>;

  /// Fold the Either into a single value
  T fold<T>(T Function(L left) onLeft, T Function(R right) onRight) {
    return switch (this) {
      Left(value: final l) => onLeft(l),
      Right(value: final r) => onRight(r),
    };
  }

  /// Map the Right value (success case)
  Either<L, T> map<T>(T Function(R right) mapper) {
    return fold(
      (left) => Either.left(left),
      (right) => Either.right(mapper(right)),
    );
  }
}

/// Left (failure) value
final class Left<L, R> extends Either<L, R> {
  final L value;
  const Left(this.value);

  @override
  String toString() => 'Left($value)';
}

/// Right (success) value
final class Right<L, R> extends Either<L, R> {
  final R value;
  const Right(this.value);

  @override
  String toString() => 'Right($value)';
}
