import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'secure_storage_service.dart';
import 'sensitive_data_detector.dart';

/// Riverpod provider for [ClipboardSecurityService].
///
/// Provides a singleton instance of the clipboard security service for
/// dependency injection throughout the application.
/// Depends on [SecureStorageService] and [SensitiveDataDetector].
final clipboardSecurityServiceProvider =
    Provider<ClipboardSecurityService>((ref) {
  final secureStorage = ref.read(secureStorageServiceProvider);
  final sensitiveDataDetector = ref.read(sensitiveDataDetectorProvider);
  return ClipboardSecurityService(
    secureStorage: secureStorage,
    sensitiveDataDetector: sensitiveDataDetector,
  );
});

/// Exception thrown when clipboard security operations fail.
///
/// Contains the original error message and optional underlying exception.
class ClipboardSecurityException implements Exception {
  /// Creates a [ClipboardSecurityException] with the given [message].
  const ClipboardSecurityException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'ClipboardSecurityException: $message (caused by: $cause)';
    }
    return 'ClipboardSecurityException: $message';
  }
}

/// Callback function for handling sensitive data warnings.
///
/// Called when sensitive data is detected before copying to clipboard.
/// Returns `true` to proceed with copying, `false` to cancel.
typedef SensitiveDataWarningCallback = Future<bool> Function(
  SensitiveDataDetectionResult result,
);

/// Result of a clipboard copy operation.
///
/// Contains information about the operation outcome and any
/// sensitive data that was detected.
class ClipboardCopyResult {
  /// Creates a [ClipboardCopyResult] with the given parameters.
  const ClipboardCopyResult({
    required this.success,
    required this.hasSensitiveData,
    this.detectionResult,
    this.errorMessage,
    this.willAutoClear = false,
    this.autoClearDuration,
  });

  /// Whether the copy operation was successful.
  final bool success;

  /// Whether sensitive data was detected in the copied text.
  final bool hasSensitiveData;

  /// The result of sensitive data detection, if performed.
  final SensitiveDataDetectionResult? detectionResult;

  /// Error message if the operation failed.
  final String? errorMessage;

  /// Whether the clipboard will be automatically cleared.
  final bool willAutoClear;

  /// The duration after which the clipboard will be cleared.
  final Duration? autoClearDuration;

  @override
  String toString() {
    return 'ClipboardCopyResult('
        'success: $success, '
        'hasSensitiveData: $hasSensitiveData, '
        'willAutoClear: $willAutoClear, '
        'autoClearDuration: $autoClearDuration)';
  }
}

/// Service for secure clipboard operations with sensitive data protection.
///
/// Provides automatic detection of sensitive information before copying to
/// clipboard, configurable auto-clear timers, and user warnings for
/// potentially sensitive content.
///
/// ## Features
/// - **Sensitive Data Detection**: Automatically scans text for SSNs, credit
///   cards, emails, phone numbers, and other sensitive patterns
/// - **Auto-Clear**: Automatically clears clipboard after configurable timeout
/// - **User Warnings**: Provides callbacks for warning users about sensitive data
/// - **Settings Persistence**: Stores user preferences in secure storage
///
/// ## Usage
/// ```dart
/// final clipboardService = ref.read(clipboardSecurityServiceProvider);
///
/// // Enable clipboard security with 30-second auto-clear
/// await clipboardService.setSecurityEnabled(true);
/// await clipboardService.setAutoClearTimeout(const Duration(seconds: 30));
///
/// // Copy text with automatic security checks
/// final result = await clipboardService.copyToClipboard(
///   'My SSN is 123-45-6789',
///   onSensitiveDataDetected: (detection) async {
///     // Show warning dialog to user
///     return await showWarningDialog();
///   },
/// );
///
/// if (result.success && result.willAutoClear) {
///   print('Clipboard will clear in ${result.autoClearDuration}');
/// }
/// ```
///
/// ## Security Considerations
/// - Detection is pattern-based and may produce false positives/negatives
/// - Auto-clear only affects clipboard content, not clipboard history managers
/// - Users can still manually copy sensitive data if they dismiss warnings
/// - Settings are stored in secure storage but are not encrypted
class ClipboardSecurityService {
  /// Creates a [ClipboardSecurityService] with required dependencies.
  ClipboardSecurityService({
    required SecureStorageService secureStorage,
    required SensitiveDataDetector sensitiveDataDetector,
  })  : _secureStorage = secureStorage,
        _sensitiveDataDetector = sensitiveDataDetector;

  /// The secure storage service for settings persistence.
  final SecureStorageService _secureStorage;

  /// The sensitive data detector for scanning clipboard content.
  final SensitiveDataDetector _sensitiveDataDetector;

  /// Active timer for auto-clearing clipboard.
  Timer? _autoClearTimer;

  /// Key for storing clipboard security enabled setting.
  static const String _securityEnabledKey = 'clipboard_security_enabled';

  /// Key for storing auto-clear timeout setting.
  static const String _autoClearTimeoutKey = 'clipboard_auto_clear_timeout';

