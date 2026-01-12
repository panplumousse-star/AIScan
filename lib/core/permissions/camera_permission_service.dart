import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';

/// Riverpod provider for [CameraPermissionService].
///
/// Provides a singleton instance of the camera permission service for
/// dependency injection throughout the application.
final cameraPermissionServiceProvider = Provider<CameraPermissionService>((ref) {
  return CameraPermissionService();
});

/// Represents the current state of camera permission.
///
/// This enum tracks both the user's consent choice and the system-level
/// permission status for comprehensive permission management.
enum CameraPermissionState {
  /// Initial state before permission has been checked.
  ///
  /// The app should check permission status before proceeding.
  unknown,

  /// User has permanently granted camera permission.
  ///
  /// This permission persists across app restarts and is stored
  /// in secure storage.
  granted,

  /// User has granted camera permission for the current session only.
  ///
  /// This permission is stored in memory and will be reset when
  /// the app process terminates.
  sessionOnly,

  /// User has denied camera permission.
  ///
  /// The camera cannot be accessed. The user should be informed
  /// why the camera is needed and how to grant permission.
  denied,

  /// Camera access is restricted by the system.
  ///
  /// This occurs on iOS with parental controls or MDM profiles,
  /// or when the device doesn't have a camera.
  restricted,

  /// Camera permission was permanently denied by the user.
  ///
  /// The user selected "Don't ask again" in the system permission dialog.
  /// They must manually enable the permission in device settings.
  permanentlyDenied,
}

/// Exception thrown when camera permission operations fail.
///
/// Contains the original error message and optional underlying exception.
class CameraPermissionException implements Exception {
  /// Creates a [CameraPermissionException] with the given [message].
  const CameraPermissionException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'CameraPermissionException: $message (caused by: $cause)';
    }
    return 'CameraPermissionException: $message';
  }
}

/// Service for managing camera permission requests and state.
///
/// Handles both system-level camera permissions (via permission_handler)
/// and user consent tracking with three options:
/// - **Permanent Grant**: Stored in secure storage, persists across restarts
/// - **Session Grant**: Stored in memory, resets when app closes
/// - **Denial**: Prevents camera access with appropriate user feedback
///
/// ## Usage
/// ```dart
/// final permissionService = ref.read(cameraPermissionServiceProvider);
///
/// // Check current permission state
/// final state = await permissionService.checkPermission();
///
/// // Request permission if not granted
/// if (!permissionService.isAccessAllowed) {
///   // Show permission dialog and request system permission
///   final result = await permissionService.requestSystemPermission();
/// }
/// ```
///
/// ## App Lifecycle
/// Call [clearSessionPermission] on app startup to reset session-only
/// permissions from the previous run:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   final service = CameraPermissionService();
///   service.clearSessionPermission();
///   // Continue with app initialization...
/// }
/// ```
///
/// ## Security Considerations
/// - Permanent grants are stored using flutter_secure_storage
/// - Session grants are stored in memory only
/// - System permission must also be granted for camera access
class CameraPermissionService {
  /// Creates a [CameraPermissionService] with platform-optimized storage.
  CameraPermissionService({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? _createSecureStorage();

  /// The underlying secure storage instance.
  final FlutterSecureStorage _storage;

  /// Key used to store the permanent permission grant in secure storage.
  static const String _permissionStorageKey = 'aiscan_camera_permission';

  /// Value stored for permanent grant.
  static const String _grantedValue = 'granted';

  /// Value stored for permanent denial.
  static const String _deniedValue = 'denied';

  /// In-memory flag for session-only permission.
  ///
  /// This is reset when the app process terminates.
  bool _sessionPermissionGranted = false;

  /// Cached permission state to avoid redundant storage reads.
  CameraPermissionState? _cachedState;

  /// Creates a [FlutterSecureStorage] instance with platform-optimized options.
  static FlutterSecureStorage _createSecureStorage() {
    const androidOptions = AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'aiscan_secure_prefs',
      preferencesKeyPrefix: 'aiscan_',
    );

    const iOSOptions = IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
      accountName: 'AIScan',
    );

    return const FlutterSecureStorage(
      aOptions: androidOptions,
      iOptions: iOSOptions,
    );
  }

