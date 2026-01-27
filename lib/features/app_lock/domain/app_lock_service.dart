import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/biometric_auth_service.dart';
import '../../../core/security/secure_storage_service.dart';

/// Provider that tracks when the app was just unlocked.
///
/// This is used to show a special unlock animation on the home screen
/// mascot for a few seconds after successful authentication.
final justUnlockedProvider = StateProvider<bool>((ref) => false);

/// Riverpod provider for [AppLockService].
///
/// Provides a singleton instance of the app lock service for
/// dependency injection throughout the application.
final appLockServiceProvider = Provider<AppLockService>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  final biometricAuth = ref.watch(biometricAuthServiceProvider);
  return AppLockService(
    secureStorage: secureStorage,
    biometricAuth: biometricAuth,
  );
});

/// Provider that checks if the lock screen should be shown.
///
/// This provider checks the app lock service to determine whether
/// the user needs to authenticate before accessing the app.
/// Uses autoDispose to re-check when the app comes to foreground.
final shouldShowLockScreenProvider =
    FutureProvider.autoDispose<bool>((ref) {
  final appLockService = ref.read(appLockServiceProvider);
  return appLockService.shouldShowLockScreen();
});

/// Exception thrown when app lock operations fail.
///
/// Contains the original error message and optional underlying exception.
class AppLockException implements Exception {
  /// Creates an [AppLockException] with the given [message].
  const AppLockException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'AppLockException: $message (caused by: $cause)';
    }
    return 'AppLockException: $message';
  }
}

/// Represents the timeout duration before re-authentication is required.
///
/// These durations define how long the app can remain unlocked after
/// successful authentication before requiring the user to authenticate again.
enum AppLockTimeout {
  /// Require authentication immediately when app comes to foreground.
  ///
  /// The most secure option - user must authenticate every time they
  /// open the app, even if they just closed it moments ago.
  immediate,

  /// Require authentication after 1 minute of inactivity.
  ///
  /// Good balance between security and convenience for quick task switching.
  oneMinute,

  /// Require authentication after 5 minutes of inactivity.
  ///
  /// Suitable for moderate security needs with better user experience.
  fiveMinutes,

  /// Require authentication after 30 minutes of inactivity.
  ///
  /// The most lenient option - suitable when convenience is prioritized
  /// over maximum security.
  thirtyMinutes;

  /// Returns the duration in seconds for this timeout.
  int get seconds {
    switch (this) {
      case AppLockTimeout.immediate:
        return 0;
      case AppLockTimeout.oneMinute:
        return 60;
      case AppLockTimeout.fiveMinutes:
        return 300;
      case AppLockTimeout.thirtyMinutes:
        return 1800;
    }
  }

  /// Returns a human-readable label for this timeout option.
  String get label {
    switch (this) {
      case AppLockTimeout.immediate:
        return 'Immediate';
      case AppLockTimeout.oneMinute:
        return '1 minute';
      case AppLockTimeout.fiveMinutes:
        return '5 minutes';
      case AppLockTimeout.thirtyMinutes:
        return '30 minutes';
    }
  }

  /// Creates an [AppLockTimeout] from a duration in seconds.
  ///
  /// Returns [immediate] if [seconds] is 0 or negative.
  /// Returns the closest matching timeout if no exact match exists.
  static AppLockTimeout fromSeconds(int seconds) {
    if (seconds <= 0) return AppLockTimeout.immediate;
    if (seconds <= 60) return AppLockTimeout.oneMinute;
    if (seconds <= 300) return AppLockTimeout.fiveMinutes;
    return AppLockTimeout.thirtyMinutes;
  }
}

