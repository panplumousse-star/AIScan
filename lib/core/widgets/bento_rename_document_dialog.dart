import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'bento_card.dart';
import 'bento_speech_bubble.dart';

/// Shows a dialog for renaming a document with mascot and speech bubble.
///
/// Returns the new title if confirmed, or null if cancelled.
///
/// Usage:
/// ```dart
/// final newTitle = await showBentoRenameDocumentDialog(
///   context,
///   currentTitle: document.title,
/// );
/// if (newTitle != null) {
///   // User confirmed with new title
/// }
/// ```
Future<String?> showBentoRenameDocumentDialog(
  BuildContext context, {
  required String currentTitle,
  String? dialogTitle,
  String? hintText,
  String? confirmButtonText,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => BentoRenameDocumentDialog(
      currentTitle: currentTitle,
      dialogTitle: dialogTitle,
      hintText: hintText,
      confirmButtonText: confirmButtonText,
    ),
  );
}

/// A dialog for renaming a document with mascot and speech bubble.
class BentoRenameDocumentDialog extends StatefulWidget {
  const BentoRenameDocumentDialog({
    super.key,
    required this.currentTitle,
    this.dialogTitle,
    this.hintText,
    this.confirmButtonText,
  });

  final String currentTitle;
  final String? dialogTitle;
  final String? hintText;
  final String? confirmButtonText;

  @override
  State<BentoRenameDocumentDialog> createState() =>
      _BentoRenameDocumentDialogState();
}

class _BentoRenameDocumentDialogState extends State<BentoRenameDocumentDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      Navigator.of(context).pop(text);
    }
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              color: Colors.transparent,
              child: BentoCard(
                padding: const EdgeInsets.all(24),
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.9),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Mascot with speech bubble
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Mascot image
                        Image.asset(
                          'assets/images/scanai_rename.png',
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 8),
                        // Speech bubble
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: BentoSpeechBubble(
                              tailDirection: BubbleTailDirection.downLeft,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFEEF2FF),
                              borderColor: Colors.transparent,
                              borderWidth: 0,
                              showShadow: false,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Text(
                                'pshiit !!!',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E1B4B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.dialogTitle ?? 'Renommer le document',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: widget.hintText ?? 'Nouveau titre...',
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      style: GoogleFonts.outfit(),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _cancel,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Annuler',
                              style: GoogleFonts.outfit(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _submit,
                                borderRadius: BorderRadius.circular(14),
                                child: Center(
                                  child: Text(
                                    widget.confirmButtonText ?? 'Enregistrer',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onPrimary,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
