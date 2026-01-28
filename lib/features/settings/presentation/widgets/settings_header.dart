import 'package:flutter/material.dart';

import '../../../../core/widgets/bouncing_widget.dart';
import '../../../../l10n/app_localizations.dart';

/// A Bento-style header for the settings screen.
///
/// Displays a back button on the left and a centered title. The back button
/// uses a bouncing animation for interactive feedback, and the styling
/// adapts to light and dark themes.
class SettingsHeader extends StatelessWidget {
  /// Creates a [SettingsHeader] with the given theme state.
  const SettingsHeader({
    super.key,
    required this.isDark,
  });

  /// Whether dark mode is active.
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          BouncingWidget(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                color: isDark
                    ? Colors.white
                    : const Color(0xFF1E1B4B),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          const Spacer(),
          Text(
            AppLocalizations.of(context)?.settings ?? 'Reglages',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? const Color(0xFFF1F5F9)
                  : const Color(0xFF1E1B4B),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // Balance spacing
        ],
      ),
    );
  }
}
