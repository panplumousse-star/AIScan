import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/premium_service.dart';

/// A badge indicating that a feature requires premium access.
///
/// Can be displayed as:
/// - Icon only (for compact spaces)
/// - Icon with text (for descriptive display)
/// - Overlay on top of disabled content
class FeatureLockedBadge extends ConsumerWidget {
  const FeatureLockedBadge({
    super.key,
    this.feature,
    this.showText = true,
    this.size = FeatureLockedBadgeSize.medium,
    this.onTap,
  });

  /// The specific feature that is locked.
  final PremiumFeature? feature;

  /// Whether to show text alongside the icon.
  final bool showText;

  /// Size variant of the badge.
  final FeatureLockedBadgeSize size;

  /// Callback when the badge is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final iconSize = switch (size) {
      FeatureLockedBadgeSize.small => 14.0,
      FeatureLockedBadgeSize.medium => 18.0,
      FeatureLockedBadgeSize.large => 24.0,
    };

    final fontSize = switch (size) {
      FeatureLockedBadgeSize.small => 10.0,
      FeatureLockedBadgeSize.medium => 12.0,
      FeatureLockedBadgeSize.large => 14.0,
    };

    final padding = switch (size) {
      FeatureLockedBadgeSize.small =>
        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      FeatureLockedBadgeSize.medium =>
        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      FeatureLockedBadgeSize.large =>
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    };

    final badgeColor = isDark
        ? AppColors.tertiaryDark.withValues(alpha: 0.2)
        : AppColors.tertiaryLight.withValues(alpha: 0.1);

    final textColor = isDark ? AppColors.tertiaryDark : AppColors.tertiaryLight;

    Widget badge = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: textColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_rounded,
            size: iconSize,
            color: textColor,
          ),
          if (showText) ...[
            SizedBox(width: size == FeatureLockedBadgeSize.small ? 4 : 6),
            Text(
              l10n.premiumBadgeLabel,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      badge = GestureDetector(
        onTap: onTap,
        child: badge,
      );
    }

    return badge;
  }
}

/// Size variants for the locked badge.
enum FeatureLockedBadgeSize {
  small,
  medium,
  large,
}

/// An overlay that covers content when a feature is locked.
///
/// Shows the locked badge and optionally dims the underlying content.
class FeatureLockedOverlay extends ConsumerWidget {
  const FeatureLockedOverlay({
    super.key,
    required this.child,
    required this.isLocked,
    this.feature,
    this.onTap,
    this.dimOpacity = 0.5,
    this.showBadge = true,
  });

  /// The content to overlay.
  final Widget child;

  /// Whether the feature is currently locked.
  final bool isLocked;

  /// The specific feature that is locked.
  final PremiumFeature? feature;

  /// Callback when the locked overlay is tapped.
  final VoidCallback? onTap;

  /// Opacity of the dimming overlay (0.0 to 1.0).
  final double dimOpacity;

  /// Whether to show the lock badge.
  final bool showBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isLocked) {
      return child;
    }

    return Stack(
      children: [
        // Dimmed content
        Opacity(
          opacity: 1.0 - dimOpacity,
          child: IgnorePointer(child: child),
        ),

        // Locked overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: showBadge
                ? Center(
                    child: FeatureLockedBadge(
                      feature: feature,
                      size: FeatureLockedBadgeSize.large,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

/// A wrapper that automatically shows/hides lock overlay based on premium status.
class PremiumGatedContent extends ConsumerWidget {
  const PremiumGatedContent({
    super.key,
    required this.child,
    required this.feature,
    this.onLockedTap,
    this.dimOpacity = 0.5,
    this.showBadge = true,
  });

  /// The content to potentially gate.
  final Widget child;

  /// The feature this content requires.
  final PremiumFeature feature;

  /// Callback when locked content is tapped.
  final VoidCallback? onLockedTap;

  /// Opacity of the dimming overlay.
  final double dimOpacity;

  /// Whether to show the lock badge.
  final bool showBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocked = !ref.watch(featureAvailableProvider(feature));

    return FeatureLockedOverlay(
      isLocked: isLocked,
      feature: feature,
      onTap: onLockedTap,
      dimOpacity: dimOpacity,
      showBadge: showBadge,
      child: child,
    );
  }
}
