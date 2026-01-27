import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

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
  }) = _LockScreenState;
}

// ============================================================================
// Lock Screen Notifier
// ============================================================================

/// State notifier for the lock screen.
///
/// Manages the biometric authentication flow for unlocking the app.
class LockScreenNotifier extends StateNotifier<LockScreenState> {
  /// Creates a [LockScreenNotifier] with the given [AppLockService].
  LockScreenNotifier(this._appLockService) : super(const LockScreenState());

  final AppLockService _appLockService;

  /// Callback invoked when authentication succeeds.
  ///
  /// This is set by the UI to handle navigation after successful unlock.
  VoidCallback? onAuthenticationSuccess;

  /// Attempts to authenticate the user using biometric authentication.
  ///
  /// Returns `true` if authentication succeeded, `false` otherwise.
  Future<bool> authenticate() async {
    // Clear any previous errors and show loading state
    state = state.copyWith(isAuthenticating: true, error: null);

    try {
      // Attempt biometric authentication
      final authenticated = await _appLockService.authenticateUser();

      if (authenticated) {
        // Record successful authentication
        _appLockService.recordSuccessfulAuth();

        // Update state
        state = state.copyWith(isAuthenticating: false, error: null);

        // Notify success callback
        onAuthenticationSuccess?.call();

        return true;
      } else {
        // Authentication failed or was cancelled
        state = state.copyWith(
          isAuthenticating: false,
          error: 'Authentication failed. Please try again.',
        );
        return false;
      }
    } on AppLockException catch (e) {
      // Handle app lock service errors
      state = state.copyWith(
        isAuthenticating: false,
        error: e.message,
      );
      return false;
    } on Exception catch (e) {
      // Handle unexpected errors
      state = state.copyWith(
        isAuthenticating: false,
        error: 'An unexpected error occurred: $e',
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
    StateNotifierProvider.autoDispose<LockScreenNotifier, LockScreenState>(
  (ref) {
    final appLockService = ref.watch(appLockServiceProvider);
    return LockScreenNotifier(appLockService);
  },
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
                    Hero(
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
                          if (state.error != null ||
                              !state.isAuthenticating) ...[
                            const SizedBox(height: 32),
                            _UnlockButton(
                              onTap: () => ref
                                  .read(lockScreenProvider.notifier)
                                  .authenticate(),
                              isDark: isDark,
                            ),
                          ],
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

                    // Error Message (Subtle)
                    if (state.error != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        state.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
                style: TextStyle(
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
