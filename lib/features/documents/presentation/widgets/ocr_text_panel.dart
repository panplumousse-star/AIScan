import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/widgets/bento_card.dart';
import '../../../../l10n/app_localizations.dart';

/// An expandable panel that displays OCR text extracted from a document.
///
/// This widget provides a collapsible interface for viewing and copying
/// OCR text, with a header that shows an expand/collapse indicator and
/// a copy button.
///
/// ## Features
/// - Expandable/collapsible interface
/// - Copy to clipboard functionality
/// - Scrollable text content with max height constraint
/// - Themed appearance matching app style
///
/// ## Usage
/// ```dart
/// OcrTextPanel(
///   ocrText: document.ocrText!,
///   theme: Theme.of(context),
/// )
/// ```
class OcrTextPanel extends StatefulWidget {
  /// Creates an [OcrTextPanel].
  const OcrTextPanel({
    super.key,
    required this.ocrText,
    required this.theme,
    this.onSelectionChanged,
  });

  /// The OCR text to display.
  final String ocrText;

  /// The theme to use for styling.
  final ThemeData theme;

  /// Callback when text selection changes.
  ///
  /// Called with the selected text when user selects text,
  /// or null when selection is cleared.
  final void Function(String?)? onSelectionChanged;

  @override
  State<OcrTextPanel> createState() => _OcrTextPanelState();
}

class _OcrTextPanelState extends State<OcrTextPanel> {
  bool _isExpanded = false;

  /// Tracks if haptic feedback was already triggered for current selection.
  /// Prevents repeated vibrations while adjusting selection handles.
  bool _hasTriggeredSelectionHaptic = false;

  /// Handles selection changes, triggering haptic feedback only when selection starts.
  void _onSelectionChanged(dynamic selectedContent) {
    final selectedText = selectedContent?.plainText as String?;
    final hasSelection = selectedText != null && selectedText.isNotEmpty;

    if (hasSelection && !_hasTriggeredSelectionHaptic) {
      // Selection just started - trigger haptic feedback once
      HapticFeedback.selectionClick();
      _hasTriggeredSelectionHaptic = true;
    } else if (!hasSelection) {
      // Selection cleared - reset flag for next selection
      _hasTriggeredSelectionHaptic = false;
    }

    // Notify parent of selection change
    widget.onSelectionChanged?.call(hasSelection ? selectedText : null);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return BentoCard(
      padding: EdgeInsets.zero,
      backgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.text_snippet_rounded,
                    size: 20,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n?.ocrText ?? 'OCR Text',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_all_rounded, size: 20),
                    onPressed: _copyText,
                    visualDensity: VisualDensity.compact,
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: widget.theme.colorScheme.onSurface
                        .withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),

          // Content
          // Using SelectionArea wrapper pattern to fix scroll/selection gesture conflict.
          // SelectionArea properly handles gesture priority, allowing scrolling to work
          // while still enabling text selection via long-press.
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SelectionArea(
                onSelectionChanged: _onSelectionChanged,
                contextMenuBuilder: (context, selectableRegionState) {
                  // Custom context menu: Copy, Share, Select All
                  // (removes system "Read aloud" option)
                  return AdaptiveTextSelectionToolbar.buttonItems(
                    anchors: selectableRegionState.contextMenuAnchors,
                    buttonItems: [
                      ContextMenuButtonItem(
                        label: l10n?.copy ?? 'Copy',
                        onPressed: () {
                          selectableRegionState
                              .copySelection(SelectionChangedCause.toolbar);
                        },
                      ),
                      ContextMenuButtonItem(
                        label: l10n?.share ?? 'Share',
                        onPressed: () {
                          // Get selected text and share it
                          selectableRegionState
                              .copySelection(SelectionChangedCause.toolbar);
                          Clipboard.getData(Clipboard.kTextPlain).then((data) {
                            if (data?.text != null && data!.text!.isNotEmpty) {
                              Share.share(data.text!);
                            }
                          });
                        },
                      ),
                      ContextMenuButtonItem(
                        label: l10n?.selectAll ?? 'Select all',
                        onPressed: () {
                          selectableRegionState
                              .selectAll(SelectionChangedCause.toolbar);
                        },
                      ),
                    ],
                  );
                },
                child: SingleChildScrollView(
                  // ClampingScrollPhysics reduces interference during selection
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      widget.ocrText,
                      style: GoogleFonts.outfit(
                        fontSize: 14, // Slightly larger for easier selection
                        color: widget.theme.colorScheme.onSurface
                            .withValues(alpha: 0.7),
                        height: 1.7, // Increased line height
                      ),
                    ),
                  ),
                ),
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: widget.ocrText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
