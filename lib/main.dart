import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/permissions/camera_permission_service.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/ocr_language_provider.dart';
import 'core/storage/database_migration_helper.dart';
import 'features/app_lock/domain/app_lock_service.dart';
import 'features/settings/presentation/settings_screen.dart';

/// Application entry point.
///
/// Initializes core services and launches the Scanaï application.
/// All document processing happens locally on-device for maximum privacy.
///
/// Startup optimization:
/// - System UI config runs without await (fire-and-forget)
/// - SharedPreferences reads run in parallel (theme, locale, OCR)
/// - Database migration deferred to after first frame
void main() async {
  // Ensure Flutter bindings are initialized before async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Fire-and-forget: Set preferred device orientations (no await needed)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Fire-and-forget: Set system UI overlay style for status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Create a ProviderContainer to initialize services before app starts
  final container = ProviderContainer();

  // Clear session-only camera permissions on cold start (synchronous)
  container.read(cameraPermissionServiceProvider).clearSessionPermission();

  // PARALLEL INITIALIZATION: Run all SharedPreferences reads concurrently
  // This reduces startup time from ~500ms to ~150ms
  await Future.wait([
    // Initialize app lock service (SecureStorage - slowest)
    container.read(appLockServiceProvider).initialize(),
    // Initialize theme preference (SharedPreferences)
    initializeTheme(container),
    // Initialize locale preference (SharedPreferences - shares instance)
    initializeLocale(container),
    // Initialize OCR language preference (SharedPreferences - shares instance)
    initializeOcrLanguage(container),
  ]);

  // Run the application wrapped with Riverpod for state management
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ScanaiApp(),
    ),
  );

  // DEFERRED: Database migration runs after first frame is painted
  // This ensures the splash screen shows immediately
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _performDatabaseMigrationIfNeeded(container);
  });
}

/// Performs database migration from unencrypted to encrypted format if needed.
///
/// This is deferred to after the first frame to avoid blocking startup.
/// Migration runs automatically on first launch after update.
Future<void> _performDatabaseMigrationIfNeeded(ProviderContainer container) async {
  try {
    final migrationHelper = container.read(databaseMigrationHelperProvider);
    if (await migrationHelper.needsMigration()) {
      debugPrint('Database migration needed, starting migration...');
      final result = await migrationHelper.migrateToEncrypted();

      if (result.success) {
        debugPrint('Database migration completed successfully: ${result.rowsMigrated} rows migrated');
        await migrationHelper.deleteBackup();
      } else {
        debugPrint('Database migration failed: ${result.error}');
      }
    }
  } catch (e) {
    debugPrint('Database migration check failed: $e');
  }
}
