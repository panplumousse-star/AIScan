import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jailbreak_root_detection/jailbreak_root_detection.dart';

/// Riverpod provider for [DeviceSecurityService].
///
/// Provides a singleton instance of the device security service for
/// dependency injection throughout the application.
final deviceSecurityServiceProvider = Provider<DeviceSecurityService>((ref) {
  return DeviceSecurityService();
});

/// Represents the security status of the device.
///
/// These states indicate whether the device has been compromised through
/// rooting (Android) or jailbreaking (iOS).
enum DeviceSecurityStatus {
  /// Security status has not been checked yet.
  unknown,

  /// Device is secure - not rooted or jailbroken.
  ///
  /// The device is running in its standard configuration with normal
  /// security protections in place.
  secure,

  /// Device is rooted (Android) or jailbroken (iOS).
  ///
  /// The device has been modified to grant elevated privileges, which
  /// compromises the security model. On such devices:
  /// - App sandboxing can be bypassed
  /// - Secure storage (KeyStore/Keychain) can be accessed
  /// - Memory can be inspected to extract encryption keys
  /// - Biometric authentication can be bypassed
  compromised,

  /// Unable to determine device security status.
  ///
  /// The security check failed or encountered an error. This may occur
  /// on unsupported platforms or due to permission issues.
  unknownError,
}

/// Represents specific security threats detected on the device.
///
/// These flags indicate individual security compromises that were detected.
enum DeviceSecurityThreat {
  /// Device is rooted (Android).
  ///
  /// Root access grants elevated privileges that can bypass app sandboxing
  /// and security features.
  rooted,

  /// Device is jailbroken (iOS).
  ///
  /// Jailbreaking removes iOS restrictions and allows unauthorized code
  /// execution outside the app sandbox.
  jailbroken,

  /// Development mode is enabled (Android).
  ///
  /// USB debugging or other development features are enabled, which may
  /// indicate a device configured for modification or testing.
  developmentMode,

  /// Device is running on an emulator or simulator.
  ///
  /// Emulated devices may have different security characteristics and
  /// are commonly used for reverse engineering.
  emulator,
}

/// Results from a device security check.
///
/// Contains the overall security status and details about any specific
/// threats that were detected.
class DeviceSecurityResult {
  /// Creates a [DeviceSecurityResult] with the given status and threats.
  const DeviceSecurityResult({
    required this.status,
    required this.threats,
    this.details,
  });

  /// The overall security status of the device.
  final DeviceSecurityStatus status;

  /// List of specific security threats detected.
  final List<DeviceSecurityThreat> threats;

  /// Additional details about the security check (for debugging).
  final String? details;

  /// Whether the device is compromised.
  bool get isCompromised => status == DeviceSecurityStatus.compromised;

  /// Whether the device is secure.
  bool get isSecure => status == DeviceSecurityStatus.secure;

  /// Whether the device has any detected threats.
  bool get hasThreats => threats.isNotEmpty;

  @override
  String toString() {
    final buffer = StringBuffer('DeviceSecurityResult(');
    buffer.write('status: $status');
    if (threats.isNotEmpty) {
      buffer.write(', threats: $threats');
    }
    if (details != null) {
      buffer.write(', details: $details');
    }
    buffer.write(')');
    return buffer.toString();
  }
}

/// Exception thrown when device security check operations fail.
///
/// Contains the original error message and optional underlying exception.
class DeviceSecurityException implements Exception {
  /// Creates a [DeviceSecurityException] with the given [message].
  const DeviceSecurityException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'DeviceSecurityException: $message (caused by: $cause)';
    }
    return 'DeviceSecurityException: $message';
  }
}

/// Service for detecting device security compromises.
///
/// Uses [JailbreakRootDetection] to check for rooted (Android) and
/// jailbroken (iOS) devices:
/// - **Android**: Checks for root access, su binary, dangerous apps, and development mode
/// - **iOS**: Checks for jailbreak indicators, Cydia, suspicious file paths
///
/// This service provides device security status checking to inform users when
/// the app is running on a compromised device where security guarantees
/// (encryption, secure storage, biometric auth) may not be reliable.
///
/// ## Usage
/// ```dart
/// final securityService = ref.read(deviceSecurityServiceProvider);
///
/// // Check device security status
/// final result = await securityService.checkDeviceSecurity();
///
/// if (result.isCompromised) {
///   // Show warning dialog to user
///   showSecurityWarningDialog(
///     threats: result.threats,
///   );
/// }
/// ```
///
/// ## Security Considerations
/// - All client-side security checks can be bypassed on sufficiently compromised devices
/// - This is informational only, not a security boundary
/// - False positives may occur on developer devices or custom ROMs
/// - The app remains functional on compromised devices - users are informed but not blocked
/// - Results are cached for performance - call [clearCache] to force a fresh check
class DeviceSecurityService {
  /// Creates a [DeviceSecurityService].
  ///
  /// Optionally accepts a custom [JailbreakRootDetection] instance for testing purposes.
  DeviceSecurityService({
    JailbreakRootDetection? jailbreakRootDetection,
  }) : _jailbreakRootDetection =
            jailbreakRootDetection ?? JailbreakRootDetection.instance;

