import '../exceptions/base_exception.dart';

/// Base exception class for permission-related errors.
///
/// This exception is thrown when permission operations fail across any
/// permission service (camera, storage, contacts, etc.).
///
/// Contains the original error message and optional underlying exception.
class PermissionException extends BaseException {
  /// Creates a [PermissionException] with the given [message].
  const PermissionException(super.message, {super.cause});
}
