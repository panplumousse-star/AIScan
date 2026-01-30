import 'package:flutter/material.dart';

import '../../../../core/widgets/bento_card.dart';
import '../../../../core/widgets/bento_interactive_wrapper.dart';

/// A Bento-style card that displays clipboard security settings.
///
/// Shows clipboard auto-clear toggle, timeout slider, and sensitive data
/// detection toggle in a visually appealing format consistent with
/// the app's design language.
class ClipboardSecurityCard extends StatelessWidget {
  /// Creates a [ClipboardSecurityCard] with the given settings and callbacks.
  const ClipboardSecurityCard({
    super.key,
    required this.clipboardSecurityEnabled,
    required this.clipboardClearTimeout,
    required this.sensitiveDataDetectionEnabled,
    required this.onClipboardSecurityChanged,
    required this.onTimeoutChanged,
    required this.onSensitiveDetectionChanged,
    required this.isDark,
  });

  /// Whether clipboard auto-clear is enabled.
  final bool clipboardSecurityEnabled;

  /// Timeout in seconds before clipboard is cleared.
  final int clipboardClearTimeout;

  /// Whether sensitive data detection is enabled.
  final bool sensitiveDataDetectionEnabled;

  /// Callback when clipboard security toggle changes.
  final ValueChanged<bool> onClipboardSecurityChanged;

  /// Callback when timeout value changes.
  final ValueChanged<int> onTimeoutChanged;

  /// Callback when sensitive data detection toggle changes.
  final ValueChanged<bool> onSensitiveDetectionChanged;

  /// Whether dark mode is active.
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(24),
      backgroundColor: isDark
          ? const Color(0xFF000000).withValues(alpha: 0.6)
          : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF065F46)
                      : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.content_paste_rounded,
                  color: isDark
                      ? const Color(0xFF10B981)
                      : const Color(0xFF059669),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Securite Presse-papiers',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF1E1B4B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Auto-clear toggle
          _buildToggleRow(
            label: 'Effacement automatique',
            subtitle: 'Efface apres copie',
            value: clipboardSecurityEnabled,
            onChanged: onClipboardSecurityChanged,
            isDark: isDark,
          ),

          if (clipboardSecurityEnabled) ...[
            const SizedBox(height: 16),
            // Timeout slider
            _buildTimeoutSlider(
              label: 'Effacer apres',
              value: clipboardClearTimeout,
              onChanged: onTimeoutChanged,
              isDark: isDark,
            ),
          ],

          const SizedBox(height: 16),

          // Sensitive data detection toggle
          _buildToggleRow(
            label: 'Detection donnees sensibles',
            subtitle: 'Alertes pour donnees sensibles',
            value: sensitiveDataDetectionEnabled,
            onChanged: onSensitiveDetectionChanged,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  /// Builds a toggle row with label, subtitle, and switch.
  Widget _buildToggleRow({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        BentoInteractiveWrapper(
          child: Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor:
                isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
          ),
        ),
      ],
    );
  }

  /// Builds a timeout slider with label and formatted value display.
  Widget _buildTimeoutSlider({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    required bool isDark,
  }) {
    // Common timeout values: 15s, 30s, 60s, 120s, 180s
    final timeoutOptions = [15, 30, 60, 120, 180];
    final currentIndex = timeoutOptions.indexOf(value);
    final sliderValue =
        currentIndex >= 0 ? currentIndex.toDouble() : 1.0; // Default to 30s

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            Text(
              _formatTimeout(value),
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor:
                isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
            inactiveTrackColor: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.2),
            thumbColor:
                isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
            overlayColor:
                (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
                    .withValues(alpha: 0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: sliderValue,
            max: (timeoutOptions.length - 1).toDouble(),
            divisions: timeoutOptions.length - 1,
            onChanged: (newValue) {
              final newTimeout = timeoutOptions[newValue.toInt()];
              onChanged(newTimeout);
            },
          ),
        ),
      ],
    );
  }

  /// Formats timeout seconds into a human-readable string.
  String _formatTimeout(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds == 60) {
      return '1 min';
    } else {
      final minutes = seconds ~/ 60;
      return '$minutes min';
    }
  }
}
