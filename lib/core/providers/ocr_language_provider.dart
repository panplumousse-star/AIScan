import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/ocr/domain/ocr_service.dart';

/// Storage key for OCR language preference.
const String _ocrLanguageKey = 'aiscan_ocr_language';

/// Represents the OCR language/script options.
///
/// These correspond to the scripts supported by Google ML Kit.
enum OcrLanguageOption {
  /// Automatic detection (defaults to Latin)
  auto('auto', 'Automatique'),

  /// Latin script (English, French, German, Spanish, etc.)
  latin('latin', 'Latin (FR, EN, ES...)'),

  /// Chinese script
  chinese('chinese', '中文 (Chinese)'),

  /// Japanese script
  japanese('japanese', '日本語 (Japanese)'),

  /// Korean script
  korean('korean', '한국어 (Korean)'),

  /// Devanagari script (Hindi, Sanskrit, etc.)
  devanagari('devanagari', 'हिन्दी (Devanagari)');

  const OcrLanguageOption(this.code, this.displayName);

  /// The language code
  final String code;

  /// The display name for the language
  final String displayName;

  /// Converts to OcrLanguage for the OCR service.
  ///
  /// Returns Latin as the default for 'auto'.
  OcrLanguage toOcrLanguage() {
    switch (this) {
      case OcrLanguageOption.auto:
        return OcrLanguage.latin; // Default to Latin for auto
      case OcrLanguageOption.latin:
        return OcrLanguage.latin;
      case OcrLanguageOption.chinese:
        return OcrLanguage.chinese;
      case OcrLanguageOption.japanese:
        return OcrLanguage.japanese;
      case OcrLanguageOption.korean:
        return OcrLanguage.korean;
      case OcrLanguageOption.devanagari:
        return OcrLanguage.devanagari;
    }
  }

  /// Creates an OcrLanguageOption from a code string.
  static OcrLanguageOption fromCode(String? code) {
    switch (code) {
      case 'latin':
        return OcrLanguageOption.latin;
      case 'chinese':
        return OcrLanguageOption.chinese;
      case 'japanese':
        return OcrLanguageOption.japanese;
      case 'korean':
        return OcrLanguageOption.korean;
      case 'devanagari':
        return OcrLanguageOption.devanagari;
      case 'auto':
      default:
        return OcrLanguageOption.auto;
    }
  }
}

/// Service for persisting OCR language preferences.
class OcrLanguagePersistenceService {
  SharedPreferences? _prefs;

  /// Lazily initializes SharedPreferences.
  Future<SharedPreferences> _getPreferences() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Loads the saved OCR language from storage.
  ///
  /// Returns [OcrLanguageOption.auto] if no preference has been saved.
  Future<OcrLanguageOption> loadOcrLanguage() async {
    try {
      final prefs = await _getPreferences();
      final value = prefs.getString(_ocrLanguageKey);
      return OcrLanguageOption.fromCode(value);
    } catch (_) {
      return OcrLanguageOption.auto;
    }
  }

  /// Saves the OCR language to storage.
  Future<void> saveOcrLanguage(OcrLanguageOption language) async {
    try {
      final prefs = await _getPreferences();
      await prefs.setString(_ocrLanguageKey, language.code);
    } catch (_) {
      // Silently ignore storage errors
    }
  }

  /// Clears the saved OCR language preference.
  Future<void> clearOcrLanguage() async {
    try {
      final prefs = await _getPreferences();
      await prefs.remove(_ocrLanguageKey);
    } catch (_) {
      // Silently ignore storage errors
    }
  }
}

/// Riverpod provider for the OCR language persistence service.
final ocrLanguagePersistenceServiceProvider = Provider<OcrLanguagePersistenceService>((ref) {
  return OcrLanguagePersistenceService();
});

/// State notifier for managing the OCR language preference.
class OcrLanguageNotifier extends StateNotifier<OcrLanguageOption> {
  OcrLanguageNotifier(this._persistenceService) : super(OcrLanguageOption.auto);

  final OcrLanguagePersistenceService _persistenceService;
  bool _isInitialized = false;

  /// Whether the OCR language has been loaded from storage.
  bool get isInitialized => _isInitialized;

  /// Initializes the OCR language from storage.
  Future<void> initialize() async {
    if (_isInitialized) return;

    final savedLanguage = await _persistenceService.loadOcrLanguage();
    state = savedLanguage;
    _isInitialized = true;
  }

  /// Sets the OCR language and persists the preference.
  Future<void> setOcrLanguage(OcrLanguageOption language) async {
    if (language == state) return;

    state = language;
    await _persistenceService.saveOcrLanguage(language);
  }

  /// Resets to automatic detection.
  Future<void> resetToAuto() async {
    await setOcrLanguage(OcrLanguageOption.auto);
  }
}

/// Riverpod provider for the OCR language state.
///
/// Provides the current [OcrLanguageOption] and allows changing it.
/// The preference is persisted to SharedPreferences.
final ocrLanguageProvider = StateNotifierProvider<OcrLanguageNotifier, OcrLanguageOption>((ref) {
  final persistenceService = ref.watch(ocrLanguagePersistenceServiceProvider);
  return OcrLanguageNotifier(persistenceService);
});

/// Riverpod provider that converts OcrLanguageOption to OcrLanguage.
///
/// Use this to get the OcrLanguage enum for the OCR service.
final ocrLanguageForServiceProvider = Provider<OcrLanguage>((ref) {
  final option = ref.watch(ocrLanguageProvider);
  return option.toOcrLanguage();
});

/// Helper function to initialize OCR language on app startup.
Future<void> initializeOcrLanguage(ProviderContainer container) async {
  try {
    await container.read(ocrLanguageProvider.notifier).initialize();
  } catch (_) {
    // Silently fall back to auto if loading fails
  }
}
