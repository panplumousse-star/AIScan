import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// View shown when OCR completed but found no text.
///
/// Features:
/// - Clear visual indication with icon
/// - Helpful explanation of the issue
/// - Optional retry action
/// - Accessible with semantic labels
/// - Centered layout for empty states
class EmptyResultView extends StatelessWidget {
  const EmptyResultView({
    super.key,
    required this.onRetry,
    required this.theme,
  });

  final VoidCallback? onRetry;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.text_snippet_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.noTextFound ?? 'No text found',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.noTextFoundDescription ?? 'The image may not contain readable text,\nor the quality may be too low.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n?.tryAgain ?? 'Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
