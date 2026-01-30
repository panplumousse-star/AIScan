import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'base_permission_service.dart';
import 'permission_exception.dart';

// Re-export for backward compatibility
export 'base_permission_service.dart' show PermissionState;

/// Type alias for backward compatibility.
typedef CameraPermissionException = PermissionException;

/// Type alias for backward compatibility with existing code using CameraPermissionState.
typedef CameraPermissionState = PermissionState;

/// Riverpod provider for [CameraPermissionService].
final cameraPermissionServiceProvider =
    Provider<CameraPermissionService>((ref) {
  return CameraPermissionService();
});

/// Service for managing camera permission state and requests.
///
/// Extends [BasePermissionService] with camera-specific configuration.
///
/// ## Usage
/// ```dart
/// final permissionService = ref.read(cameraPermissionServiceProvider);
///
/// // Check current permission state
/// final state = await permissionService.checkPermission();
///
/// // Check if permission is blocked and needs settings redirect
/// if (await permissionService.isPermissionBlocked()) {
///   // Show Yes/No dialog to redirect to settings
/// }
///
/// // Request permission from system
/// final result = await permissionService.requestSystemPermission();
/// ```
class CameraPermissionService extends BasePermissionService {
  /// Creates a [CameraPermissionService].
  ///
  /// Optionally accepts a custom [Permission] for testing purposes.
  CameraPermissionService({Permission? permission})
      : super(permission ?? Permission.camera);
}
