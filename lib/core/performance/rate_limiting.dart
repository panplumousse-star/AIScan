import 'dart:async';

import 'package:flutter/foundation.dart';

// ============================================================================
// Debouncing & Throttling
// ============================================================================

/// A debouncer that delays execution until input stops.
///
/// Useful for search fields, filter inputs, and other cases where
/// you want to wait for the user to stop typing before executing.
///
/// ## Usage
/// ```dart
/// final debouncer = Debouncer(duration: Duration(milliseconds: 300));
///
/// // In onChanged callback
/// debouncer.run(() {
///   // This runs 300ms after the last call
///   performSearch(query);
/// });
/// ```
class Debouncer {
  /// Creates a [Debouncer] with the given [duration].
  Debouncer({required this.duration});

  /// The debounce duration.
  final Duration duration;

  Timer? _timer;

  /// Whether a debounced call is pending.
  bool get isPending => _timer?.isActive ?? false;

  /// Runs the given [action] after the debounce duration.
  ///
  /// Cancels any previously scheduled action.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Runs the given [action] immediately and prevents further calls
  /// during the debounce period.
  void runImmediate(VoidCallback action) {
    if (!isPending) {
      action();
      _timer = Timer(duration, () {});
    }
  }

  /// Cancels any pending debounced action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Disposes the debouncer.
  void dispose() {
    cancel();
  }
}

/// A throttler that limits execution rate.
///
/// Ensures the action is only executed at most once per interval,
/// regardless of how many times it's called.
///
/// ## Usage
/// ```dart
/// final throttler = Throttler(duration: Duration(milliseconds: 100));
///
/// // In scroll listener
/// throttler.run(() {
///   // This runs at most every 100ms
///   updateScrollPosition();
/// });
/// ```
class Throttler {
  /// Creates a [Throttler] with the given [duration].
  Throttler({required this.duration});

  /// The throttle duration.
  final Duration duration;

  DateTime? _lastRunTime;
  Timer? _timer;
  VoidCallback? _pendingAction;

  /// Whether the throttler is currently in a throttle period.
  bool get isThrottled {
    if (_lastRunTime == null) return false;
    return DateTime.now().difference(_lastRunTime!) < duration;
  }

  /// Runs the given [action], respecting the throttle duration.
  ///
  /// If within throttle period, schedules the action to run after.
  void run(VoidCallback action) {
    final now = DateTime.now();

    if (_lastRunTime == null || now.difference(_lastRunTime!) >= duration) {
      // Not throttled, run immediately
      _lastRunTime = now;
      action();
    } else {
      // Throttled, schedule for later
      _pendingAction = action;
      _timer?.cancel();
      _timer = Timer(duration - now.difference(_lastRunTime!), () {
        _lastRunTime = DateTime.now();
        _pendingAction?.call();
        _pendingAction = null;
      });
    }
  }

  /// Cancels any pending throttled action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pendingAction = null;
  }

  /// Disposes the throttler.
  void dispose() {
    cancel();
  }
}
