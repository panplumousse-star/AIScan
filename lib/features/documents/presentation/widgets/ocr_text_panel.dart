import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/security/clipboard_security_service.dart';
import '../../../../core/security/sensitive_data_detector.dart';
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
class OcrTextPanel extends ConsumerStatefulWidget {
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
  ConsumerState<OcrTextPanel> createState() => _OcrTextPanelState();
}

class _OcrTextPanelState extends ConsumerState<OcrTextPanel> {
  bool _isExpanded = false;

  /// Tracks if haptic feedback was already triggered for current selection.
  /// Prevents repeated vibrations while adjusting selection handles.
  bool _hasTriggeredSelectionHaptic = false;

  /// Currently selected text from the selection area.
  String? _currentSelectedText;

  /// Handles selection changes, triggering haptic feedback only when selection starts.
  void _onSelectionChanged(dynamic selectedContent) {
    final selectedText = selectedContent?.plainText as String?;
    final hasSelection = selectedText != null && selectedText.isNotEmpty;

    // Store selected text for later use
    _currentSelectedText = hasSelection ? selectedText : null;

    if (hasSelection && !_hasTriggeredSelectionHaptic) {
      // Selection just started - trigger haptic feedback once
      unawaited(HapticFeedback.selectionClick());
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
                      style: TextStyle(
                        fontFamily: 'Outfit',
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
                          // Close context menu
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            selectableRegionState.hideToolbar();
                          });

                          // Copy with security using tracked selected text
                          if (_currentSelectedText != null) {
                            _copySelectedText(_currentSelectedText!);
                          }
                        },
                      ),
                      ContextMenuButtonItem(
                        label: l10n?.share ?? 'Share',
                        onPressed: () {
                          // Close context menu
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            selectableRegionState.hideToolbar();
                          });

                          // Share the selected text
                          if (_currentSelectedText != null && _currentSelectedText!.isNotEmpty) {
                            SharePlus.instance.share(
                              ShareParams(text: _currentSelectedText!),
                            );
                          }
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
                      style: TextStyle(
                        fontFamily: 'Outfit',
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

  /// Copies all OCR text to clipboard with security features.
  Future<void> _copyText() async {
    final clipboardService = ref.read(clipboardSecurityServiceProvider);

    try {
      final result = await clipboardService.copyToClipboard(
        widget.ocrText,
        onSensitiveDataDetected: (detection) async {
          if (!context.mounted) return false;
          return await _showSensitiveDataWarning(context, detection);
        },
      );

      if (!result.success) {
        // User cancelled or error occurred
        return;
      }

      if (context.mounted) {
        // Show success message with optional auto-clear countdown
        final message = result.willAutoClear
            ? 'Text copied to clipboard. Clipboard will clear in ${result.autoClearDuration?.inSeconds ?? 0}s'
            : 'Text copied to clipboard';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on ClipboardSecurityException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy text: ${e.message}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Copies selected text to clipboard with security features.
  Future<void> _copySelectedText(String selectedText) async {
    if (selectedText.isEmpty) return;

    final clipboardService = ref.read(clipboardSecurityServiceProvider);

    try {
      final result = await clipboardService.copyToClipboard(
        selectedText,
        onSensitiveDataDetected: (detection) async {
          if (!context.mounted) return false;
          return await _showSensitiveDataWarning(context, detection);
        },
      );

      if (!result.success) {
        // User cancelled or error occurred
        return;
      }

      if (context.mounted) {
        // Show success message with optional auto-clear countdown
        final message = result.willAutoClear
            ? 'Text copied to clipboard. Clipboard will clear in ${result.autoClearDuration?.inSeconds ?? 0}s'
            : 'Text copied to clipboard';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on ClipboardSecurityException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy text: ${e.message}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Shows a warning dialog when sensitive data is detected.
  ///
  /// Returns `true` if the user chooses to copy anyway, `false` if cancelled.
  Future<bool> _showSensitiveDataWarning(
    BuildContext context,
    SensitiveDataDetectionResult detection,
  ) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final detector = ref.read(sensitiveDataDetectorProvider);

    // Get human-readable description of detected types
    final detectedDescription = detector.getSensitiveDataDescription(detection);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: theme.colorScheme.error,
          size: 48,
        ),
        title: const Text('Sensitive Data Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The text you are copying may contain sensitive information that could be accessed by other apps.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withAlpha(77),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withAlpha(77),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detected:',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detectedDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Copy Anyway'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
