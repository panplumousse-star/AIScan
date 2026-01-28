import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/bento_card.dart';

/// A Bento-style card with 3D flip animation between front and back sides.
///
/// This widget provides an interactive card that can flip to reveal content
/// on its reverse side. The flip animation uses a 3D perspective transform
/// for a realistic effect. Tapping the card triggers haptic feedback and
/// animates the flip using a smooth easing curve.
///
/// The widget is commonly used in the settings screen to display additional
/// information or details that don't fit on the primary card face.
///
/// ## Example Usage
/// ```dart
/// BentoFlipCard(
///   isDark: true,
///   front: Text('Front Content'),
///   back: Text('Back Content'),
/// )
/// ```
class BentoFlipCard extends StatefulWidget {
  /// Creates a [BentoFlipCard] with the given front and back widgets.
  const BentoFlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.isDark,
  });

  /// The widget to display on the front side of the card.
  final Widget front;

  /// The widget to display on the back side of the card.
  final Widget back;

  /// Whether dark mode is active.
  final bool isDark;

  @override
  State<BentoFlipCard> createState() => _BentoFlipCardState();
}

class _BentoFlipCardState extends State<BentoFlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_controller.isAnimating) return;
    unawaited(HapticFeedback.mediumImpact());
    if (_isFront) {
      unawaited(_controller.forward());
    } else {
      unawaited(_controller.reverse());
    }
    setState(() => _isFront = !_isFront);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final angle = _animation.value * 3.141592653589793;
        final isBack = angle > 3.141592653589793 / 2;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: BentoCard(
            borderRadius: 32,
            padding: const EdgeInsets.all(16),
            onTap: _toggleCard,
            animateOnTap: false,
            backgroundColor: widget.isDark
                ? const Color(0xFF000000).withValues(alpha: 0.6)
                : Colors.white,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateY(isBack ? 3.141592653589793 : 0),
              child: isBack ? widget.back : widget.front,
            ),
          ),
        );
      },
    );
  }
}
