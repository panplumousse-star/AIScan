import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for [BiometricRateLimiter].
final biometricRateLimiterProvider = Provider<BiometricRateLimiter>((ref) {
  return BiometricRateLimiter();
});

/// Result of a rate limit check.
enum RateLimitStatus {
  /// Can attempt authentication immediately.
  allowed,

  /// Must wait before next attempt (progressive delay).
  delayed,

  /// Locked out - too many failed attempts.
  lockedOut,
}

/// Information about the current rate limit state.
class RateLimitInfo {
  const RateLimitInfo({
    required this.status,
    required this.failedAttempts,
    this.waitDuration = Duration.zero,
    this.lockoutEndsAt,
    this.attemptsUntilLockout,
    this.message,
  });

  /// Current rate limit status.
  final RateLimitStatus status;

  /// Number of consecutive failed attempts.
  final int failedAttempts;

  /// Time to wait before next attempt (for delayed status).
  final Duration waitDuration;

  /// When the lockout ends (for lockedOut status).
  final DateTime? lockoutEndsAt;

  /// How many attempts remain before lockout.
  final int? attemptsUntilLockout;

  /// User-friendly message to display.
  final String? message;

  /// Whether authentication can be attempted now.
  bool get canAttemptNow => status == RateLimitStatus.allowed;

  /// Remaining lockout time.
  Duration get remainingLockout {
    if (lockoutEndsAt == null) return Duration.zero;
    final remaining = lockoutEndsAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

/// Rate limiter for biometric authentication attempts.
///
/// Implements a combined strategy:
/// - Phase 1 (1-3 failures): Progressive delays (0s, 2s, 5s)
/// - Phase 2 (4-5 failures): Longer delays + warning
/// - Phase 3 (6+ failures): Lockout for 5 minutes
/// - Phase 4 (multiple lockouts): Extended lockout (30 min)
///
/// State is persisted to survive app restarts.
class BiometricRateLimiter {
  static const String _prefsKey = 'biometric_rate_limit_state';

  // Thresholds
  static const int _warningThreshold = 4;
  static const int _lockoutThreshold = 6;
  static const int _extendedLockoutThreshold = 3; // lockouts in 1 hour

  // Delays (in seconds)
  static const List<int> _delaySeconds = [0, 0, 2, 5, 10, 30];

  // Lockout durations
  static const Duration _standardLockout = Duration(minutes: 5);
  static const Duration _extendedLockout = Duration(minutes: 30);
  static const Duration _lockoutWindowDuration = Duration(hours: 1);

  /// In-memory state (loaded from persistence on first use).
  _RateLimitState? _state;
  bool _initialized = false;

  /// Initializes the rate limiter by loading persisted state.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = prefs.getString(_prefsKey);

      if (stateJson != null) {
        _state = _RateLimitState.fromJson(jsonDecode(stateJson));
        // Clean up expired lockout history
        _state!.cleanupExpiredLockouts();
      } else {
        _state = _RateLimitState();
      }
    } catch (_) {
      // If loading fails, start fresh
      _state = _RateLimitState();
    }

    _initialized = true;
  }

