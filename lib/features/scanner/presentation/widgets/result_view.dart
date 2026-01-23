/// Unified result view for scan preview and post-save actions.
///
/// This widget provides a comprehensive interface for displaying scanned
/// documents, managing page selection, and guiding users through the
/// save workflow with interactive action wizards.
///
/// Features:
/// - Document preview with page navigation
/// - Animated mascot feedback and speech bubbles
/// - Multi-step action wizard (rename, folder selection, final actions)
/// - Thumbnail strip for multi-page documents
/// - Adaptive UI for pre-save and post-save states
/// - Integrated folder selection with color-coded UI
///
/// The view automatically adapts based on whether the document has been
/// saved or is still in preview mode.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/bento_card.dart';
import '../../../../core/widgets/bento_mascot.dart';
import '../../../../core/widgets/bento_speech_bubble.dart';
import '../../../documents/domain/document_model.dart';
import '../../domain/scanner_service.dart';
import 'action_wizard.dart';
import 'page_preview.dart';
import 'saved_preview.dart';

/// Unified view for scan result preview and post-save actions.
///
/// Displays a scanned document preview with mascot feedback, page navigation,
/// and an action wizard for saving and processing the document. The view
/// adapts its display based on whether the document has been saved or not.
///
/// ## Features
/// - Document preview with interactive viewing
/// - Page selection for multi-page documents
/// - Animated action wizard with step-by-step flow
/// - Document naming and folder selection
/// - Post-save actions (share, export, OCR)
///
/// ## Usage
/// ```dart
/// ResultView(
///   scanResult: scanResult,
///   savedDocument: null,
///   selectedIndex: 0,
///   onPageSelected: (index) => print('Page $index selected'),
///   onSave: (title, folderId) => saveScan(title, folderId),
///   onDelete: () => deleteScan(),
///   onShare: () => shareDocument(),
///   onExport: () => exportDocument(),
///   onOcr: () => extractText(),
///   onDone: () => finishScanning(),
/// )
/// ```
class ResultView extends ConsumerWidget {
  /// Creates a [ResultView].
  const ResultView({
    super.key,
    required this.scanResult,
    required this.savedDocument,
    required this.selectedIndex,
    required this.onPageSelected,
    required this.onSave,
    required this.onDelete,
    required this.onShare,
    required this.onExport,
    required this.onOcr,
    required this.onDone,
  });

  /// The scan result containing page data.
  ///
  /// May be null if only displaying a saved document.
  final ScanResult? scanResult;

  /// The saved document, if the scan has been saved to storage.
  ///
  /// When null, the view displays the save workflow. When not null,
  /// the view displays post-save actions.
  final Document? savedDocument;

  /// Currently selected page index for preview.
  final int selectedIndex;

  /// Callback invoked when a page is selected for preview.
  final void Function(int) onPageSelected;

  /// Callback to save the scan with a title and optional folder ID.
  final Function(String, String?) onSave;

  /// Callback to delete/discard the current scan.
  final VoidCallback onDelete;

  /// Callback to share the saved document.
  final VoidCallback onShare;

  /// Callback to export the saved document.
  final VoidCallback onExport;

  /// Callback to perform OCR on the document.
  final VoidCallback onOcr;

  /// Callback when the user completes all actions.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSaved = savedDocument != null;
    final l10n = AppLocalizations.of(context);

    final now = DateTime.now();
    final timestamp =
        'scanai_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    // We prefer the saved document for title, but fallback to a default if not yet saved
    final title = savedDocument?.title ?? timestamp;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Spacing to clear the floating header
          // Spacing to clear the system status bar
          const SizedBox(height: 60),

          // 1. Top Section: Mascot & Bubble (Simplified)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mascot Card
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF000000).withValues(alpha: 0.6)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFFFFFFFF).withValues(alpha: 0.1)
                            : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: BentoMascot(
                        height: 90,
                        variant: BentoMascotVariant.photo,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Message Bubble using BentoSpeechBubble widget
                Expanded(
                  flex: 6,
                  child: BentoSpeechBubble(
                    tailDirection: BubbleTailDirection.left,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Center(
                      child: Text(
                        isSaved
                            ? (l10n?.scanSuccessMessage ??
                                'Done, it\'s in the box!')
                            : (l10n?.savePromptMessage ?? 'Shall we save it?'),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? Colors.white : const Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Center Section: Document Preview
          Container(
            height: 310, // Reduced from 380 to save vertical space
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: BentoCard(
                padding: EdgeInsets.zero,
                borderRadius: 28,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: savedDocument != null
                      ? SavedPreview(document: savedDocument!)
                      : (scanResult != null
                          ? PagePreview(
                              imagePath:
                                  scanResult!.pages[selectedIndex].imagePath)
                          : const SizedBox()),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Page Info Text
          if (!isSaved && scanResult != null)
            Text(
              'Page ${selectedIndex + 1} sur ${scanResult!.pageCount}',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),

          const SizedBox(height: 16),

          // 3. Footer Section: Action Wizard (Multi-step)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: ActionWizard(
              initialTitle: title,
              isSaved: isSaved,
              onSave: onSave,
              onDelete: onDelete,
              onShare: onShare,
              onExport: onExport,
              onOcr: onOcr,
              onDone: onDone,
            ),
          ),
        ],
      ),
    );
  }
}
