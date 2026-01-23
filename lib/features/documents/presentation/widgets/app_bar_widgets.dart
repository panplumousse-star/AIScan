import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/bento_card.dart';
import '../../../../core/widgets/bento_mascot.dart';
import '../../../../core/widgets/bento_speech_bubble.dart';
import '../documents_screen.dart' show DocumentsScreenState, DocumentsScreenNotifier;

/// Top app bar widget for the documents screen.
///
/// Displays a back button and the screen title "Mes Documents".
/// The back button either navigates back or exits the current folder depending on navigation state.
///
/// Usage:
/// ```dart
/// DocumentsAppBar(
///   state: documentsScreenState,
///   notifier: documentsScreenNotifier,
///   theme: Theme.of(context),
/// )
/// ```
class DocumentsAppBar extends StatelessWidget {
  const DocumentsAppBar({
    super.key,
    required this.state,
    required this.notifier,
    required this.theme,
  });

  final DocumentsScreenState state;
  final DocumentsScreenNotifier notifier;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final isInFolder = !state.isAtRoot && state.currentFolder != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          // Bouton retour
          BentoBouncingWidget(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                onPressed: () {
                  if (isInFolder) {
                    notifier.exitFolder();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),
          const Spacer(),
          // Titre toujours "Mes Documents"
          Text(
            'Mes Documents',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E1B4B),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // Balance spacing
        ],
      ),
    );
  }
}

/// Bento-styled header widget for the documents screen.
///
/// Displays a speech bubble with the text "Que cherches-tu ?" alongside a mascot illustration.
/// The speech bubble includes a custom painted tail pointing toward the mascot.
///
/// Usage:
/// ```dart
/// DocumentsBentoHeader(
///   state: documentsScreenState,
///   notifier: documentsScreenNotifier,
///   theme: Theme.of(context),
/// )
/// ```
class DocumentsBentoHeader extends StatelessWidget {
  const DocumentsBentoHeader({
    super.key,
    required this.state,
    required this.notifier,
    required this.theme,
  });

  final DocumentsScreenState state;
  final DocumentsScreenNotifier notifier;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Speech Bubble (Left)
          Expanded(
            flex: 5,
            child: SizedBox(
              height: 64,
              child: BentoSpeechBubble(
                tailDirection: BubbleTailDirection.right,
                color: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                    : const Color(0xFFF1F5F9).withValues(alpha: 0.8),
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Center(
                  child: Text(
                    'Que cherches-tu ?',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Mascot Tile (Right)
          Expanded(
            flex: 5,
            child: BentoCard(
              height: 110,
              padding: const EdgeInsets.all(8),
              backgroundColor: isDark
                  ? const Color(0xFF000000).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.6),
              borderRadius: 20,
              child: const Center(
                child: BentoMascot(
                  height: 90,
                  variant: BentoMascotVariant.documents,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
