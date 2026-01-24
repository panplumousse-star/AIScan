import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/ocr_service.dart';
import 'metadata_item.dart';

/// Metadata bar showing OCR result statistics.
///
/// Displays a horizontal bar with:
/// - Selection mode toggle button (optional)
/// - Word count statistic
/// - Line count statistic
/// - Processing time statistic
/// - Confidence percentage (if available)
///
/// Usage:
/// ```dart
/// MetadataBar(
///   result: ocrResult,
///   theme: Theme.of(context),
///   isSelectionMode: false,
///   onSelectionModeToggle: () => toggleSelectionMode(),
/// )
/// ```
class MetadataBar extends StatelessWidget {
  const MetadataBar({
    super.key,
    required this.result,
    required this.theme,
    this.isSelectionMode = false,
    this.onSelectionModeToggle,
  });

  final OcrResult result;
  final ThemeData theme;
  final bool isSelectionMode;
  final VoidCallback? onSelectionModeToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          // Selection mode toggle button
          if (onSelectionModeToggle != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: isSelectionMode
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: onSelectionModeToggle,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelectionMode ? Icons.touch_app : Icons.touch_app_outlined,
                          size: 16,
                          color: isSelectionMode
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return Text(
                              l10n?.selection ?? 'Selection',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isSelectionMode
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: isSelectionMode ? FontWeight.w600 : null,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Stats
          Expanded(
            child: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    MetadataItem(
                      icon: Icons.text_fields,
                      label: l10n?.words ?? 'Words',
                      value: '${result.wordCount ?? 0}',
                      theme: theme,
                    ),
                    MetadataItem(
                      icon: Icons.format_line_spacing,
                      label: l10n?.lines ?? 'Lines',
                      value: '${result.lineCount ?? 0}',
                      theme: theme,
                    ),
                    MetadataItem(
                      icon: Icons.timer_outlined,
                      label: l10n?.time ?? 'Time',
                      value: result.processingTimeMs != null
                          ? '${(result.processingTimeMs! / 1000).toStringAsFixed(1)}s'
                          : 'N/A',
                      theme: theme,
                    ),
                    if (result.confidence != null)
                      MetadataItem(
                        icon: Icons.check_circle_outline,
                        label: l10n?.confidence ?? 'Confidence',
                        value: result.confidencePercent,
                        theme: theme,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
