import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/theme/app_theme.dart';

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
  });

  /// Current theme mode setting.
  final ThemeMode themeMode;

  /// Whether settings are being loaded or saved.
  final bool isLoading;

  /// Whether settings have been loaded from storage.
  final bool isInitialized;

  /// Error message, if any.
  final String? error;

  /// Creates a copy with updated values.
  SettingsScreenState copyWith({
    ThemeMode? themeMode,
    bool? isLoading,
    bool? isInitialized,
    String? error,
    bool clearError = false,
  }) {
    return SettingsScreenState(
      themeMode: themeMode ?? this.themeMode,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SettingsScreenState &&
        other.themeMode == themeMode &&
        other.isLoading == isLoading &&
        other.isInitialized == isInitialized &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(themeMode, isLoading, isInitialized, error);
}

// ============================================================================
// Settings Notifier
// ============================================================================

/// State notifier for the settings screen.
///
/// Manages theme mode selection and persistence.
class SettingsScreenNotifier extends StateNotifier<SettingsScreenState> {
  /// Creates a [SettingsScreenNotifier] with the given dependencies.
  SettingsScreenNotifier(
    this._persistenceService,
    this._themeModeNotifier,
  ) : super(const SettingsScreenState());

  final ThemePersistenceService _persistenceService;
  final StateController<ThemeMode> _themeModeNotifier;

  /// Initializes settings by loading saved preferences.
  Future<void> initialize() async {
    if (state.isInitialized) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final savedThemeMode = await _persistenceService.loadThemeMode();

      // Update both local state and global theme provider
      _themeModeNotifier.state = savedThemeMode;

      state = state.copyWith(
        themeMode: savedThemeMode,
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
}

/// Riverpod provider for the settings screen state.
final settingsScreenProvider =
    StateNotifierProvider.autoDispose<SettingsScreenNotifier, SettingsScreenState>(
  (ref) {
    final persistenceService = ref.watch(themePersistenceServiceProvider);
    final themeModeNotifier = ref.watch(themeModeProvider.notifier);
    return SettingsScreenNotifier(persistenceService, themeModeNotifier);
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

    // Initialize settings after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsScreenProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsScreenProvider);
    final notifier = ref.read(settingsScreenProvider.notifier);
    final theme = Theme.of(context);

    // Listen for errors and show snackbar
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
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: state.isLoading && !state.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              children: [
                // Appearance section
                _SettingsSection(
                  title: 'Appearance',
                  theme: theme,
                  children: [
                    _ThemeModeSelector(
                      selectedMode: state.themeMode,
                      onModeChanged: notifier.setThemeMode,
                      theme: theme,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Privacy section
                _SettingsSection(
                  title: 'Privacy & Security',
                  theme: theme,
                  children: [
                    _SettingsInfoTile(
                      icon: Icons.security_outlined,
                      title: 'Encryption',
                      subtitle: 'AES-256 encryption for all documents',
                      theme: theme,
                    ),
                    _SettingsInfoTile(
                      icon: Icons.wifi_off_outlined,
                      title: 'Offline Processing',
                      subtitle: 'All data stays on your device',
                      theme: theme,
                    ),
                    _SettingsInfoTile(
                      icon: Icons.analytics_outlined,
                      title: 'No Tracking',
                      subtitle: 'No analytics or third-party trackers',
                      theme: theme,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // About section
                _SettingsSection(
                  title: 'About',
                  theme: theme,
                  children: [
                    _SettingsInfoTile(
                      icon: Icons.info_outline,
                      title: 'Scanaï',
                      subtitle: 'Version 1.0.0',
                      theme: theme,
                    ),
                    _SettingsInfoTile(
                      icon: Icons.description_outlined,
                      title: 'Privacy-First Scanner',
                      subtitle: 'Secure document scanning with local processing',
                      theme: theme,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

// ============================================================================
// Settings Section Widget
// ============================================================================

/// Section container for grouped settings.
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
    required this.theme,
  });

  final String title;
  final List<Widget> children;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

// ============================================================================
// Theme Mode Selector Widget
// ============================================================================

/// Theme mode selection widget with visual indicators.
class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({
    required this.selectedMode,
    required this.onModeChanged,
    required this.theme,
  });

  final ThemeMode selectedMode;
  final ValueChanged<ThemeMode> onModeChanged;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            'Theme',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: _ThemeModeOption(
                  mode: ThemeMode.light,
                  icon: Icons.light_mode_outlined,
                  label: 'Light',
                  isSelected: selectedMode == ThemeMode.light,
                  onTap: () => onModeChanged(ThemeMode.light),
                  theme: theme,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ThemeModeOption(
                  mode: ThemeMode.dark,
                  icon: Icons.dark_mode_outlined,
                  label: 'Dark',
                  isSelected: selectedMode == ThemeMode.dark,
                  onTap: () => onModeChanged(ThemeMode.dark),
                  theme: theme,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ThemeModeOption(
                  mode: ThemeMode.system,
                  icon: Icons.settings_brightness_outlined,
                  label: 'System',
                  isSelected: selectedMode == ThemeMode.system,
                  onTap: () => onModeChanged(ThemeMode.system),
                  theme: theme,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            _getThemeDescription(selectedMode),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  String _getThemeDescription(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Always use light theme';
      case ThemeMode.dark:
        return 'Always use dark theme';
      case ThemeMode.system:
        return 'Follow system settings';
    }
  }
}

// ============================================================================
// Theme Mode Option Widget
// ============================================================================

/// Individual theme mode option button.
class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.mode,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  final ThemeMode mode;
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: '$label theme',
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Settings Info Tile Widget
// ============================================================================

/// Information tile for displaying read-only settings.
class _SettingsInfoTile extends StatelessWidget {
  const _SettingsInfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: Icon(
          icon,
          size: 20,
          color: colorScheme.primary,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
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