  /// Ensures the limiter is initialized.
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Persists the current state.
  Future<void> _persistState() async {
    if (_state == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_state!.toJson()));
    } catch (_) {
      // Silently ignore persistence errors
    }
  }

  /// Checks the current rate limit status.
  ///
  /// Call this before attempting authentication to determine if
  /// the user should wait or is locked out.
  Future<RateLimitInfo> checkStatus() async {
    await _ensureInitialized();

    final state = _state!;

    // Check if currently locked out
    if (state.lockoutUntil != null) {
      if (DateTime.now().isBefore(state.lockoutUntil!)) {
        final remaining = state.lockoutUntil!.difference(DateTime.now());
        final minutes = remaining.inMinutes;
        final seconds = remaining.inSeconds % 60;

        return RateLimitInfo(
          status: RateLimitStatus.lockedOut,
          failedAttempts: state.failedAttempts,
          lockoutEndsAt: state.lockoutUntil,
          message: minutes > 0
              ? 'Trop de tentatives. Reessayez dans $minutes min $seconds s'
              : 'Trop de tentatives. Reessayez dans $seconds s',
        );
      } else {
        // Lockout expired, but keep failed attempts count
        state.lockoutUntil = null;
        await _persistState();
      }
    }

    // Check for progressive delay
    final delay = _getDelayForAttempt(state.failedAttempts);
    if (delay > Duration.zero && state.lastAttemptTime != null) {
      final timeSinceLastAttempt =
          DateTime.now().difference(state.lastAttemptTime!);
      if (timeSinceLastAttempt < delay) {
        final remaining = delay - timeSinceLastAttempt;
        return RateLimitInfo(
          status: RateLimitStatus.delayed,
          failedAttempts: state.failedAttempts,
          waitDuration: remaining,
          attemptsUntilLockout: _lockoutThreshold - state.failedAttempts,
          message: 'Veuillez patienter ${remaining.inSeconds} secondes',
        );
      }
    }

    // Can attempt now
    final attemptsRemaining = _lockoutThreshold - state.failedAttempts;
    String? message;

    if (state.failedAttempts >= _warningThreshold) {
      message = 'Attention: $attemptsRemaining tentative(s) restante(s)';
    }

    return RateLimitInfo(
      status: RateLimitStatus.allowed,
      failedAttempts: state.failedAttempts,
      attemptsUntilLockout: attemptsRemaining,
      message: message,
    );
  }

  /// Records a failed authentication attempt.
  ///
  /// Call this after a failed biometric authentication.
  /// Returns the updated rate limit info.
  Future<RateLimitInfo> recordFailure() async {
    await _ensureInitialized();

    final state = _state!;
    state.failedAttempts++;
    state.lastAttemptTime = DateTime.now();

    // Check if we should trigger lockout
    if (state.failedAttempts >= _lockoutThreshold) {
      // Determine lockout duration based on recent lockout history
      final recentLockouts = state.lockoutHistory
          .where((time) =>
              DateTime.now().difference(time) < _lockoutWindowDuration)
          .length;

      final lockoutDuration = recentLockouts >= _extendedLockoutThreshold
          ? _extendedLockout
          : _standardLockout;

      state.lockoutUntil = DateTime.now().add(lockoutDuration);
      state.lockoutHistory.add(DateTime.now());
      state.failedAttempts = 0; // Reset for next cycle
    }

    await _persistState();
    return checkStatus();
  }

  /// Records a successful authentication.
  ///
  /// Call this after a successful biometric authentication.
  /// Resets all failure tracking.
  Future<void> recordSuccess() async {
    await _ensureInitialized();

    final state = _state!;
    state.failedAttempts = 0;
    state.lastAttemptTime = null;
    state.lockoutUntil = null;
    // Don't clear lockout history - we want to track patterns

    await _persistState();
  }

  /// Gets the delay duration for a given attempt number.
  Duration _getDelayForAttempt(int failedAttempts) {
    if (failedAttempts < 0 || failedAttempts >= _delaySeconds.length) {
      return Duration(seconds: _delaySeconds.last);
    }
    return Duration(seconds: _delaySeconds[failedAttempts]);
  }

  /// Clears all rate limit state (for testing or admin reset).
  Future<void> reset() async {
    _state = _RateLimitState();
    _initialized = true;
    await _persistState();
  }

  /// Gets the number of failed attempts (for display purposes).
  Future<int> getFailedAttempts() async {
    await _ensureInitialized();
    return _state!.failedAttempts;
  }
}

/// Internal state class for rate limiting.
class _RateLimitState {
  int failedAttempts;
  DateTime? lastAttemptTime;
  DateTime? lockoutUntil;
  List<DateTime> lockoutHistory;

  _RateLimitState({
    this.failedAttempts = 0,
    this.lastAttemptTime,
    this.lockoutUntil,
    List<DateTime>? lockoutHistory,
  }) : lockoutHistory = lockoutHistory ?? [];

  /// Creates state from JSON.
  factory _RateLimitState.fromJson(Map<String, dynamic> json) {
    return _RateLimitState(
      failedAttempts: json['failedAttempts'] as int? ?? 0,
      lastAttemptTime: json['lastAttemptTime'] != null
          ? DateTime.tryParse(json['lastAttemptTime'] as String)
          : null,
      lockoutUntil: json['lockoutUntil'] != null
          ? DateTime.tryParse(json['lockoutUntil'] as String)
          : null,
      lockoutHistory: (json['lockoutHistory'] as List<dynamic>?)
              ?.map((e) => DateTime.parse(e as String))
              .toList() ??
          [],
    );
  }

  /// Converts state to JSON.
  Map<String, dynamic> toJson() {
    return {
      'failedAttempts': failedAttempts,
      'lastAttemptTime': lastAttemptTime?.toIso8601String(),
      'lockoutUntil': lockoutUntil?.toIso8601String(),
      'lockoutHistory':
          lockoutHistory.map((e) => e.toIso8601String()).toList(),
    };
  }

  /// Removes lockout history older than 1 hour.
  void cleanupExpiredLockouts() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    lockoutHistory.removeWhere((time) => time.isBefore(cutoff));
  }
}
