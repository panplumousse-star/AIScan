import 'package:flutter/material.dart';

/// A lightweight mesh-gradient background that visually matches the original
/// animated blob + BackdropFilter approach but uses only static [RadialGradient]
/// layers — eliminating all [AnimationController]s and the expensive per-frame
/// [BackdropFilter] rasterisation.
///
/// When the platform does **not** request reduced motion, a single slow opacity
/// crossfade between two gradient states adds subtle visual life at near-zero
/// GPU cost.
class BentoBackground extends StatelessWidget {
  const BentoBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return RepaintBoundary(
      child: Stack(
        children: [
          // Solid base
          Positioned.fill(
            child: ColoredBox(
              color: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
            ),
          ),

          // Static radial gradient blobs — mimics the blurred circles
          Positioned.fill(
            child: _StaticGradientLayer(isDark: isDark),
          ),

          // Subtle animated shimmer (skipped when reduceMotion is on)
          if (!reduceMotion)
            Positioned.fill(
              child: _SubtleShimmer(isDark: isDark),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Static gradient layer — replaces 4 animated blobs + BackdropFilter
// ---------------------------------------------------------------------------

class _StaticGradientLayer extends StatelessWidget {
  const _StaticGradientLayer({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // Each radial gradient matches one of the original blob positions/colours
    // after the sigma-50 blur was applied (large, soft, semi-transparent).
    return CustomPaint(
      painter: _GradientPainter(isDark: isDark),
    );
  }
}

class _GradientPainter extends CustomPainter {
  _GradientPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final blobs = _blobSpecs(size);
    for (final blob in blobs) {
      final gradient = RadialGradient(
        center: blob.alignment,
        radius: blob.radius,
        colors: [blob.color, blob.color.withAlpha(0)],
        stops: const [0.0, 1.0],
      );
      final paint = Paint()
        ..shader = gradient.createShader(Offset.zero & size);
      canvas.drawRect(Offset.zero & size, paint);
    }
  }

  List<_BlobSpec> _blobSpecs(Size size) {
    if (isDark) {
      return const [
        // Top-left — Midnight Indigo
        _BlobSpec(Alignment(-0.7, -0.6), 0.9, Color(0x991E1B4B)),
        // Bottom-right — Midnight Purple
        _BlobSpec(Alignment(0.7, 0.7), 0.85, Color(0x994C1D95)),
        // Right-center — Midnight Emerald
        _BlobSpec(Alignment(0.5, -0.1), 0.8, Color(0x99064E3B)),
        // Left-bottom — Deep Navy
        _BlobSpec(Alignment(-0.4, 0.5), 0.75, Color(0x99312E81)),
      ];
    }
    return const [
      // Top-left — Light Indigo
      _BlobSpec(Alignment(-0.7, -0.6), 0.9, Color(0x99C7D2FE)),
      // Bottom-right — Light Purple
      _BlobSpec(Alignment(0.7, 0.7), 0.85, Color(0x99E9D5FF)),
      // Right-center — Light Sky
      _BlobSpec(Alignment(0.5, -0.1), 0.8, Color(0x99BAE6FD)),
      // Left-bottom — Soft Pink
      _BlobSpec(Alignment(-0.4, 0.5), 0.75, Color(0x99FBCFE8)),
    ];
  }

  @override
  bool shouldRepaint(_GradientPainter oldDelegate) =>
      isDark != oldDelegate.isDark;
}

class _BlobSpec {
  const _BlobSpec(this.alignment, this.radius, this.color);
  final Alignment alignment;
  final double radius;
  final Color color;
}

// ---------------------------------------------------------------------------
// Subtle shimmer — one slow opacity crossfade, not per-frame rasterisation
// ---------------------------------------------------------------------------

class _SubtleShimmer extends StatefulWidget {
  const _SubtleShimmer({required this.isDark});

  final bool isDark;

  @override
  State<_SubtleShimmer> createState() => _SubtleShimmerState();
}

class _SubtleShimmerState extends State<_SubtleShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      // Very slow cycle — 30 seconds per loop keeps the background alive
      // without burning GPU on rapid repaints.
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 0.12).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.3, -0.3),
            radius: 1.0,
            colors: widget.isDark
                ? const [Color(0xFF1E1B4B), Color(0x00020617)]
                : const [Color(0xFFC7D2FE), Color(0x00F8FAFC)],
          ),
        ),
      ),
    );
  }
}
