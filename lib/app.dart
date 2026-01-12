import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/animated_widgets.dart';
import 'features/documents/presentation/documents_screen.dart';
import 'features/scanner/presentation/scanner_screen.dart';

/// The root widget of the AIScan application.
///
/// Configures MaterialApp with theming, routing, and global settings.
/// Supports both light and dark themes with system preference detection.
///
/// ## Theme Configuration
/// Uses [AppTheme] for centralized theme definitions. The theme mode is
/// managed by [themeModeProvider] which supports:
/// - [ThemeMode.system]: Follow system preference (default)
/// - [ThemeMode.light]: Always use light theme
/// - [ThemeMode.dark]: Always use dark theme
///
/// ## Page Transitions
/// Custom page transitions are configured for smooth navigation:
/// - iOS: Cupertino-style slide transitions
/// - Android: Predictive back with fade-through transitions
/// - Other platforms: Fade-through transitions
///
/// For custom transitions, use the animated navigation extensions:
/// ```dart
/// context.pushSlide(const DetailScreen());
/// context.pushFade(const SettingsScreen());
/// context.pushScale(const ImagePreviewScreen());
/// ```
///
/// ## Usage
/// ```dart
/// // Change theme mode programmatically
/// ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
/// ```
class AIScanApp extends ConsumerWidget {
  const AIScanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the theme mode provider for reactive updates
    final themeMode = ref.watch(themeModeProvider);

    // Configure page transitions for smooth navigation
    final pageTransitionsTheme = PageTransitionsTheme(
      builders: {
        // Use zoom transition for Android (Material 3 style)
        TargetPlatform.android: const ZoomPageTransitionsBuilder(
          allowEnterRouteSnapshotting: false,
        ),
        // Use Cupertino-style slide for iOS
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        // Fade through for other platforms
        TargetPlatform.linux: const FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: const FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: const ZoomPageTransitionsBuilder(),
      },
    );

    return MaterialApp(
      title: 'AIScan',
      debugShowCheckedModeBanner: false,

      // Theme configuration using centralized AppTheme with page transitions
      theme: AppTheme.lightTheme.copyWith(
        pageTransitionsTheme: pageTransitionsTheme,
      ),
      darkTheme: AppTheme.darkTheme.copyWith(
        pageTransitionsTheme: pageTransitionsTheme,
      ),
      themeMode: themeMode,

      // Home screen - placeholder until DocumentsScreen is implemented
      home: const _PlaceholderHomeScreen(),
    );
  }
}

/// Placeholder home screen shown until DocumentsScreen is implemented.
///
/// This provides a basic UI to verify the app structure is working correctly.
/// Demonstrates animated widgets and micro-interactions.
/// Uses [ThemeContextExtension] for convenient theme access.
class _PlaceholderHomeScreen extends StatelessWidget {
  const _PlaceholderHomeScreen();

  @override
  Widget build(BuildContext context) {
    // Use theme extension for cleaner access
    final colorScheme = context.colorScheme;
    final textTheme = context.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('AIScan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon with scale-in effect
              AnimatedScaleIn(
                duration: AppDuration.long,
                curve: Curves.elasticOut,
                child: Icon(
                  Icons.document_scanner_outlined,
                  size: 80,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Animated title with fade-in
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  'AIScan',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Animated subtitle with slide-in
              AnimatedSlideIn(
                delay: const Duration(milliseconds: 300),
                direction: SlideDirection.up,
                child: Text(
                  'Privacy-First Document Scanner',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Button with tap scale feedback
              AnimatedSlideIn(
                delay: const Duration(milliseconds: 400),
                direction: SlideDirection.up,
                child: TapScaleFeedback(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ScannerScreen(),
                      ),
                    );
                  },
                  child: FilledButton.icon(
                    onPressed: null, // Handled by TapScaleFeedback
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Scan Document'),
                    style: FilledButton.styleFrom(
                      disabledBackgroundColor: colorScheme.primary,
                      disabledForegroundColor: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // My Documents button with slide-in animation
              AnimatedSlideIn(
                delay: const Duration(milliseconds: 500),
                direction: SlideDirection.up,
                child: TapScaleFeedback(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DocumentsScreen(),
                      ),
                    );
                  },
                  child: OutlinedButton.icon(
                    onPressed: null, // Handled by TapScaleFeedback
                    icon: const Icon(Icons.folder_outlined),
                    label: const Text('My Documents'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: AnimatedSlideIn(
        delay: const Duration(milliseconds: 600),
        direction: SlideDirection.up,
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ScannerScreen(startWithQuickScan: true),
              ),
            );
          },
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Quick Scan'),
        ),
      ),
    );
  }
}
