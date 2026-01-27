import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../folders/domain/folder_model.dart';
import '../../../folders/domain/folder_service.dart';
import '../../domain/document_model.dart';
import '../documents_screen.dart'
    show DocumentsScreenState, DocumentsScreenNotifier;
import '../models/documents_ui_models.dart';
import 'folder_widgets.dart';
import 'grid_view_widgets.dart';
import 'list_view_widgets.dart';

/// Folder header widget displayed when viewing documents inside a folder.
///
/// Shows the folder name, icon with color, favorite toggle button, and edit button.
/// Provides quick actions for managing the current folder.
///
/// Usage:
/// ```dart
/// FolderHeaderWidget(
///   folder: currentFolder,
///   notifier: documentsScreenNotifier,
///   theme: Theme.of(context),
///   ref: ref,
///   onEditFolder: (folder) => _showEditFolderDialog(context, folder, notifier),
/// )
/// ```
class FolderHeaderWidget extends ConsumerWidget {
  const FolderHeaderWidget({
    super.key,
    required this.folder,
    required this.notifier,
    required this.theme,
    required this.onEditFolder,
  });

  final Folder folder;
  final DocumentsScreenNotifier notifier;
  final ThemeData theme;
  final void Function(Folder folder) onEditFolder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderColor = _parseHexColor(folder.color, theme);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: folderColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.folder_rounded,
              color: folderColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  folder.name,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Dossier actuel',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              folder.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 18,
            ),
            onPressed: () async {
              await ref.read(folderServiceProvider).toggleFavorite(folder.id);
              unawaited(notifier.loadDocuments());
            },
            style: IconButton.styleFrom(
              backgroundColor: folder.isFavorite
                  ? theme.colorScheme.error.withValues(alpha: 0.1)
                  : theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
              padding: const EdgeInsets.all(8),
              foregroundColor: folder.isFavorite
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 18),
            onPressed: () => onEditFolder(folder),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              padding: const EdgeInsets.all(8),
              foregroundColor: folderColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Helper to parse hex color strings from folder.color
  Color _parseHexColor(String? hexString, ThemeData theme) {
    if (hexString == null) {
      return theme.colorScheme.primary;
    }
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } on Object catch (_) {
      // Fallback to primary color if parsing fails
      return theme.colorScheme.primary;
    }
  }
}

/// Documents sliver list widget that displays folders and documents.
///
/// Shows folders at the root level and documents in either grid or list view.
/// Includes pull-to-refresh functionality and empty state messages.
///
/// Usage:
/// ```dart
/// DocumentsSliverList(
///   state: documentsScreenState,
///   notifier: documentsScreenNotifier,
///   theme: Theme.of(context),
///   onFolderTap: _handleFolderTap,
///   onFolderLongPress: _handleFolderLongPress,
///   onDocumentTap: _handleDocumentTap,
///   onDocumentLongPress: _handleDocumentLongPress,
///   onRename: _showRenameDialog,
///   onCreateFolder: _showCreateNewFolderDialog,
/// )
/// ```
class DocumentsSliverList extends StatelessWidget {
  const DocumentsSliverList({
    super.key,
    required this.state,
    required this.notifier,
    required this.theme,
    required this.onFolderTap,
    required this.onFolderLongPress,
    required this.onDocumentTap,
    required this.onDocumentLongPress,
    required this.onRename,
    required this.onCreateFolder,
    required this.searchController,
  });

  final DocumentsScreenState state;
  final DocumentsScreenNotifier notifier;
  final ThemeData theme;
  final void Function(Folder folder) onFolderTap;
  final void Function(Folder folder) onFolderLongPress;
  final void Function(Document document) onDocumentTap;
  final void Function(Document document) onDocumentLongPress;
  final void Function(String documentId, String currentTitle) onRename;
  final VoidCallback onCreateFolder;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: CustomScrollView(
        slivers: [
          // Folders section (only at root)
          if (state.isAtRoot &&
              (state.filteredFolders.isNotEmpty || !state.filter.favoritesOnly))
            SliverToBoxAdapter(
              child: FoldersSection(
                folders: state.filteredFolders,
                selectedFolderIds: state.selectedFolderIds,
                isSelectionMode: state.isSelectionMode,
                onFolderTap: onFolderTap,
                onFolderLongPress: onFolderLongPress,
                onCreateFolder: onCreateFolder,
                theme: theme,
              ),
            ),

          // Documents section
          if (state.filteredDocuments.isNotEmpty)
            state.viewMode == DocumentsViewMode.grid
                ? SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: DocumentsGridSliver(
                      documents: state.filteredDocuments,
                      thumbnails: state.decryptedThumbnails,
                      selectedIds: state.selectedDocumentIds,
                      isSelectionMode: state.isSelectionMode,
                      onDocumentTap: onDocumentTap,
                      onDocumentLongPress: onDocumentLongPress,
                      onFavoriteToggle: notifier.toggleFavorite,
                      onRename: onRename,
                      theme: theme,
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final doc = state.filteredDocuments[index];
                          return DocumentListItem(
                            document: doc,
                            thumbnailBytes: state.decryptedThumbnails[doc.id],
                            isSelected:
                                state.selectedDocumentIds.contains(doc.id),
                            isSelectionMode: state.isSelectionMode,
                            onTap: () => onDocumentTap(doc),
                            onLongPress: () => onDocumentLongPress(doc),
                            onFavoriteToggle: () =>
                                notifier.toggleFavorite(doc.id),
                            onRename: () => onRename(doc.id, doc.title),
                            theme: theme,
                          );
                        },
                        childCount: state.filteredDocuments.length,
                      ),
                    ),
                  ),

          // Empty filters message (when filtering returns no results)
          if (state.filteredDocuments.isEmpty &&
              state.filteredFolders.isEmpty &&
              (state.filter.hasActiveFilters || state.hasSearch))
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      state.filter.favoritesOnly
                          ? Icons.favorite_border_rounded
                          : Icons.filter_list_off,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.hasSearch
                          ? (l10n?.noResultsFor(state.searchQuery) ??
                              'No results for "${state.searchQuery}"')
                          : state.filter.favoritesOnly
                              ? (l10n?.noFavorites ?? 'No favorites')
                              : (l10n?.noDocuments ?? 'No documents'),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        if (state.hasSearch) {
                          searchController.clear();
                          notifier.clearSearch();
                        }
                        notifier.clearFilters();
                      },
                      child: Text(l10n?.clearAll ?? 'Clear filters'),
                    ),
                  ],
                ),
              ),
            ),

          // Empty folder message (inside a folder with no documents)
          if (!state.hasDocuments &&
              !state.hasFolders &&
              !state.isAtRoot &&
              !state.filter.hasActiveFilters &&
              !state.hasSearch)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ce dossier est vide',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
