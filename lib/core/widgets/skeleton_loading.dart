
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'bento_background.dart';

/// A shimmer effect widget that creates a loading animation.
///
/// The shimmer moves from left to right, giving the impression
/// that content is about to appear.
class ShimmerEffect extends StatefulWidget {
  const ShimmerEffect({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

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

    final baseColor = widget.baseColor ??
        (isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.6)
            : const Color(0xFFE2E8F0));

    final highlightColor = widget.highlightColor ??
        (isDark
            ? const Color(0xFF334155).withValues(alpha: 0.8)
            : const Color(0xFFF1F5F9));

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(_animation.value),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.slidePercent);

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// A skeleton placeholder card that matches the Bento card style.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = 32,
    this.showIcon = false,
    this.showText = false,
  });

  final double height;
  final double? width;
  final double borderRadius;
  final bool showIcon;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.6)
            : AppColors.bentoCardWhite,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: showIcon || showText
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showIcon) _buildIconPlaceholder(isDark),
                  if (showIcon && showText) const Spacer(),
                  if (showText) _buildTextPlaceholder(isDark),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildIconPlaceholder(bool isDark) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceVariantDark
            : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildTextPlaceholder(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          height: 16,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceVariantDark
                : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 60,
          height: 12,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceVariantDark.withValues(alpha: 0.5)
                : const Color(0xFFE2E8F0).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }
}

/// A skeleton placeholder for the scan CTA card with gradient.
class SkeletonScanCard extends StatelessWidget {
  const SkeletonScanCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                ]
              : [
                  const Color(0xFF3B82F6).withValues(alpha: 0.5),
                  const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.15),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Icon placeholder
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(width: 32),
            // Text placeholders
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 90,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A skeleton placeholder for the speech bubble greeting card.
class SkeletonGreetingCard extends StatelessWidget {
  const SkeletonGreetingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 140,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 85,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark.withValues(alpha: 0.6)
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? AppColors.surfaceLight.withValues(alpha: 0.1)
                  : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 24,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceVariantDark
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 70,
                height: 12,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceVariantDark.withValues(alpha: 0.5)
                      : const Color(0xFFE2E8F0).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A skeleton placeholder for the footer.
class SkeletonFooter extends StatelessWidget {
  const SkeletonFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF000000).withValues(alpha: 0.6)
              : AppColors.bentoCardWhite,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark
                ? const Color(0xFFFFFFFF).withValues(alpha: 0.1)
                : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Icon placeholder
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceVariantDark
                    : const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            // Text placeholders
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceVariantDark
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceVariantDark.withValues(alpha: 0.5)
                          : const Color(0xFFE2E8F0).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Mascot placeholder
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceVariantDark
                    : const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The complete skeleton loading screen that matches the BentoHomeScreen layout.
///
/// Shows animated placeholder cards while the app initializes,
/// providing a smoother perceived loading experience.
class BentoHomeScreenSkeleton extends StatelessWidget {
  const BentoHomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background with animated blobs
          const BentoBackground(),

          // Skeleton content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                // Scrollable skeleton content
                Expanded(
                  child: ShimmerEffect(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),

                          // Row 1: Greeting + Mascot
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Greeting placeholder (40%)
                              const Expanded(
                                flex: 5,
                                child: SkeletonGreetingCard(),
                              ),
                              const SizedBox(width: 16),
                              // Mascot placeholder (60%)
                              const Expanded(
                                flex: 5,
                                child: SkeletonCard(height: 140),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Scan CTA placeholder
                          const SkeletonScanCard(),

                          const SizedBox(height: 32),

                          // Row 2: Documents + Settings
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Documents placeholder (65%)
                              Expanded(
                                flex: 65,
                                child: SkeletonCard(
                                  height: 140,
                                  showIcon: true,
                                  showText: true,
                                ),
                              ),
                              SizedBox(width: 16),
                              // Settings placeholder (35%)
                              Expanded(
                                flex: 35,
                                child: SkeletonCard(
                                  height: 140,
                                  showIcon: true,
                                  showText: true,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),

                // Footer placeholder
                ShimmerEffect(child: const SkeletonFooter()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
