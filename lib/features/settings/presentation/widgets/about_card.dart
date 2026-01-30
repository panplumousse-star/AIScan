import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import 'bento_flip_card.dart';

/// A Bento-style flippable card that displays app information and security details.
///
/// The front side shows the app name, version, and a "developed with love" message.
/// The back side displays security features including AES-256 encryption,
/// zero-knowledge architecture, and offline operation.
///
/// This widget uses [BentoFlipCard] to provide an interactive flip animation
/// between the front and back sides when tapped.
class AboutCard extends StatelessWidget {
  /// Creates an [AboutCard] with the given theme and context.
  const AboutCard({
    super.key,
    required this.isDark,
  });

  /// Whether dark mode is active.
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BentoFlipCard(
      isDark: isDark,
      front: _buildFrontSide(l10n),
      back: _buildBackSide(l10n),
    );
  }

  /// Builds the front side of the card with app information.
  Widget _buildFrontSide(AppLocalizations? l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF312E81)
                    : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: isDark
                    ? const Color(0xFF818CF8)
                    : const Color(0xFF6366F1),
                size: 20,
              ),
            ),
            Text(
              'v1.0.0',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l10n?.appTitle ?? 'Scanai',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E1B4B),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              l10n?.developedWith ?? 'Developpee avec le',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
            Icon(
              Icons.favorite_rounded,
              size: 12,
              color: Colors.redAccent.withValues(alpha: 0.8),
            ),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 14,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n?.securityDetails ?? 'Details securite',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  color: isDark ? Colors.white38 : Colors.black26,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the back side of the card with security features.
  Widget _buildBackSide(AppLocalizations? l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.securityTitle ?? 'Securite',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(height: 8),
        _buildSecurityFeature(
          Icons.lock_outline,
          l10n?.aes256 ?? 'AES-256',
          l10n?.localEncryption ?? 'Chiffrement local',
        ),
        const SizedBox(height: 6),
        _buildSecurityFeature(
          Icons.visibility_off_outlined,
          l10n?.zeroKnowledge ?? 'Zero-Knowledge',
          l10n?.exclusiveAccess ?? 'Acces exclusif',
        ),
        const SizedBox(height: 6),
        _buildSecurityFeature(
          Icons.cloud_off_outlined,
          l10n?.offline ?? 'Hors-ligne',
          l10n?.securedPercent ?? '100% securise',
        ),
      ],
    );
  }

  /// Builds a single security feature row with icon, title, and subtitle.
  Widget _buildSecurityFeature(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1))
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 12,
            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF1E1B4B),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 9,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