/// Service for managing app lock state and biometric authentication settings.
///
/// This service coordinates between biometric authentication and secure storage
/// to provide app-level security. It manages:
/// - **Lock enabled/disabled state**: Whether biometric lock is active
/// - **Timeout settings**: When to require re-authentication
/// - **Authentication state**: Tracking when the user last authenticated
///
/// ## Usage
/// ```dart
/// final appLock = ref.read(appLockServiceProvider);
///
/// // Initialize service on app startup
/// await appLock.initialize();
///
/// // Check if lock screen should be shown
/// if (await appLock.shouldShowLockScreen()) {
///   // Show lock screen
/// }
///
/// // Enable biometric lock
/// await appLock.setEnabled(true);
///
/// // Set timeout
/// await appLock.setTimeout(AppLockTimeout.fiveMinutes);
///
/// // Record successful authentication
/// await appLock.recordSuccessfulAuth();
/// ```
///
/// ## Security Considerations
/// - Settings are stored in secure storage to prevent tampering
/// - Last authentication time is kept in memory only (not persisted)
/// - Service integrates with [BiometricAuthService] for actual authentication
/// - Timeout enforcement happens on app launch and when returning from background
class AppLockService {
  /// Creates an [AppLockService] with the given dependencies.
  AppLockService({
    required SecureStorageService secureStorage,
    required BiometricAuthService biometricAuth,
  })  : _secureStorage = secureStorage,
        _biometricAuth = biometricAuth;

  /// The secure storage service for persisting settings.
  final SecureStorageService _secureStorage;

  /// The biometric authentication service.
  final BiometricAuthService _biometricAuth;

  /// Storage key for the app lock enabled state.
  static const String _enabledKey = 'aiscan_app_lock_enabled';

  /// Storage key for the app lock timeout duration (in seconds).
  static const String _timeoutKey = 'aiscan_app_lock_timeout_seconds';

  /// Timestamp of the last successful authentication.
  ///
  /// Stored in memory only - not persisted to storage.
  /// This resets to null when the app is restarted, ensuring
  /// authentication is required on app launch.
  DateTime? _lastAuthTime;

  /// Whether the app lock feature is enabled.
  bool _isEnabled = false;

  /// Current timeout setting.
  AppLockTimeout _timeout = AppLockTimeout.immediate;

  /// Whether the service has been initialized.
  bool _isInitialized = false;

  /// Initializes the service by loading settings from secure storage.
  ///
  /// This should be called once during app startup, before checking
  /// if the lock screen should be shown.
  ///
  /// Throws [AppLockException] if initialization fails.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load enabled state
      final enabledValue = await _secureStorage.getUserData(_enabledKey);
      _isEnabled = enabledValue == 'true';

      // Load timeout setting
      final timeoutValue = await _secureStorage.getUserData(_timeoutKey);
      if (timeoutValue != null) {
        final seconds = int.tryParse(timeoutValue) ?? 0;
        _timeout = AppLockTimeout.fromSeconds(seconds);
      }

