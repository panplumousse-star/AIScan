import 'package:flutter/material.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/widgets/bento_card.dart';
import '../../../../core/widgets/bento_interactive_wrapper.dart';
import '../../../../l10n/app_localizations.dart';

/// A Bento-style card that allows users to select the application language.
///
/// Displays a dropdown menu with available language options (System, French, English)
/// and allows users to change the interface language. The card follows the app's
/// Bento design language with theme-aware styling.
class AppLanguageCard extends StatelessWidget {
  /// Creates an [AppLanguageCard] with the given parameters.
  const AppLanguageCard({
    super.key,
    required this.isDark,
    required this.currentLocale,
    required this.onLocaleChanged,
    required this.l10n,
  });

  /// Whether dark mode is active.
  final bool isDark;

  /// The currently selected locale.
  final AppLocale currentLocale;

  /// Callback invoked when the locale changes.
  final ValueChanged<AppLocale> onLocaleChanged;

  /// The localization instance for translating UI text.
  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      borderRadius: 32,
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
                      ? const Color(0xFF312E81)
                      : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.language_rounded,
                  color: isDark
                      ? const Color(0xFF818CF8)
                      : const Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n?.appLanguage ?? 'Langue',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF1E1B4B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BentoInteractiveWrapper(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AppLocale>(
                  value: currentLocale,
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: isDark ? Colors.grey : Colors.black54,
                  ),
                  dropdownColor:
                      isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF1E1B4B),
                  ),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      onLocaleChanged(newValue);
                    }
                  },
                  items: AppLocale.values.map((locale) {
                    return DropdownMenuItem(
                      value: locale,
                      child: Text(locale.displayName),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 12,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Interface',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
