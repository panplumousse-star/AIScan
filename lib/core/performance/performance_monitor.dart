import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// Performance Monitor Provider
// ============================================================================

/// Riverpod provider for the performance monitor.
///
/// Provides frame rate monitoring and jank detection.
final performanceMonitorProvider = Provider<PerformanceMonitor>((ref) {
  return PerformanceMonitor();
});

// ============================================================================
// Performance Monitor
// ============================================================================

/// Monitors frame rate and detects jank during rendering.
///
/// Use this to identify performance issues and adapt UI complexity.
///
/// ## Usage
/// ```dart
/// final monitor = ref.read(performanceMonitorProvider);
/// monitor.start();
/// // ... do work ...
/// monitor.stop();
/// print('Average FPS: ${monitor.averageFps}');
/// ```
class PerformanceMonitor {
  final List<double> _frameTimings = [];
  bool _isMonitoring = false;
  int _droppedFrameCount = 0;
  DateTime? _startTime;

  /// Whether monitoring is currently active.
  bool get isMonitoring => _isMonitoring;

  /// Number of frames that exceeded 16ms (dropped frames).
  int get droppedFrameCount => _droppedFrameCount;

  /// Total frames recorded.
  int get totalFrames => _frameTimings.length;

  /// Average frame time in milliseconds.
  double get averageFrameTimeMs {
    if (_frameTimings.isEmpty) return 0;
    return _frameTimings.reduce((a, b) => a + b) / _frameTimings.length;
  }

  /// Average frames per second.
  double get averageFps {
    final avgMs = averageFrameTimeMs;
    if (avgMs <= 0) return 0;
    return 1000 / avgMs;
  }

  /// Percentage of frames that were dropped (>16ms).
  double get droppedFramePercentage {
    if (_frameTimings.isEmpty) return 0;
    return (_droppedFrameCount / _frameTimings.length) * 100;
  }

  /// Whether performance is considered smooth (>50 FPS, <10% dropped).
  bool get isPerformanceSmooth =>
      averageFps >= 50 && droppedFramePercentage < 10;

  /// Starts monitoring frame timings.
  void start() {
    if (_isMonitoring) return;

    _frameTimings.clear();
    _droppedFrameCount = 0;
    _startTime = DateTime.now();
    _isMonitoring = true;

    SchedulerBinding.instance.addTimingsCallback(_handleTimings);
  }

  /// Stops monitoring and returns summary.
  PerformanceSummary stop() {
    if (!_isMonitoring) {
      return PerformanceSummary.empty();
    }

    _isMonitoring = false;
    SchedulerBinding.instance.removeTimingsCallback(_handleTimings);

    final duration = DateTime.now().difference(_startTime!);

    return PerformanceSummary(
      averageFps: averageFps,
      droppedFrames: _droppedFrameCount,
      totalFrames: totalFrames,
      monitoringDuration: duration,
      averageFrameTimeMs: averageFrameTimeMs,
    );
  }

  void _handleTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      // Calculate total frame time (build + raster)
      final buildMs = timing.buildDuration.inMicroseconds / 1000;
      final rasterMs = timing.rasterDuration.inMicroseconds / 1000;
      final totalMs = buildMs + rasterMs;

      _frameTimings.add(totalMs);

      // 16.67ms = 60 FPS target
      if (totalMs > 16.67) {
        _droppedFrameCount++;
      }
    }
  }

  /// Resets all recorded data.
  void reset() {
    _frameTimings.clear();
    _droppedFrameCount = 0;
    _startTime = null;
  }
}

/// Summary of performance monitoring results.
@immutable
class PerformanceSummary {
  /// Creates a [PerformanceSummary] with the given values.
  const PerformanceSummary({
    required this.averageFps,
    required this.droppedFrames,
    required this.totalFrames,
    required this.monitoringDuration,
    required this.averageFrameTimeMs,
  });

  /// Creates an empty summary.
  factory PerformanceSummary.empty() {
    return const PerformanceSummary(
      averageFps: 0,
      droppedFrames: 0,
      totalFrames: 0,
      monitoringDuration: Duration.zero,
      averageFrameTimeMs: 0,
    );
  }

  /// Average frames per second.
  final double averageFps;

  /// Number of dropped frames.
  final int droppedFrames;

  /// Total frames recorded.
  final int totalFrames;

  /// Duration of monitoring.
  final Duration monitoringDuration;

  /// Average frame time in milliseconds.
  final double averageFrameTimeMs;

  /// Whether performance met the 60fps target.
  bool get isSmooth => averageFps >= 55 && droppedFrames < totalFrames * 0.05;

  @override
  String toString() =>
      'PerformanceSummary(fps: ${averageFps.toStringAsFixed(1)}, '
      'dropped: $droppedFrames/$totalFrames, '
      'duration: ${monitoringDuration.inSeconds}s)';
}
