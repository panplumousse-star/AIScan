/// Base exception class for all custom exceptions in the application.
///
/// Provides a consistent structure for error handling across the app.
/// All custom exceptions should extend this class instead of implementing
/// [Exception] directly.
///
/// ## Usage
/// ```dart
/// class MyServiceException extends BaseException {
///   const MyServiceException(super.message, {super.cause});
/// }
///
/// // Throwing an exception
/// throw MyServiceException('Operation failed', cause: originalError);
/// ```
///
/// ## Benefits
/// - Consistent error message format across all exceptions
/// - Standardized cause chain for debugging
/// - Single place to add common exception functionality
/// - Reduces code duplication (~13 lines per exception)
abstract class BaseException implements Exception {
  /// Creates a [BaseException] with the given [message] and optional [cause].
  ///
  /// The [message] should be a human-readable description of the error.
  /// The [cause] is the underlying exception that triggered this error, if any.
  const BaseException(this.message, {this.cause});

  /// Human-readable error message describing what went wrong.
  final String message;

  /// The underlying exception that caused this error, if any.
  ///
  /// Useful for debugging and error chain analysis.
  final Object? cause;

  @override
  String toString() {
    final className = runtimeType.toString();
    if (cause != null) {
      return '$className: $message (caused by: $cause)';
    }
    return '$className: $message';
  }
}
