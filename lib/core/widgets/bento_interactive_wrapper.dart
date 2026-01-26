import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// Bento Interactive Wrapper
// ============================================================================

/// Interactive wrapper for bento-style cards with scale and tilt animations.
///
/// Provides tactile feedback when tapped, including:
/// - Scale-down animation on press
/// - 3D tilt effect based on touch position
/// - Haptic feedback for enhanced user experience
///
/// This wrapper creates a premium, app-like feel for interactive elements
/// in the bento grid layout.
///
/// ## Usage
/// ```dart
/// // Basic interactive card
/// BentoInteractiveWrapper(
///   onTap: () => print('Card tapped!'),
///   child: Container(
///     padding: EdgeInsets.all(20),
///     decoration: BoxDecoration(
///       color: Colors.white,
///       borderRadius: BorderRadius.circular(32),
///     ),
///     child: Text('Interactive Card'),
///   ),
/// )
///
/// // Card with semantic labels for accessibility
/// BentoInteractiveWrapper(
///   semanticLabel: 'Scan Document',
///   semanticHint: 'Opens camera to scan a new document',
///   onTap: () => startScanning(),
///   child: ScanCard(),
/// )
/// ```
class BentoInteractiveWrapper extends StatefulWidget {
  /// Creates a [BentoInteractiveWrapper].
  const BentoInteractiveWrapper({
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.semanticHint,
    super.key,
  });

  /// The child widget to wrap with interactive effects.
  final Widget child;

  /// Callback invoked when the widget is tapped.
  /// If null, the widget will not respond to taps.
  final VoidCallback? onTap;

  /// Semantic label for screen readers.
  final String? semanticLabel;

  /// Semantic hint for screen readers.
  final String? semanticHint;

  @override
  State<BentoInteractiveWrapper> createState() => _BentoInteractiveWrapperState();
}

class _BentoInteractiveWrapperState extends State<BentoInteractiveWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  double _rotationX = 0.0;
  double _rotationY = 0.0;

  /// Whether the wrapper is interactive.
  bool get _isInteractive => widget.onTap != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    _controller.forward();

    // Tilt calculation based on touch position relative to center
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;
    final box = renderObject;
    final localPos = details.localPosition;
    final centerX = box.size.width / 2;
    final centerY = box.size.height / 2;

    setState(() {
      // Sensitivity factor: 0.08
      _rotationX = (centerY - localPos.dy) / centerY * 0.08;
      _rotationY = (localPos.dx - centerX) / centerX * 0.08;
    });

    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    setState(() {
      _rotationX = 0.0;
      _rotationY = 0.0;
    });
  }

  void _handleTapCancel() {
    _controller.reverse();
    setState(() {
      _rotationX = 0.0;
      _rotationY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      button: _isInteractive,
      enabled: _isInteractive,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // perspective
                  ..rotateX(_rotationX)
                  ..rotateY(_rotationY),
                child: child,
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
