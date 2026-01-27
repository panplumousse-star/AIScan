import 'package:flutter/material.dart';

/// Direction of the speech bubble tail.
enum BubbleTailDirection {
  /// Tail points to the left (speaker is on the left).
  left,

  /// Tail points to the right (speaker is on the right).
  right,

  /// Tail points down-left (speaker is below-left).
  downLeft,

  /// Tail points down-right (speaker is below-right).
  downRight,

  /// No tail displayed.
  none,
}

/// A speech bubble widget styled to match the Bento design system.
///
/// The bubble includes an optional tail that can point left or right,
/// making it suitable for chat-like interfaces or mascot speech.
///
/// Example usage:
/// ```dart
/// BentoSpeechBubble(
///   tailDirection: BubbleTailDirection.left,
///   child: Text('Hello!'),
/// )
/// ```
class BentoSpeechBubble extends StatelessWidget {
  /// The content to display inside the bubble.
  final Widget child;

  /// Direction the tail points towards.
  final BubbleTailDirection tailDirection;

  /// Background color of the bubble.
  /// If null, uses theme-appropriate default (white/dark).
  final Color? color;

  /// Border color of the bubble.
  /// If null, uses theme-appropriate default.
  final Color? borderColor;

  /// Border width. Defaults to 1.5.
  final double borderWidth;

  /// Corner radius of the bubble. Defaults to 16.0.
  final double borderRadius;

  /// Padding inside the bubble.
  final EdgeInsetsGeometry padding;

  /// Optional constraints for the bubble width.
  final BoxConstraints? constraints;

  /// Whether to show shadow. Defaults to true.
  final bool showShadow;

  /// Creates a [BentoSpeechBubble] widget.
  const BentoSpeechBubble({
    super.key,
    required this.child,
    this.tailDirection = BubbleTailDirection.none,
    this.color,
    this.borderColor,
    this.borderWidth = 1.5,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.constraints,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bubbleColor = color ??
        (isDark
            ? const Color(0xFF000000).withValues(alpha: 0.6)
            : Colors.white);

    final bubbleBorderColor = borderColor ??
        (isDark
            ? const Color(0xFFFFFFFF).withValues(alpha: 0.1)
            : const Color(0xFFE2E8F0));

    return CustomPaint(
      painter: _BentoSpeechBubblePainter(
        color: bubbleColor,
        borderColor: bubbleBorderColor,
        borderWidth: borderWidth,
        radius: borderRadius,
        tailDirection: tailDirection,
        showShadow: showShadow,
        shadowColor: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.08),
      ),
      child: Container(
        constraints: constraints,
        padding: _adjustedPadding,
        child: child,
      ),
    );
  }

  /// Adjusts padding to account for tail space.
  EdgeInsetsGeometry get _adjustedPadding {
    const tailSpace = 10.0;

    if (padding is EdgeInsets) {
      final p = padding as EdgeInsets;
      switch (tailDirection) {
        case BubbleTailDirection.left:
          return EdgeInsets.fromLTRB(
              p.left + tailSpace, p.top, p.right, p.bottom);
        case BubbleTailDirection.right:
          return EdgeInsets.fromLTRB(
              p.left, p.top, p.right + tailSpace, p.bottom);
        case BubbleTailDirection.downLeft:
        case BubbleTailDirection.downRight:
          return EdgeInsets.fromLTRB(
              p.left, p.top, p.right, p.bottom + tailSpace);
        case BubbleTailDirection.none:
          return p;
      }
    }
    return padding;
  }
}