  /// Checks the current camera permission state.
  ///
  /// This method checks both:
  /// 1. The app's stored permission consent (permanent or session)
  /// 2. The system-level camera permission status
  ///
  /// Returns the combined [CameraPermissionState] based on both factors.
  ///
  /// Throws [CameraPermissionException] if checking fails.
  Future<CameraPermissionState> checkPermission() async {
    try {
      // First check system-level permission
      final systemStatus = await Permission.camera.status;

      // If system permission is restricted or permanently denied,
      // that takes precedence
      if (systemStatus.isRestricted) {
        _cachedState = CameraPermissionState.restricted;
        return CameraPermissionState.restricted;
      }

      if (systemStatus.isPermanentlyDenied) {
        _cachedState = CameraPermissionState.permanentlyDenied;
        return CameraPermissionState.permanentlyDenied;
      }

      // Check session permission first (takes precedence if set)
      if (_sessionPermissionGranted) {
        // Verify system permission is also granted
        if (systemStatus.isGranted) {
          _cachedState = CameraPermissionState.sessionOnly;
          return CameraPermissionState.sessionOnly;
        }
        // Session permission set but system permission revoked
        _sessionPermissionGranted = false;
      }

      // Check persistent permission
      final storedValue = await _storage.read(key: _permissionStorageKey);

      if (storedValue == _grantedValue) {
        // Verify system permission is also granted
        if (systemStatus.isGranted) {
          _cachedState = CameraPermissionState.granted;
          return CameraPermissionState.granted;
        }
        // User consent granted but system permission revoked
        // They need to re-grant system permission
        _cachedState = CameraPermissionState.denied;
        return CameraPermissionState.denied;
      }

      if (storedValue == _deniedValue) {
        _cachedState = CameraPermissionState.denied;
        return CameraPermissionState.denied;
      }

      // No stored permission - state is unknown
      _cachedState = CameraPermissionState.unknown;
      return CameraPermissionState.unknown;
    } on Exception catch (e) {
      throw CameraPermissionException(
        'Failed to check camera permission',
        cause: e,
      );
    }
  }

  /// Requests camera permission from the system.
  ///
  /// This triggers the platform-specific permission dialog. The result
  /// indicates whether the system permission was granted.
  ///
  /// This method only requests system permission - it does not update
  /// the app's consent state. Use [grantPermanentPermission] or
  /// [grantSessionPermission] to record user consent.
  ///
  /// Returns the [CameraPermissionState] after the system dialog.
  ///
  /// Throws [CameraPermissionException] if the request fails.
  Future<CameraPermissionState> requestSystemPermission() async {
    try {
      final status = await Permission.camera.request();

      if (status.isGranted) {
        // System permission granted - check if we have app consent
        if (_sessionPermissionGranted) {
          _cachedState = CameraPermissionState.sessionOnly;
          return CameraPermissionState.sessionOnly;
        }

        final storedValue = await _storage.read(key: _permissionStorageKey);
        if (storedValue == _grantedValue) {
          _cachedState = CameraPermissionState.granted;
          return CameraPermissionState.granted;
        }

        // System granted but no app consent yet - return unknown
        // to trigger consent dialog
        _cachedState = CameraPermissionState.unknown;
        return CameraPermissionState.unknown;
      }

      if (status.isPermanentlyDenied) {
        _cachedState = CameraPermissionState.permanentlyDenied;
        return CameraPermissionState.permanentlyDenied;
      }

      if (status.isRestricted) {
        _cachedState = CameraPermissionState.restricted;
        return CameraPermissionState.restricted;
      }

      // Permission denied
      _cachedState = CameraPermissionState.denied;
      return CameraPermissionState.denied;
    } on Exception catch (e) {
      throw CameraPermissionException(
        'Failed to request camera permission',
        cause: e,
      );
    }
  }

