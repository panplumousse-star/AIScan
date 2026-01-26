import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class BentoBackground extends StatelessWidget {
  const BentoBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // The Base Layer
        Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
          ),
        ),

        // Deep Mesh Blobs (Using more saturated pastels for visibility)
        _LiquidBlob(
          color: isDark
              ? const Color(0xFF1E1B4B)
              : const Color(0xFFC7D2FE), // Midnight Indigo / Light Indigo
          size: 600,
          left: -150,
          top: -100,
          duration: const Duration(seconds: 25),
        ),
        _LiquidBlob(
          color: isDark
              ? const Color(0xFF4C1D95)
              : const Color(0xFFE9D5FF), // Midnight Purple / Light Purple
          size: 550,
          right: -150,
          bottom: -50,
          duration: const Duration(seconds: 30),
        ),
        _LiquidBlob(
          color: isDark
              ? const Color(0xFF064E3B)
              : const Color(0xFFBAE6FD), // Midnight Emerald / Light Sky
          size: 500,
          right: 0,
          top: 150,
          duration: const Duration(seconds: 22),
        ),
        _LiquidBlob(
          color: isDark
              ? const Color(0xFF312E81)
              : const Color(0xFFFBCFE8), // Deep Navy / Soft Pink
          size: 450,
          left: 50,
          bottom: 100,
          duration: const Duration(seconds: 28),
        ),

        // The Glassy Blur Layer (Reduced to 50 for more visible shapes)
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),

        // Subtle Grain Texture
        Positioned.fill(
          child: Opacity(
            opacity: 0.02,
            child: Image.network(
              'https://grainy-gradients.vercel.app/noise.svg',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }
}

class _LiquidBlob extends StatefulWidget {
  final Color color;
  final double size;
  final double? top;
  final double? left;
  final double? bottom;
  final double? right;
  final Duration duration;

  const _LiquidBlob({
    required this.color,
    required this.size,
    this.top,
    this.left,
    this.bottom,
    this.right,
    required this.duration,
  });

  @override
  State<_LiquidBlob> createState() => _LiquidBlobState();
}

class _LiquidBlobState extends State<_LiquidBlob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
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
    return Positioned(
      top: widget.top,
      left: widget.left,
      bottom: widget.bottom,
      right: widget.right,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // wandering movement
          final angle = _controller.value * 2 * math.pi;
          final xOffset = math.sin(angle) * 40;
          final yOffset = math.cos(angle) * 40;

          return Transform.translate(
            offset: Offset(xOffset, yOffset),
            child: Transform.scale(
              scale: 1.0 + (math.sin(angle) * 0.1), // subtle pulsing
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
