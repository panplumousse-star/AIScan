import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../device_performance.dart';
import '../optimization/scroll_optimization.dart';

// ============================================================================
// Optimized List View Widget
// ============================================================================

/// An optimized list view that adapts to device capabilities.
///
/// Automatically configures caching, physics, and item rendering
/// based on device tier.
///
/// ## Features
/// - Device-adaptive scroll physics (clamping for low-end, bouncing for high-end)
/// - Optimized cache extent based on device tier
/// - Automatic repaint boundaries for better performance
/// - Optional pagination support via onScrollEnd callback
/// - Separator support for divided lists
///
/// ## Usage
/// ```dart
/// OptimizedListView(
///   itemCount: documents.length,
///   itemBuilder: (context, index) {
///     return DocumentTile(document: documents[index]);
///   },
///   onScrollEnd: () {
///     // Load more items
///     loadNextPage();
///   },
/// )
/// ```
///
/// ## Performance Optimizations
/// The widget applies different optimizations based on device tier:
///
/// **Low-end devices:**
/// - Minimal cache extent (100px)
/// - Clamping scroll physics (no overscroll)
/// - No automatic keep-alives
/// - Repaint boundaries enabled
///
/// **Mid-range devices:**
/// - Standard cache extent (250px)
/// - Bouncing scroll physics
/// - Automatic keep-alives enabled
/// - Repaint boundaries enabled
///
/// **High-end devices:**
/// - Large cache extent (500px)
/// - Bouncing scroll physics with always scrollable
/// - Automatic keep-alives enabled
/// - Repaint boundaries enabled
class OptimizedListView extends ConsumerWidget {
  /// Creates an [OptimizedListView].
  const OptimizedListView({
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.itemExtent,
    this.padding,
    this.scrollController,
    this.onScrollEnd,
    super.key,
  });

  /// Number of items.
  final int itemCount;

  /// Builder for list items.
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Builder for separators (optional).
  final Widget Function(BuildContext context, int index)? separatorBuilder;

  /// Fixed item extent for optimization.
  final double? itemExtent;

  /// List padding.
  final EdgeInsetsGeometry? padding;

  /// Scroll controller.
  final ScrollController? scrollController;

  /// Called when scrolled to end (for pagination).
  final VoidCallback? onScrollEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicePerformance = ref.watch(devicePerformanceProvider);
    final config = ScrollOptimizationConfig.forDevice(devicePerformance);

    // Add scroll listener for pagination
    final controller = scrollController ?? ScrollController();

    if (onScrollEnd != null) {
      controller.addListener(() {
        if (controller.position.pixels >=
            controller.position.maxScrollExtent * 0.9) {
          onScrollEnd!();
        }
      });
    }

    if (separatorBuilder != null) {
      return ListView.separated(
        controller: controller,
        padding: padding,
        physics: config.physics,
        cacheExtent: config.cacheExtent,
        addAutomaticKeepAlives: config.addAutomaticKeepAlives,
        addRepaintBoundaries: config.addRepaintBoundaries,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return RepaintBoundary(child: itemBuilder(context, index));
        },
        separatorBuilder: separatorBuilder!,
      );
    }

    return ListView.builder(
      controller: controller,
      padding: padding,
      physics: config.physics,
      cacheExtent: config.cacheExtent,
      addAutomaticKeepAlives: config.addAutomaticKeepAlives,
      addRepaintBoundaries: config.addRepaintBoundaries,
      itemExtent: itemExtent ?? config.itemExtent,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return RepaintBoundary(child: itemBuilder(context, index));
      },
    );
  }
}
