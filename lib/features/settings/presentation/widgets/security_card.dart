import 'package:flutter/material.dart';

import '../../../../core/widgets/bento_card.dart';
import '../../../../core/widgets/bento_interactive_wrapper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_lock/domain/app_lock_service.dart';

/// A Bento-style card that displays security and biometric lock settings.
///
/// Shows the current lock status (enabled/disabled), a visual indicator,
/// and a timeout dropdown when the lock is enabled. The card is tappable
/// when biometric authentication is available, triggering the onToggle callback.
class SecurityCard extends StatelessWidget {
  /// Creates a [SecurityCard] with the given security settings and theme.
  const SecurityCard({
    super.key,
    required this.enabled,
    required this.available,
    required this.timeout,
    required this.onTimeoutChanged,
    required this.onToggle,
    required this.isDark,
  });

  /// Whether biometric lock is currently enabled.
  final bool enabled;

  /// Whether biometric authentication is available on this device.
  final bool available;

  /// The current timeout setting for re-authentication.
  final AppLockTimeout timeout;

  /// Callback invoked when the timeout value changes.
  final ValueChanged<AppLockTimeout> onTimeoutChanged;

  /// Callback invoked when the card is tapped to toggle the lock.
  final VoidCallback onToggle;

  /// Whether dark mode is active.
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusColor = enabled
        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF10B981))
        : (isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444));

    final statusBg = enabled
        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
        : (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2));

    return BentoCard(
      borderRadius: 32,
      onTap: available ? onToggle : null,
      backgroundColor: isDark
          ? const Color(0xFF000000).withValues(alpha: 0.6)
          : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fingerprint_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              if (enabled)
                Icon(
                  Icons.verified_rounded,
                  color: statusColor.withValues(alpha: 0.5),
                  size: 16,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n?.security ?? 'Verrouillage',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            enabled
                ? (l10n?.enabled ?? 'Active')
                : (l10n?.disabled ?? 'Desactive'),
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          if (enabled) ...[
            const SizedBox(height: 10),
            BentoInteractiveWrapper(
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<AppLockTimeout>(
                    value: timeout,
                    isDense: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: isDark ? Colors.grey : Colors.black54),
                    dropdownColor:
                        isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFF1E1B4B),
                    ),
                    onChanged: (newValue) {
                      if (newValue != null) onTimeoutChanged(newValue);
                    },
                    items: AppLockTimeout.values.map((val) {
                      final label = switch (val) {
                        AppLockTimeout.immediate =>
                          l10n?.lockTimeoutImmediate ?? 'Immediat',
                        AppLockTimeout.oneMinute =>
                          l10n?.lockTimeout1Min ?? '1 min',
                        AppLockTimeout.fiveMinutes =>
                          l10n?.lockTimeout5Min ?? '5 min',
                        AppLockTimeout.thirtyMinutes =>
                          l10n?.lockTimeout30Min ?? '30 min',
                      };
                      return DropdownMenuItem(
                        value: val,
                        child: Text(label),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
