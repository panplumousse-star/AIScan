import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Initial prompt view shown when OCR has not been run yet.
///
/// Features:
/// - Clear call-to-action to run OCR
/// - Informative description of OCR functionality
/// - Privacy reassurance about local processing
/// - Semantic labels for accessibility
/// - Theme-aware styling
class OcrPromptView extends StatelessWidget {
  const OcrPromptView({
    super.key,
    required this.canRunOcr,
    required this.onRunOcr,
    required this.theme,
  });

  final bool canRunOcr;
  final VoidCallback onRunOcr;
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
              Icons.document_scanner_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.extractTextTitle ?? 'Extract Text',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.extractTextDescription ?? 'Run OCR to extract readable text\nfrom this document.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: 'Run OCR',
              hint: 'Double tap to start text extraction',
              child: FilledButton.icon(
                onPressed: canRunOcr ? onRunOcr : null,
                icon: const Icon(Icons.text_fields),
                label: Text(l10n?.runOcr ?? 'Run OCR'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.allProcessingLocal ?? 'All processing happens locally on your device',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
