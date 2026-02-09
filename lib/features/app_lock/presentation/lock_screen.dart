import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/security/biometric_rate_limiter.dart';
import '../../../core/widgets/bento_background.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/app_lock_service.dart';
import '../../../core/widgets/bento_mascot.dart';

// Re-export justUnlockedProvider for convenience
export '../domain/app_lock_service.dart' show justUnlockedProvider;

part 'lock_screen.freezed.dart';

// ============================================================================
// Lock Screen State
// ============================================================================

/// State for the lock screen.
@freezed
class LockScreenState with _$LockScreenState {
  /// Creates a [LockScreenState] with default values.
  const factory LockScreenState({
    /// Whether authentication is in progress.
    @Default(false) bool isAuthenticating,

    /// Error message, if any.
    String? error,

    /// Warning message (e.g., "X attempts remaining").
    String? warning,

    /// Whether the user is currently locked out.
    @Default(false) bool isLockedOut,

    /// Remaining lockout time in seconds.
    @Default(0) int lockoutSecondsRemaining,
  }) = _LockScreenState;
}

// ============================================================================
// Lock Screen Notifier
// ============================================================================

/// Notifier for the lock screen.
///
/// Manages the biometric authentication flow for unlocking the app.
/// Includes rate limiting to prevent brute force attacks.
class LockScreenNotifier extends AutoDisposeNotifier<LockScreenState> {
  late final AppLockService _appLockService;
  late final BiometricRateLimiter _rateLimiter;

  Timer? _lockoutTimer;
  bool _disposed = false;

  /// Callback invoked when authentication succeeds.
  ///
  /// This is set by the UI to handle navigation after successful unlock.
  VoidCallback? onAuthenticationSuccess;

  @override
  LockScreenState build() {
    _appLockService = ref.watch(appLockServiceProvider);
    _rateLimiter = ref.watch(biometricRateLimiterProvider);
    _disposed = false;

    ref.onDispose(() {
      _disposed = true;
      _lockoutTimer?.cancel();
    });

    // Initialize rate limiter asynchronously
    initialize();

    return const LockScreenState();
  }

  /// Initializes the notifier and checks rate limit status.
  Future<void> initialize() async {
    await _rateLimiter.initialize();
    await _checkRateLimitStatus();
  }

  /// Checks and updates the rate limit status.
  Future<void> _checkRateLimitStatus() async {
    final info = await _rateLimiter.checkStatus();

    switch (info.status) {
      case RateLimitStatus.lockedOut:
        _startLockoutTimer(info.remainingLockout);
        state = state.copyWith(
          isLockedOut: true,
          lockoutSecondsRemaining: info.remainingLockout.inSeconds,
          error: info.message,
          warning: null,
        );

      case RateLimitStatus.delayed:
        // Wait for the delay before allowing next attempt
        await Future.delayed(info.waitDuration);
        state = state.copyWith(
          isLockedOut: false,
          warning: info.message,
          error: null,
        );

      case RateLimitStatus.allowed:
        state = state.copyWith(
          isLockedOut: false,
          lockoutSecondsRemaining: 0,
          warning: info.message, // May contain "X attempts remaining"
          error: null,
        );
    }
  }

  /// Starts a timer to update lockout countdown.
  void _startLockoutTimer(Duration remaining) {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }

      final newRemaining = state.lockoutSecondsRemaining - 1;
      if (newRemaining <= 0) {
        timer.cancel();
        state = state.copyWith(
          isLockedOut: false,
          lockoutSecondsRemaining: 0,
          error: null,
        );
      } else {
        final minutes = newRemaining ~/ 60;
        final seconds = newRemaining % 60;
        state = state.copyWith(
          lockoutSecondsRemaining: newRemaining,
          error: minutes > 0
              ? 'Trop de tentatives. Reessayez dans $minutes min $seconds s'
              : 'Trop de tentatives. Reessayez dans $seconds s',
        );
      }
    });
  }

  /// Attempts to authenticate the user using biometric authentication.
  ///
  /// Returns `true` if authentication succeeded, `false` otherwise.
  /// Implements rate limiting to prevent brute force attacks.
  Future<bool> authenticate() async {
    // Check rate limit first
    final rateLimitInfo = await _rateLimiter.checkStatus();
    if (!rateLimitInfo.canAttemptNow) {
      await _checkRateLimitStatus();
      return false;
    }

    // Clear any previous errors and show loading state
    state = state.copyWith(isAuthenticating: true, error: null);

    try {
      // Attempt biometric authentication
      final authenticated = await _appLockService.authenticateUser();

      if (authenticated) {
        // Record successful authentication (resets rate limiter)
        await _rateLimiter.recordSuccess();
        _appLockService.recordSuccessfulAuth();

        // Update state
        state = state.copyWith(
          isAuthenticating: false,
          error: null,
          warning: null,
          isLockedOut: false,
        );

        // Notify success callback
        onAuthenticationSuccess?.call();

        return true;
      } else {
        // Authentication failed - record failure and check rate limit
        final newInfo = await _rateLimiter.recordFailure();

        state = state.copyWith(
          isAuthenticating: false,
          error: newInfo.status == RateLimitStatus.lockedOut
              ? newInfo.message
              : 'Echec de l\'authentification. Reessayez.',
          warning: newInfo.status == RateLimitStatus.allowed
              ? newInfo.message
              : null,
          isLockedOut: newInfo.status == RateLimitStatus.lockedOut,
          lockoutSecondsRemaining: newInfo.remainingLockout.inSeconds,
        );

        if (newInfo.status == RateLimitStatus.lockedOut) {
          _startLockoutTimer(newInfo.remainingLockout);
        }

        return false;
      }
    } on AppLockException catch (e) {
      // Handle app lock service errors (don't count as failed attempt)
      state = state.copyWith(
        isAuthenticating: false,
        error: e.message,
      );
      return false;
    } on Exception catch (e) {
      // Handle unexpected errors (don't count as failed attempt)
      state = state.copyWith(
        isAuthenticating: false,
        error: 'Une erreur inattendue s\'est produite: $e',
      );
      return false;
    }
  }

  /// Clears the current error message.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Riverpod provider for the lock screen state.
