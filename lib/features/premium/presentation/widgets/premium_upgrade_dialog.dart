import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bento_card.dart';
import '../../../../core/widgets/bento_mascot.dart';
import '../../../../core/widgets/bento_speech_bubble.dart';
import '../../domain/iap_service.dart';
import '../../domain/premium_service.dart';

/// A dialog prompting the user to upgrade to premium.
///
/// Features:
/// - Mascot with speech bubble
/// - List of premium features with checkmarks
/// - Purchase button with price (from Google Play)
/// - Restore purchases link
/// - "Later" button to dismiss
class PremiumUpgradeDialog extends ConsumerStatefulWidget {
  const PremiumUpgradeDialog({
    super.key,
    this.feature,
  });

  /// The feature that triggered the dialog (for context-aware messaging).
  final PremiumFeature? feature;

  /// Shows the premium upgrade dialog.
  static Future<bool?> show(
    BuildContext context, {
    PremiumFeature? feature,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => PremiumUpgradeDialog(
        feature: feature,
      ),
    );
  }

  @override
  ConsumerState<PremiumUpgradeDialog> createState() =>
      _PremiumUpgradeDialogState();
}

class _PremiumUpgradeDialogState extends ConsumerState<PremiumUpgradeDialog> {
  bool _isLoading = false;
  String? _errorMessage;

  /// Returns the appropriate message for the speech bubble based on the feature.
  String _getSpeechBubbleMessage(AppLocalizations l10n) {
    switch (widget.feature) {
      case PremiumFeature.unlimitedScans:
        return l10n.premiumNoScansLeft;
      case PremiumFeature.ocr:
        return l10n.premiumOcrRequired;
      case PremiumFeature.pdfExport:
        return l10n.premiumExportRequired;
      default:
        return l10n.premiumUnlockPotential;
    }
  }

  Future<void> _handlePurchase() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final iapService = ref.read(iapServiceProvider);
      final result = await iapService.purchasePremium();

      if (!mounted) return;

      switch (result) {
        case IAPResult.success:
        case IAPResult.pending:
          // Purchase initiated, dialog will close when purchase completes
          // via the purchase stream listener
          Navigator.of(context).pop(true);
        case IAPResult.alreadyOwned:
          // User already owns premium, try to restore
          await _handleRestore();
        case IAPResult.cancelled:
          setState(() {
            _isLoading = false;
          });
        case IAPResult.notAvailable:
          setState(() {
            _isLoading = false;
            _errorMessage = 'Achats non disponibles sur cet appareil';
          });
        case IAPResult.error:
          setState(() {
            _isLoading = false;
            _errorMessage = 'Erreur lors de l\'achat. Réessayez.';
          });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: $e';
      });
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final iapService = ref.read(iapServiceProvider);
      final result = await iapService.restorePurchases();

      if (!mounted) return;

      switch (result) {
        case IAPResult.success:
        case IAPResult.pending:
          // Restore initiated, will be processed via stream
          // Show a brief message then close
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Recherche des achats précédents...'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          Navigator.of(context).pop(true);
        case IAPResult.notAvailable:
          setState(() {
            _isLoading = false;
            _errorMessage = 'Achats non disponibles';
          });
        case IAPResult.error:
        case IAPResult.cancelled:
        case IAPResult.alreadyOwned:
          setState(() {
            _isLoading = false;
            _errorMessage = 'Aucun achat trouvé';
          });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get price from IAP service (or fallback to static price)
    final priceString = ref.watch(premiumPriceProvider);

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
                    height: 90,
                    variant: BentoMascotVariant.limited,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: BentoSpeechBubble(
                    tailDirection: BubbleTailDirection.left,
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      _getSpeechBubbleMessage(l10n),
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

                  // Error message
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.errorLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Purchase button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handlePurchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.primaryLight.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Débloquer pour $priceString',
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
                    onPressed: _isLoading ? null : _handleRestore,
                    child: Text(
                      l10n.premiumRestorePurchases,
                      style: TextStyle(
                        fontSize: 14,
                        color: _isLoading
                            ? (isDark ? Colors.white30 : Colors.black26)
                            : (isDark
                                ? AppColors.primaryDark
                                : AppColors.primaryLight),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Later button
                  TextButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.of(context).pop(false),
                    child: Text(
                      l10n.premiumLater,
                      style: TextStyle(
                        fontSize: 14,
                        color: _isLoading
                            ? (isDark ? Colors.white30 : Colors.black26)
                            : (isDark ? Colors.white54 : Colors.black45),
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
