import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage key for locale preference.
const String _localeKey = 'aiscan_locale';

/// Represents the supported locales in the application.
enum AppLocale {
  /// System default locale
  system('system', 'Systeme'),

  /// French locale
  french('fr', 'Francais'),

  /// English locale
  english('en', 'English');

  const AppLocale(this.code, this.displayName);

  /// The locale code (e.g., 'fr', 'en', 'system')
  final String code;

  /// The display name for the locale
  final String displayName;

  /// Converts the AppLocale to a Flutter Locale, or null for system.
  Locale? toLocale() {
    switch (this) {
      case AppLocale.system:
        return null; // null means use system locale
      case AppLocale.french:
        return const Locale('fr');
      case AppLocale.english:
        return const Locale('en');
    }
  }

  /// Creates an AppLocale from a locale code string.
  static AppLocale fromCode(String? code) {
    switch (code) {
      case 'fr':
        return AppLocale.french;
      case 'en':
        return AppLocale.english;
      case 'system':
      default:
        return AppLocale.system;
    }
  }
}

/// Service for persisting locale preferences.
///
/// Uses SharedPreferences for non-sensitive locale preference storage.
class LocalePersistenceService {
  SharedPreferences? _prefs;

  /// Lazily initializes SharedPreferences.
  Future<SharedPreferences> _getPreferences() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Loads the saved locale from storage.
  ///
  /// Returns [AppLocale.system] if no preference has been saved.
  Future<AppLocale> loadLocale() async {
    try {
      final prefs = await _getPreferences();
      final value = prefs.getString(_localeKey);
      return AppLocale.fromCode(value);
    } catch (_) {
      return AppLocale.system;
    }
  }

  /// Saves the locale to storage.
  Future<void> saveLocale(AppLocale locale) async {
    try {
      final prefs = await _getPreferences();
      await prefs.setString(_localeKey, locale.code);
    } catch (_) {
      // Silently ignore storage errors for locale preferences
    }
  }

  /// Clears the saved locale preference.
  Future<void> clearLocale() async {
    try {
      final prefs = await _getPreferences();
      await prefs.remove(_localeKey);
    } catch (_) {
      // Silently ignore storage errors
    }
  }
}

/// Riverpod provider for the locale persistence service.
final localePersistenceServiceProvider = Provider<LocalePersistenceService>((ref) {
  return LocalePersistenceService();
});

/// State notifier for managing the application locale.
class LocaleNotifier extends StateNotifier<AppLocale> {
  LocaleNotifier(this._persistenceService) : super(AppLocale.system);

  final LocalePersistenceService _persistenceService;
  bool _isInitialized = false;

  /// Whether the locale has been loaded from storage.
  bool get isInitialized => _isInitialized;

  /// Initializes the locale from storage.
  Future<void> initialize() async {
    if (_isInitialized) return;

    final savedLocale = await _persistenceService.loadLocale();
    state = savedLocale;
    _isInitialized = true;
  }

  /// Sets the locale and persists the preference.
  Future<void> setLocale(AppLocale locale) async {
    if (locale == state) return;

    state = locale;
    await _persistenceService.saveLocale(locale);
  }

  /// Resets to system locale.
  Future<void> resetToSystem() async {
    await setLocale(AppLocale.system);
  }
}

/// Riverpod provider for the locale state.
///
/// Provides the current [AppLocale] and allows changing it.
/// The locale is persisted to SharedPreferences.
final localeProvider = StateNotifierProvider<LocaleNotifier, AppLocale>((ref) {
  final persistenceService = ref.watch(localePersistenceServiceProvider);
  return LocaleNotifier(persistenceService);
});

/// Riverpod provider that converts AppLocale to Flutter Locale.
///
/// Returns null for system locale, which tells MaterialApp
/// to use the device's locale.
final flutterLocaleProvider = Provider<Locale?>((ref) {
  final appLocale = ref.watch(localeProvider);
  return appLocale.toLocale();
});

/// Helper function to initialize locale on app startup.
///
/// Call this in your main.dart to restore the saved locale preference
/// before the app UI is built.
Future<void> initializeLocale(ProviderContainer container) async {
  try {
    await container.read(localeProvider.notifier).initialize();
  } catch (_) {
    // Silently fall back to system locale if loading fails
  }
}
