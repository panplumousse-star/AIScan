import 'package:flutter/material.dart';

import '../../../../core/widgets/bento_card.dart';
import '../../../../core/widgets/bento_mascot.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/document_model.dart';

/// A bottom sheet that displays comprehensive document information.
///
/// This sheet presents document metadata in a clean, organized manner using
/// Bento-styled cards. It includes a handle for dragging, a title section,
/// and a scrollable list of information rows.
///
/// ## Usage
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (context) => DocumentInfoSheet(
///     document: document,
///     scrollController: DraggableScrollableController(),
///     theme: Theme.of(context),
///   ),
/// )
/// ```
class DocumentInfoSheet extends StatelessWidget {
  /// Creates a [DocumentInfoSheet].
  const DocumentInfoSheet({
    super.key,
    required this.document,
    required this.scrollController,
    required this.theme,
  });

  /// The document whose information is being displayed.
  final Document document;

  /// Controller for the scrollable content area.
  ///
  /// This is typically provided by a DraggableScrollableSheet
  /// to enable scroll-based sheet height adjustment.
  final ScrollController scrollController;

  /// The theme data for consistent styling.
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                const BentoLevitationWidget(
                  child: Icon(Icons.info_rounded,
                      color: Color(0xFF4F46E5), size: 28),
                ),
                const SizedBox(width: 16),
                Text(
                  'Informations Document',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                BentoInfoRow(
                    icon: Icons.title_rounded,
                    label: 'Titre',
                    value: document.title,
                    theme: theme),
                BentoInfoRow(
                  icon: Icons.straighten_rounded,
                  label: 'Taille du fichier',
                  value: document.fileSizeFormatted,
                  theme: theme,
                ),
                BentoInfoRow(
                  icon: Icons.pages_rounded,
                  label: 'Pages',
                  value: '${document.pageCount}',
                  theme: theme,
                ),
                BentoInfoRow(
                  icon: Icons.calendar_today_rounded,
                  label: l10n?.createdAt ?? 'Created',
                  value: _formatFullDate(document.createdAt),
                  theme: theme,
                ),
                BentoInfoRow(
                  icon: Icons.history_rounded,
                  label: l10n?.modifiedAt ?? 'Modified',
                  value: _formatFullDate(document.updatedAt),
                  theme: theme,
                ),
                if (document.mimeType != null)
                  BentoInfoRow(
                    icon: Icons.code_rounded,
                    label: 'Format',
                    value: document.mimeType!,
                    theme: theme,
                  ),
                BentoInfoRow(
                  icon: Icons.font_download_rounded,
                  label: 'Statut OCR',
                  value: document.ocrStatus.value.toUpperCase(),
                  theme: theme,
                ),
                if (document.folderId != null)
                  BentoInfoRow(
                    icon: Icons.folder_rounded,
                    label: 'Dossier',
                    value: document.folderId!,
                    theme: theme,
                  ),
                BentoInfoRow(
                  icon: document.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: 'Favori',
                  value: document.isFavorite ? 'Oui' : 'Non',
                  theme: theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Formats a date in a human-readable format.
  ///
  /// Returns a string like "January 15, 2024 at 14:30".
  String _formatFullDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:$minute';
  }
}

/// A Bento-styled information row displaying a labeled value with an icon.
///
/// This widget presents a single piece of information in a card format,
/// with an icon, a label, and the associated value. It follows the Bento
/// design system's visual style.
///
/// ## Usage
/// ```dart
/// BentoInfoRow(
///   icon: Icons.calendar_today_rounded,
///   label: 'Created',
///   value: 'January 15, 2024',
///   theme: Theme.of(context),
/// )
/// ```
class BentoInfoRow extends StatelessWidget {
  /// Creates a [BentoInfoRow].
  const BentoInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  /// The icon displayed on the left side of the row.
  final IconData icon;

  /// The label text describing what the value represents.
  ///
  /// Displayed in a smaller, lighter font above the value.
  final String label;

  /// The value text to display.
  ///
  /// Displayed in a larger, bolder font below the label.
  final String value;

  /// The theme data for consistent styling.
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BentoCard(
        padding: const EdgeInsets.all(16),
        backgroundColor: theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.02),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
