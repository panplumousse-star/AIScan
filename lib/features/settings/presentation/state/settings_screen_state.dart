/// Immutable state model for the settings screen.
///
/// This file defines the state representation for application settings,
/// including theme preferences, biometric lock configuration, clipboard security, and initialization status.
///
/// Features:
/// - Theme mode selection (light, dark, system)
/// - Biometric app lock settings
/// - Clipboard security settings
/// - Error handling
/// - Loading state tracking
library;

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../app_lock/domain/app_lock_service.dart';

part 'settings_screen_state.freezed.dart';

/// State for the settings screen.
@freezed
class SettingsScreenState with _$SettingsScreenState {
  const SettingsScreenState._();

  /// Creates a [SettingsScreenState] with default values.
  const factory SettingsScreenState({
    /// Current theme mode setting.
    @Default(ThemeMode.system) ThemeMode themeMode,

    /// Whether settings are being loaded or saved.
    @Default(false) bool isLoading,

    /// Whether settings have been loaded from storage.
    @Default(false) bool isInitialized,

    /// Error message, if any.
    String? error,

    /// Whether biometric app lock is enabled.
    @Default(false) bool biometricLockEnabled,

    /// Timeout setting for biometric lock.
    @Default(AppLockTimeout.immediate) AppLockTimeout biometricLockTimeout,

    /// Whether biometric authentication is available on this device.
    @Default(false) bool isBiometricAvailable,

    /// Whether clipboard security features are enabled.
    @Default(false) bool clipboardSecurityEnabled,

    /// Timeout in seconds before clipboard is automatically cleared.
    @Default(30) int clipboardClearTimeout,

    /// Whether sensitive data detection is enabled for clipboard operations.
    @Default(false) bool sensitiveDataDetectionEnabled,
  }) = _SettingsScreenState;
}
