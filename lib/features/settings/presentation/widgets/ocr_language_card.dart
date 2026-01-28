import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/ocr_language_provider.dart';
import '../../../../core/widgets/bento_card.dart';
import '../../../../core/widgets/bento_interactive_wrapper.dart';
import '../../../../l10n/app_localizations.dart';

/// A Bento-style card for selecting OCR language preference.
///
/// Displays the current OCR language and provides a dropdown menu to
/// change it. The selection is persisted and used for text recognition
/// in document scanning.
class OcrLanguageCard extends ConsumerWidget {
  /// Creates an [OcrLanguageCard] with the given theme mode.
  const OcrLanguageCard({
    super.key,
    required this.isDark,
  });

  /// Whether dark mode is active.
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentOcrLanguage = ref.watch(ocrLanguageProvider);
    final l10n = AppLocalizations.of(context);

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
                      ? const Color(0xFF1E3A5F)
                      : const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.text_fields_rounded,
                  color: isDark
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF0284C7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n?.ocrLanguage ?? 'OCR',
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
                child: DropdownButton<OcrLanguageOption>(
                  value: currentOcrLanguage,
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
                      unawaited(ref
                          .read(ocrLanguageProvider.notifier)
                          .setOcrLanguage(newValue));
                    }
                  },
                  items: OcrLanguageOption.values.map((lang) {
                    return DropdownMenuItem(
                      value: lang,
                      child: Text(
                        lang.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                  'Reconnaissance texte',
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