final lockScreenProvider =
    NotifierProvider.autoDispose<LockScreenNotifier, LockScreenState>(
  LockScreenNotifier.new,
);

// ============================================================================
// Lock Screen UI
// ============================================================================

/// Lock screen that prompts for biometric authentication.
///
/// This screen is displayed when the app is locked and requires the user
/// to authenticate using biometric authentication (fingerprint, Face ID, etc.)
/// before accessing the app content.
///
/// ## Usage
/// ```dart
/// // Show lock screen
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => const LockScreen()),
/// );
///
/// // Or use as a conditional widget
/// if (await appLock.shouldShowLockScreen()) {
///   return const LockScreen();
/// } else {
///   return const MainApp();
/// }
/// ```
///
/// ## Features
/// - App icon and name display
/// - Biometric authentication prompt button
/// - Loading state during authentication
/// - Error message display with retry option
/// - Dismisses automatically on successful authentication
class LockScreen extends ConsumerStatefulWidget {
  /// Creates a [LockScreen].
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenWidgetState();
}

class _LockScreenWidgetState extends ConsumerState<LockScreen> {
  @override
  void initState() {
    super.initState();

    // Set up authentication success callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(lockScreenProvider.notifier).onAuthenticationSuccess = () {
        if (mounted) {
          // Signal that the app was just unlocked (for mascot animation)
          ref.read(justUnlockedProvider.notifier).state = true;
          Navigator.of(context).pop();
        }
      };

      // Auto-trigger authentication
      unawaited(_triggerAuth());
    });
  }

  Future<void> _triggerAuth() async {
    // Small delay to let the screen transition finish
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      await ref.read(lockScreenProvider.notifier).authenticate();
    }
  }

  /// Formats the lockout time in MM:SS format.
  String _formatLockoutTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lockScreenProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const BentoBackground(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mascot / Logo Section
                    const Hero(
                      tag: 'app_mascot',
                      child: BentoMascot(
                        height: 160,
                        variant: BentoMascotVariant.lock,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Main Lock Card
                    BentoCard(
                      borderRadius: 32,
                      padding: const EdgeInsets.all(32),
                      backgroundColor: isDark
                          ? const Color(0xFF000000).withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.9),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: (isDark
                                      ? const Color(0xFF818CF8)
                                      : const Color(0xFF6366F1))
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock_person_rounded,
                              size: 40,
                              color: isDark
                                  ? const Color(0xFF818CF8)
                                  : const Color(0xFF6366F1),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            l10n?.appIsLocked ?? 'Scanai is locked',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFFF1F5F9)
                                  : const Color(0xFF1E1B4B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n?.authenticateToAccess ??
                                'Authenticate to access your secured documents.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 14,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          // Warning message (attempts remaining)
                          if (state.warning != null && !state.isLockedOut) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    size: 16,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      state.warning!,
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 12,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // Unlock button (disabled when locked out)
                          if (!state.isAuthenticating && !state.isLockedOut) ...[
                            const SizedBox(height: 32),
                            _UnlockButton(
                              onTap: () => ref
                                  .read(lockScreenProvider.notifier)
                                  .authenticate(),
                              isDark: isDark,
                            ),
                          ],
                          // Lockout indicator
                          if (state.isLockedOut) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.lock_clock_rounded,
                                    size: 32,
                                    color: Colors.redAccent,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatLockoutTime(state.lockoutSecondsRemaining),
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Trop de tentatives',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 12,
                                      color: Colors.redAccent.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // Loading indicator
                          if (state.isAuthenticating) ...[
                            const SizedBox(height: 40),
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark
                                    ? const Color(0xFF818CF8)
                                    : const Color(0xFF6366F1),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Error Message (Subtle) - only show when not locked out
                    if (state.error != null && !state.isLockedOut) ...[
                      const SizedBox(height: 24),
                      Text(
                        state.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isDark;

  const _UnlockButton({required this.onTap, required this.isDark});

  @override
  State<_UnlockButton> createState() => _UnlockButtonState();
}

class _UnlockButtonState extends State<_UnlockButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
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
    final color =
        widget.isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        unawaited(_controller.reverse());
        unawaited(HapticFeedback.mediumImpact());
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fingerprint_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)?.unlock ?? 'Unlock',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