/// Custom painter that draws the speech bubble shape with integrated tail.
class _BentoSpeechBubblePainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final double radius;
  final BubbleTailDirection tailDirection;
  final bool showShadow;
  final Color shadowColor;

  /// Tail dimensions.
  static const double _tailWidth = 10.0;
  static const double _tailHeight = 8.0;

  const _BentoSpeechBubblePainter({
    required this.color,
    required this.borderColor,
    required this.borderWidth,
    required this.radius,
    required this.tailDirection,
    required this.showShadow,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = _buildBubblePath(size);

    // Draw shadow if enabled
    if (showShadow) {
      final shadowPaint = Paint()
        ..color = shadowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawPath(path.shift(const Offset(0, 4)), shadowPaint);
    }

    // Draw fill
    canvas.drawPath(path, paint);

    // Draw border
    if (borderWidth > 0) {
      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, borderPaint);
    }
  }

  Path _buildBubblePath(Size size) {
    final h = size.height;
    final w = size.width;
    final r = radius;

    switch (tailDirection) {
      case BubbleTailDirection.left:
        return _buildLeftTailPath(w, h, r);
      case BubbleTailDirection.right:
        return _buildRightTailPath(w, h, r);
      case BubbleTailDirection.downLeft:
        return _buildDownLeftTailPath(w, h, r);
      case BubbleTailDirection.downRight:
        return _buildDownRightTailPath(w, h, r);
      case BubbleTailDirection.none:
        return _buildNoTailPath(w, h, r);
    }
  }

  /// Builds path with tail pointing left (speaker on left side).
  Path _buildLeftTailPath(double w, double h, double r) {
    final path = Path();
    const tailOffset = _tailWidth;

    // Start at top-left after tail area
    path.moveTo(tailOffset + r, 0);

    // Top edge to top-right corner
    path.lineTo(w - r, 0);

    // Top-right corner
    path.quadraticBezierTo(w, 0, w, r);

    // Right edge
    path.lineTo(w, h - r);

    // Bottom-right corner
    path.quadraticBezierTo(w, h, w - r, h);

    // Bottom edge to tail area
    path.lineTo(tailOffset + r, h);

    // Bottom-left corner (before tail)
    path.quadraticBezierTo(tailOffset, h, tailOffset, h - r);

    // Left edge down to tail start
    path.lineTo(tailOffset, h * 0.6 + _tailHeight / 2);

    // Tail curve outward (pointing left)
    path.quadraticBezierTo(
      tailOffset - _tailWidth * 0.3,
      h * 0.5,
      0,
      h * 0.45,
    );

    // Tail tip curve back
    path.quadraticBezierTo(
      tailOffset - _tailWidth * 0.3,
      h * 0.4,
      tailOffset,
      h * 0.4 - _tailHeight / 2,
    );

    // Left edge up from tail
    path.lineTo(tailOffset, r);

    // Top-left corner
    path.quadraticBezierTo(tailOffset, 0, tailOffset + r, 0);

    path.close();
    return path;
  }

  /// Builds path with tail pointing right (speaker on right side).
  Path _buildRightTailPath(double w, double h, double r) {
    final path = Path();
    final tailOffset = w - _tailWidth;

    // Start at top-left
    path.moveTo(r, 0);

    // Top edge to before tail area
    path.lineTo(tailOffset - r, 0);

    // Top-right corner (before tail)
    path.quadraticBezierTo(tailOffset, 0, tailOffset, r);

    // Right edge down to tail start
    path.lineTo(tailOffset, h * 0.4 - _tailHeight / 2);

    // Tail curve outward (pointing right)
    path.quadraticBezierTo(
      tailOffset + _tailWidth * 0.3,
      h * 0.4,
      w,
      h * 0.45,
    );

    // Tail tip curve back
    path.quadraticBezierTo(
      tailOffset + _tailWidth * 0.3,
      h * 0.5,
      tailOffset,
      h * 0.6 + _tailHeight / 2,
    );

    // Right edge from tail to bottom
    path.lineTo(tailOffset, h - r);

    // Bottom-right corner (after tail)
    path.quadraticBezierTo(tailOffset, h, tailOffset - r, h);

    // Bottom edge
    path.lineTo(r, h);

    // Bottom-left corner
    path.quadraticBezierTo(0, h, 0, h - r);

    // Left edge
    path.lineTo(0, r);

    // Top-left corner
    path.quadraticBezierTo(0, 0, r, 0);

    path.close();
    return path;
  }

  /// Builds path with tail pointing down-left (speaker below-left).
  Path _buildDownLeftTailPath(double w, double h, double r) {
    final path = Path();
    const tailOffset = _tailHeight;
    final bodyH = h - tailOffset;

    // Start at top-left
    path.moveTo(r, 0);

    // Top edge
    path.lineTo(w - r, 0);

    // Top-right corner
    path.quadraticBezierTo(w, 0, w, r);

    // Right edge
    path.lineTo(w, bodyH - r);

    // Bottom-right corner
    path.quadraticBezierTo(w, bodyH, w - r, bodyH);

    // Bottom edge to tail area
    path.lineTo(r + _tailWidth + 8, bodyH);

    // Tail curve down-left
    path.quadraticBezierTo(
      r + _tailWidth * 0.5 + 8,
      bodyH + tailOffset * 0.3,
      r + 8,
      h,
    );

    // Tail tip curve back
    path.quadraticBezierTo(
      r + _tailWidth * 0.3 + 8,
      bodyH + tailOffset * 0.3,
      r + 8,
      bodyH,
    );

    // Bottom edge from tail
    path.lineTo(r, bodyH);

    // Bottom-left corner
    path.quadraticBezierTo(0, bodyH, 0, bodyH - r);

    // Left edge
    path.lineTo(0, r);

    // Top-left corner
    path.quadraticBezierTo(0, 0, r, 0);

    path.close();
    return path;
  }

  /// Builds path with tail pointing down-right (speaker below-right).
  Path _buildDownRightTailPath(double w, double h, double r) {
    final path = Path();
    const tailOffset = _tailHeight;
    final bodyH = h - tailOffset;

    // Start at top-left
    path.moveTo(r, 0);

    // Top edge
    path.lineTo(w - r, 0);

    // Top-right corner
    path.quadraticBezierTo(w, 0, w, r);

    // Right edge
    path.lineTo(w, bodyH - r);

    // Bottom-right corner
    path.quadraticBezierTo(w, bodyH, w - r, bodyH);

    // Bottom edge to tail start
    path.lineTo(w - r - 8, bodyH);

    // Tail curve back from tip
    path.quadraticBezierTo(
      w - r - _tailWidth * 0.3 - 8,
      bodyH + tailOffset * 0.3,
      w - r - 8,
      h,
    );

    // Tail tip curve down-right
    path.quadraticBezierTo(
      w - r - _tailWidth * 0.5 - 8,
      bodyH + tailOffset * 0.3,
      w - r - _tailWidth - 8,
      bodyH,
    );

    // Bottom edge from tail
    path.lineTo(r, bodyH);

    // Bottom-left corner
    path.quadraticBezierTo(0, bodyH, 0, bodyH - r);

    // Left edge
    path.lineTo(0, r);

    // Top-left corner
    path.quadraticBezierTo(0, 0, r, 0);

    path.close();
    return path;
  }

  /// Builds simple rounded rectangle path without tail.
  Path _buildNoTailPath(double w, double h, double r) {
    return Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h),
        Radius.circular(r),
      ));
  }

  @override
  bool shouldRepaint(covariant _BentoSpeechBubblePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.radius != radius ||
        oldDelegate.tailDirection != tailDirection ||
        oldDelegate.showShadow != showShadow ||
        oldDelegate.shadowColor != shadowColor;
  }
}