  /// Key for storing sensitive data detection enabled setting.
  static const String _sensitiveDetectionEnabledKey =
      'clipboard_sensitive_detection_enabled';

  /// Default auto-clear timeout duration (30 seconds).
  static const Duration defaultAutoClearTimeout = Duration(seconds: 30);

  /// Copies text to the clipboard with security features.
  ///
  /// This method:
  /// 1. Checks if sensitive data detection is enabled
  /// 2. Scans the text for sensitive patterns if enabled
  /// 3. Calls the [onSensitiveDataDetected] callback if sensitive data is found
  /// 4. Copies to clipboard if approved
  /// 5. Schedules auto-clear if enabled
  ///
  /// Returns a [ClipboardCopyResult] with operation details.
  ///
  /// The [text] parameter is the content to copy.
  ///
  /// The [onSensitiveDataDetected] callback is called when sensitive data
  /// is detected and detection is enabled. If the callback returns `false`,
  /// the copy operation is cancelled.
  ///
  /// Throws [ClipboardSecurityException] if the operation fails.
  Future<ClipboardCopyResult> copyToClipboard(
    String text, {
    SensitiveDataWarningCallback? onSensitiveDataDetected,
  }) async {
    try {
      // Check if sensitive data detection is enabled
      final detectionEnabled = await isSensitiveDetectionEnabled();
      SensitiveDataDetectionResult? detectionResult;
      var hasSensitiveData = false;

      if (detectionEnabled) {
        // Scan for sensitive data
        detectionResult = _sensitiveDataDetector.detectSensitiveData(text);
        hasSensitiveData = detectionResult.hasSensitiveData;

        // If sensitive data detected and callback provided, ask user
        if (hasSensitiveData && onSensitiveDataDetected != null) {
          final proceed = await onSensitiveDataDetected(detectionResult);
          if (!proceed) {
            // User cancelled the operation
            return ClipboardCopyResult(
              success: false,
              hasSensitiveData: true,
              detectionResult: detectionResult,
              errorMessage: 'User cancelled due to sensitive data',
            );
          }
        }
      }

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: text));

      // Check if auto-clear is enabled
      final securityEnabled = await isSecurityEnabled();
      var willAutoClear = false;
      Duration? autoClearDuration;

      if (securityEnabled) {
        // Cancel any existing timer
        _autoClearTimer?.cancel();

        // Schedule auto-clear
        autoClearDuration = await getAutoClearTimeout();
        _autoClearTimer = Timer(autoClearDuration, () {
          _clearClipboard();
        });
        willAutoClear = true;
      }

