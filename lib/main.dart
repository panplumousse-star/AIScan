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

  // Run the application wrapped with Riverpod for state management
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ScanaiApp(),
    ),
  );
}
