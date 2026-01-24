import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/ocr_service.dart';

/// Shows a bottom sheet for configuring OCR options.
///
/// Returns when the sheet is dismissed.
///
/// Usage:
/// ```dart
/// await showOcrOptionsSheet(
///   context,
///   currentOptions: state.options,
///   onOptionsChanged: (options) => notifier.setOptions(options),
///   onRunOcr: () => notifier.runOcr(),
/// );
/// ```
Future<void> showOcrOptionsSheet(
  BuildContext context, {
  required OcrOptions currentOptions,
  required void Function(OcrOptions) onOptionsChanged,
  required VoidCallback onRunOcr,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) => OcrOptionsSheet(
      options: currentOptions,
      onOptionsChanged: onOptionsChanged,
      onRunOcr: onRunOcr,
    ),
  );
}

/// Bottom sheet for OCR options configuration.
///
/// Provides options for:
/// - Language selection (Latin, Chinese, Japanese, Korean, Devanagari)
/// - Document type/page segmentation mode
/// - Apply options or run OCR immediately with new settings
///
/// ## Usage
/// ```dart
/// await showModalBottomSheet(
///   context: context,
///   builder: (context) => OcrOptionsSheet(
///     options: currentOptions,
///     onOptionsChanged: (options) {
///       notifier.setOptions(options);
///       Navigator.pop(context);
///     },
///     onRunOcr: () {
///       Navigator.pop(context);
///       notifier.runOcr();
///     },
///   ),
/// );
/// ```
class OcrOptionsSheet extends StatefulWidget {
  /// Creates an [OcrOptionsSheet] with the current options.
  const OcrOptionsSheet({
    super.key,
    required this.options,
    required this.onOptionsChanged,
    required this.onRunOcr,
  });

  /// The current OCR options.
  final OcrOptions options;

  /// Callback when options are changed and applied.
  final void Function(OcrOptions) onOptionsChanged;

  /// Callback when user wants to run OCR with the new options.
  final VoidCallback onRunOcr;

  @override
  State<OcrOptionsSheet> createState() => _OcrOptionsSheetState();
}

class _OcrOptionsSheetState extends State<OcrOptionsSheet> {
  late OcrLanguage _language;
  late OcrPageSegmentationMode _pageMode;

  @override
  void initState() {
    super.initState();
    _language = widget.options.language;
    _pageMode = widget.options.pageSegmentationMode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n?.ocrOptions ?? 'OCR Options',
                  style: theme.textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Language selection
            Text(
              l10n?.language ?? 'Language',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<OcrLanguage>(
              initialValue: _language,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                OcrLanguage.latin,
                OcrLanguage.chinese,
                OcrLanguage.japanese,
                OcrLanguage.korean,
                OcrLanguage.devanagari,
              ]
                  .map((lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(lang.displayName),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _language = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Page segmentation mode
            Text(
              l10n?.documentType ?? 'Document Type',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildModeChip(
                  l10n?.auto ?? 'Auto',
                  OcrPageSegmentationMode.auto,
                  theme,
                ),
                _buildModeChip(
                  l10n?.singleColumn ?? 'Single Column',
                  OcrPageSegmentationMode.singleColumn,
                  theme,
                ),
                _buildModeChip(
                  l10n?.singleBlock ?? 'Single Block',
                  OcrPageSegmentationMode.singleBlock,
                  theme,
                ),
                _buildModeChip(
                  l10n?.sparseText ?? 'Sparse Text',
                  OcrPageSegmentationMode.sparseText,
                  theme,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final options = widget.options.copyWith(
                        language: _language,
                        pageSegmentationMode: _pageMode,
                      );
                      widget.onOptionsChanged(options);
                    },
                    child: Text(l10n?.apply ?? 'Apply'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final options = widget.options.copyWith(
                        language: _language,
                        pageSegmentationMode: _pageMode,
                      );
                      widget.onOptionsChanged(options);
                      widget.onRunOcr();
                    },
                    icon: const Icon(Icons.text_fields),
                    label: Text(l10n?.runOcr ?? 'Run OCR'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(
    String label,
    OcrPageSegmentationMode mode,
    ThemeData theme,
  ) {
    final isSelected = _pageMode == mode;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _pageMode = mode);
        }
      },
    );
  }
}