  /// Grants permanent camera permission.
  ///
  /// This stores the permission grant in secure storage, making it
  /// persist across app restarts and device reboots.
  ///
  /// Throws [CameraPermissionException] if storing the permission fails.
  Future<void> grantPermanentPermission() async {
    try {
      await _storage.write(
        key: _permissionStorageKey,
        value: _grantedValue,
      );
      _sessionPermissionGranted = false; // Clear session flag
      _cachedState = CameraPermissionState.granted;
    } on Exception catch (e) {
      throw CameraPermissionException(
        'Failed to store permanent permission grant',
        cause: e,
      );
    }
  }

  /// Grants camera permission for the current session only.
  ///
  /// This stores the permission in memory, so it will be reset when
  /// the app process terminates. Does not persist to storage.
  void grantSessionPermission() {
    _sessionPermissionGranted = true;
    _cachedState = CameraPermissionState.sessionOnly;
  }

  /// Records that the user denied camera permission.
  ///
  /// This stores the denial in secure storage. The user will need
  /// to be re-prompted if they want to grant permission later.
  ///
  /// Throws [CameraPermissionException] if storing the denial fails.
  Future<void> denyPermission() async {
    try {
      await _storage.write(
        key: _permissionStorageKey,
        value: _deniedValue,
      );
      _sessionPermissionGranted = false;
      _cachedState = CameraPermissionState.denied;
    } on Exception catch (e) {
      throw CameraPermissionException(
        'Failed to store permission denial',
        cause: e,
      );
    }
  }

  /// Clears the session-only permission flag.
  ///
  /// Call this method on app startup to ensure session permissions
  /// from the previous run are not carried over.
  ///
  /// This method does NOT clear permanent permissions - only the
  /// in-memory session flag.
  void clearSessionPermission() {
    _sessionPermissionGranted = false;
    // Invalidate cache to force re-check
    _cachedState = null;
  }

  /// Clears all permission state, including permanent grants.
  ///
  /// This resets the permission state to [CameraPermissionState.unknown].
  /// Use this when the user wants to reset their permission choice.
  ///
  /// Throws [CameraPermissionException] if clearing fails.
  Future<void> clearAllPermissions() async {
    try {
      await _storage.delete(key: _permissionStorageKey);
      _sessionPermissionGranted = false;
      _cachedState = CameraPermissionState.unknown;
    } on Exception catch (e) {
      throw CameraPermissionException(
        'Failed to clear permission state',
        cause: e,
      );
    }
  }

  /// Whether camera access is currently allowed.
  ///
  /// Returns `true` if the permission state is either [CameraPermissionState.granted]
  /// or [CameraPermissionState.sessionOnly].
  ///
  /// **Note**: This uses the cached state if available. Call [checkPermission]
  /// first to ensure the cache is up to date.
  bool get isAccessAllowed {
    final state = _cachedState;
    return state == CameraPermissionState.granted ||
        state == CameraPermissionState.sessionOnly;
  }

  /// Whether the user needs to grant permission.
  ///
  /// Returns `true` if the permission state is [CameraPermissionState.unknown],
  /// indicating the user has not yet made a choice.
  ///
  /// **Note**: This uses the cached state if available. Call [checkPermission]
  /// first to ensure the cache is up to date.
  bool get needsPermission {
    final state = _cachedState;
    return state == null || state == CameraPermissionState.unknown;
  }

  /// Whether the system permission requires opening settings.
  ///
  /// Returns `true` if the permission state is [CameraPermissionState.permanentlyDenied]
  /// or [CameraPermissionState.restricted], meaning the user must change
  /// the permission in device settings.
  ///
  /// **Note**: This uses the cached state if available. Call [checkPermission]
  /// first to ensure the cache is up to date.
  bool get requiresSettingsChange {
    final state = _cachedState;
    return state == CameraPermissionState.permanentlyDenied ||
        state == CameraPermissionState.restricted;
  }

  /// Opens the app settings page for the user to change permissions.
  ///
  /// Use this when [requiresSettingsChange] is `true` to guide the user
  /// to manually enable camera permission.
  ///
  /// Returns `true` if the settings page was opened successfully.
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Gets the current cached permission state.
  ///
  /// Returns `null` if no check has been performed yet.
  /// Use [checkPermission] to get an up-to-date state.
  CameraPermissionState? get currentState => _cachedState;
}