  /// The jailbreak/root detection instance.
  final JailbreakRootDetection _jailbreakRootDetection;

  /// Cached security check result.
  DeviceSecurityResult? _cachedResult;

  /// Checks the security status of the device.
  ///
  /// Performs a comprehensive check for rooting (Android) and jailbreaking (iOS).
  /// Returns a [DeviceSecurityResult] with the overall status and detected threats.
  ///
  /// Results are cached until [clearCache] is called. This avoids redundant
  /// checks and provides better performance.
  ///
  /// The check examines:
  /// - **Root/jailbreak status**: Whether the device has elevated privileges
  /// - **Development mode**: Whether debugging features are enabled (Android)
  /// - **Emulator detection**: Whether running on a simulator/emulator
  ///
  /// Returns a [DeviceSecurityResult] with status and detected threats.
  ///
  /// Does not throw exceptions - errors are reported through the result status.
  Future<DeviceSecurityResult> checkDeviceSecurity() async {
    if (_cachedResult != null) {
      return _cachedResult!;
    }

    try {
      final threats = <DeviceSecurityThreat>[];
      final details = <String>[];

      // Check for jailbreak/root
      final isJailbroken = await _jailbreakRootDetection.isJailBroken;
      if (isJailbroken) {
        threats.add(DeviceSecurityThreat.jailbroken);
        details.add('Device is jailbroken/rooted');
      }

      // Check for development mode (Android)
      final isDevelopmentMode = await _jailbreakRootDetection.isDevMode;
      if (isDevelopmentMode) {
        threats.add(DeviceSecurityThreat.developmentMode);
        details.add('Development mode is enabled');
      }

      // Check if running on emulator
      final isRealDevice = await _jailbreakRootDetection.isRealDevice;
      if (!isRealDevice) {
        threats.add(DeviceSecurityThreat.emulator);
        details.add('Running on emulator/simulator');
      }

      // Determine overall status
      final DeviceSecurityStatus status;
      if (threats.contains(DeviceSecurityThreat.jailbroken)) {
        status = DeviceSecurityStatus.compromised;
      } else if (threats.isEmpty) {
        status = DeviceSecurityStatus.secure;
      } else {
        // Development mode or emulator without root - still considered secure
        // for the purposes of showing a warning
        status = DeviceSecurityStatus.secure;
      }

      _cachedResult = DeviceSecurityResult(
        status: status,
        threats: threats,
        details: details.isEmpty ? null : details.join('; '),
      );

      return _cachedResult!;
    } catch (e) {
      // Don't throw - return an error status instead
      _cachedResult = DeviceSecurityResult(
        status: DeviceSecurityStatus.unknownError,
        threats: const [],
        details: 'Failed to check device security: $e',
      );

      return _cachedResult!;
    }
  }

  /// Checks if the device is jailbroken or rooted.
  ///
  /// This is a simplified check that only examines the primary root/jailbreak
  /// indicator. For more detailed information, use [checkDeviceSecurity].
  ///
  /// Returns `true` if the device is compromised, `false` otherwise.
  ///
  /// Throws [DeviceSecurityException] if the check fails.
  Future<bool> isDeviceCompromised() async {
    try {
      final result = await checkDeviceSecurity();
      return result.isCompromised;
    } catch (e) {
      throw DeviceSecurityException(
        'Failed to check if device is compromised',
        cause: e,
      );
    }
  }

  /// Checks if the device is running in development mode.
  ///
  /// Development mode indicators include:
  /// - USB debugging enabled (Android)
  /// - Developer options enabled (Android)
  ///
  /// Returns `true` if development mode is detected, `false` otherwise.
  ///
  /// Throws [DeviceSecurityException] if the check fails.
  Future<bool> isDevelopmentModeEnabled() async {
    try {
      return await _jailbreakRootDetection.isDevMode;
    } catch (e) {
      throw DeviceSecurityException(
        'Failed to check development mode status',
        cause: e,
      );
    }
  }

  /// Checks if the device is a real physical device.
  ///
  /// Returns `false` if running on an emulator or simulator.
  ///
  /// Throws [DeviceSecurityException] if the check fails.
  Future<bool> isRealDevice() async {
    try {
      return await _jailbreakRootDetection.isRealDevice;
    } catch (e) {
      throw DeviceSecurityException(
        'Failed to check if device is real',
        cause: e,
      );
    }
  }

  /// Clears the cached security check result.
  ///
  /// The next call to [checkDeviceSecurity] will perform a fresh check.
  /// Use this when you need to re-check the device status, such as:
  /// - After significant time has passed
  /// - After the user has made system changes
  /// - When testing different scenarios
  void clearCache() {
    _cachedResult = null;
  }

  /// Gets the cached security result without performing a new check.
  ///
  /// Returns `null` if no check has been performed yet or cache was cleared.
  DeviceSecurityResult? get cachedResult => _cachedResult;
}
