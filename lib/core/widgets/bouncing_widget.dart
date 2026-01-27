import 'dart:async';

import 'package:flutter/material.dart';

/// A widget that continuously bounces its child with a subtle pulsing scale animation.
///
/// Creates a lively, breathing effect by repeatedly scaling the child widget
/// up and down. Perfect for drawing attention to interactive elements or
/// adding playful motion to mascots and icons.
///
/// The animation uses a smooth ease-in-out curve and automatically repeats
/// in reverse, creating a natural pulsing rhythm.
///
/// ## Animation Properties
/// - **Duration**: 2 seconds per cycle
/// - **Scale Range**: 0.92 to 1.08 (16% total scale variation)
/// - **Curve**: Ease-in-out for smooth acceleration/deceleration
/// - **Repeat**: Infinite with reverse
///
/// ## Usage
/// ```dart
/// BouncingWidget(
///   child: Icon(
///     Icons.star,
///     size: 48,
///     color: Colors.amber,
///   ),
/// )
/// ```
///
/// ## Use Cases
/// - Animated mascots or characters
/// - Attention-grabbing call-to-action buttons
/// - Playful UI elements in idle states
/// - Loading indicators with personality
///
/// See also:
/// - [AnimatedFadeIn], for fade-in entrance animations
/// - [AnimatedSlideIn], for slide-in entrance animations
/// - [ScaleTransition], the underlying Flutter widget
class BouncingWidget extends StatefulWidget {
  /// Creates a [BouncingWidget] that animates its child.
  const BouncingWidget({
    required this.child,
    super.key,
  });

  /// The widget to animate with the bouncing effect.
  final Widget child;

  @override
  State<BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<BouncingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2), // Faster, more lively pulse
      vsync: this,
    );
    unawaited(_controller.repeat(reverse: true));

    _animation = Tween<double>(begin: 0.92, end: 1.08).animate(
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
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}
