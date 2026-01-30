import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../exceptions/base_exception.dart';

/// Riverpod provider for [BiometricAuthService].
///
/// Provides a singleton instance of the biometric authentication service for
/// dependency injection throughout the application.
final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthService();
});

/// Represents the biometric capability status of the device.
///
/// These states indicate whether the device supports biometric authentication
/// and if it's currently available for use.
enum BiometricCapability {
  /// Capability status has not been checked yet.
  unknown,

  /// Device supports biometrics and at least one biometric is enrolled.
  ///
  /// The device has biometric hardware and the user has enrolled at least
  /// one fingerprint, face, or other biometric identifier.
  available,

  /// Device has biometric hardware but no biometrics are enrolled.
  ///
  /// The user needs to set up fingerprint, face, or other biometric
  /// authentication in their device settings before it can be used.
  notEnrolled,

  /// Device does not have biometric hardware.
  ///
  /// The device lacks the necessary hardware (fingerprint sensor, face scanner)
  /// to support biometric authentication.
  notAvailable,

  /// Biometric authentication is not supported on this platform.
  ///
  /// The current platform (OS version, device model) does not support
  /// biometric authentication through the local_auth plugin.
  notSupported,
}

/// Represents the types of biometric authentication available.
///
/// Maps to the [BiometricType] enum from the local_auth package.
enum BiometricAuthType {
  /// Fingerprint authentication.
  ///
  /// Uses the device's fingerprint sensor to authenticate the user.
  fingerprint,

  /// Face recognition authentication.
  ///
  /// Uses the device's face recognition system (Face ID, Face Unlock) to
  /// authenticate the user.
  face,

  /// Iris scanning authentication.
  ///
  /// Uses the device's iris scanner to authenticate the user.
  /// Rare on modern devices.
  iris,

  /// Weak biometric authentication.
  ///
  /// Indicates a biometric method that doesn't meet strong security requirements.
  /// This may include less secure face unlock implementations.
  weak,

  /// Strong biometric authentication.
  ///
  /// Indicates a biometric method that meets strong security requirements
  /// as defined by the platform (Android's StrongBox, iOS's Secure Enclave).
  strong,
}

/// Exception thrown when biometric authentication operations fail.
///
/// Contains the original error message and optional underlying exception.
class BiometricAuthException extends BaseException {
  /// Creates a [BiometricAuthException] with the given [message].
  const BiometricAuthException(super.message, {super.cause});
}

/// Service for managing biometric authentication operations.
///
/// Uses [LocalAuthentication] to interact with platform biometric systems:
/// - **Android**: Fingerprint, Face Unlock, Iris Scanner (via BiometricPrompt API)
/// - **iOS**: Touch ID and Face ID (via LocalAuthentication framework)
///
/// This service provides device capability checking, biometric enrollment status,
/// and authentication methods for securing app access.
///
/// ## Usage
/// ```dart
/// final biometricService = ref.read(biometricAuthServiceProvider);
///
/// // Check device capability
/// final capability = await biometricService.checkBiometricCapability();
///
/// if (capability == BiometricCapability.available) {
///   // Get available biometric types
///   final types = await biometricService.getAvailableBiometrics();
///
///   // Authenticate user
///   final authenticated = await biometricService.authenticate(
///     reason: 'Verify your identity to access encrypted documents',
///   );
///
///   if (authenticated) {
///     // Proceed with secure operation
///   }
/// }
/// ```
///
/// ## Security Considerations
/// - Always provide a clear, user-friendly reason for authentication requests
/// - Biometric authentication should be used in addition to, not instead of, other security measures
/// - On Android, the service uses BiometricPrompt API for secure, system-level authentication
/// - On iOS, the service uses LocalAuthentication framework with Secure Enclave integration
/// - Failed authentication attempts are rate-limited by the platform
class BiometricAuthService {
  /// Creates a [BiometricAuthService].
  ///
  /// Optionally accepts a custom [LocalAuthentication] instance for testing purposes.
  BiometricAuthService({
    LocalAuthentication? localAuth,
  }) : _localAuth = localAuth ?? LocalAuthentication();

  /// The local authentication instance.
  final LocalAuthentication _localAuth;

  /// Cached biometric capability state.
  BiometricCapability? _cachedCapability;

  /// Cached list of available biometric types.
  List<BiometricAuthType>? _cachedBiometrics;

  // SEC-08: Rate limiting for authentication attempts
  /// Maximum number of failed attempts before lockout.
  static const int _maxFailedAttempts = 5;

  /// Lockout duration after max failed attempts.
  static const Duration _lockoutDuration = Duration(minutes: 5);

  /// Counter for consecutive failed authentication attempts.
  int _failedAttempts = 0;

