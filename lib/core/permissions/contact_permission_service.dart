import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'permission_exception.dart';

/// Type alias for backward compatibility.
///
/// This allows existing code referencing [ContactPermissionException]
/// to work seamlessly with the common [PermissionException] base class.
typedef ContactPermissionException = PermissionException;

/// Riverpod provider for [ContactPermissionService].
///
/// Provides a singleton instance of the contact permission service for
/// dependency injection throughout the application.
final contactPermissionServiceProvider = Provider<ContactPermissionService>((ref) {
  return ContactPermissionService();
});

/// Represents the possible states of contact permission.
///
/// These states map to the underlying system permission states while providing
/// additional app-level tracking for temporary permissions.
enum ContactPermissionState {
  /// Permission status has not been checked yet.
  unknown,

  /// Contact permission is fully granted.
  granted,

  /// Contact permission was granted for this session only ("Only this time").
  ///
  /// This is an app-level state tracked when the system grants temporary permission.
  /// On Android, this corresponds to the "Only this time" option in the native dialog.
  sessionOnly,

  /// Contact permission was denied but can still be requested again.
  ///
  /// The user declined the permission but has not selected "Don't ask again".
  denied,

  /// Contacts are restricted due to device policy.
  ///
  /// This typically means contacts are disabled by enterprise policy.
  /// Permission cannot be requested.
  restricted,

  /// Contact permission was permanently denied by the user.
  ///
  /// The user selected "Don't ask again" or denied multiple times.
  /// The only way to grant permission is through system settings.
  permanentlyDenied,
}

/// Service for managing contact permission state and requests.
///
/// Uses [permission_handler] to interact with the native permission system
/// and maintains app-level state for tracking temporary permissions.
///
/// ## Usage
/// ```dart
/// final permissionService = ref.read(contactPermissionServiceProvider);
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
/// as [ContactPermissionState.sessionOnly]. Call [clearSessionPermission] on
/// app startup to reset this state for the new session.
class ContactPermissionService {
  /// Creates a [ContactPermissionService].
  ///
  /// Optionally accepts a custom [Permission] for testing purposes.
  ContactPermissionService({
    Permission? permission,
  }) : _permission = permission ?? Permission.contacts;

  /// The permission to check/request.
  final Permission _permission;

  /// Tracks whether session-level permission was granted.
  ///
  /// This is set to `true` when the system returns a granted status that
  /// might be temporary (Android "Only this time").
  bool _sessionPermissionGranted = false;

  /// Cached permission state to avoid redundant checks.
  ContactPermissionState? _cachedState;

  /// Checks the current contact permission state.
  ///
  /// Returns the current [ContactPermissionState] based on both the system
  /// permission status and app-level session tracking.
  ///
  /// Results are cached until [clearCache] or [clearSessionPermission] is called.
  Future<ContactPermissionState> checkPermission() async {
    if (_cachedState != null) {
      return _cachedState!;
    }

    final systemStatus = await _permission.status;
    _cachedState = _mapSystemStatus(systemStatus);
    return _cachedState!;
  }

  /// Requests contact permission from the system.
  ///
  /// This will show the native permission dialog if permission has not been
  /// permanently denied. Returns the resulting [ContactPermissionState].
  ///
  /// Note: If permission is permanently denied, this will not show a dialog.
  /// Use [openSettings] to redirect the user to app settings instead.
  Future<ContactPermissionState> requestSystemPermission() async {
    final status = await _permission.request();
    final state = _mapSystemStatus(status);

    // Track if this might be a session-only grant
    if (state == ContactPermissionState.granted) {
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
  /// - [ContactPermissionState.denied] - User denied but may have selected "Don't ask again"
  /// - [ContactPermissionState.permanentlyDenied] - User explicitly blocked the permission
  /// - [ContactPermissionState.restricted] - System/device restriction
  /// - Session-only permission that has expired (app was restarted)
  ///
  /// Use this method to determine when to show the Yes/No dialog that offers
  /// to redirect the user to system settings.
  Future<bool> isPermissionBlocked() async {
    final state = await checkPermission();

    switch (state) {
      case ContactPermissionState.denied:
      case ContactPermissionState.permanentlyDenied:
      case ContactPermissionState.restricted:
        return true;
      case ContactPermissionState.sessionOnly:
        // Session-only is blocked if the session was cleared (app restart)
        return !_sessionPermissionGranted;
      case ContactPermissionState.granted:
      case ContactPermissionState.unknown:
        return false;
    }
  }

  /// Opens the app settings page where the user can grant contact permission.
  ///
  /// Returns `true` if the settings page was opened successfully,
  /// `false` otherwise.
  Future<bool> openSettings() async {
    return openAppSettings();
  }

  /// Returns `true` if this is a first-time permission request.
  ///
  /// A first-time request means the app has never requested contact permission
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

  /// Maps the system [PermissionStatus] to our [ContactPermissionState].
  ContactPermissionState _mapSystemStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return _sessionPermissionGranted
            ? ContactPermissionState.sessionOnly
            : ContactPermissionState.granted;
      case PermissionStatus.denied:
        return ContactPermissionState.denied;
      case PermissionStatus.restricted:
        return ContactPermissionState.restricted;
      case PermissionStatus.limited:
        // Limited access is treated as granted for contacts
        return ContactPermissionState.granted;
      case PermissionStatus.permanentlyDenied:
        return ContactPermissionState.permanentlyDenied;
      case PermissionStatus.provisional:
        // Provisional is iOS-specific, treat as granted
        return ContactPermissionState.granted;
    }
  }

  /// Returns whether session permission is currently granted.
  ///
  /// This is primarily for testing purposes.
  bool get isSessionPermissionGranted => _sessionPermissionGranted;
}
