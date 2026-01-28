import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bento_card.dart';
import '../../../../core/widgets/bento_mascot.dart';
import '../../../../core/widgets/bento_speech_bubble.dart';
import '../../domain/premium_service.dart';

/// A dialog prompting the user to upgrade to premium.
///
/// Features:
/// - Mascot with speech bubble
/// - List of premium features with checkmarks
/// - Purchase button with price
/// - Restore purchases link
/// - "Later" button to dismiss
class PremiumUpgradeDialog extends ConsumerWidget {
  const PremiumUpgradeDialog({
    super.key,
    this.feature,
    this.onPurchase,
    this.onRestore,
  });

  /// The feature that triggered the dialog (for context-aware messaging).
  final PremiumFeature? feature;

  /// Callback when purchase button is pressed.
  final VoidCallback? onPurchase;

  /// Callback when restore purchases is pressed.
  final VoidCallback? onRestore;

  /// Shows the premium upgrade dialog.
  static Future<bool?> show(
    BuildContext context, {
    PremiumFeature? feature,
    VoidCallback? onPurchase,
    VoidCallback? onRestore,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => PremiumUpgradeDialog(
        feature: feature,
        onPurchase: onPurchase,
        onRestore: onRestore,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mascot with speech bubble
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const BentoLevitationWidget(
                  child: BentoMascot(
                    height: 120,
                    variant: BentoMascotVariant.limited,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: BentoSpeechBubble(
                    tailDirection: BubbleTailDirection.left,
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      l10n.premiumUnlockPotential,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Main card
            BentoCard(
              backgroundColor: isDark
                  ? AppColors.surfaceVariantDark
                  : AppColors.bentoCardWhite,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    l10n.premiumTitle,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.premiumSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Features list
                  _FeatureItem(
                    icon: Icons.all_inclusive_rounded,
                    text: l10n.premiumFeatureUnlimitedScans,
                    isDark: isDark,
                  ),
                  _FeatureItem(
                    icon: Icons.auto_stories_rounded,
                    text: l10n.premiumFeatureMultipage,
                    isDark: isDark,
                  ),
                  _FeatureItem(
                    icon: Icons.picture_as_pdf_rounded,
                    text: l10n.premiumFeaturePdfExport,
                    isDark: isDark,
                  ),
                  _FeatureItem(
                    icon: Icons.share_rounded,
                    text: l10n.premiumFeatureSharing,
                    isDark: isDark,
                  ),
                  _FeatureItem(
                    icon: Icons.text_fields_rounded,
                    text: l10n.premiumFeatureOcr,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 24),

                  // Purchase button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        onPurchase?.call();
                        Navigator.of(context).pop(true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        l10n.premiumPurchaseButton,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Restore purchases
                  TextButton(
                    onPressed: () {
                      onRestore?.call();
                    },
                    child: Text(
                      l10n.premiumRestorePurchases,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.primaryDark
                            : AppColors.primaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Later button
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      l10n.premiumLater,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white54 : Colors.black45,
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

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.text,
    required this.isDark,
  });

  final IconData icon;
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.successLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppColors.successLight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: AppColors.successLight,
          ),
        ],
      ),
    );
  }
}
