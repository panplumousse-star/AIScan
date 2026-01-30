import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/bento_speech_bubble.dart';
import '../../../../core/widgets/bento_mascot.dart';
import '../../../../core/widgets/bento_interactive_wrapper.dart';
import '../../../../l10n/app_localizations.dart';

/// A greeting row widget combining a speech bubble and mascot.
///
/// Displays a welcoming message in a speech bubble alongside the app's mascot
/// character in the settings screen. Both elements are interactive with haptic
/// feedback and consistent with the app's Bento design language.
///
/// The speech bubble shows a customizable greeting message (typically
/// "On peaufine notre application" - "We're refining our application"),
/// while the mascot provides a friendly visual element.
class SettingsGreetingRow extends StatelessWidget {
  /// Creates a [SettingsGreetingRow] with the given theme.
  const SettingsGreetingRow({
    super.key,
    required this.isDark,
  });

  /// Whether dark mode is active.
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Speech Bubble Tile
        Expanded(
          flex: 5,
          child: _buildSpeechBubbleCard(context),
        ),
        const SizedBox(width: 16),
        // Mascot Tile
        Expanded(
          flex: 5,
          child: _buildMascotCard(),
        ),
      ],
    );
  }

  /// Builds the speech bubble card with greeting text.
  Widget _buildSpeechBubbleCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BentoInteractiveWrapper(
      onTap: () {
        unawaited(HapticFeedback.lightImpact());
      },
      child: SizedBox(
        height: 100,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: 65,
            child: BentoSpeechBubble(
              tailDirection: BubbleTailDirection.right,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n?.settingsSpeechBubbleLine1 ?? 'On peaufine',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFF1E293B),
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    l10n?.settingsSpeechBubbleLine2 ?? 'notre application',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFF1E293B),
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the mascot card.
  Widget _buildMascotCard() {
    return BentoInteractiveWrapper(
      onTap: () {
        unawaited(HapticFeedback.mediumImpact());
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF000000).withValues(alpha: 0.6)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark
                ? const Color(0xFFFFFFFF).withValues(alpha: 0.1)
                : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: BentoMascot(
            height: 80,
            variant: BentoMascotVariant.settings,
          ),
        ),
      ),
    );
  }
}