  /// Timestamp when the last lockout started.
  DateTime? _lockoutStartTime;

  /// Checks the biometric capability of the device.
  ///
  /// Returns the current [BiometricCapability] based on hardware availability
  /// and biometric enrollment status.
  ///
  /// Results are cached until [clearCache] is called. This avoids redundant
  /// hardware checks and provides better performance.
  ///
  /// Throws [BiometricAuthException] if the capability check fails.
  Future<BiometricCapability> checkBiometricCapability() async {
    if (_cachedCapability != null) {
      return _cachedCapability!;
    }

    try {
      // Check if device supports biometrics
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        _cachedCapability = BiometricCapability.notSupported;
        return _cachedCapability!;
      }

      // Check if device can authenticate (has hardware and enrolled biometrics)
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) {
        _cachedCapability = BiometricCapability.notAvailable;
        return _cachedCapability!;
      }

      // Get available biometrics to determine enrollment status
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        _cachedCapability = BiometricCapability.notEnrolled;
        return _cachedCapability!;
      }

      _cachedCapability = BiometricCapability.available;
      return _cachedCapability!;
    } on Exception catch (e) {
      throw BiometricAuthException(
        'Failed to check biometric capability',
        cause: e,
      );
    }
  }

  /// Returns the list of available biometric types on the device.
  ///
  /// This includes all enrolled biometric methods that can be used for
  /// authentication. Common types include fingerprint and face recognition.
  ///
  /// Returns an empty list if no biometrics are available or enrolled.
  ///
  /// Results are cached until [clearCache] is called.
  ///
  /// Throws [BiometricAuthException] if the query fails.
  Future<List<BiometricAuthType>> getAvailableBiometrics() async {
    if (_cachedBiometrics != null) {
      return _cachedBiometrics!;
    }

    try {
      final biometrics = await _localAuth.getAvailableBiometrics();
      _cachedBiometrics = biometrics.map(_mapBiometricType).toList();
      return _cachedBiometrics!;
    } on Exception catch (e) {
      throw BiometricAuthException(
        'Failed to get available biometrics',
        cause: e,
      );
    }
  }

  /// Authenticates the user using biometric authentication.
  ///
  /// Displays the system biometric prompt with the provided [reason].
  /// The reason should be a clear, user-friendly explanation of why
  /// authentication is required (e.g., "Verify your identity to access encrypted documents").
  ///
  /// Optional parameters:
  /// - [persistAcrossBackgrounding]: Whether authentication should automatically retry
  ///   when app returns from background instead of failing (default: false)
  /// - [biometricOnly]: Whether to allow only biometric authentication, disabling
  ///   device credentials like PIN/passcode (default: false). SEC-07: Use this to
  ///   enforce biometric-only authentication for sensitive operations.
  ///
  /// Returns `true` if authentication succeeded, `false` if the user cancelled
  /// or authentication failed.
  ///
  /// ## Platform-specific behavior:
  /// - **Android**: Shows BiometricPrompt with system UI
  /// - **iOS**: Shows LocalAuthentication dialog with system UI
  ///
  /// ## Error handling:
  /// - User cancellation returns `false` (not an exception)
  /// - Too many failed attempts may lock out biometrics temporarily (platform-enforced)
  /// - SEC-08: Application-level rate limiting also applies (5 attempts, 5 min lockout)
  /// - System errors throw [BiometricAuthException]
  ///
  /// Throws [BiometricAuthException] if authentication cannot be performed
  /// due to system errors (not user cancellation or failed attempts), or if
  /// SEC-08 rate limiting is in effect.
  Future<bool> authenticate({
    required String reason,
    bool persistAcrossBackgrounding = false,
    bool biometricOnly = false,
  }) async {
    // SEC-08: Check if we're currently in lockout
    if (isLockedOut) {
      final remainingTime = remainingLockoutTime;
      throw BiometricAuthException(
        'Too many failed attempts. Please wait ${remainingTime.inMinutes} minute(s) before trying again.',
      );
    }

    try {
      // SEC-07: Pass biometricOnly to ensure only biometric auth is accepted
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: persistAcrossBackgrounding,
      );

      // SEC-08: Update attempt counters based on result
      if (authenticated) {
        _resetFailedAttempts();
      } else {
        _recordFailedAttempt();
      }

      return authenticated;
    } on Exception catch (e) {
      // User cancellation and failed attempts should not throw exceptions
      // Only throw for system-level errors
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('cancel') ||
          errorMessage.contains('user') ||
          errorMessage.contains('auth') && errorMessage.contains('fail')) {
        // SEC-08: Record failed attempt on authentication failure
        _recordFailedAttempt();
        return false;
      }

      throw BiometricAuthException(
        'Biometric authentication failed',
        cause: e,
      );
    }
  }

  // SEC-08: Rate limiting helper methods

  /// Returns `true` if the user is currently locked out due to too many failed attempts.
  bool get isLockedOut {
    final lockoutStart = _lockoutStartTime;
    if (lockoutStart == null) return false;

    final elapsed = DateTime.now().difference(lockoutStart);
    if (elapsed >= _lockoutDuration) {
      // Lockout period has expired, reset state
      _lockoutStartTime = null;
      _failedAttempts = 0;
      return false;
    }
    return true;
  }

  /// Returns the remaining lockout time, or [Duration.zero] if not locked out.
  Duration get remainingLockoutTime {
    final lockoutStart = _lockoutStartTime;
    if (lockoutStart == null) return Duration.zero;

    final elapsed = DateTime.now().difference(lockoutStart);
    final remaining = _lockoutDuration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Returns the number of failed authentication attempts.
  int get failedAttempts => _failedAttempts;

  /// Records a failed authentication attempt.
  void _recordFailedAttempt() {
    _failedAttempts++;
    if (_failedAttempts >= _maxFailedAttempts) {
      _lockoutStartTime = DateTime.now();
    }
  }

  /// Resets the failed attempts counter after successful authentication.
  void _resetFailedAttempts() {
    _failedAttempts = 0;
    _lockoutStartTime = null;
  }

  /// Stops any ongoing authentication.
  ///
  /// Useful when the user navigates away from a screen that triggered
  /// biometric authentication, ensuring the dialog is dismissed.
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } on Exception catch (e) {
      throw BiometricAuthException(
        'Failed to stop authentication',
        cause: e,
      );
    }
  }

  /// Returns `true` if biometrics are available and enrolled on the device.
  ///
  /// This is a convenience method that checks if the device capability
  /// is [BiometricCapability.available].
  Future<bool> isBiometricAvailable() async {
    final capability = await checkBiometricCapability();
    return capability == BiometricCapability.available;
  }

  /// Returns `true` if the device has biometric hardware but no biometrics are enrolled.
  ///
  /// Use this to prompt the user to enroll biometrics in their device settings.
  Future<bool> needsEnrollment() async {
    final capability = await checkBiometricCapability();
    return capability == BiometricCapability.notEnrolled;
  }

  /// Clears the cached capability and biometrics data.
  ///
  /// Call this method to force fresh capability checks on the next call
  /// to [checkBiometricCapability] or [getAvailableBiometrics].
  ///
  /// Useful when returning from device settings where the user may have
  /// enrolled new biometrics.
  ///
  /// Note: This does NOT reset rate limiting state. Use [resetRateLimiting]
  /// explicitly if needed.
  void clearCache() {
    _cachedCapability = null;
    _cachedBiometrics = null;
  }

  /// Resets the rate limiting state.
  ///
  /// SEC-08: Use this method to reset failed attempts counter and lockout state.
  /// Should only be called after successful authentication or by admin action.
  void resetRateLimiting() {
    _resetFailedAttempts();
  }

  /// Maps the platform [BiometricType] to our [BiometricAuthType].
  BiometricAuthType _mapBiometricType(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return BiometricAuthType.face;
      case BiometricType.fingerprint:
        return BiometricAuthType.fingerprint;
      case BiometricType.iris:
        return BiometricAuthType.iris;
      case BiometricType.weak:
        return BiometricAuthType.weak;
      case BiometricType.strong:
        return BiometricAuthType.strong;
    }
  }

  /// Returns a user-friendly description of the given [BiometricAuthType].
  ///
  /// Useful for displaying available biometric methods to the user.
  static String getTypeDescription(BiometricAuthType type) {
    switch (type) {
      case BiometricAuthType.fingerprint:
        return 'Fingerprint';
      case BiometricAuthType.face:
        return 'Face Recognition';
      case BiometricAuthType.iris:
        return 'Iris Scanner';
      case BiometricAuthType.weak:
        return 'Biometric (Weak)';
      case BiometricAuthType.strong:
        return 'Biometric (Strong)';
    }
  }

  /// Returns a user-friendly description of the given [BiometricCapability].
  ///
  /// Useful for displaying capability status to the user or for debugging.
  static String getCapabilityDescription(BiometricCapability capability) {
    switch (capability) {
      case BiometricCapability.unknown:
        return 'Unknown';
      case BiometricCapability.available:
        return 'Biometric authentication is available';
      case BiometricCapability.notEnrolled:
        return 'No biometrics enrolled. Please set up biometric authentication in your device settings.';
      case BiometricCapability.notAvailable:
        return 'This device does not support biometric authentication';
      case BiometricCapability.notSupported:
        return 'Biometric authentication is not supported on this platform';
    }
  }
}
