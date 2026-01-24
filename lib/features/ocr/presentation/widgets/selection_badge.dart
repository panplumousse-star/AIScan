import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Badge showing selected word count.
///
/// Displays a floating badge indicating the number of words selected
/// in the OCR results text. Uses Material Design 3 styling with
/// primary container background and shadow for elevation.
class SelectionBadge extends StatelessWidget {
  const SelectionBadge({
    super.key,
    required this.wordCount,
    required this.theme,
  });

  final int wordCount;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.text_fields,
              size: 14,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 6),
            Text(
              l10n?.wordSelected(wordCount) ?? '$wordCount ${wordCount == 1 ? 'word selected' : 'words selected'}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
