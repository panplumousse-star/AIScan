import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_lock/domain/app_lock_service.dart';
import '../../../../core/security/clipboard_security_service.dart';
import '../../../../core/storage/document_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/storage_stats.dart';
import '../../domain/theme_persistence_service.dart';
import 'settings_screen_state.dart';

/// State notifier for the settings screen.
///
/// Manages theme mode selection and persistence, biometric lock settings, and clipboard security.
class SettingsScreenNotifier extends StateNotifier<SettingsScreenState> {
  /// Creates a [SettingsScreenNotifier] with the given dependencies.
  SettingsScreenNotifier(
    this._persistenceService,
    this._themeModeNotifier,
    this._appLockService,
    this._clipboardSecurityService,
    this._documentRepository,
  ) : super(const SettingsScreenState());

  final ThemePersistenceService _persistenceService;
  final StateController<ThemeMode> _themeModeNotifier;
  final AppLockService _appLockService;
  final ClipboardSecurityService _clipboardSecurityService;
  final DocumentRepository _documentRepository;

  /// Initializes settings by loading saved preferences.
  Future<void> initialize() async {
    if (state.isInitialized) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load theme mode
      final savedThemeMode = await _persistenceService.loadThemeMode();
      _themeModeNotifier.state = savedThemeMode;

      // Initialize and load app lock settings
      await _appLockService.initialize();
      final biometricEnabled = _appLockService.isEnabled();
      final biometricTimeout = _appLockService.getTimeout();
      final isBiometricAvailable = await _appLockService.isBiometricAvailable();

      // Load clipboard security settings
      final clipboardEnabled =
          await _clipboardSecurityService.isSecurityEnabled();
      final clipboardTimeout =
          await _clipboardSecurityService.getAutoClearTimeout();
      final sensitiveDetectionEnabled =
          await _clipboardSecurityService.isSensitiveDetectionEnabled();

      // Load storage statistics
      final storageInfoMap = await _documentRepository.getStorageInfo();
      final storageStats = StorageStats.fromMap(storageInfoMap);

      state = state.copyWith(
        themeMode: savedThemeMode,
        biometricLockEnabled: biometricEnabled,
        biometricLockTimeout: biometricTimeout,
        isBiometricAvailable: isBiometricAvailable,
        clipboardSecurityEnabled: clipboardEnabled,
        clipboardClearTimeout: clipboardTimeout.inSeconds,
        sensitiveDataDetectionEnabled: sensitiveDetectionEnabled,
        storageStats: storageStats,
        isLoading: false,
        isInitialized: true,
      );
    } on Object catch (e) {
      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
        error: 'Failed to load settings: $e',
      );
    }
  }

  /// Sets the theme mode and persists the preference.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state.themeMode) return;

    // Update immediately for responsive UI
    _themeModeNotifier.state = mode;
    state = state.copyWith(themeMode: mode, error: null);

    // Persist in background
    try {
      await _persistenceService.saveThemeMode(mode);
    } on Object catch (_) {
      state = state.copyWith(error: 'Failed to save theme preference');
    }
  }

  /// Clears the current error.
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Toggles biometric lock enabled state.
  Future<void> setBiometricLockEnabled(bool enabled) async {
    if (enabled == state.biometricLockEnabled) return;

    // Optimistically update UI
    state = state.copyWith(
      biometricLockEnabled: enabled,
      error: null,
    );

    try {
      await _appLockService.setEnabled(enabled);
    } on Object catch (e) {
      // Revert on error
      state = state.copyWith(
        biometricLockEnabled: !enabled,
        error: 'Failed to ${enabled ? 'enable' : 'disable'} biometric lock: $e',
      );
    }
  }

  /// Sets the biometric lock timeout duration.
  Future<void> setBiometricLockTimeout(AppLockTimeout timeout) async {
    if (timeout == state.biometricLockTimeout) return;

    // Optimistically update UI
    state = state.copyWith(
      biometricLockTimeout: timeout,
      error: null,
    );

    try {
      await _appLockService.setTimeout(timeout);
    } on Object catch (_) {
      state = state.copyWith(
        error: 'Failed to update timeout setting',
      );
    }
  }

  /// Toggles clipboard security (auto-clear) enabled state.
  Future<void> setClipboardSecurityEnabled(bool enabled) async {
    if (enabled == state.clipboardSecurityEnabled) return;

    // Optimistically update UI
    state = state.copyWith(
      clipboardSecurityEnabled: enabled,
      error: null,
    );

    try {
      await _clipboardSecurityService.setSecurityEnabled(enabled);
    } on Object catch (e) {
      // Revert on error
      state = state.copyWith(
        clipboardSecurityEnabled: !enabled,
        error:
            'Failed to ${enabled ? 'enable' : 'disable'} clipboard security: $e',
      );
    }
  }

  /// Sets the clipboard auto-clear timeout duration.
  Future<void> setClipboardClearTimeout(int seconds) async {
    if (seconds == state.clipboardClearTimeout) return;

    // Optimistically update UI
    state = state.copyWith(
      clipboardClearTimeout: seconds,
      error: null,
    );

    try {
      await _clipboardSecurityService
          .setAutoClearTimeout(Duration(seconds: seconds));
    } on Object catch (_) {
      state = state.copyWith(
        error: 'Failed to update clipboard timeout',
      );
    }
  }

  /// Toggles sensitive data detection enabled state.
  Future<void> setSensitiveDataDetectionEnabled(bool enabled) async {
    if (enabled == state.sensitiveDataDetectionEnabled) return;

    // Optimistically update UI
    state = state.copyWith(
      sensitiveDataDetectionEnabled: enabled,
      error: null,
    );

    try {
      await _clipboardSecurityService.setSensitiveDetectionEnabled(enabled);
    } on Object catch (e) {
      // Revert on error
      state = state.copyWith(
        sensitiveDataDetectionEnabled: !enabled,
        error:
            'Failed to ${enabled ? 'enable' : 'disable'} sensitive data detection: $e',
      );
    }
  }
}

/// Riverpod provider for the settings screen state.
final settingsScreenProvider = StateNotifierProvider.autoDispose<
    SettingsScreenNotifier, SettingsScreenState>(
  (ref) {
    final persistenceService = ref.watch(themePersistenceServiceProvider);
    final themeModeNotifier = ref.watch(themeModeProvider.notifier);
    final appLockService = ref.watch(appLockServiceProvider);
    final clipboardSecurityService =
        ref.watch(clipboardSecurityServiceProvider);
    final documentRepository = ref.watch(documentRepositoryProvider);
    return SettingsScreenNotifier(
      persistenceService,
      themeModeNotifier,
      appLockService,
      clipboardSecurityService,
      documentRepository,
    );
  },
);
