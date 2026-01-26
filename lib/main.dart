
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'l10n/app_localizations.dart';
import 'core/permissions/camera_permission_service.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/ocr_language_provider.dart';
import 'core/security/device_security_service.dart';
import 'core/storage/database_migration_helper.dart';
import 'core/widgets/bento_card.dart';
import 'core/widgets/bento_speech_bubble.dart';
import 'features/app_lock/domain/app_lock_service.dart';
import 'features/settings/presentation/settings_screen.dart';

/// Application entry point.
///
/// Initializes core services and launches the Scanaï application.
/// All document processing happens locally on-device for maximum privacy.
void main() async {
  // Ensure Flutter bindings are initialized before async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred device orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style for status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Create a ProviderContainer to initialize services before app starts
  final container = ProviderContainer();

  // Clear session-only camera permissions on cold start
  // This ensures "Accept for this session" permissions reset when app restarts
  container.read(cameraPermissionServiceProvider).clearSessionPermission();

  // Initialize app lock service to load biometric lock settings
  // This must happen before app launches to properly check lock state
  await container.read(appLockServiceProvider).initialize();

  // Initialize theme preference from storage
  await initializeTheme(container);

  // Initialize locale preference from storage
  await initializeLocale(container);

  // Initialize OCR language preference from storage
  await initializeOcrLanguage(container);

  // Migrate database from unencrypted to encrypted format if needed
  // This runs automatically on first launch after update
  // Creates backup of old database before migration for safety
  final migrationHelper = container.read(databaseMigrationHelperProvider);
  if (await migrationHelper.needsMigration()) {
    debugPrint('Database migration needed, starting migration...');
    final result = await migrationHelper.migrateToEncrypted();

    if (result.success) {
      debugPrint('Database migration completed successfully: ${result.rowsMigrated} rows migrated');
      // Delete backup after successful migration
      await migrationHelper.deleteBackup();
    } else {
      debugPrint('Database migration failed: ${result.error}');
      // Migration failed and backup was restored automatically
      // App will continue with old unencrypted database
    }
  }

  // Check device security status to warn users about compromised devices
  // This runs during app initialization to detect rooted/jailbroken devices
  // The app remains functional on compromised devices - users are informed but not blocked
  final deviceSecurityService = container.read(deviceSecurityServiceProvider);
  final securityResult = await deviceSecurityService.checkDeviceSecurity();

  // Run the application wrapped with Riverpod for state management
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: _DeviceSecurityWrapper(
        securityResult: securityResult,
        child: const ScanaiApp(),
      ),
    ),
  );
}

/// Provider that holds the device security check result from app initialization.
///
/// This result is computed once during app startup and cached for the session.
/// The app shows a warning dialog if the device is compromised.
final deviceSecurityResultProvider =
    Provider<DeviceSecurityResult?>((ref) => null);

/// Wrapper widget that shows security warning dialog if device is compromised.
///
/// This widget wraps the main app and shows an informative (not alarming)
/// dialog on first launch if root/jailbreak is detected. Users can dismiss
/// the warning and continue using the app normally.
class _DeviceSecurityWrapper extends ConsumerStatefulWidget {
  const _DeviceSecurityWrapper({
    required this.securityResult,
    required this.child,
  });

  final DeviceSecurityResult securityResult;
  final Widget child;

  @override
  ConsumerState<_DeviceSecurityWrapper> createState() =>
      _DeviceSecurityWrapperState();
}

class _DeviceSecurityWrapperState
    extends ConsumerState<_DeviceSecurityWrapper> {
  bool _dialogShown = false;
  bool _preferenceLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Show security warning dialog after first frame if device is compromised
    // and user has not disabled security warnings
    if (!_dialogShown && !_preferenceLoaded && widget.securityResult.isCompromised) {
      _preferenceLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          // Load security warnings preference
          final persistenceService = ref.read(themePersistenceServiceProvider);
          final showWarnings = await persistenceService.loadShowSecurityWarnings();

          if (mounted && showWarnings && !_dialogShown) {
            _dialogShown = true;
            _showSecurityWarningDialog();
          }
        }
      });
    }
  }

  /// Shows an informative security warning dialog.
  ///
  /// The dialog informs users that their device has been modified (rooted/jailbroken)
  /// and explains the security implications in a calm, educational tone.
  /// Users can dismiss the dialog and continue using the app.
  void _showSecurityWarningDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _SecurityWarningDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Security warning dialog shown when device is compromised.
///
/// Uses the app's bento design style with mascot and speech bubble.
/// The message is informative and educational rather than alarming,
/// explaining the security implications of rooted/jailbroken devices.
class _SecurityWarningDialog extends StatelessWidget {
  const _SecurityWarningDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              color: Colors.transparent,
              child: BentoCard(
                padding: const EdgeInsets.all(24),
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.9),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Mascot with speech bubble
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Mascot image
                        Image.asset(
                          'assets/images/scanai_hello.png',
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 8),
                        // Speech bubble
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: BentoSpeechBubble(
                              tailDirection: BubbleTailDirection.downLeft,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFFFF4E6),
                              borderColor: Colors.transparent,
                              borderWidth: 0,
                              showShadow: false,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Text(
                                'Security Notice',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.deviceSecurityWarningTitle,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${l10n.deviceSecurityWarningMessage}\n\n${l10n.deviceSecurityWarningDetails}',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        height: 1.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(14),
                          child: Center(
                            child: Text(
                              l10n.deviceSecurityContinue,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
