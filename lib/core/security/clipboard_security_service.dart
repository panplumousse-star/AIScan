import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../exceptions/base_exception.dart';
import 'secure_storage_service.dart';

/// Riverpod provider for [ClipboardSecurityService].
///
/// Provides a singleton instance of the clipboard security service for
/// dependency injection throughout the application.
final clipboardSecurityServiceProvider =
    Provider<ClipboardSecurityService>((ref) {
  final secureStorage = ref.read(secureStorageServiceProvider);
  return ClipboardSecurityService(secureStorage: secureStorage);
});

/// Exception thrown when clipboard security operations fail.
///
/// Contains the original error message and optional underlying exception.
class ClipboardSecurityException extends BaseException {
  /// Creates a [ClipboardSecurityException] with the given [message].
  const ClipboardSecurityException(super.message, {super.cause});
}

/// Result of a clipboard copy operation.
///
/// Contains information about the operation outcome.
class ClipboardCopyResult {
  /// Creates a [ClipboardCopyResult] with the given parameters.
  const ClipboardCopyResult({
    required this.success,
    this.errorMessage,
    this.willAutoClear = false,
    this.autoClearDuration,
  });

  /// Whether the copy operation was successful.
  final bool success;

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
        'willAutoClear: $willAutoClear, '
        'autoClearDuration: $autoClearDuration)';
  }
}

/// Service for secure clipboard operations with auto-clear feature.
///
/// Provides automatic clipboard clearing after a configurable timeout
/// to prevent sensitive information from remaining in the clipboard.
///
/// ## Features
/// - **Auto-Clear**: Automatically clears clipboard after configurable timeout
/// - **Settings Persistence**: Stores user preferences in secure storage
///
/// ## SEC-14: Background Behavior Note
/// The auto-clear timer uses Dart's [Timer] which may not fire reliably when
/// the app is backgrounded on mobile platforms. This is acceptable because:
/// 1. The timer provides protection during active use (most common case)
/// 2. If backgrounded, the user likely intends to paste the content
/// 3. System clipboard is already accessible to other apps while in background
/// 4. For critical background tasks, consider WorkManager/BackgroundFetch
///
/// The clipboard is best-effort cleared; encryption is the primary security.
///
/// ## Usage
/// ```dart
/// final clipboardService = ref.read(clipboardSecurityServiceProvider);
///
/// // Enable clipboard security with 30-second auto-clear
/// await clipboardService.setSecurityEnabled(true);
/// await clipboardService.setAutoClearTimeout(const Duration(seconds: 30));
///
/// // Copy text with automatic security
/// final result = await clipboardService.copyToClipboard('Some text');
///
/// if (result.success && result.willAutoClear) {
///   print('Clipboard will clear in ${result.autoClearDuration}');
/// }
/// ```
class ClipboardSecurityService {
  /// Creates a [ClipboardSecurityService] with required dependencies.
  ClipboardSecurityService({
    required SecureStorageService secureStorage,
  }) : _secureStorage = secureStorage;

  /// The secure storage service for settings persistence.
  final SecureStorageService _secureStorage;

  /// Active timer for auto-clearing clipboard.
  Timer? _autoClearTimer;

  /// Key for storing clipboard security enabled setting.
  static const String _securityEnabledKey = 'clipboard_security_enabled';

  /// Key for storing auto-clear timeout setting.
  static const String _autoClearTimeoutKey = 'clipboard_auto_clear_timeout';

  /// Default auto-clear timeout duration (30 seconds).
  static const Duration defaultAutoClearTimeout = Duration(seconds: 30);

  /// Copies text to the clipboard with security features.
  ///
  /// This method:
  /// 1. Copies the text to clipboard
  /// 2. Schedules auto-clear if enabled
  ///
  /// Returns a [ClipboardCopyResult] with operation details.
  ///
  /// Throws [ClipboardSecurityException] if the operation fails.
  Future<ClipboardCopyResult> copyToClipboard(String text) async {
    try {
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
          unawaited(_clearClipboard());
        });
        willAutoClear = true;
      }

      return ClipboardCopyResult(
        success: true,
        willAutoClear: willAutoClear,
        autoClearDuration: autoClearDuration,
      );
    } on ClipboardSecurityException {
      rethrow;
    } on Object catch (e) {
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
    } on Object catch (e) {
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
    } on Object catch (e) {
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

  /// Gets all clipboard security settings.
  ///
  /// Returns a map containing all current settings:
  /// - `securityEnabled`: Whether auto-clear is enabled
  /// - `autoClearTimeout`: Timeout duration in seconds
  ///
  /// Throws [ClipboardSecurityException] if the operation fails.
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final securityEnabled = await isSecurityEnabled();
      final timeout = await getAutoClearTimeout();

      return {
        'securityEnabled': securityEnabled,
        'autoClearTimeout': timeout.inSeconds,
      };
    } on ClipboardSecurityException {
      rethrow;
    } on Object catch (e) {
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
  ///
  /// Throws [ClipboardSecurityException] if the operation fails.
  Future<void> resetSettings() async {
    try {
      await setSecurityEnabled(false);
      await setAutoClearTimeout(defaultAutoClearTimeout);
      cancelAutoClear();
    } on ClipboardSecurityException {
      rethrow;
    } on Object catch (e) {
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
