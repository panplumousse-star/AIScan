import 'dart:async';

import 'package:flutter/material.dart';

import '../accessibility/accessibility_config.dart';
import '../theme/app_theme.dart';

// ============================================================================
// Loading Indicator Variants
// ============================================================================

/// Loading indicator style variants.
enum LoadingIndicatorVariant {
  /// Circular spinner (default).
  circular,

  /// Linear progress bar.
  linear,

  /// Pulsing dots animation.
  dots,

  /// Fading text with dots.
  text,
}

/// Loading indicator size presets.
enum LoadingIndicatorSize {
  /// Small indicator (16px).
  small,

  /// Medium indicator (24px) - default.
  medium,

  /// Large indicator (36px).
  large,

  /// Extra large indicator (48px).
  extraLarge,
}

// ============================================================================
// Loading Indicator Widget
// ============================================================================

/// A reusable loading indicator widget with multiple variants.
///
/// Provides consistent loading states across the app with accessibility
/// support and customizable styling.
///
/// ## Usage
/// ```dart
/// // Simple circular loader
/// LoadingIndicator()
///
/// // Linear progress with value
/// LoadingIndicator.linear(value: 0.65)
///
/// // Loading with message
/// LoadingIndicator.withMessage(
///   message: 'Scanning document...',
/// )
///
/// // Full-screen loading overlay
/// LoadingOverlay(
///   isLoading: isProcessing,
///   message: 'Processing...',
///   child: DocumentContent(),
/// )
/// ```
class LoadingIndicator extends StatelessWidget {
  /// Creates a [LoadingIndicator] with circular variant (default).
  const LoadingIndicator({
    this.variant = LoadingIndicatorVariant.circular,
    this.size = LoadingIndicatorSize.medium,
    this.value,
    this.color,
    this.backgroundColor,
    this.strokeWidth,
    this.semanticLabel,
    super.key,
  }) : message = null;

  /// Creates a circular [LoadingIndicator].
  const LoadingIndicator.circular({
    this.size = LoadingIndicatorSize.medium,
    this.value,
    this.color,
    this.backgroundColor,
    this.strokeWidth,
    this.semanticLabel,
    super.key,
  })  : variant = LoadingIndicatorVariant.circular,
        message = null;

  /// Creates a linear [LoadingIndicator].
  const LoadingIndicator.linear({
    this.size = LoadingIndicatorSize.medium,
    this.value,
    this.color,
    this.backgroundColor,
    this.semanticLabel,
    super.key,
  })  : variant = LoadingIndicatorVariant.linear,
        strokeWidth = null,
        message = null;

  /// Creates a dots [LoadingIndicator].
  const LoadingIndicator.dots({
    this.size = LoadingIndicatorSize.medium,
    this.color,
    this.semanticLabel,
    super.key,
  })  : variant = LoadingIndicatorVariant.dots,
        value = null,
        backgroundColor = null,
        strokeWidth = null,
        message = null;

  /// Creates a [LoadingIndicator] with a message.
  const LoadingIndicator.withMessage({
    required this.message,
    this.variant = LoadingIndicatorVariant.circular,
    this.size = LoadingIndicatorSize.medium,
    this.value,
    this.color,
    this.backgroundColor,
    this.strokeWidth,
    this.semanticLabel,
    super.key,
  });

  /// The visual style variant.
  final LoadingIndicatorVariant variant;

  /// The size of the indicator.
  final LoadingIndicatorSize size;

  /// Progress value (0.0 to 1.0) for determinate indicators.
  /// If null, shows indeterminate animation.
  final double? value;

  /// Custom indicator color.
  final Color? color;

  /// Background color for the track.
  final Color? backgroundColor;

  /// Stroke width for circular indicator.
  final double? strokeWidth;

  /// Optional message to display with the indicator.
  final String? message;

  /// Semantic label for screen readers.
  final String? semanticLabel;

  /// Gets the dimension for the indicator based on size.
  double get _dimension {
    switch (size) {
      case LoadingIndicatorSize.small:
        return 16.0;
      case LoadingIndicatorSize.medium:
        return 24.0;
      case LoadingIndicatorSize.large:
        return 36.0;
      case LoadingIndicatorSize.extraLarge:
        return 48.0;
    }
  }

  /// Gets the stroke width based on size.
  double get _strokeWidth {
    if (strokeWidth != null) return strokeWidth!;

    switch (size) {
      case LoadingIndicatorSize.small:
        return 2.0;
      case LoadingIndicatorSize.medium:
        return 3.0;
      case LoadingIndicatorSize.large:
        return 4.0;
      case LoadingIndicatorSize.extraLarge:
        return 4.0;
    }
  }

