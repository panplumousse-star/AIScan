import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/permissions/camera_permission_service.dart';
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

  // Initialize theme preference from storage
  await initializeTheme(container);

  // Run the application wrapped with Riverpod for state management
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AIScanApp(),
    ),
  );
}
