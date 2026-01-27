import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/locale_provider.dart';
import 'core/storage/document_repository.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/skeleton_loading.dart';
import 'features/app_lock/domain/app_lock_service.dart';
import 'features/app_lock/presentation/lock_screen.dart';
import 'features/home/presentation/bento_home_screen.dart';
import 'l10n/app_localizations.dart';

/// The root widget of the Scanaï application.
///
/// Configures MaterialApp with theming, routing, and global settings.
/// Supports both light and dark themes with system preference detection.
class ScanaiApp extends ConsumerWidget {
  const ScanaiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the theme mode provider for reactive updates
    final themeMode = ref.watch(themeModeProvider);

    // Watch the locale provider for reactive updates
    final locale = ref.watch(flutterLocaleProvider);

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
      title: 'Scanai',
      debugShowCheckedModeBanner: false,

      // Localization configuration
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Fallback to English for unsupported languages
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        // If user explicitly set a locale, use it
        if (locale != null) {
          return locale;
        }
        // Check if device locale is supported
        for (final supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == deviceLocale?.languageCode) {
            return supportedLocale;
          }
        }
        // Fallback to English for unsupported languages
        return const Locale('en');
      },

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

/// Minimum duration to show skeleton for smooth perceived loading.
const _kMinSkeletonDuration = Duration(milliseconds: 800);

/// Root home widget that handles startup animation and lock screen logic.
///
/// Shows a skeleton loading screen during app initialization, then
/// transitions smoothly to the home screen or lock screen.
class _AppHome extends ConsumerStatefulWidget {
  const _AppHome();

  @override
  ConsumerState<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends ConsumerState<_AppHome>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _isInitialized = false;
  bool _minDurationPassed = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Cleanup temporary decrypted files from any previous crashed sessions
    // This ensures leftover sensitive data is securely deleted on app startup
    final repository = ref.read(documentRepositoryProvider);
    repository.cleanupTempFiles().catchError((error) {
      // Silently ignore cleanup errors to prevent app startup issues
      // Logging would happen inside cleanupTempFiles if needed
    });

    // Setup fade animation for smooth transition
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Start minimum duration timer
    Future.delayed(_kMinSkeletonDuration, () {
      if (mounted) {
        setState(() => _minDurationPassed = true);
        _checkAndTransition();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    super.dispose();
  }

  void _checkAndTransition() {
    if (_isInitialized && _minDurationPassed && !_fadeController.isAnimating) {
      _fadeController.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app comes back to foreground, re-check lock screen
    if (state == AppLifecycleState.resumed) {
      // Invalidate the provider to force a fresh check
      ref.invalidate(shouldShowLockScreenProvider);
    }

    // Cleanup temporary decrypted files when app goes to background or terminates
    // This ensures sensitive data is securely deleted when not in use
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Run cleanup asynchronously without blocking lifecycle transition
      final repository = ref.read(documentRepositoryProvider);
      repository.cleanupTempFiles().catchError((error) {
        // Silently ignore cleanup errors to prevent app lifecycle issues
        // Logging would happen inside cleanupTempFiles if needed
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if lock screen should be shown
    final lockScreenCheck = ref.watch(shouldShowLockScreenProvider);

    return lockScreenCheck.when(
      // Lock check complete - show appropriate screen
      data: (shouldShowLock) {
        // Mark as initialized
        if (!_isInitialized) {
          _isInitialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkAndTransition();
          });
        }

        // Determine target screen
        final targetScreen = shouldShowLock
            ? const _LockScreenWrapper()
            : const BentoHomeScreen();

        // Show skeleton until both init complete AND min duration passed
        if (!_minDurationPassed) {
          return const _LoadingScreen();
        }

        // Fade transition from skeleton to target
        return AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Stack(
              children: [
                // Skeleton underneath (fades out)
                Opacity(
                  opacity: 1.0 - _fadeAnimation.value,
                  child: const _LoadingScreen(),
                ),
                // Target screen on top (fades in)
                Opacity(
                  opacity: _fadeAnimation.value,
                  child: targetScreen,
                ),
              ],
            );
          },
        );
      },
      // While checking lock status, show loading screen
      loading: () => const _LoadingScreen(),
      // On error, show main app (fail-open for better UX)
      error: (error, stackTrace) {
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
///
/// Uses skeleton placeholder cards that match the home screen layout,
/// providing a smoother perceived loading experience instead of a spinner.
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const BentoHomeScreenSkeleton();
  }
}
