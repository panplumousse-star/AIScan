import 'dart:ui';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'bento_card.dart';
import 'bento_speech_bubble.dart';

/// Shows a confirmation dialog with mascot and speech bubble.
///
/// Returns true if confirmed, false or null if cancelled.
///
/// The [isDestructive] parameter changes the confirm button to error styling,
/// useful for delete/discard actions.
///
/// Usage:
/// ```dart
/// final confirmed = await showBentoConfirmationDialog(
///   context,
///   title: 'Delete folder?',
///   message: 'This action cannot be undone.',
///   confirmButtonText: 'Delete',
///   isDestructive: true,
/// );
/// if (confirmed == true) {
///   // User confirmed the action
/// }
/// ```
Future<bool?> showBentoConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmButtonText,
  String? cancelButtonText,
  bool isDestructive = false,
  String? mascotAssetPath,
  String? speechBubbleText,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => BentoConfirmationDialog(
      title: title,
      message: message,
      confirmButtonText: confirmButtonText,
      cancelButtonText: cancelButtonText,
      isDestructive: isDestructive,
      mascotAssetPath: mascotAssetPath,
      speechBubbleText: speechBubbleText,
    ),
  );
}

/// A confirmation dialog with mascot and speech bubble.
///
/// Features configurable title, message, button text, and styling.
/// The [isDestructive] flag changes the confirm button to error styling.
class BentoConfirmationDialog extends StatelessWidget {
  const BentoConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmButtonText,
    this.cancelButtonText,
    this.isDestructive = false,
    this.mascotAssetPath,
    this.speechBubbleText,
  });

  final String title;
  final String message;
  final String? confirmButtonText;
  final String? cancelButtonText;
  final bool isDestructive;
  final String? mascotAssetPath;
  final String? speechBubbleText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final effectiveMascotPath =
        mascotAssetPath ?? 'assets/images/scanai_hello.png';
    final effectiveSpeechBubbleText = speechBubbleText ?? '!!!';

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
                          effectiveMascotPath,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Text(
                                effectiveSpeechBubbleText,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
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
                      title,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              cancelButtonText ?? (l10n?.cancel ?? 'Cancel'),
                              style: TextStyle(
                                fontFamily: 'Outfit',
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
                              color: isDestructive
                                  ? Colors.red
                                  : theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.of(context).pop(true),
                                borderRadius: BorderRadius.circular(14),
                                child: Center(
                                  child: Text(
                                    confirmButtonText ?? (l10n?.ok ?? 'OK'),
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
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
