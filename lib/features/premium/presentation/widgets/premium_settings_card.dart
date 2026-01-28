import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bento_card.dart';
import '../../domain/premium_service.dart';
import '../../domain/scan_usage_service.dart';
import 'premium_upgrade_dialog.dart';

/// A settings card showing the user's premium status.
///
/// Features:
/// - Shows current premium/free status
/// - Displays remaining scans for free users
/// - Upgrade button for free users
/// - Debug toggle in debug mode
class PremiumSettingsCard extends ConsumerWidget {
  const PremiumSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPremium = ref.watch(isPremiumProvider);
    final scanUsage = ref.watch(scanUsageProvider);
    final debugPremium = ref.watch(debugPremiumProvider);

    return BentoCard(
      backgroundColor: isDark
          ? AppColors.surfaceVariantDark
          : AppColors.bentoCardWhite,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: isPremium
                      ? const LinearGradient(
                          colors: [
                            AppColors.tertiaryLight,
                            AppColors.primaryLight,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isPremium
                      ? null
                      : (isDark
                          ? AppColors.neutralDark.withValues(alpha: 0.2)
                          : AppColors.neutralLight.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPremium ? Icons.workspace_premium_rounded : Icons.star_border_rounded,
                  size: 24,
                  color: isPremium
                      ? Colors.white
                      : (isDark ? AppColors.neutralDark : AppColors.neutralLight),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPremium
                          ? l10n.premiumStatusPremium
                          : l10n.premiumStatusFree,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPremium
                          ? l10n.premiumStatusPremiumSubtitle
                          : l10n.premiumStatusFreeSubtitle(
                              scanUsage.scansRemaining,
                              scanUsage.maxFreeScans,
                            ),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.tertiaryLight,
                        AppColors.primaryLight,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PRO',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),

          // Free user section: usage stats + upgrade button
          if (!isPremium) ...[
            const SizedBox(height: 16),

            // Scans remaining progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.premiumScansRemaining,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    Text(
                      '${scanUsage.scansRemaining}/${scanUsage.maxFreeScans}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scanUsage.hasScansRemaining
                            ? (isDark ? AppColors.successDark : AppColors.successLight)
                            : (isDark ? AppColors.errorDark : AppColors.errorLight),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: scanUsage.scansRemaining / scanUsage.maxFreeScans,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    valueColor: AlwaysStoppedAnimation(
                      scanUsage.hasScansRemaining
                          ? (isDark ? AppColors.successDark : AppColors.successLight)
                          : (isDark ? AppColors.errorDark : AppColors.errorLight),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Upgrade button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  PremiumUpgradeDialog.show(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.workspace_premium_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.premiumUpgradeButton,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Debug toggle (only in debug mode)
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            Divider(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.bug_report_outlined,
                  size: 20,
                  color: isDark ? AppColors.warningDark : AppColors.warningLight,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.premiumDebugToggleTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        l10n.premiumDebugToggleSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: debugPremium,
                  onChanged: (value) {
                    ref.read(debugPremiumProvider.notifier).setEnabled(value);
                  },
                  activeTrackColor: AppColors.warningLight,
                ),
              ],
            ),

            // Reset scan usage button (debug only)
            if (!isPremium || debugPremium) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () async {
                  await ref.read(scanUsageProvider.notifier).resetUsage();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.premiumDebugResetSuccess),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: isDark ? AppColors.warningDark : AppColors.warningLight,
                ),
                label: Text(
                  l10n.premiumDebugResetScans,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.warningDark : AppColors.warningLight,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
