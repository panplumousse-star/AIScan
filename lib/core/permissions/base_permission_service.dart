import 'package:permission_handler/permission_handler.dart';

/// Represents the possible states of a permission.
///
/// These states map to the underlying system permission states while providing
/// additional app-level tracking for temporary permissions.
enum PermissionState {
  /// Permission status has not been checked yet.
  unknown,

  /// Permission is fully granted.
  granted,

  /// Permission was granted for this session only ("Only this time").
  ///
  /// This is an app-level state tracked when the system grants temporary permission.
  /// On Android, this corresponds to the "Only this time" option in the native dialog.
  sessionOnly,

  /// Permission was denied but can still be requested again.
  ///
  /// The user declined the permission but has not selected "Don't ask again".
  denied,

  /// Permission is restricted due to device policy or lack of hardware.
  ///
  /// This typically means the feature is disabled by enterprise policy or
  /// the device doesn't have the required hardware. Permission cannot be requested.
  restricted,

  /// Permission was permanently denied by the user.
  ///
  /// The user selected "Don't ask again" or denied multiple times.
  /// The only way to grant permission is through system settings.
  permanentlyDenied,
}

/// Base service for managing permission state and requests.
///
/// Uses [permission_handler] to interact with the native permission system
/// and maintains app-level state for tracking temporary permissions.
///
/// Extend this class to create specific permission services (e.g., camera, storage).
///
/// ## Usage
/// ```dart
/// class CameraPermissionService extends BasePermissionService {
///   CameraPermissionService() : super(Permission.camera);
/// }
/// ```
///
/// ## Session Permissions
/// When the user grants "Only this time" permission, this service tracks it
/// as [PermissionState.sessionOnly]. Call [clearSessionPermission] on
/// app startup to reset this state for the new session.
class BasePermissionService {
  /// Creates a [BasePermissionService] with the given [Permission].
  BasePermissionService(this._permission);

  /// The permission to check/request.
  final Permission _permission;

  /// Tracks whether session-level permission was granted.
  bool _sessionPermissionGranted = false;

  /// Cached permission state to avoid redundant checks.
  PermissionState? _cachedState;

  /// Checks the current permission state.
  ///
  /// Returns the current [PermissionState] based on both the system
  /// permission status and app-level session tracking.
  ///
  /// Results are cached until [clearCache] or [clearSessionPermission] is called.
  Future<PermissionState> checkPermission() async {
    if (_cachedState != null) {
      return _cachedState!;
    }

    final systemStatus = await _permission.status;
    _cachedState = _mapSystemStatus(systemStatus);
    return _cachedState!;
  }

  /// Requests permission from the system.
  ///
  /// This will show the native permission dialog if permission has not been
  /// permanently denied. Returns the resulting [PermissionState].
  ///
  /// Note: If permission is permanently denied, this will not show a dialog.
  /// Use [openSettings] to redirect the user to app settings instead.
  Future<PermissionState> requestSystemPermission() async {
    final status = await _permission.request();
    final state = _mapSystemStatus(status);

    // Track if this might be a session-only grant
    if (state == PermissionState.granted) {
      _sessionPermissionGranted = true;
    }

    _cachedState = state;
    return state;
  }

  /// Returns `true` if permission is in a blocked state requiring settings redirect.
  ///
  /// A blocked state means the user cannot grant permission through the normal
  /// dialog flow and needs to be redirected to system settings.
  Future<bool> isPermissionBlocked() async {
    final state = await checkPermission();

    switch (state) {
      case PermissionState.denied:
      case PermissionState.permanentlyDenied:
      case PermissionState.restricted:
        return true;
      case PermissionState.sessionOnly:
        // Session-only is blocked if the session was cleared (app restart)
        return !_sessionPermissionGranted;
      case PermissionState.granted:
      case PermissionState.unknown:
        return false;
    }
  }

  /// Opens the app settings page where the user can grant permission.
  ///
  /// Returns `true` if the settings page was opened successfully.
  Future<bool> openSettings() async {
    return openAppSettings();
  }

  /// Returns `true` if this is a first-time permission request.
  ///
  /// A first-time request means the app has never requested this permission
  /// from the user, so the native Android permission dialog should be shown.
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
    final shouldShowRationale = await _permission.shouldShowRequestRationale;
    return !shouldShowRationale;
  }

  /// Clears the session permission state.
  ///
  /// Call this method on app startup to reset the temporary permission state.
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
  void clearAllPermissions() {
    _sessionPermissionGranted = false;
    _cachedState = null;
  }

  /// Maps the system [PermissionStatus] to our [PermissionState].
  PermissionState _mapSystemStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return _sessionPermissionGranted
            ? PermissionState.sessionOnly
            : PermissionState.granted;
      case PermissionStatus.denied:
        return PermissionState.denied;
      case PermissionStatus.restricted:
        return PermissionState.restricted;
      case PermissionStatus.limited:
        // Limited access is treated as granted
        return PermissionState.granted;
      case PermissionStatus.permanentlyDenied:
        return PermissionState.permanentlyDenied;
      case PermissionStatus.provisional:
        // Provisional is iOS-specific, treat as granted
        return PermissionState.granted;
    }
  }

  /// Returns whether session permission is currently granted.
  ///
  /// This is primarily for testing purposes.
  bool get isSessionPermissionGranted => _sessionPermissionGranted;
}
