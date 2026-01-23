import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/ocr_language_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_lock/domain/app_lock_service.dart';
import '../../../core/widgets/bento_background.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../core/widgets/scanai_loader.dart';
import '../../../core/widgets/bento_mascot.dart';
import '../../../core/widgets/bento_speech_bubble.dart';

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
    } catch (_) {
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
    } catch (_) {
      // Silently ignore storage errors for theme preferences
    }
  }
}

/// Riverpod provider for the theme persistence service.
final themePersistenceServiceProvider = Provider<ThemePersistenceService>((ref) {
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
// Settings State
// ============================================================================

/// State for the settings screen.
@immutable
class SettingsScreenState {
  /// Creates a [SettingsScreenState] with default values.
  const SettingsScreenState({
    this.themeMode = ThemeMode.system,
    this.isLoading = false,
    this.isInitialized = false,
    this.error,
    this.biometricLockEnabled = false,
    this.biometricLockTimeout = AppLockTimeout.immediate,
    this.isBiometricAvailable = false,
  });

  /// Current theme mode setting.
  final ThemeMode themeMode;

  /// Whether settings are being loaded or saved.
  final bool isLoading;

  /// Whether settings have been loaded from storage.
  final bool isInitialized;

  /// Error message, if any.
  final String? error;

  /// Whether biometric app lock is enabled.
  final bool biometricLockEnabled;

  /// Timeout setting for biometric lock.
  final AppLockTimeout biometricLockTimeout;

  /// Whether biometric authentication is available on this device.
  final bool isBiometricAvailable;

  /// Creates a copy with updated values.
  SettingsScreenState copyWith({
    ThemeMode? themeMode,
    bool? isLoading,
    bool? isInitialized,
    String? error,
    bool clearError = false,
    bool? biometricLockEnabled,
    AppLockTimeout? biometricLockTimeout,
    bool? isBiometricAvailable,
  }) {
    return SettingsScreenState(
      themeMode: themeMode ?? this.themeMode,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      error: clearError ? null : (error ?? this.error),
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
      biometricLockTimeout: biometricLockTimeout ?? this.biometricLockTimeout,
      isBiometricAvailable: isBiometricAvailable ?? this.isBiometricAvailable,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SettingsScreenState &&
        other.themeMode == themeMode &&
        other.isLoading == isLoading &&
        other.isInitialized == isInitialized &&
        other.error == error &&
        other.biometricLockEnabled == biometricLockEnabled &&
        other.biometricLockTimeout == biometricLockTimeout &&
        other.isBiometricAvailable == isBiometricAvailable;
  }

  @override
  int get hashCode => Object.hash(
        themeMode,
        isLoading,
        isInitialized,
        error,
        biometricLockEnabled,
        biometricLockTimeout,
        isBiometricAvailable,
      );
}

// ============================================================================
// Settings Notifier
// ============================================================================

/// State notifier for the settings screen.
///
/// Manages theme mode selection and persistence, and biometric lock settings.
class SettingsScreenNotifier extends StateNotifier<SettingsScreenState> {
  /// Creates a [SettingsScreenNotifier] with the given dependencies.
  SettingsScreenNotifier(
    this._persistenceService,
    this._themeModeNotifier,
    this._appLockService,
  ) : super(const SettingsScreenState());

  final ThemePersistenceService _persistenceService;
  final StateController<ThemeMode> _themeModeNotifier;
  final AppLockService _appLockService;

  /// Initializes settings by loading saved preferences.
  Future<void> initialize() async {
    if (state.isInitialized) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Load theme mode
      final savedThemeMode = await _persistenceService.loadThemeMode();
      _themeModeNotifier.state = savedThemeMode;

      // Initialize and load app lock settings
      await _appLockService.initialize();
      final biometricEnabled = _appLockService.isEnabled();
      final biometricTimeout = _appLockService.getTimeout();
      final isBiometricAvailable = await _appLockService.isBiometricAvailable();

      state = state.copyWith(
        themeMode: savedThemeMode,
        biometricLockEnabled: biometricEnabled,
        biometricLockTimeout: biometricTimeout,
        isBiometricAvailable: isBiometricAvailable,
        isLoading: false,
        isInitialized: true,
      );
    } catch (e) {
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
    state = state.copyWith(themeMode: mode, clearError: true);

    // Persist in background
    try {
      await _persistenceService.saveThemeMode(mode);
    } catch (e) {
      state = state.copyWith(error: 'Failed to save theme preference');
    }
  }

  /// Clears the current error.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Toggles biometric lock enabled state.
  Future<void> setBiometricLockEnabled(bool enabled) async {
    if (enabled == state.biometricLockEnabled) return;

    // Optimistically update UI
    state = state.copyWith(
      biometricLockEnabled: enabled,
      clearError: true,
    );

    try {
      await _appLockService.setEnabled(enabled);
    } catch (e) {
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
      clearError: true,
    );

    try {
      await _appLockService.setTimeout(timeout);
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to update timeout setting',
      );
    }
  }
}

/// Riverpod provider for the settings screen state.
final settingsScreenProvider =
    StateNotifierProvider.autoDispose<SettingsScreenNotifier, SettingsScreenState>(
  (ref) {
    final persistenceService = ref.watch(themePersistenceServiceProvider);
    final themeModeNotifier = ref.watch(themeModeProvider.notifier);
    final appLockService = ref.watch(appLockServiceProvider);
    return SettingsScreenNotifier(
      persistenceService,
      themeModeNotifier,
      appLockService,
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
      ref.read(settingsScreenProvider.notifier).initialize();
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
                        _BouncingWidget(
                          child: Container(
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
                              color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          AppLocalizations.of(context)?.settings ?? 'Reglages',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E1B4B),
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
                        ? const Center(child: ScanaiLoader(size: 40))
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Apparence (Theme) - Large Card
                                BentoAnimatedEntry(
                                  delay: const Duration(milliseconds: 100),
                                  child: _buildThemeCard(state.themeMode, notifier.setThemeMode, isDark),
                                ),

                                const SizedBox(height: 16),

                                // Language Settings Row
                                SizedBox(
                                  height: 180,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // App Language Card
                                      Expanded(
                                        child: BentoAnimatedEntry(
                                          delay: const Duration(milliseconds: 150),
                                          child: _buildAppLanguageCard(isDark),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // OCR Language Card
                                      Expanded(
                                        child: BentoAnimatedEntry(
                                          delay: const Duration(milliseconds: 200),
                                          child: _buildOcrLanguageCard(isDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Security & Info Row
                                SizedBox(
                                  height: 196, // Increased from 180 to prevent overflow
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Security Card
                                      Expanded(
                                        child: BentoAnimatedEntry(
                                          delay: const Duration(milliseconds: 200),
                                          child: _buildSecurityCard(
                                            enabled: state.biometricLockEnabled,
                                            available: state.isBiometricAvailable,
                                            timeout: state.biometricLockTimeout,
                                            onTimeoutChanged: notifier.setBiometricLockTimeout,
                                            isDark: isDark,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // About Card
                                      Expanded(
                                        child: BentoAnimatedEntry(
                                          delay: const Duration(milliseconds: 300),
                                          child: _buildAboutCard(isDark),
                                        ),
                                      ),
                                    ],
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
    return _BentoInteractiveWrapper(
      onTap: () {
        HapticFeedback.lightImpact();
      },
      child: SizedBox(
        height: 140, // Match mascot card height
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: 85,
            child: BentoSpeechBubble(
              tailDirection: BubbleTailDirection.right,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n?.settingsSpeechBubbleLine1 ?? 'On peaufine',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    l10n?.settingsSpeechBubbleLine2 ?? 'notre application',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
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
    return _BentoInteractiveWrapper(
      onTap: () {
        HapticFeedback.mediumImpact();
      },
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF000000).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
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
        child: Center(
          child: BentoMascot(
            height: 110,
            variant: BentoMascotVariant.settings,
          ),
        ),
      ),
    );
  }

  Widget _buildThemeCard(ThemeMode selectedMode, ValueChanged<ThemeMode> onModeChanged, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return BentoCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(24),
      backgroundColor: isDark ? const Color(0xFF000000).withValues(alpha: 0.6) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             children: [
               Container(
                 padding: const EdgeInsets.all(10),
                 decoration: BoxDecoration(
                   color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Icon(
                   Icons.palette_rounded,
                   color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
                   size: 20,
                 ),
               ),
               const SizedBox(width: 12),
               Text(
                 l10n?.appearance ?? 'Apparence',
                 style: GoogleFonts.outfit(
                   fontSize: 18,
                   fontWeight: FontWeight.w700,
                   color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E1B4B),
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
    final selectedColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1);
    final unselectedBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? selectedColor.withValues(alpha: 0.15) : unselectedBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? selectedColor : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                color: isSelected ? selectedColor : (isDark ? Colors.grey : Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? selectedColor : (isDark ? Colors.grey : Colors.grey[600]),
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
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: Text(
            l10n?.enableLockMessage ?? 'Souhaitez-vous securiser l\'acces a vos documents avec votre empreinte digitale ?',
            style: GoogleFonts.outfit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                l10n?.cancel ?? 'Annuler',
                style: GoogleFonts.outfit(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                l10n?.enable ?? 'Activer',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF6366F1),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await ref.read(settingsScreenProvider.notifier).setBiometricLockEnabled(true);
      }
    } else {
      // Deactivating - Request biometric scan
      final authenticated = await ref.read(appLockServiceProvider).authenticateUser();
      if (authenticated) {
        await ref.read(settingsScreenProvider.notifier).setBiometricLockEnabled(false);
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
      padding: const EdgeInsets.all(20),
      backgroundColor: isDark ? const Color(0xFF000000).withValues(alpha: 0.6) : Colors.white,
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
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            enabled ? (l10n?.enabled ?? 'Active') : (l10n?.disabled ?? 'Desactive'),
             style: GoogleFonts.outfit(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          if (enabled) ...[
            const SizedBox(height: 10),
            _BentoInteractiveWrapper(
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<AppLockTimeout>(
                    value: timeout,
                    isDense: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isDark ? Colors.grey : Colors.black54),
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E1B4B),
                    ),
                    onChanged: (newValue) {
                      if (newValue != null) onTimeoutChanged(newValue);
                    },
                    items: AppLockTimeout.values.map((val) {
                      final label = switch(val) {
                        AppLockTimeout.immediate => l10n?.lockTimeoutImmediate ?? 'Immediat',
                        AppLockTimeout.oneMinute => l10n?.lockTimeout1Min ?? '1 min',
                        AppLockTimeout.fiveMinutes => l10n?.lockTimeout5Min ?? '5 min',
                        AppLockTimeout.thirtyMinutes => l10n?.lockTimeout30Min ?? '30 min',
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
      padding: const EdgeInsets.all(20),
      backgroundColor: isDark ? const Color(0xFF000000).withValues(alpha: 0.6) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.language_rounded,
                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n?.appLanguage ?? 'Langue',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E1B4B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _BentoInteractiveWrapper(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
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
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E1B4B),
                  ),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      ref.read(localeProvider.notifier).setLocale(newValue);
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
                  style: GoogleFonts.outfit(
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
      padding: const EdgeInsets.all(20),
      backgroundColor: isDark ? const Color(0xFF000000).withValues(alpha: 0.6) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.text_fields_rounded,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n?.ocrLanguage ?? 'OCR',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E1B4B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _BentoInteractiveWrapper(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
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
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E1B4B),
                  ),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      ref.read(ocrLanguageProvider.notifier).setOcrLanguage(newValue);
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
                  style: GoogleFonts.outfit(
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
                  color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              Text(
                'v1.0.0',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n?.appTitle ?? 'Scanai',
            style: GoogleFonts.outfit(
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
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                  style: GoogleFonts.outfit(
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
            style: GoogleFonts.outfit(
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

  Widget _buildAboutInfoItem(IconData icon, String title, String subtitle, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1)).withValues(alpha: 0.1),
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
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E1B4B),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}

// Bouncing Widget Helper
class _BouncingWidget extends StatefulWidget {
  final Widget child;
  const _BouncingWidget({required this.child});

  @override
  State<_BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<_BouncingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}


class _BentoInteractiveWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _BentoInteractiveWrapper({
    required this.child,
    this.onTap,
  });

  @override
  State<_BentoInteractiveWrapper> createState() => _BentoInteractiveWrapperState();
}

class _BentoInteractiveWrapperState extends State<_BentoInteractiveWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  double _rotationX = 0.0;
  double _rotationY = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    _controller.forward();
    
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPos = details.localPosition;
    final centerX = box.size.width / 2;
    final centerY = box.size.height / 2;
    
    setState(() {
      _rotationX = (centerY - localPos.dy) / centerY * 0.08;
      _rotationY = (localPos.dx - centerX) / centerX * 0.08;
    });
    
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    setState(() {
      _rotationX = 0.0;
      _rotationY = 0.0;
    });
  }

  void _handleTapCancel() {
    _controller.reverse();
    setState(() {
      _rotationX = 0.0;
      _rotationY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(_rotationX)
              ..rotateY(_rotationY)
              ..scale(_scaleAnimation.value),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
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
  } catch (_) {
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
    HapticFeedback.mediumImpact();
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
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
