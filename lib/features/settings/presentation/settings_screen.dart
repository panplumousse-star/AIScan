import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/ocr_language_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_lock/domain/app_lock_service.dart';
import '../../../core/security/clipboard_security_service.dart';
import '../../../core/widgets/bento_background.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../core/widgets/scanai_loader.dart';
import '../../../core/widgets/bento_mascot.dart';
import '../../../core/widgets/bento_speech_bubble.dart';
import '../../../core/widgets/bento_interactive_wrapper.dart';
import '../../../core/widgets/bouncing_widget.dart';
import '../../../core/storage/document_repository.dart';
import '../domain/storage_stats.dart';
import 'state/settings_screen_state.dart';
import 'widgets/storage_stats_card.dart';

// ============================================================================
// Theme Persistence Service
// ============================================================================

/// Storage key for theme mode preference.
const String _themeModeKey = 'aiscan_theme_mode';

/// Service for persisting theme preferences.
///
/// Uses secure storage to persist the user's theme mode choice across
/// app restarts. While theme mode isn't sensitive data, using secure
/// storage maintains consistency with the app's security-first approach.
class ThemePersistenceService {
  /// Creates a [ThemePersistenceService] with the given storage instance.
  ThemePersistenceService(this._storage);

  final FlutterSecureStorage _storage;

  /// Loads the saved theme mode from storage.
  ///
  /// Returns [ThemeMode.system] if no preference has been saved.
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

  static const _showSecurityWarningsKey = 'show_security_warnings';

  /// Loads the security warnings preference from storage.
  Future<bool> loadShowSecurityWarnings() async {
    try {
      final value = await _storage.read(key: _showSecurityWarningsKey);
      return value != 'false'; // Default to true
    } on Object catch (_) {
      return true;
    }
  }

  /// Saves the security warnings preference to storage.
  Future<void> saveShowSecurityWarnings(bool show) async {
    try {
      await _storage.write(
          key: _showSecurityWarningsKey, value: show.toString());
    } on Object catch (_) {
      // Silently ignore storage errors
    }
  }
}

/// Riverpod provider for the theme persistence service.
final themePersistenceServiceProvider =
    Provider<ThemePersistenceService>((ref) {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  return ThemePersistenceService(storage);
});

// ============================================================================
// Settings Notifier
// ============================================================================

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

// ============================================================================
// Settings Screen Widget
// ============================================================================

