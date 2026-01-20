import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/bento_card.dart';
import '../../domain/document_model.dart';

/// A panel displaying document information and navigation controls.
///
/// This widget shows document metadata including file size, creation date,
/// status badges (OCR, favorite), and provides page navigation controls
/// for multi-page documents.
///
/// ## Usage
/// ```dart
/// DocumentInfoPanel(
///   document: document,
///   currentPage: 0,
///   onPageChanged: (page) => setState(() => _currentPage = page),
///   onPreviousPage: () => _navigateToPreviousPage(),
///   onNextPage: () => _navigateToNextPage(),
///   isLoading: false,
///   theme: Theme.of(context),
/// )
/// ```
class DocumentInfoPanel extends StatelessWidget {
  /// Creates a [DocumentInfoPanel].
  const DocumentInfoPanel({
    super.key,
    required this.document,
    required this.currentPage,
    required this.onPageChanged,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.isLoading,
    required this.theme,
  });

  /// The document being displayed.
  final Document document;

  /// The current page index (0-based).
  final int currentPage;

  /// Callback invoked when the page is changed.
  ///
  /// Provides the new page index as a parameter.
  final ValueChanged<int> onPageChanged;

  /// Callback invoked when navigating to the previous page.
  final VoidCallback onPreviousPage;

  /// Callback invoked when navigating to the next page.
  final VoidCallback onNextPage;

  /// Whether the document is currently loading.
  ///
  /// When true, displays a loading indicator in the page counter.
  final bool isLoading;

  /// The current theme data.
  ///
  /// Used for consistent styling across light and dark modes.
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    return BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      backgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.8),
      child: Row(
        children: [
          // Page navigation for multi-page documents
          if (document.isMultiPage) ...[
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: currentPage > 0 && !isLoading ? onPreviousPage : null,
              visualDensity: VisualDensity.compact,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                      ),
                    )
                  : Text(
                      '${currentPage + 1} / ${document.pageCount}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: currentPage < document.pageCount - 1 && !isLoading ? onNextPage : null,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
          ],

          // Size and date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  document.fileSizeFormatted,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  _formatDate(document.createdAt),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),

          // Status badges
          if (document.hasOcrText)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'OCR',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF10B981),
                ),
              ),
            ),

          if (document.isFavorite)
            const Icon(Icons.favorite_rounded, size: 18, color: Colors.redAccent),
        ],
      ),
    );
  }

  /// Formats a date into a human-readable string.
  ///
  /// Returns "Today at HH:MM" for today's dates, "Yesterday at HH:MM"
  /// for yesterday, "X days ago" for the last week, and "DD/MM/YYYY"
  /// for older dates.
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${_formatTime(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${_formatTime(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Formats a time as "HH:MM".
  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
