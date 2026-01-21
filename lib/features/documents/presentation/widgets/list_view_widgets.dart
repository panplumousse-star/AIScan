import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/document_model.dart';
import '../../../../core/widgets/bento_card.dart';

/// List view for documents.
class DocumentsList extends StatelessWidget {
  const DocumentsList({
    super.key,
    required this.documents,
    required this.thumbnails,
    required this.selectedIds,
    required this.isSelectionMode,
    required this.onDocumentTap,
    required this.onDocumentLongPress,
    required this.onFavoriteToggle,
    required this.onRename,
    required this.theme,
  });

  final List<Document> documents;
  final Map<String, String> thumbnails;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final void Function(Document) onDocumentTap;
  final void Function(Document) onDocumentLongPress;
  final void Function(String) onFavoriteToggle;
  final void Function(String id, String currentTitle) onRename;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final document = documents[index];
        final thumbnailPath = thumbnails[document.id];
        final isSelected = selectedIds.contains(document.id);

        return DocumentListItem(
          document: document,
          thumbnailPath: thumbnailPath,
          isSelected: isSelected,
          isSelectionMode: isSelectionMode,
          onTap: () => onDocumentTap(document),
          onLongPress: () => onDocumentLongPress(document),
          onFavoriteToggle: () => onFavoriteToggle(document.id),
          onRename: () => onRename(document.id, document.title),
          theme: theme,
        );
      },
    );
  }
}

/// Single document list item.
class DocumentListItem extends StatelessWidget {
  const DocumentListItem({
    super.key,
    required this.document,
    required this.thumbnailPath,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onFavoriteToggle,
    required this.onRename,
    required this.theme,
  });

  final Document document;
  final String? thumbnailPath;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onRename;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: BentoCard(
        padding: const EdgeInsets.all(12),
        blur: 8,
        backgroundColor: isSelected
            ? colorScheme.primary.withValues(alpha: 0.1)
            : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.7)),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Row(
          children: [
            // Selection checkbox
            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? colorScheme.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? colorScheme.primary : colorScheme.outline,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check, size: 16, color: colorScheme.onPrimary)
                      : null,
                ),
              ),

            // Thumbnail
            Container(
              width: 56,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: colorScheme.surfaceContainerHighest,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _DocumentThumbnail(
                thumbnailPath: thumbnailPath,
                theme: theme,
              ),
            ),
            const SizedBox(width: 16),

            // Title and info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        document.fileSizeFormatted,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                      if (document.pageCount > 1) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.layers_outlined,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${document.pageCount} pages',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatDate(document.createdAt),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      if (document.hasOcrText) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'OCR',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Action buttons
            if (!isSelectionMode) ...[
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 20),
                onPressed: onRename,
                color: colorScheme.onSurfaceVariant,
              ),
              IconButton(
                icon: Icon(
                  document.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 20,
                ),
                onPressed: onFavoriteToggle,
                color: document.isFavorite ? colorScheme.error : colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return "Aujourd'hui";
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jours';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Document thumbnail widget.
///
/// Uses cacheWidth/cacheHeight to limit memory usage.
/// Thumbnails are typically displayed at ~56x72px in list view.
class _DocumentThumbnail extends StatelessWidget {
  const _DocumentThumbnail({required this.thumbnailPath, required this.theme});

  final String? thumbnailPath;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (thumbnailPath != null) {
      return Image.file(
        File(thumbnailPath!),
        fit: BoxFit.cover,
        // Cache at reasonable size for list thumbnails (2x for retina)
        cacheWidth: 112,
        cacheHeight: 144,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder();
        },
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.description_outlined,
          size: 24,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
