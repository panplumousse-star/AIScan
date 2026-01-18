import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/app_lock/domain/app_lock_service.dart';
import 'features/app_lock/presentation/lock_screen.dart';
import 'features/home/presentation/bento_home_screen.dart';

/// Provider that checks if the lock screen should be shown.
///
/// This provider checks the app lock service to determine whether
/// the user needs to authenticate before accessing the app.
/// Uses autoDispose to re-check when the app comes to foreground.
final shouldShowLockScreenProvider = FutureProvider.autoDispose<bool>((ref) async {
  final appLockService = ref.read(appLockServiceProvider);
  return await appLockService.shouldShowLockScreen();
});

/// The root widget of the Scanaï application.
///
/// Configures MaterialApp with theming, routing, and global settings.
/// Supports both light and dark themes with system preference detection.
class AIScanApp extends ConsumerWidget {
  const AIScanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the theme mode provider for reactive updates
    final themeMode = ref.watch(themeModeProvider);

    // Configure page transitions for smooth navigation
    final pageTransitionsTheme = const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        // Use zoom transition for Android (Material 3 style)
        TargetPlatform.android: ZoomPageTransitionsBuilder(
          allowEnterRouteSnapshotting: false,
        ),
        // Use Cupertino-style slide for iOS
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        // Fade through for other platforms
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
      },
    );

    return MaterialApp(
      title: 'Scanaï',
      debugShowCheckedModeBanner: false,

      // Theme configuration using centralized AppTheme with page transitions
      theme: AppTheme.lightTheme.copyWith(
        pageTransitionsTheme: pageTransitionsTheme,
      ),
      darkTheme: AppTheme.darkTheme.copyWith(
        pageTransitionsTheme: pageTransitionsTheme,
      ),
      themeMode: themeMode,

      // Home screen - check for lock requirement first
      home: const _AppHome(),
    );
  }
}

/// Root home widget that handles lock screen logic.
///
/// Checks if the app lock is enabled and shows the lock screen
/// if authentication is required. After successful authentication,
/// shows the main app content.
class _AppHome extends ConsumerStatefulWidget {
  const _AppHome();

  @override
  ConsumerState<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends ConsumerState<_AppHome> {
  @override
  Widget build(BuildContext context) {
    // Check if lock screen should be shown
    final lockScreenCheck = ref.watch(shouldShowLockScreenProvider);

    return lockScreenCheck.when(
      // Lock check complete - show appropriate screen
      data: (shouldShowLock) {
        if (shouldShowLock) {
          // Show lock screen - after authentication, it will dismiss
          return const _LockScreenWrapper();
        } else {
          // No lock required - show main app
          return const BentoHomeScreen();
        }
      },
      // While checking lock status, show loading screen
      loading: () => const _LoadingScreen(),
      // On error, show main app (fail-open for better UX)
      error: (error, stackTrace) {
        // Log error in development
        debugPrint('Error checking lock screen: $error');
        return const BentoHomeScreen();
      },
    );
  }
}

/// Wrapper widget that shows lock screen and handles post-auth navigation.
class _LockScreenWrapper extends ConsumerStatefulWidget {
  const _LockScreenWrapper();

  @override
  ConsumerState<_LockScreenWrapper> createState() => _LockScreenWrapperState();
}

class _LockScreenWrapperState extends ConsumerState<_LockScreenWrapper> {
  bool _lockScreenShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Show lock screen after first frame
    if (!_lockScreenShown) {
      _lockScreenShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Push lock screen on top of main app
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const LockScreen(),
              fullscreenDialog: true,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show main app underneath
    return const BentoHomeScreen();
  }
}

/// Loading screen shown while checking lock status.
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bentoBackground,
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
