import 'dart:async';

import 'package:flutter/material.dart';

// ============================================================================
// Startup Optimization
// ============================================================================

/// Utility for optimizing app startup time.
///
/// Provides methods to defer non-critical initialization and
/// track startup performance.
abstract final class StartupOptimization {
  static DateTime? _startTime;
  static bool _isInitialized = false;

  /// Marks the start of app initialization.
  ///
  /// Call this at the very beginning of main().
  static void markStart() {
    _startTime = DateTime.now();
  }

  /// Marks the end of initialization.
  ///
  /// Returns the startup duration.
  static Duration markInitialized() {
    _isInitialized = true;
    if (_startTime == null) return Duration.zero;
    return DateTime.now().difference(_startTime!);
  }

  /// Whether initialization is complete.
  static bool get isInitialized => _isInitialized;

  /// Time since app started.
  static Duration get timeSinceStart {
    if (_startTime == null) return Duration.zero;
    return DateTime.now().difference(_startTime!);
  }

  /// Defers a task to run after the first frame is rendered.
  ///
  /// Use this for non-critical initialization to improve startup time.
  static void deferAfterFirstFrame(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      callback();
    });
  }

  /// Defers a task to run after a specified delay.
  ///
  /// Use this for very low-priority initialization.
  static void deferWithDelay(Duration delay, VoidCallback callback) {
    Future.delayed(delay, callback);
  }

  /// Runs initialization tasks in priority order.
  ///
  /// Critical tasks run immediately, normal tasks after first frame,
  /// low priority tasks after delay.
  static Future<void> runInitSequence({
    required List<Future<void> Function()> criticalTasks,
    List<Future<void> Function()>? normalTasks,
    List<Future<void> Function()>? lowPriorityTasks,
    Duration lowPriorityDelay = const Duration(seconds: 2),
  }) async {
    // Run critical tasks synchronously
    for (final task in criticalTasks) {
      await task();
    }

    // Schedule normal tasks after first frame
    if (normalTasks != null && normalTasks.isNotEmpty) {
      deferAfterFirstFrame(() async {
        for (final task in normalTasks) {
          await task();
        }
      });
    }

    // Schedule low priority tasks after delay
    if (lowPriorityTasks != null && lowPriorityTasks.isNotEmpty) {
      deferWithDelay(lowPriorityDelay, () async {
        for (final task in lowPriorityTasks) {
          await task();
        }
      });
    }
  }
}