  /// Gets the linear progress height based on size.
  double get _linearHeight {
    switch (size) {
      case LoadingIndicatorSize.small:
        return 2.0;
      case LoadingIndicatorSize.medium:
        return 4.0;
      case LoadingIndicatorSize.large:
        return 6.0;
      case LoadingIndicatorSize.extraLarge:
        return 8.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? colorScheme.primary;
    final effectiveBackground = backgroundColor ?? colorScheme.primaryContainer;

    Widget indicator = switch (variant) {
      LoadingIndicatorVariant.circular => _buildCircular(
          effectiveColor,
          effectiveBackground,
        ),
      LoadingIndicatorVariant.linear => _buildLinear(
          effectiveColor,
          effectiveBackground,
        ),
      LoadingIndicatorVariant.dots => _LoadingDots(
          color: effectiveColor,
          size: _dimension / 4,
        ),
      LoadingIndicatorVariant.text => _LoadingTextDots(
          color: effectiveColor,
          message: message ?? A11yLabels.loading,
        ),
    };

    // Add message if provided (except for text variant which includes it)
    if (message != null && variant != LoadingIndicatorVariant.text) {
      indicator = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          const SizedBox(height: AppSpacing.md),
          Text(
            message!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // Wrap with semantics
    final label = semanticLabel ??
        (value != null
            ? '${(value! * 100).round()}% ${A11yLabels.loading.toLowerCase()}'
            : A11yLabels.loading);

    return Semantics(
      label: label,
      liveRegion: true,
      child: indicator,
    );
  }

  /// Builds a circular progress indicator.
  Widget _buildCircular(Color color, Color background) {
    if (value != null) {
      return SizedBox(
        width: _dimension,
        height: _dimension,
        child: CircularProgressIndicator(
          value: value,
          strokeWidth: _strokeWidth,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          backgroundColor: background,
        ),
      );
    }

    return SizedBox(
      width: _dimension,
      height: _dimension,
      child: CircularProgressIndicator(
        strokeWidth: _strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  /// Builds a linear progress indicator.
  Widget _buildLinear(Color color, Color background) {
    return SizedBox(
      height: _linearHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_linearHeight / 2),
        child: value != null
            ? LinearProgressIndicator(
                value: value,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                backgroundColor: background,
              )
            : LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(color),
                backgroundColor: background,
              ),
      ),
    );
  }
}

// ============================================================================
// Loading Dots Animation
// ============================================================================

/// Animated loading dots indicator.
class _LoadingDots extends StatefulWidget {
  const _LoadingDots({
    required this.color,
    this.size = 8.0,
  });

  final Color color;
  final double size;

  /// Spacing between dots (hardcoded for simplicity).
  static const double _spacing = 4.0;

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final animValue = (_controller.value - delay) % 1.0;
            final opacity = _calculateOpacity(animValue);
            final scale = _calculateScale(animValue);

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: _LoadingDots._spacing / 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double _calculateOpacity(double value) {
    if (value < 0.0 || value >= 1.0) return 0.3;
    if (value < 0.5) return 0.3 + (value * 1.4);
    return 1.0 - ((value - 0.5) * 1.4);
  }

  double _calculateScale(double value) {
    if (value < 0.0 || value >= 1.0) return 0.8;
    if (value < 0.5) return 0.8 + (value * 0.4);
    return 1.0 - ((value - 0.5) * 0.4);
  }
}

// ============================================================================
// Loading Text with Dots Animation
// ============================================================================

/// Loading text with animated trailing dots.
class _LoadingTextDots extends StatefulWidget {
  const _LoadingTextDots({
    required this.color,
    required this.message,
  });

  final Color color;
  final String message;

  @override
  State<_LoadingTextDots> createState() => _LoadingTextDotsState();
}

class _LoadingTextDotsState extends State<_LoadingTextDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dotCount = (_controller.value * 4).floor() % 4;
        final dots = '.' * dotCount;
        final padding = '.' * (3 - dotCount);

        return Text.rich(
          TextSpan(
            children: [
              TextSpan(text: widget.message),
              TextSpan(text: dots),
              TextSpan(
                text: padding,
                style: TextStyle(color: Colors.transparent),
              ),
            ],
          ),
          style: TextStyle(
            color: widget.color,
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }
}

// ============================================================================
// Loading Overlay Widget
// ============================================================================

/// A loading overlay that covers its child widget.
///
/// Displays a semi-transparent overlay with a loading indicator
/// when [isLoading] is true.
///
/// ## Usage
/// ```dart
/// LoadingOverlay(
///   isLoading: isProcessing,
///   message: 'Saving document...',
///   child: DocumentEditor(),
/// )
/// ```
class LoadingOverlay extends StatelessWidget {
  /// Creates a [LoadingOverlay].
  const LoadingOverlay({
    required this.isLoading,
    required this.child,
    this.message,
    this.color,
    this.overlayColor,
    this.indicatorSize = LoadingIndicatorSize.large,
    this.barrierDismissible = false,
    super.key,
  });

  /// Whether to show the loading overlay.
  final bool isLoading;

  /// The child widget to overlay.
  final Widget child;

  /// Optional loading message.
  final String? message;

  /// Loading indicator color.
  final Color? color;

  /// Overlay background color.
  final Color? overlayColor;

  /// Size of the loading indicator.
  final LoadingIndicatorSize indicatorSize;

  /// Whether tapping the overlay dismisses it.
  final bool barrierDismissible;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: GestureDetector(
              onTap: barrierDismissible ? () {} : null,
              child: AnimatedOpacity(
                opacity: isLoading ? 1.0 : 0.0,
                duration: AppDuration.standard,
                child: Container(
                  color: overlayColor ??
                      colorScheme.surface.withValues(alpha: 0.8),
                  child: Center(
                    child: LoadingIndicator.withMessage(
                      message: message,
                      size: indicatorSize,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// Skeleton Loading Widget
// ============================================================================

/// A skeleton loading placeholder with shimmer effect.
///
/// Use for content placeholders while data is loading.
///
/// ## Usage
/// ```dart
/// // Single skeleton
/// SkeletonLoader(
///   width: double.infinity,
///   height: 100,
/// )
///
/// // Text skeleton
/// SkeletonLoader.text(lines: 3)
///
/// // Avatar skeleton
/// SkeletonLoader.circle(size: 48)
/// ```
class SkeletonLoader extends StatefulWidget {
  /// Creates a [SkeletonLoader].
  const SkeletonLoader({
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
    super.key,
  })  : isCircle = false,
        lines = null;

  /// Creates a circular [SkeletonLoader].
  const SkeletonLoader.circle({
    required double size,
    this.baseColor,
    this.highlightColor,
    super.key,
  })  : width = size,
        height = size,
        borderRadius = null,
        isCircle = true,
        lines = null;

  /// Creates a text [SkeletonLoader] with multiple lines.
  const SkeletonLoader.text({
    this.lines = 3,
    this.width,
    this.baseColor,
    this.highlightColor,
    super.key,
  })  : height = null,
        borderRadius = null,
        isCircle = false;

  /// Width of the skeleton.
  final double? width;

  /// Height of the skeleton.
  final double? height;

  /// Border radius of the skeleton.
  final BorderRadius? borderRadius;

  /// Base color of the shimmer.
  final Color? baseColor;

  /// Highlight color of the shimmer.
  final Color? highlightColor;

  /// Whether the skeleton is circular.
  final bool isCircle;

  /// Number of text lines for text skeleton.
  final int? lines;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        widget.baseColor ?? (isDark ? Colors.grey[800]! : Colors.grey[300]!);
    final highlightColor = widget.highlightColor ??
        (isDark ? Colors.grey[700]! : Colors.grey[100]!);

    // Handle text skeleton
    if (widget.lines != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(widget.lines!, (index) {
          // Last line is shorter
          final isLast = index == widget.lines! - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: index < widget.lines! - 1 ? 8 : 0),
            child: _buildShimmer(
              width: isLast
                  ? (widget.width ?? double.infinity) * 0.6
                  : widget.width,
              height: 14,
              borderRadius: BorderRadius.circular(4),
              baseColor: baseColor,
              highlightColor: highlightColor,
            ),
          );
        }),
      );
    }

    // Handle regular skeleton
    return _buildShimmer(
      width: widget.width,
      height: widget.height,
      borderRadius: widget.isCircle
          ? null
          : widget.borderRadius ?? BorderRadius.circular(AppBorderRadius.md),
      isCircle: widget.isCircle,
      baseColor: baseColor,
      highlightColor: highlightColor,
    );
  }

  Widget _buildShimmer({
    double? width,
    double? height,
    BorderRadius? borderRadius,
    bool isCircle = false,
    required Color baseColor,
    required Color highlightColor,
  }) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircle ? null : borderRadius,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [0.0, 0.5, 1.0],
              transform: _GradientTransform(_animation.value),
            ),
          ),
        );
      },
    );
  }
}

/// Gradient transform for shimmer effect.
class _GradientTransform extends GradientTransform {
  const _GradientTransform(this.value);

  final double value;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * value, 0.0, 0.0);
  }
}

// ============================================================================
// Loading State Extension
// ============================================================================

/// Extension methods for loading states on widgets.
extension LoadingStateExtension on Widget {
  /// Wraps the widget with a loading overlay.
  Widget withLoadingOverlay({
    required bool isLoading,
    String? message,
    Color? overlayColor,
  }) {
    return LoadingOverlay(
      isLoading: isLoading,
      message: message,
      overlayColor: overlayColor,
      child: this,
    );
  }
}
