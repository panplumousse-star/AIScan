import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'permission_exception.dart';

/// Type alias for backward compatibility.
///
/// This allows existing code referencing [CameraPermissionException]
/// to work seamlessly with the common [PermissionException] base class.
typedef CameraPermissionException = PermissionException;

/// Riverpod provider for [CameraPermissionService].
///
/// Provides a singleton instance of the camera permission service for
/// dependency injection throughout the application.
final cameraPermissionServiceProvider = Provider<CameraPermissionService>((ref) {
  return CameraPermissionService();
});

/// Represents the possible states of camera permission.
///
/// These states map to the underlying system permission states while providing
/// additional app-level tracking for temporary permissions.
enum CameraPermissionState {
  /// Permission status has not been checked yet.
  unknown,

  /// Camera permission is fully granted.
  granted,

  /// Camera permission was granted for this session only ("Only this time").
  ///
  /// This is an app-level state tracked when the system grants temporary permission.
  /// On Android, this corresponds to the "Only this time" option in the native dialog.
  sessionOnly,

  /// Camera permission was denied but can still be requested again.
  ///
  /// The user declined the permission but has not selected "Don't ask again".
  denied,

  /// Camera is restricted due to device policy or lack of hardware.
  ///
  /// This typically means the device doesn't have a camera or it's disabled
  /// by enterprise policy. Permission cannot be requested.
  restricted,

  /// Camera permission was permanently denied by the user.
  ///
  /// The user selected "Don't ask again" or denied multiple times.
  /// The only way to grant permission is through system settings.
  permanentlyDenied,
}

/// Service for managing camera permission state and requests.
///
/// Uses [permission_handler] to interact with the native permission system
/// and maintains app-level state for tracking temporary permissions.
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
///
/// ## Session Permissions
/// When the user grants "Only this time" permission, this service tracks it
/// as [CameraPermissionState.sessionOnly]. Call [clearSessionPermission] on
/// app startup to reset this state for the new session.
class CameraPermissionService {
  /// Creates a [CameraPermissionService].
  ///
  /// Optionally accepts a custom [Permission] for testing purposes.
  CameraPermissionService({
    Permission? permission,
  }) : _permission = permission ?? Permission.camera;

  /// The permission to check/request.
  final Permission _permission;

  /// Tracks whether session-level permission was granted.
  ///
  /// This is set to `true` when the system returns a granted status that
  /// might be temporary (Android "Only this time").
  bool _sessionPermissionGranted = false;

  /// Cached permission state to avoid redundant checks.
  CameraPermissionState? _cachedState;

  /// Checks the current camera permission state.
  ///
  /// Returns the current [CameraPermissionState] based on both the system
  /// permission status and app-level session tracking.
  ///
  /// Results are cached until [clearCache] or [clearSessionPermission] is called.
  Future<CameraPermissionState> checkPermission() async {
    if (_cachedState != null) {
      return _cachedState!;
    }

    final systemStatus = await _permission.status;
    _cachedState = _mapSystemStatus(systemStatus);
    return _cachedState!;
  }

  /// Requests camera permission from the system.
  ///
  /// This will show the native permission dialog if permission has not been
  /// permanently denied. Returns the resulting [CameraPermissionState].
  ///
  /// Note: If permission is permanently denied, this will not show a dialog.
  /// Use [openSettings] to redirect the user to app settings instead.
  Future<CameraPermissionState> requestSystemPermission() async {
    final status = await _permission.request();
    final state = _mapSystemStatus(status);

    // Track if this might be a session-only grant
    if (state == CameraPermissionState.granted) {
      _sessionPermissionGranted = true;
    }

    _cachedState = state;
    return state;
  }

  /// Returns `true` if permission is in a blocked state requiring settings redirect.
  ///
  /// A blocked state means the user cannot grant permission through the normal
  /// dialog flow and needs to be redirected to system settings. This includes:
  ///
  /// - [CameraPermissionState.denied] - User denied but may have selected "Don't ask again"
  /// - [CameraPermissionState.permanentlyDenied] - User explicitly blocked the permission
  /// - [CameraPermissionState.restricted] - System/device restriction
  /// - Session-only permission that has expired (app was restarted)
  ///
  /// Use this method to determine when to show the Yes/No dialog that offers
  /// to redirect the user to system settings.
  ///
  /// ## Example
  /// ```dart
  /// final permissionService = ref.read(cameraPermissionServiceProvider);
  ///
  /// if (await permissionService.isPermissionBlocked()) {
  ///   // Show Yes/No dialog asking if user wants to open settings
  ///   final shouldOpenSettings = await showCameraSettingsDialog(context);
  ///   if (shouldOpenSettings) {
  ///     await permissionService.openSettings();
  ///   }
  /// }
  /// ```
  Future<bool> isPermissionBlocked() async {
    final state = await checkPermission();

    switch (state) {
      case CameraPermissionState.denied:
      case CameraPermissionState.permanentlyDenied:
      case CameraPermissionState.restricted:
        return true;
      case CameraPermissionState.sessionOnly:
        // Session-only is blocked if the session was cleared (app restart)
        return !_sessionPermissionGranted;
      case CameraPermissionState.granted:
      case CameraPermissionState.unknown:
        return false;
    }
  }

