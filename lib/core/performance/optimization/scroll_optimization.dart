import 'package:flutter/material.dart';

import '../device_performance.dart';

// ============================================================================
// Scroll Optimization
// ============================================================================

/// Configuration for optimized scrolling on low-end devices.
///
/// Use with [ListView.builder] and [GridView.builder] for smooth scrolling.
///
/// ## Usage
/// ```dart
/// final config = ScrollOptimizationConfig.forDevice(devicePerformance);
///
/// ListView.builder(
///   cacheExtent: config.cacheExtent,
///   physics: config.physics,
///   addAutomaticKeepAlives: config.addAutomaticKeepAlives,
///   addRepaintBoundaries: config.addRepaintBoundaries,
///   itemBuilder: (context, index) => ...,
/// )
/// ```
@immutable
class ScrollOptimizationConfig {
  /// Creates a [ScrollOptimizationConfig] with the given values.
  const ScrollOptimizationConfig({
    required this.cacheExtent,
    required this.physics,
    required this.addAutomaticKeepAlives,
    required this.addRepaintBoundaries,
    required this.itemExtent,
  });

  /// Creates a configuration optimized for the given device.
  factory ScrollOptimizationConfig.forDevice(DevicePerformance device) {
    switch (device.tier) {
      case DeviceTier.low:
        return const ScrollOptimizationConfig(
          cacheExtent: 100, // Minimal cache
          physics: ClampingScrollPhysics(),
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          itemExtent: null,
        );
      case DeviceTier.medium:
        return const ScrollOptimizationConfig(
          cacheExtent: 250,
          physics: BouncingScrollPhysics(),
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
          itemExtent: null,
        );
      case DeviceTier.high:
        return const ScrollOptimizationConfig(
          cacheExtent: 500,
          physics: BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
          itemExtent: null,
        );
    }
  }

  /// How many pixels to cache ahead/behind visible area.
  final double cacheExtent;

  /// Scroll physics to use.
  final ScrollPhysics physics;

  /// Whether to add automatic keep-alives.
  final bool addAutomaticKeepAlives;

  /// Whether to add repaint boundaries.
  final bool addRepaintBoundaries;

  /// Fixed item extent for optimization (null for variable).
  final double? itemExtent;
}
