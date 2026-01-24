/// Base exception class for permission-related errors.
///
/// This exception is thrown when permission operations fail across any
/// permission service (camera, storage, contacts, etc.).
///
/// Contains the original error message and optional underlying exception.
class PermissionException implements Exception {
  /// Creates a [PermissionException] with the given [message].
  const PermissionException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying exception that caused this error, if any.
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
