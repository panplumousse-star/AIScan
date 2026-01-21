import 'package:flutter/material.dart';

/// Custom painter for drawing a speech bubble tail.
///
/// Draws a curved tail pointing to the left, typically used for speech bubbles
/// or tooltip-style UI elements. Includes shadow effect and border.
///
/// Usage:
/// ```dart
/// CustomPaint(
///   size: Size(20, 30),
///   painter: BubbleTailPainter(
///     color: Colors.white,
///     borderColor: Colors.grey.shade300,
///   ),
/// )
/// ```
class BubbleTailPainter extends CustomPainter {
  /// Creates a bubble tail painter with the specified colors.
  ///
  /// The [color] is the fill color for the tail, and [borderColor] is used
  /// for the outline stroke.
  const BubbleTailPainter({
    required this.color,
    required this.borderColor,
  });

  /// The fill color of the bubble tail.
  final Color color;

  /// The border/stroke color of the bubble tail.
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(size.width * 1.2, size.height / 2, 0, size.height);
    path.close();

    // Draw shadow effect
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.03)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path.shift(const Offset(2, 4)), shadowPaint);

    // Draw fill
    canvas.drawPath(path, paint);

    // Draw border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for drawing a speech bubble tail pointing down-left.
///
/// Specifically designed for share dialog speech bubbles that point toward
/// a mascot positioned on the bottom-left. Creates a triangular tail shape.
///
/// Usage:
/// ```dart
/// CustomPaint(
///   size: Size(20, 30),
///   painter: ShareBubbleTailPainter(
///     color: Colors.white,
///   ),
/// )
/// ```
class ShareBubbleTailPainter extends CustomPainter {
  /// Creates a share bubble tail painter with the specified color.
  const ShareBubbleTailPainter({required this.color});

  /// The fill color of the bubble tail.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw tail pointing down-left (toward mascot on the left)
    final path = Path();
    path.moveTo(size.width, 0); // Top right (connected to bubble)
    path.lineTo(0, size.height); // Bottom left (pointing to mascot)
    path.lineTo(size.width, size.height * 0.6); // Right side
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