/// Settings screen with theme toggle and app preferences.
///
/// Provides user-configurable settings including:
/// - Theme mode selection (Light, Dark, System)
/// - App information and version
///
/// Theme preference is automatically persisted and restored on app launch.
///
/// ## Usage
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => const SettingsScreen()),
/// );
/// ```
class SettingsScreen extends ConsumerStatefulWidget {
  /// Creates a [SettingsScreen].
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(settingsScreenProvider.notifier).initialize());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsScreenProvider);
    final notifier = ref.read(settingsScreenProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ref.listen<SettingsScreenState>(settingsScreenProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: notifier.clearError,
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent, // Let BentoBackground show
      body: Stack(
        children: [
          // 1. Unified Background
          const BentoBackground(),

          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  // 2. Custom Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Row(
                      children: [
                        BouncingWidget(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_rounded),
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E1B4B),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          AppLocalizations.of(context)?.settings ?? 'Reglages',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFFF1F5F9)
                                : const Color(0xFF1E1B4B),
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48), // Balance spacing
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Greeting Row (Bento Layout)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Speech Bubble Tile
                        Expanded(
                          flex: 5,
                          child: BentoAnimatedEntry(
                            delay: const Duration(milliseconds: 100),
                            child: _buildSpeechBubbleCard(isDark),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Mascot Tile
                        Expanded(
                          flex: 5,
                          child: BentoAnimatedEntry(
                            delay: const Duration(milliseconds: 200),
                            child: _buildMascotCard(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Bento Grid Scrollable
                  Expanded(
                    child: state.isLoading && !state.isInitialized
                        ? const Center(child: ScanaiLoader())
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 1. Apparence (Theme) - Large Card (2x1)
                                BentoAnimatedEntry(
                                  delay: const Duration(milliseconds: 100),
                                  child: _buildThemeCard(state.themeMode,
                                      notifier.setThemeMode, isDark),
                                ),

                                const SizedBox(height: 16),

                                // 2. App Language (1x1) & Security (1x1) Row
                                SizedBox(
                                  height: 196,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // App Language Card
                                      Expanded(
                                        child: BentoAnimatedEntry(
                                          delay:
                                              const Duration(milliseconds: 150),
                                          child: _buildAppLanguageCard(isDark),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Security Card
                                      Expanded(
                                        child: BentoAnimatedEntry(
                                          delay:
                                              const Duration(milliseconds: 200),
                                          child: _buildSecurityCard(
                                            enabled: state.biometricLockEnabled,
                                            available:
                                                state.isBiometricAvailable,
                                            timeout: state.biometricLockTimeout,
                                            onTimeoutChanged: notifier
                                                .setBiometricLockTimeout,
                                            isDark: isDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // 3. Clipboard Security - Large Card (2x1)
                                BentoAnimatedEntry(
                                  delay: const Duration(milliseconds: 250),
                                  child: _buildClipboardSecurityCard(
                                    clipboardSecurityEnabled:
                                        state.clipboardSecurityEnabled,
                                    clipboardClearTimeout:
                                        state.clipboardClearTimeout,
                                    sensitiveDataDetectionEnabled:
                                        state.sensitiveDataDetectionEnabled,
                                    onClipboardSecurityChanged:
                                        notifier.setClipboardSecurityEnabled,
                                    onTimeoutChanged:
                                        notifier.setClipboardClearTimeout,
                                    onSensitiveDetectionChanged: notifier
                                        .setSensitiveDataDetectionEnabled,
                                    isDark: isDark,
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // 4. OCR Language (1x1) & About (1x1) Row
                                SizedBox(
                                  height: 196,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // OCR Language Card
                                      Expanded(
                                        child: BentoAnimatedEntry(
                                          delay:
                                              const Duration(milliseconds: 300),
                                          child: _buildOcrLanguageCard(isDark),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // About Card
                                      Expanded(
                                        child: BentoAnimatedEntry(
                                          delay:
                                              const Duration(milliseconds: 350),
                                          child: _buildAboutCard(isDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // 5. Storage Statistics - Large Card (2x1)
                                BentoAnimatedEntry(
                                  delay: const Duration(milliseconds: 400),
                                  child: StorageStatsCard(
                                    stats: state.storageStats,
                                    isDark: isDark,
                                  ),
                                ),

                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeechBubbleCard(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return BentoInteractiveWrapper(
      onTap: () {
        unawaited(HapticFeedback.lightImpact());
      },
      child: SizedBox(
        height: 100,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: 65,
            child: BentoSpeechBubble(
              tailDirection: BubbleTailDirection.right,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n?.settingsSpeechBubbleLine1 ?? 'On peaufine',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFF1E293B),
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    l10n?.settingsSpeechBubbleLine2 ?? 'notre application',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFF1E293B),
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMascotCard(bool isDark) {
    return BentoInteractiveWrapper(
      onTap: () {
        unawaited(HapticFeedback.mediumImpact());
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF000000).withValues(alpha: 0.6)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark
                ? const Color(0xFFFFFFFF).withValues(alpha: 0.1)
                : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: BentoMascot(
            height: 80,
            variant: BentoMascotVariant.settings,
          ),
        ),
      ),
    );
  }

  Widget _buildThemeCard(ThemeMode selectedMode,
      ValueChanged<ThemeMode> onModeChanged, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return BentoCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(24),
      backgroundColor: isDark
          ? const Color(0xFF000000).withValues(alpha: 0.6)
          : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.palette_rounded,
                  color: isDark
                      ? const Color(0xFF818CF8)
                      : const Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n?.appearance ?? 'Apparence',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF1E1B4B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildThemeOption(
                mode: ThemeMode.light,
                icon: Icons.light_mode_rounded,
                label: l10n?.themeLight ?? 'Clair',
                isSelected: selectedMode == ThemeMode.light,
                onTap: () => onModeChanged(ThemeMode.light),
                isDark: isDark,
              ),
              _buildThemeOption(
                mode: ThemeMode.dark,
                icon: Icons.dark_mode_rounded,
                label: l10n?.themeDark ?? 'Sombre',
                isSelected: selectedMode == ThemeMode.dark,
                onTap: () => onModeChanged(ThemeMode.dark),
                isDark: isDark,
              ),
              _buildThemeOption(
                mode: ThemeMode.system,
                icon: Icons.settings_brightness_rounded,
                label: l10n?.themeAuto ?? 'Auto',
                isSelected: selectedMode == ThemeMode.system,
                onTap: () => onModeChanged(ThemeMode.system),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required ThemeMode mode,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final selectedColor =
        isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1);
    final unselectedBg =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedColor.withValues(alpha: 0.15)
                    : unselectedBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? selectedColor : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? selectedColor
                    : (isDark ? Colors.grey : Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? selectedColor
                    : (isDark ? Colors.grey : Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSecurityToggle(bool currentEnabled) async {
    final l10n = AppLocalizations.of(context);
    if (!currentEnabled) {
      // Activating - Show confirmation
      final confirmed = await showAdaptiveDialog<bool>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
          title: Text(
            l10n?.enableLockTitle ?? 'Activer le verrouillage ?',
            style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700),
          ),
          content: Text(
            l10n?.enableLockMessage ??
                'Souhaitez-vous securiser l\'acces a vos documents avec votre empreinte digitale ?',
            style: const TextStyle(
              fontFamily: 'Outfit',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                l10n?.cancel ?? 'Annuler',
                style: const TextStyle(fontFamily: 'Outfit', color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                l10n?.enable ?? 'Activer',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirmed ?? false) {
        await ref
            .read(settingsScreenProvider.notifier)
            .setBiometricLockEnabled(true);
      }
    } else {
      // Deactivating - Request biometric scan
      final authenticated =
          await ref.read(appLockServiceProvider).authenticateUser();
      if (authenticated) {
        await ref
            .read(settingsScreenProvider.notifier)
            .setBiometricLockEnabled(false);
      }
    }
  }

  Widget _buildSecurityCard({
    required bool enabled,
    required bool available,
    required AppLockTimeout timeout,
    required ValueChanged<AppLockTimeout> onTimeoutChanged,
    required bool isDark,
  }) {
    final l10n = AppLocalizations.of(context);
    final statusColor = enabled
        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF10B981))
        : (isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444));

    final statusBg = enabled
        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
        : (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2));

    return BentoCard(
      borderRadius: 32,
      onTap: available ? () => _handleSecurityToggle(enabled) : null,
      backgroundColor: isDark
          ? const Color(0xFF000000).withValues(alpha: 0.6)
          : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fingerprint_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              if (enabled)
                Icon(
                  Icons.verified_rounded,
                  color: statusColor.withValues(alpha: 0.5),
                  size: 16,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n?.security ?? 'Verrouillage',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            enabled
                ? (l10n?.enabled ?? 'Active')
                : (l10n?.disabled ?? 'Desactive'),
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          if (enabled) ...[
            const SizedBox(height: 10),
            BentoInteractiveWrapper(
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<AppLockTimeout>(
                    value: timeout,
                    isDense: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: isDark ? Colors.grey : Colors.black54),
                    dropdownColor:
                        isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFF1E1B4B),
                    ),
                    onChanged: (newValue) {
                      if (newValue != null) onTimeoutChanged(newValue);
                    },
                    items: AppLockTimeout.values.map((val) {
                      final label = switch (val) {
                        AppLockTimeout.immediate =>
                          l10n?.lockTimeoutImmediate ?? 'Immediat',
                        AppLockTimeout.oneMinute =>
                          l10n?.lockTimeout1Min ?? '1 min',
                        AppLockTimeout.fiveMinutes =>
                          l10n?.lockTimeout5Min ?? '5 min',
                        AppLockTimeout.thirtyMinutes =>
                          l10n?.lockTimeout30Min ?? '30 min',
                      };
                      return DropdownMenuItem(
                        value: val,
                        child: Text(label),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppLanguageCard(bool isDark) {
    final currentLocale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);

    return BentoCard(
      borderRadius: 32,
      backgroundColor: isDark
          ? const Color(0xFF000000).withValues(alpha: 0.6)
          : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF312E81)
                      : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.language_rounded,
                  color: isDark
                      ? const Color(0xFF818CF8)
                      : const Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n?.appLanguage ?? 'Langue',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF1E1B4B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BentoInteractiveWrapper(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AppLocale>(
                  value: currentLocale,
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: isDark ? Colors.grey : Colors.black54,
                  ),
                  dropdownColor:
                      isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF1E1B4B),
                  ),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      unawaited(ref
                          .read(localeProvider.notifier)
                          .setLocale(newValue));
                    }
                  },
                  items: AppLocale.values.map((locale) {
                    return DropdownMenuItem(
                      value: locale,
                      child: Text(locale.displayName),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 12,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Interface',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOcrLanguageCard(bool isDark) {
    final currentOcrLanguage = ref.watch(ocrLanguageProvider);
    final l10n = AppLocalizations.of(context);

    return BentoCard(
      borderRadius: 32,
      backgroundColor: isDark
          ? const Color(0xFF000000).withValues(alpha: 0.6)
          : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E3A5F)
                      : const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.text_fields_rounded,
                  color: isDark
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF0284C7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n?.ocrLanguage ?? 'OCR',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF1E1B4B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BentoInteractiveWrapper(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<OcrLanguageOption>(
                  value: currentOcrLanguage,
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: isDark ? Colors.grey : Colors.black54,
                  ),
                  dropdownColor:
                      isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF1E1B4B),
                  ),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      unawaited(ref
                          .read(ocrLanguageProvider.notifier)
                          .setOcrLanguage(newValue));
                    }
                  },
                  items: OcrLanguageOption.values.map((lang) {
                    return DropdownMenuItem(
                      value: lang,
                      child: Text(
                        lang.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 12,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Reconnaissance texte',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return _BentoFlipCard(
      isDark: isDark,
      front: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF312E81)
                      : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: isDark
                      ? const Color(0xFF818CF8)
                      : const Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              Text(
                'v1.0.0',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n?.appTitle ?? 'Scanai',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                l10n?.developedWith ?? 'Developpee avec le',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              Icon(
                Icons.favorite_rounded,
                size: 12,
                color: Colors.redAccent.withValues(alpha: 0.8),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: 14,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n?.securityDetails ?? 'Details securite',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
      back: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.securityTitle ?? 'Securite',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 8),
          _buildAboutInfoItem(
            Icons.lock_outline,
            l10n?.aes256 ?? 'AES-256',
            l10n?.localEncryption ?? 'Chiffrement local',
            isDark,
          ),
          const SizedBox(height: 6),
          _buildAboutInfoItem(
            Icons.visibility_off_outlined,
            l10n?.zeroKnowledge ?? 'Zero-Knowledge',
            l10n?.exclusiveAccess ?? 'Acces exclusif',
            isDark,
          ),
          const SizedBox(height: 6),
          _buildAboutInfoItem(
            Icons.cloud_off_outlined,
            l10n?.offline ?? 'Hors-ligne',
            l10n?.securedPercent ?? '100% securise',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutInfoItem(
      IconData icon, String title, String subtitle, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1))
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 12,
            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF1E1B4B),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 9,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClipboardSecurityCard({
    required bool clipboardSecurityEnabled,
    required int clipboardClearTimeout,
    required bool sensitiveDataDetectionEnabled,
    required ValueChanged<bool> onClipboardSecurityChanged,
    required ValueChanged<int> onTimeoutChanged,
    required ValueChanged<bool> onSensitiveDetectionChanged,
    required bool isDark,
  }) {
    return BentoCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(24),
      backgroundColor: isDark
          ? const Color(0xFF000000).withValues(alpha: 0.6)
          : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF065F46)
                      : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.content_paste_rounded,
                  color: isDark
                      ? const Color(0xFF10B981)
                      : const Color(0xFF059669),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Securite Presse-papiers',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF1E1B4B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Auto-clear toggle
          _buildToggleRow(
            label: 'Effacement automatique',
            subtitle: 'Efface apres copie',
            value: clipboardSecurityEnabled,
            onChanged: onClipboardSecurityChanged,
            isDark: isDark,
          ),

          if (clipboardSecurityEnabled) ...[
            const SizedBox(height: 16),
            // Timeout slider
            _buildTimeoutSlider(
              label: 'Effacer apres',
              value: clipboardClearTimeout,
              onChanged: onTimeoutChanged,
              isDark: isDark,
            ),
          ],

          const SizedBox(height: 16),

          // Sensitive data detection toggle
          _buildToggleRow(
            label: 'Detection donnees sensibles',
            subtitle: 'Alertes pour donnees sensibles',
            value: sensitiveDataDetectionEnabled,
            onChanged: onSensitiveDetectionChanged,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        BentoInteractiveWrapper(
          child: Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor:
                isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeoutSlider({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    required bool isDark,
  }) {
    // Common timeout values: 15s, 30s, 60s, 120s, 180s
    final timeoutOptions = [15, 30, 60, 120, 180];
    final currentIndex = timeoutOptions.indexOf(value);
    final sliderValue =
        currentIndex >= 0 ? currentIndex.toDouble() : 1.0; // Default to 30s

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            Text(
              _formatTimeout(value),
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor:
                isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
            inactiveTrackColor: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.2),
            thumbColor:
                isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
            overlayColor:
                (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
                    .withValues(alpha: 0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: sliderValue,
            max: (timeoutOptions.length - 1).toDouble(),
            divisions: timeoutOptions.length - 1,
            onChanged: (newValue) {
              final newTimeout = timeoutOptions[newValue.toInt()];
              onChanged(newTimeout);
            },
          ),
        ),
      ],
    );
  }

  String _formatTimeout(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds == 60) {
      return '1 min';
    } else {
      final minutes = seconds ~/ 60;
      return '$minutes min';
    }
  }
}

// ============================================================================
// Theme Initialization Helper
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

class _BentoFlipCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final bool isDark;

  const _BentoFlipCard({
    required this.front,
    required this.back,
    required this.isDark,
  });

  @override
  State<_BentoFlipCard> createState() => _BentoFlipCardState();
}

class _BentoFlipCardState extends State<_BentoFlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_controller.isAnimating) return;
    unawaited(HapticFeedback.mediumImpact());
    if (_isFront) {
      unawaited(_controller.forward());
    } else {
      unawaited(_controller.reverse());
    }
    setState(() => _isFront = !_isFront);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final angle = _animation.value * 3.141592653589793;
        final isBack = angle > 3.141592653589793 / 2;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: BentoCard(
            borderRadius: 32,
            padding: const EdgeInsets.all(16), // Reduced padding to 16
            onTap: _toggleCard,
            animateOnTap: false,
            backgroundColor: widget.isDark
                ? const Color(0xFF000000).withValues(alpha: 0.6)
                : Colors.white,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateY(isBack ? 3.141592653589793 : 0),
              child: isBack ? widget.back : widget.front,
            ),
          ),
        );
      },
    );
  }
}
