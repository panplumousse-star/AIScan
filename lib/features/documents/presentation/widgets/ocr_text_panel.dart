import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/bento_card.dart';

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
  });

  /// The OCR text to display.
  final String ocrText;

  /// The theme to use for styling.
  final ThemeData theme;

  @override
  State<OcrTextPanel> createState() => _OcrTextPanelState();
}

class _OcrTextPanelState extends State<OcrTextPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.theme.brightness == Brightness.dark;

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
                      'Texte OCR',
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
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.ocrText,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: widget.theme.colorScheme.onSurface
                        .withValues(alpha: 0.7),
                    height: 1.5,
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
