import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/locale_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_lock/domain/app_lock_service.dart';
import '../../premium/presentation/widgets/premium_settings_card.dart';
import '../../../core/widgets/bento_background.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../core/widgets/scanai_loader.dart';
import 'state/settings_screen_notifier.dart';
import 'state/settings_screen_state.dart';
import 'widgets/about_card.dart';
import 'widgets/app_language_card.dart';
import 'widgets/clipboard_security_card.dart';
import 'widgets/ocr_language_card.dart';
import 'widgets/security_card.dart';
import 'widgets/settings_greeting_row.dart';
import 'widgets/settings_header.dart';
import 'widgets/storage_stats_card.dart';
import 'widgets/theme_card.dart';

/// Settings screen with theme toggle and app preferences.
///
/// Provides user-configurable settings including:
/// - Theme mode selection (Light, Dark, System)
/// - Biometric lock settings
/// - Clipboard security settings
/// - Language preferences
/// - Storage statistics
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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const BentoBackground(),
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  SettingsHeader(isDark: isDark),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: BentoAnimatedEntry(
                      delay: const Duration(milliseconds: 100),
                      child: SettingsGreetingRow(isDark: isDark),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: state.isLoading && !state.isInitialized
                        ? const Center(child: ScanaiLoader())
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Premium status card - shown first for visibility
                                BentoAnimatedEntry(
                                  delay: const Duration(milliseconds: 50),
                                  child: const PremiumSettingsCard(),
                                ),
                                const SizedBox(height: 16),
                                BentoAnimatedEntry(
                                  delay: const Duration(milliseconds: 100),
                                  child: ThemeCard(
                                    selectedMode: state.themeMode,
                                    onModeChanged: notifier.setThemeMode,
                                    isDark: isDark,
                                    localizations: AppLocalizations.of(context),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 196,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: BentoAnimatedEntry(
                                          delay:
                                              const Duration(milliseconds: 150),
                                          child: AppLanguageCard(
                                            isDark: isDark,
                                            currentLocale:
                                                ref.watch(localeProvider),
                                            onLocaleChanged: (newValue) {
                                              unawaited(ref
                                                  .read(localeProvider.notifier)
                                                  .setLocale(newValue));
                                            },
                                            l10n: AppLocalizations.of(context),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: BentoAnimatedEntry(
                                          delay:
                                              const Duration(milliseconds: 200),
                                          child: SecurityCard(
                                            enabled: state.biometricLockEnabled,
                                            available:
                                                state.isBiometricAvailable,
                                            timeout: state.biometricLockTimeout,
                                            onTimeoutChanged: notifier
                                                .setBiometricLockTimeout,
                                            onToggle: () => _handleSecurityToggle(
                                                state.biometricLockEnabled),
                                            isDark: isDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                BentoAnimatedEntry(
                                  delay: const Duration(milliseconds: 250),
                                  child: ClipboardSecurityCard(
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
                                SizedBox(
                                  height: 196,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: BentoAnimatedEntry(
                                          delay:
                                              const Duration(milliseconds: 300),
                                          child: OcrLanguageCard(isDark: isDark),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: BentoAnimatedEntry(
                                          delay:
                                              const Duration(milliseconds: 350),
                                          child: AboutCard(isDark: isDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
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

  Future<void> _handleSecurityToggle(bool currentEnabled) async {
    final l10n = AppLocalizations.of(context);
    if (!currentEnabled) {
      // Activating - Show confirmation
      final confirmed = await showAdaptiveDialog<bool>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
          title: Text(
            l10n?.enableLockTitle ?? 'Activer le verrouillage ?',
            style: const TextStyle(
                fontFamily: 'Outfit', fontWeight: FontWeight.w700),
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
                style:
                    const TextStyle(fontFamily: 'Outfit', color: Colors.grey),
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
}
