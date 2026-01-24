import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';

/// Processing view widget showing OCR progress.
///
/// Displays a progress indicator with status messages while OCR
/// text extraction is in progress. Supports both single-page and
/// multi-page document processing with detailed progress tracking.
///
/// ## Features
/// - Circular progress indicator (indeterminate for single page, determinate for multi-page)
/// - Status text with localization support
/// - Linear progress bar for multi-page documents
/// - Percentage display for multi-page processing
///
/// ## Usage
/// ```dart
/// OcrProcessingView(
///   progress: 0.6,
///   currentPage: 3,
///   totalPages: 5,
///   theme: Theme.of(context),
/// )
/// ```
class OcrProcessingView extends StatelessWidget {
  /// Creates an [OcrProcessingView].
  const OcrProcessingView({
    super.key,
    required this.progress,
    required this.currentPage,
    required this.totalPages,
    required this.theme,
  });

  /// Current progress value between 0.0 and 1.0.
  ///
  /// For multi-page documents, this represents the overall progress
  /// across all pages. For single-page documents, this is used to
  /// show an indeterminate progress indicator.
  final double progress;

  /// Current page being processed (1-indexed).
  ///
  /// Used to display "Processing page X of Y" for multi-page documents.
  final int currentPage;

  /// Total number of pages in the document.
  ///
  /// When > 1, shows detailed progress tracking with page numbers
  /// and a linear progress bar.
  final int totalPages;

  /// Theme data for styling the view.
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: totalPages > 1 ? progress : null,
              strokeWidth: 4,
            ),
            const SizedBox(height: 24),
            Text(
              l10n?.extractingTextProgress ?? 'Extracting text...',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (totalPages > 1)
              Text(
                l10n?.processingPage(currentPage, totalPages) ?? 'Processing page $currentPage of $totalPages',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Text(
                l10n?.thisMayTakeAMoment ?? 'This may take a moment',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (totalPages > 1) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progress,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).toInt()}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
