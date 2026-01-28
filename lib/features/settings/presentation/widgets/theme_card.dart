import 'package:flutter/material.dart';

import '../../../../core/widgets/bento_card.dart';
import '../../../../l10n/app_localizations.dart';

/// A Bento-style card that displays theme selection options.
///
/// Shows three theme modes (Light, Dark, Auto) in a visually appealing format
/// consistent with the app's design language. Each theme option is selectable
/// with animated transitions and visual feedback.
class ThemeCard extends StatelessWidget {
  /// Creates a [ThemeCard] with the given theme settings.
  const ThemeCard({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
    required this.isDark,
    required this.localizations,
  });

  /// The currently selected theme mode.
  final ThemeMode selectedMode;

  /// Callback when theme mode is changed.
  final ValueChanged<ThemeMode> onModeChanged;

  /// Whether dark mode is active.
  final bool isDark;

  /// Localization for theme labels.
  final AppLocalizations? localizations;

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
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.palette_rounded,
                  color: isDark
                      ? const Color(0xFF818CF8)
                      : const Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                localizations?.appearance ?? 'Apparence',
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
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildThemeOption(
                mode: ThemeMode.light,
                icon: Icons.light_mode_rounded,
                label: localizations?.themeLight ?? 'Clair',
                isSelected: selectedMode == ThemeMode.light,
                onTap: () => onModeChanged(ThemeMode.light),
                isDark: isDark,
              ),
              _buildThemeOption(
                mode: ThemeMode.dark,
                icon: Icons.dark_mode_rounded,
                label: localizations?.themeDark ?? 'Sombre',
                isSelected: selectedMode == ThemeMode.dark,
                onTap: () => onModeChanged(ThemeMode.dark),
                isDark: isDark,
              ),
              _buildThemeOption(
                mode: ThemeMode.system,
                icon: Icons.settings_brightness_rounded,
                label: localizations?.themeAuto ?? 'Auto',
                isSelected: selectedMode == ThemeMode.system,
                onTap: () => onModeChanged(ThemeMode.system),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a single theme option button with selection state.
  Widget _buildThemeOption({
    required ThemeMode mode,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final selectedColor =
        isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1);
    final unselectedBg =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedColor.withValues(alpha: 0.15)
                    : unselectedBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? selectedColor : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? selectedColor
                    : (isDark ? Colors.grey : Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? selectedColor
                    : (isDark ? Colors.grey : Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