      return ClipboardCopyResult(
        success: true,
        hasSensitiveData: hasSensitiveData,
        detectionResult: detectionResult,
        willAutoClear: willAutoClear,
        autoClearDuration: autoClearDuration,
      );
    } on ClipboardSecurityException {
      rethrow;
    } catch (e) {
      throw ClipboardSecurityException(
        'Failed to copy to clipboard',
        cause: e,
      );
    }
  }

  /// Clears the clipboard content.
  ///
  /// This is called automatically by the auto-clear timer or can be
  /// called manually to immediately clear clipboard content.
  ///
  /// Throws [ClipboardSecurityException] if the operation fails.
  Future<void> clearClipboard() async {
    try {
      // Cancel any pending auto-clear timer
      _autoClearTimer?.cancel();
      await _clearClipboard();
    } catch (e) {
      throw ClipboardSecurityException(
        'Failed to clear clipboard',
        cause: e,
      );
    }
  }

  /// Internal method to clear clipboard.
  Future<void> _clearClipboard() async {
    try {
      await Clipboard.setData(const ClipboardData(text: ''));
    } catch (e) {
      // Log error but don't throw - clearing is best-effort
      if (kDebugMode) {
        print('Failed to clear clipboard: $e');
      }
    }
  }

  /// Cancels any pending auto-clear timer.
  ///
  /// This is useful when the user explicitly clears the clipboard
  /// or when the app is closing.
  void cancelAutoClear() {
    _autoClearTimer?.cancel();
    _autoClearTimer = null;
  }

  /// Gets the current clipboard security enabled setting.
  ///
  /// Returns `true` if clipboard security (auto-clear) is enabled.
  /// Defaults to `false` if not configured.
  ///
  /// Throws [ClipboardSecurityException] if the operation fails.
  Future<bool> isSecurityEnabled() async {
    try {
      final value = await _secureStorage.getUserData(_securityEnabledKey);
      return value == 'true';
    } on SecureStorageException catch (e) {
      throw ClipboardSecurityException(
        'Failed to get security enabled setting',
        cause: e,
      );
    }
  }

  /// Sets the clipboard security enabled setting.
  ///
  /// When enabled, clipboard content will be automatically cleared
  /// after the configured timeout.
  ///
  /// If [enabled] is `false`, any pending auto-clear timer is cancelled.
  ///
  /// Throws [ClipboardSecurityException] if the operation fails.
  Future<void> setSecurityEnabled(bool enabled) async {
    try {
      await _secureStorage.storeUserData(
        _securityEnabledKey,
        enabled.toString(),
      );

      // Cancel auto-clear timer if disabling security
      if (!enabled) {
        cancelAutoClear();
      }
    } on SecureStorageException catch (e) {
      throw ClipboardSecurityException(
        'Failed to set security enabled setting',
        cause: e,
      );
    }
  }

  /// Gets the current auto-clear timeout duration.
  ///
  /// Returns the configured timeout duration.
  /// Defaults to [defaultAutoClearTimeout] if not configured.
  ///
  /// Throws [ClipboardSecurityException] if the operation fails.
  Future<Duration> getAutoClearTimeout() async {
    try {
      final value = await _secureStorage.getUserData(_autoClearTimeoutKey);
      if (value == null) {
        return defaultAutoClearTimeout;
      }

      final seconds = int.tryParse(value);
      if (seconds == null) {
        return defaultAutoClearTimeout;
      }

      return Duration(seconds: seconds);
    } on SecureStorageException catch (e) {
      throw ClipboardSecurityException(
        'Failed to get auto-clear timeout setting',
        cause: e,
      );
    }
  }

  /// Sets the auto-clear timeout duration.
  ///
  /// The [timeout] specifies how long after copying to clipboard
  /// the content should be automatically cleared.
  ///
  /// Common values: 15s, 30s, 60s, 120s
  ///
  /// Throws [ClipboardSecurityException] if the operation fails.
  /// Throws [ArgumentError] if timeout is negative or zero.
  Future<void> setAutoClearTimeout(Duration timeout) async {
    if (timeout.inSeconds <= 0) {
      throw ArgumentError('Timeout must be positive');
    }

    try {
      await _secureStorage.storeUserData(
        _autoClearTimeoutKey,
        timeout.inSeconds.toString(),
      );
    } on SecureStorageException catch (e) {
      throw ClipboardSecurityException(
        'Failed to set auto-clear timeout setting',
        cause: e,
      );
    }
  }

  /// Gets the current sensitive data detection enabled setting.
  ///
  /// Returns `true` if sensitive data detection is enabled.
  /// Defaults to `true` if not configured.
  ///
  /// Throws [ClipboardSecurityException] if the operation fails.
  Future<bool> isSensitiveDetectionEnabled() async {
    try {
      final value =
          await _secureStorage.getUserData(_sensitiveDetectionEnabledKey);
      // Default to enabled if not set
      return value != 'false';
    } on SecureStorageException catch (e) {
      throw ClipboardSecurityException(
        'Failed to get sensitive detection enabled setting',
        cause: e,
      );
    }
  }

  /// Sets the sensitive data detection enabled setting.
  ///
  /// When enabled, text is scanned for sensitive patterns before
  /// copying to clipboard and warnings are shown to users.
  ///
  /// Throws [ClipboardSecurityException] if the operation fails.
  Future<void> setSensitiveDetectionEnabled(bool enabled) async {
    try {
      await _secureStorage.storeUserData(
        _sensitiveDetectionEnabledKey,
        enabled.toString(),
      );
    } on SecureStorageException catch (e) {
      throw ClipboardSecurityException(
        'Failed to set sensitive detection enabled setting',
        cause: e,
      );
    }
  }

  /// Gets all clipboard security settings.
  ///
  /// Returns a map containing all current settings:
  /// - `securityEnabled`: Whether auto-clear is enabled
  /// - `autoClearTimeout`: Timeout duration in seconds
  /// - `sensitiveDetectionEnabled`: Whether sensitive data detection is enabled
  ///
  /// Throws [ClipboardSecurityException] if the operation fails.
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final securityEnabled = await isSecurityEnabled();
      final timeout = await getAutoClearTimeout();
      final detectionEnabled = await isSensitiveDetectionEnabled();

      return {
        'securityEnabled': securityEnabled,
        'autoClearTimeout': timeout.inSeconds,
        'sensitiveDetectionEnabled': detectionEnabled,
      };
    } on ClipboardSecurityException {
      rethrow;
    } catch (e) {
      throw ClipboardSecurityException(
        'Failed to get settings',
        cause: e,
      );
    }
  }

  /// Resets all clipboard security settings to defaults.
  ///
  /// Default values:
  /// - Security enabled: `false`
  /// - Auto-clear timeout: 30 seconds
  /// - Sensitive detection enabled: `true`
  ///
  /// Throws [ClipboardSecurityException] if the operation fails.
  Future<void> resetSettings() async {
    try {
      await setSecurityEnabled(false);
      await setAutoClearTimeout(defaultAutoClearTimeout);
      await setSensitiveDetectionEnabled(true);
      cancelAutoClear();
    } on ClipboardSecurityException {
      rethrow;
    } catch (e) {
      throw ClipboardSecurityException(
        'Failed to reset settings',
        cause: e,
      );
    }
  }

  /// Disposes resources used by this service.
  ///
  /// Cancels any active auto-clear timers.
  /// Should be called when the service is no longer needed.
  void dispose() {
    cancelAutoClear();
  }
}
