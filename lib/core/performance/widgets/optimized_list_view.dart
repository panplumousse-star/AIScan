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
class OptimizedListView extends ConsumerStatefulWidget {
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
  ConsumerState<OptimizedListView> createState() =>
      _OptimizedListViewState();
}

class _OptimizedListViewState extends ConsumerState<OptimizedListView> {
  ScrollController? _ownController;
  bool _ownsController = false;

  ScrollController get _effectiveController {
    if (widget.scrollController != null) {
      return widget.scrollController!;
    }
    _ownController ??= ScrollController();
    _ownsController = true;
    return _ownController!;
  }

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
  }

  @override
  void didUpdateWidget(OptimizedListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the external controller or callback changed, re-setup listener
    if (oldWidget.scrollController != widget.scrollController ||
        oldWidget.onScrollEnd != widget.onScrollEnd) {
      _removeScrollListener(oldWidget);
      // If the external controller changed and we owned the old one, dispose it
      if (oldWidget.scrollController == null &&
          widget.scrollController != null &&
          _ownController != null) {
        _ownController!.dispose();
        _ownController = null;
        _ownsController = false;
      }
      _setupScrollListener();
    }
  }

  void _setupScrollListener() {
    if (widget.onScrollEnd != null) {
      _effectiveController.addListener(_onScroll);
    }
  }

  void _removeScrollListener(OptimizedListView oldWidget) {
    final oldController = oldWidget.scrollController ?? _ownController;
    oldController?.removeListener(_onScroll);
  }

  void _onScroll() {
    if (_effectiveController.position.pixels >=
        _effectiveController.position.maxScrollExtent * 0.9) {
      widget.onScrollEnd?.call();
    }
  }

  @override
  void dispose() {
    final controller = widget.scrollController ?? _ownController;
    controller?.removeListener(_onScroll);
    if (_ownsController) {
      _ownController?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devicePerformance = ref.watch(devicePerformanceProvider);
    final config = ScrollOptimizationConfig.forDevice(devicePerformance);

    final controller = _effectiveController;

    if (widget.separatorBuilder != null) {
      return ListView.separated(
        controller: controller,
        padding: widget.padding,
        physics: config.physics,
        cacheExtent: config.cacheExtent,
        addAutomaticKeepAlives: config.addAutomaticKeepAlives,
        addRepaintBoundaries: config.addRepaintBoundaries,
        itemCount: widget.itemCount,
        itemBuilder: (context, index) {
          return RepaintBoundary(child: widget.itemBuilder(context, index));
        },
        separatorBuilder: widget.separatorBuilder!,
      );
    }

    return ListView.builder(
      controller: controller,
      padding: widget.padding,
      physics: config.physics,
      cacheExtent: config.cacheExtent,
      addAutomaticKeepAlives: config.addAutomaticKeepAlives,
      addRepaintBoundaries: config.addRepaintBoundaries,
      itemExtent: widget.itemExtent ?? config.itemExtent,
      itemCount: widget.itemCount,
      itemBuilder: (context, index) {
        return RepaintBoundary(child: widget.itemBuilder(context, index));
      },
    );
  }
}
