import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'base_permission_service.dart';
import 'permission_exception.dart';

// Re-export for backward compatibility
export 'base_permission_service.dart' show PermissionState;

/// Type alias for backward compatibility.
typedef StoragePermissionException = PermissionException;

/// Type alias for backward compatibility with existing code using StoragePermissionState.
typedef StoragePermissionState = PermissionState;

/// Riverpod provider for [StoragePermissionService].
final storagePermissionServiceProvider =
    Provider<StoragePermissionService>((ref) {
  return StoragePermissionService();
});

/// Service for managing storage permission state and requests.
///
/// Extends [BasePermissionService] with storage-specific configuration.
///
/// ## Android Storage Permission Notes
/// - Android 10+ (API 29+): Uses scoped storage, explicit permission may not
///   be required for app-specific directories and sharing via FileProvider.
/// - Android 9 and below: Requires explicit storage permission for file access.
///
/// This service handles both scenarios transparently.
///
/// ## Usage
/// ```dart
/// final permissionService = ref.read(storagePermissionServiceProvider);
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
class StoragePermissionService extends BasePermissionService {
  /// Creates a [StoragePermissionService].
  ///
  /// Optionally accepts a custom [Permission] for testing purposes.
  StoragePermissionService({Permission? permission})
      : super(permission ?? Permission.storage);
}
