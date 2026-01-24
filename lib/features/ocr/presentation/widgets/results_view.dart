import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/ocr_service.dart';
import 'metadata_bar.dart';
import 'selection_badge.dart';

/// Results view widget showing extracted OCR text with selection capabilities.
///
/// Displays OCR results with:
/// - Selectable text with custom context menu
/// - Metadata bar showing word count, line count, processing time, and confidence
/// - Selection mode toggle for easier text selection
/// - Floating selection badge showing selected word count
/// - Search highlighting support
///
/// ## Features
/// - **Selection Mode**: Toggle to disable scrolling for precise text selection
/// - **Custom Context Menu**: Copy, Share, and Select All actions
/// - **Live Selection Tracking**: Shows selected word count in a floating badge
/// - **Text Highlighting**: Supports search query highlighting
///
/// ## Usage
/// ```dart
/// OcrResultsView(
///   result: ocrResult,
///   searchQuery: '',
///   theme: Theme.of(context),
///   onTextSelected: (text) => print('Selected: $text'),
///   selectedText: null,
/// )
/// ```
class OcrResultsView extends StatefulWidget {
  /// Creates an [OcrResultsView].
  const OcrResultsView({
    super.key,
    required this.result,
    required this.searchQuery,
    required this.theme,
    required this.onTextSelected,
    this.selectedText,
  });

  /// The OCR result to display.
  final OcrResult result;

  /// Search query for highlighting text (optional).
  final String searchQuery;

  /// Theme data for styling the view.
  final ThemeData theme;

  /// Callback invoked when text selection changes.
  ///
  /// Called with the selected text, or null if selection is cleared.
  final void Function(String?) onTextSelected;

  /// Currently selected text (for tracking selection state).
  final String? selectedText;

  @override
  State<OcrResultsView> createState() => _OcrResultsViewState();
}

class _OcrResultsViewState extends State<OcrResultsView> {
  bool _isSelectionMode = false;

  /// Counts words in selected text.
  int _countSelectedWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection =
        widget.selectedText != null && widget.selectedText!.isNotEmpty;
    final selectedWordCount =
        hasSelection ? _countSelectedWords(widget.selectedText!) : 0;

    return Column(
      children: [
        // Metadata bar with selection mode toggle
        MetadataBar(
          result: widget.result,
          theme: widget.theme,
          isSelectionMode: _isSelectionMode,
          onSelectionModeToggle: () {
            setState(() => _isSelectionMode = !_isSelectionMode);
            HapticFeedback.selectionClick();
          },
        ),

        // Text content with overlaid selection badge
        Expanded(
          child: Stack(
            children: [
              // Main scrollable content
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                // Disable scroll in selection mode for precise text selection
                physics: _isSelectionMode
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selection mode indicator
                    if (_isSelectionMode)
                      Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: widget.theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.touch_app,
                                  size: 16,
                                  color: widget
                                      .theme.colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n?.scrollDisabledInSelectionMode ??
                                      'Selection mode active - scroll disabled',
                                  style: widget.theme.textTheme.labelMedium
                                      ?.copyWith(
                                    color: widget
                                        .theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    // Selectable text with optional highlighting
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: widget.theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isSelectionMode
                              ? widget.theme.colorScheme.primary
                                  .withValues(alpha: 0.5)
                              : widget.theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                          width: _isSelectionMode ? 2 : 1,
                        ),
                      ),
                      child: SelectableText(
                        widget.result.trimmedText,
                        style: widget.theme.textTheme.bodyLarge?.copyWith(
                          height:
                              1.8, // Increased line height for easier selection
                          color: widget.theme.colorScheme.onSurface,
                        ),
                        contextMenuBuilder: (context, editableTextState) {
                          // Custom context menu: Copy and Select All
                          // (removes system "Read aloud" option)
                          final l10n = AppLocalizations.of(context);

                          return AdaptiveTextSelectionToolbar.buttonItems(
                            anchors: editableTextState.contextMenuAnchors,
                            buttonItems: [
                              ContextMenuButtonItem(
                                label: l10n?.copy ?? 'Copy',
                                onPressed: () {
                                  editableTextState.copySelection(
                                      SelectionChangedCause.toolbar);
                                },
                              ),
                              ContextMenuButtonItem(
                                label: l10n?.selectAll ?? 'Select all',
                                onPressed: () {
                                  editableTextState
                                      .selectAll(SelectionChangedCause.toolbar);
                                },
                              ),
                            ],
                          );
                        },
                        onSelectionChanged: (selection, cause) {
                          if (selection.isCollapsed) {
                            widget.onTextSelected(null);
                          } else {
                            final selectedText =
                                widget.result.trimmedText.substring(
                              selection.start,
                              selection.end,
                            );
                            widget.onTextSelected(selectedText);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Copy hint
                    Builder(
                      builder: (context) {
                        final l10n = AppLocalizations.of(context);
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: widget.theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isSelectionMode
                                  ? (l10n?.selectTextEasily ??
                                      'Select text easily')
                                  : (l10n?.longPressToSelect ??
                                      'Long press to select'),
                              style: widget.theme.textTheme.bodySmall?.copyWith(
                                color:
                                    widget.theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Floating selection badge (doesn't affect layout)
              if (hasSelection)
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: hasSelection ? 1.0 : 0.0,
                      child: SelectionBadge(
                        wordCount: selectedWordCount,
                        theme: widget.theme,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