  /// Opens the app settings page where the user can grant camera permission.
  ///
  /// Returns `true` if the settings page was opened successfully,
  /// `false` otherwise.
  Future<bool> openSettings() async {
    return openAppSettings();
  }

  /// Returns `true` if this is a first-time permission request.
  ///
  /// A first-time request means the app has never requested camera permission
  /// from the user, so the native Android permission dialog should be shown.
  ///
  /// This method uses Android's `shouldShowRequestRationale` to distinguish
  /// between a fresh install (never requested) and a previous denial:
  ///
  /// - Fresh install: status is `denied`, rationale is `false`
  /// - User denied once: status is `denied`, rationale is `true`
  /// - User selected "Don't ask again": status is `permanentlyDenied`
  ///
  /// Use this method to determine whether to show the native permission dialog
  /// (first-time) or the Yes/No settings redirect dialog (subsequent requests).
  ///
  /// ## Example
  /// ```dart
  /// final permissionService = ref.read(cameraPermissionServiceProvider);
  ///
  /// if (await permissionService.isFirstTimeRequest()) {
  ///   // Show native Android permission dialog
  ///   await permissionService.requestSystemPermission();
  /// } else if (await permissionService.isPermissionBlocked()) {
  ///   // Show Yes/No dialog to redirect to settings
  ///   await showCameraSettingsDialog(context);
  /// }
  /// ```
  ///
  /// ## Platform Notes
  /// - On Android, this uses `shouldShowRequestRationale` from the permission system
  /// - On iOS, the behavior may differ as iOS uses a different permission model
  Future<bool> isFirstTimeRequest() async {
    final status = await _permission.status;

    // If permission is already granted or permanently denied, it's not first-time
    if (status == PermissionStatus.granted ||
        status == PermissionStatus.permanentlyDenied ||
        status == PermissionStatus.restricted ||
        status == PermissionStatus.limited ||
        status == PermissionStatus.provisional) {
      return false;
    }

    // For denied status, check if rationale should be shown
    // On Android:
    // - First-time request: shouldShowRequestRationale returns false
    // - After denial (without "Don't ask again"): returns true
    // This allows us to distinguish between never-requested and previously-denied
    final shouldShowRationale = await _permission.shouldShowRequestRationale;
    return !shouldShowRationale;
  }

  /// Clears the session permission state.
  ///
  /// Call this method on app startup to reset the temporary permission state.
  /// This ensures that "Only this time" permissions from a previous session
  /// are treated as blocked, requiring the user to grant permission again.
  ///
  /// ## Usage
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///
  ///   final container = ProviderContainer();
  ///   final permissionService = container.read(cameraPermissionServiceProvider);
  ///   permissionService.clearSessionPermission();
  ///
  ///   runApp(const MyApp());
  /// }
  /// ```
  void clearSessionPermission() {
    _sessionPermissionGranted = false;
    _cachedState = null;
  }

  /// Clears the cached permission state.
  ///
  /// Call this method to force a fresh permission check on the next call
  /// to [checkPermission]. Useful when returning from system settings.
  void clearCache() {
    _cachedState = null;
  }

  /// Clears all permission-related state including session and cache.
  ///
  /// This is equivalent to calling both [clearSessionPermission] and [clearCache].
  void clearAllPermissions() {
    _sessionPermissionGranted = false;
    _cachedState = null;
  }

  /// Maps the system [PermissionStatus] to our [CameraPermissionState].
  CameraPermissionState _mapSystemStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return _sessionPermissionGranted
            ? CameraPermissionState.sessionOnly
            : CameraPermissionState.granted;
      case PermissionStatus.denied:
        return CameraPermissionState.denied;
      case PermissionStatus.restricted:
        return CameraPermissionState.restricted;
      case PermissionStatus.limited:
        // Limited access is treated as granted for camera
        return CameraPermissionState.granted;
      case PermissionStatus.permanentlyDenied:
        return CameraPermissionState.permanentlyDenied;
      case PermissionStatus.provisional:
        // Provisional is iOS-specific, treat as granted
        return CameraPermissionState.granted;
    }
  }

  /// Returns whether session permission is currently granted.
  ///
  /// This is primarily for testing purposes.
  bool get isSessionPermissionGranted => _sessionPermissionGranted;
}
