import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/theme/app_theme.dart';

// ============================================================================
// Storage Keys
// ============================================================================

/// Storage key for theme mode preference.
const String _themeModeKey = 'aiscan_theme_mode';

/// Storage key for security warnings preference.
const String _showSecurityWarningsKey = 'show_security_warnings';

// ============================================================================
// Service
// ============================================================================

/// Service for persisting theme and related preferences.
///
/// Uses secure storage to persist the user's theme mode choice and other
/// settings preferences across app restarts. While theme mode isn't sensitive
/// data, using secure storage maintains consistency with the app's
/// security-first approach.
class ThemePersistenceService {
  /// Creates a [ThemePersistenceService] with the given storage instance.
  ThemePersistenceService(this._storage);

  final FlutterSecureStorage _storage;

  /// Loads the saved theme mode from storage.
  ///
  /// Returns [ThemeMode.system] if no preference has been saved.
  /// All errors during loading are caught and result in the default
  /// system theme being returned.
  Future<ThemeMode> loadThemeMode() async {
    try {
      final value = await _storage.read(key: _themeModeKey);
      if (value == null) return ThemeMode.system;

      switch (value) {
        case 'light':
          return ThemeMode.light;
        case 'dark':
          return ThemeMode.dark;
        case 'system':
        default:
          return ThemeMode.system;
      }
    } on Object catch (_) {
      return ThemeMode.system;
    }
  }

  /// Saves the theme mode to storage.
  ///
  /// Converts the [ThemeMode] enum to a string value and persists it
  /// to secure storage. Storage errors are silently ignored as theme
  /// preferences are non-critical.
  Future<void> saveThemeMode(ThemeMode mode) async {
    try {
      final value = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await _storage.write(key: _themeModeKey, value: value);
    } on Object catch (_) {
      // Silently ignore storage errors for theme preferences
    }
  }

  /// Loads the security warnings preference from storage.
  ///
  /// Returns `true` by default if no preference has been saved.
  /// This ensures users see security warnings by default for maximum safety.
  Future<bool> loadShowSecurityWarnings() async {
    try {
      final value = await _storage.read(key: _showSecurityWarningsKey);
      return value != 'false'; // Default to true
    } on Object catch (_) {
      return true;
    }
  }

  /// Saves the security warnings preference to storage.
  ///
  /// Persists whether the user wants to see security warnings.
  /// Storage errors are silently ignored as this is a non-critical preference.
  Future<void> saveShowSecurityWarnings(bool show) async {
    try {
      await _storage.write(
        key: _showSecurityWarningsKey,
        value: show.toString(),
      );
    } on Object catch (_) {
      // Silently ignore storage errors
    }
  }
}

// ============================================================================
// Provider
// ============================================================================

/// Riverpod provider for [ThemePersistenceService].
///
/// Provides a singleton instance of the theme persistence service with
/// configured secure storage for dependency injection throughout the application.
///
/// The storage is configured with:
/// - Android: Uses custom ciphers for secure encryption (auto-migrated)
/// - iOS: Keychain with unlocked_this_device accessibility for balance
///   between security and user convenience
final themePersistenceServiceProvider = Provider<ThemePersistenceService>((ref) {
  const storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  return ThemePersistenceService(storage);
});

// ============================================================================
// Initialization Helper
// ============================================================================

/// Helper function to initialize theme on app startup.
///
/// Call this in your main.dart to restore the saved theme preference
/// before the app UI is built.
///
/// ## Usage
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   // Initialize theme before running app
///   final container = ProviderContainer();
///   await initializeTheme(container);
///
///   runApp(
///     UncontrolledProviderScope(
///       container: container,
///       child: const AIScanApp(),
///     ),
///   );
/// }
/// ```
Future<void> initializeTheme(ProviderContainer container) async {
  try {
    final persistenceService = container.read(themePersistenceServiceProvider);
    final savedThemeMode = await persistenceService.loadThemeMode();
    container.read(themeModeProvider.notifier).state = savedThemeMode;
  } on Object catch (_) {
    // Silently fall back to system theme if loading fails
  }
}