      _isInitialized = true;
    } on SecureStorageException catch (e) {
      throw AppLockException(
        'Failed to initialize app lock service',
        cause: e,
      );
    } on Exception catch (e) {
      throw AppLockException(
        'Failed to initialize app lock service',
        cause: e,
      );
    }
  }

  /// Returns whether the app lock feature is enabled.
  ///
  /// Throws [AppLockException] if the service has not been initialized.
  bool isEnabled() {
    _ensureInitialized();
    return _isEnabled;
  }

  /// Enables or disables the app lock feature.
  ///
  /// When enabling, the device must have biometric authentication available.
  /// Use [BiometricAuthService.isBiometricAvailable] to check before enabling.
  ///
  /// Throws [AppLockException] if:
  /// - The service has not been initialized
  /// - Attempting to enable when biometrics are not available
  /// - Storage operation fails
  Future<void> setEnabled(bool enabled) async {
    _ensureInitialized();

    // If enabling, verify biometrics are available
    if (enabled) {
      final isAvailable = await _biometricAuth.isBiometricAvailable();
      if (!isAvailable) {
        throw const AppLockException(
          'Cannot enable app lock: biometric authentication is not available',
        );
      }
    }

    try {
      await _secureStorage.storeUserData(
        _enabledKey,
        enabled ? 'true' : 'false',
      );
      _isEnabled = enabled;

      // Clear auth state when disabling
      if (!enabled) {
        _lastAuthTime = null;
      }
    } on SecureStorageException catch (e) {
      throw AppLockException(
        'Failed to save app lock enabled state',
        cause: e,
      );
    } on Exception catch (e) {
      throw AppLockException(
        'Failed to save app lock enabled state',
        cause: e,
      );
    }
  }

  /// Returns the current timeout setting.
  ///
  /// Throws [AppLockException] if the service has not been initialized.
  AppLockTimeout getTimeout() {
    _ensureInitialized();
    return _timeout;
  }

  /// Sets the timeout duration for re-authentication.
  ///
  /// This determines how long the app can remain unlocked after
  /// successful authentication before requiring the user to authenticate again.
  ///
  /// Throws [AppLockException] if:
  /// - The service has not been initialized
  /// - Storage operation fails
  Future<void> setTimeout(AppLockTimeout timeout) async {
    _ensureInitialized();

    try {
      await _secureStorage.storeUserData(
        _timeoutKey,
        timeout.seconds.toString(),
      );
      _timeout = timeout;
    } on SecureStorageException catch (e) {
      throw AppLockException(
        'Failed to save app lock timeout setting',
        cause: e,
      );
    } on Exception catch (e) {
      throw AppLockException(
        'Failed to save app lock timeout setting',
        cause: e,
      );
    }
  }

  /// Returns whether the lock screen should be shown.
  ///
  /// The lock screen should be shown when:
  /// 1. App lock is enabled
  /// 2. User has not authenticated yet, or the timeout has elapsed
  ///
  /// This should be called on app launch and when returning from background.
  ///
  /// Throws [AppLockException] if the service has not been initialized.
  Future<bool> shouldShowLockScreen() async {
    _ensureInitialized();

    // If app lock is disabled, never show lock screen
    if (!_isEnabled) {
      return false;
    }

    // If never authenticated, show lock screen
    if (_lastAuthTime == null) {
      return true;
    }

    // Check if timeout has elapsed
    final now = DateTime.now();
    final elapsed = now.difference(_lastAuthTime!);
    final timeoutDuration = Duration(seconds: _timeout.seconds);

    return elapsed >= timeoutDuration;
  }

  /// Records a successful authentication.
  ///
  /// This updates the last authentication timestamp, which is used
  /// to determine when re-authentication is required based on the
  /// configured timeout.
  ///
  /// Call this method after the user successfully authenticates
  /// via the lock screen.
  ///
  /// Throws [AppLockException] if the service has not been initialized.
  void recordSuccessfulAuth() {
    _ensureInitialized();
    _lastAuthTime = DateTime.now();
  }

  /// Clears the authentication state.
  ///
  /// This forces the lock screen to be shown on the next check,
  /// regardless of timeout settings.
  ///
  /// Useful when explicitly locking the app or when the user logs out.
  void clearAuthState() {
    _lastAuthTime = null;
  }

  /// Returns whether biometric authentication is available on the device.
  ///
  /// This is a convenience method that checks the underlying
  /// [BiometricAuthService] for device capability.
  ///
  /// Use this to determine whether to show the app lock enable toggle
  /// in settings, or to show a message explaining why the feature is
  /// not available.
  Future<bool> isBiometricAvailable() {
    return _biometricAuth.isBiometricAvailable();
  }

  /// Returns the biometric capability status of the device.
  ///
  /// This provides detailed information about why biometrics might
  /// not be available (no hardware, not enrolled, etc.).
  Future<BiometricCapability> getBiometricCapability() {
    return _biometricAuth.checkBiometricCapability();
  }

  /// Authenticates the user using biometric authentication.
  ///
  /// This is a convenience method that wraps [BiometricAuthService.authenticate]
  /// with an app-specific reason message.
  ///
  /// Returns `true` if authentication succeeded, `false` if the user cancelled
  /// or authentication failed.
  ///
  /// Throws [BiometricAuthException] if authentication cannot be performed
  /// due to system errors.
  Future<bool> authenticateUser() {
    return _biometricAuth.authenticate(
      reason: 'Verify your identity to access Scanaï',
    );
  }

  /// Ensures the service has been initialized.
  ///
  /// Throws [AppLockException] if not initialized.
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw const AppLockException(
        'AppLockService has not been initialized. Call initialize() first.',
      );
    }
  }

  /// Resets the service to its initial state.
  ///
  /// This is primarily useful for testing. In production, avoid calling
  /// this method as it will require re-initialization.
  void reset() {
    _isInitialized = false;
    _isEnabled = false;
    _timeout = AppLockTimeout.immediate;
    _lastAuthTime = null;
  }
}
