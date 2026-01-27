import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../domain/document_model.dart';

/// Grid view for documents.
class DocumentsGrid extends StatelessWidget {
  const DocumentsGrid({
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
  final Map<String, Uint8List> thumbnails;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final void Function(Document) onDocumentTap;
  final void Function(Document) onDocumentLongPress;
  final void Function(String) onFavoriteToggle;
  final void Function(String id, String currentTitle) onRename;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final document = documents[index];
        final thumbnailBytes = thumbnails[document.id];
        final isSelected = selectedIds.contains(document.id);

        return RepaintBoundary(
          child: DocumentGridItem(
            document: document,
            thumbnailBytes: thumbnailBytes,
            isSelected: isSelected,
            isSelectionMode: isSelectionMode,
            onTap: () => onDocumentTap(document),
            onLongPress: () => onDocumentLongPress(document),
            onFavoriteToggle: () => onFavoriteToggle(document.id),
            onRename: () => onRename(document.id, document.title),
            theme: theme,
          ),
        );
      },
    );
  }
}

/// Single document grid item.
class DocumentGridItem extends StatelessWidget {
  const DocumentGridItem({
    super.key,
    required this.document,
    required this.thumbnailBytes,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onFavoriteToggle,
    required this.onRename,
    required this.theme,
  });

  final Document document;
  final Uint8List? thumbnailBytes;
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

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            // Thumbnail or placeholder
            Positioned.fill(
              child: _DocumentThumbnail(
                thumbnailBytes: thumbnailBytes,
                theme: theme,
              ),
            ),

            // Gradient overlay for text readability
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7)
                    ],
                  ),
                ),
              ),
            ),

            // Title and info
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    document.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        document.fileSizeFormatted,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      if (document.pageCount > 1) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.layers_outlined,
                          size: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${document.pageCount}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                      if (document.hasOcrText) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.text_fields,
                          size: 14,
                          color: Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Action buttons (favorite + rename)
            if (!isSelectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionButton(
                      icon: Icons.edit_outlined,
                      onPressed: onRename,
                    ),
                    const SizedBox(width: 4),
                    _FavoriteButton(
                      isFavorite: document.isFavorite,
                      onPressed: onFavoriteToggle,
                    ),
                  ],
                ),
              ),

            // Selection indicator
            if (isSelectionMode)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outline,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: colorScheme.onPrimary,
                        )
                      : null,
                ),
              ),

            // Selection highlight
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.primary, width: 3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sliver version of the documents grid.
class DocumentsGridSliver extends StatelessWidget {
  const DocumentsGridSliver({
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
  final Map<String, Uint8List> thumbnails;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final void Function(Document) onDocumentTap;
  final void Function(Document) onDocumentLongPress;
  final void Function(String) onFavoriteToggle;
  final void Function(String id, String currentTitle) onRename;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final document = documents[index];
          final thumbnailBytes = thumbnails[document.id];
          final isSelected = selectedIds.contains(document.id);

          return RepaintBoundary(
            child: DocumentGridItem(
              document: document,
              thumbnailBytes: thumbnailBytes,
              isSelected: isSelected,
              isSelectionMode: isSelectionMode,
              onTap: () => onDocumentTap(document),
              onLongPress: () => onDocumentLongPress(document),
              onFavoriteToggle: () => onFavoriteToggle(document.id),
              onRename: () => onRename(document.id, document.title),
              theme: theme,
            ),
          );
        },
        childCount: documents.length,
      ),
    );
  }
}

/// Document thumbnail widget.
///
/// Uses cacheWidth/cacheHeight to limit memory usage.
/// Thumbnails are typically displayed at ~150-200px width in grid view.
class _DocumentThumbnail extends StatelessWidget {
  const _DocumentThumbnail({required this.thumbnailBytes, required this.theme});

  final Uint8List? thumbnailBytes;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (thumbnailBytes != null) {
      return Image.memory(
        thumbnailBytes!,
        fit: BoxFit.cover,
        // Cache at reasonable size for grid thumbnails (2x for retina)
        cacheWidth: 300,
        cacheHeight: 400,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder();
        },
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.description_outlined,
          size: 32,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

/// Favorite button widget.
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.isFavorite, required this.onPressed});

  final bool isFavorite;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            size: 20,
            color: isFavorite ? Colors.red : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Generic action button widget for document cards.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
