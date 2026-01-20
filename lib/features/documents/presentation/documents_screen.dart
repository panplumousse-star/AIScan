import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/storage/document_repository.dart';
import '../../../core/services/audio_service.dart';
import '../../folders/domain/folder_model.dart';
import '../../folders/domain/folder_service.dart';
import '../../folders/presentation/widgets/bento_folder_dialog.dart';
import '../../scanner/presentation/scanner_screen.dart';
import '../../ocr/presentation/ocr_results_screen.dart';
import '../../enhancement/presentation/enhancement_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../sharing/domain/document_share_service.dart';
import '../../../core/export/document_export_service.dart';
import '../domain/document_model.dart';
import 'document_detail_screen.dart';
import 'models/documents_ui_models.dart';
import 'widgets/bento_documents_widgets.dart';
import 'widgets/filter_sheet.dart';
import '../../../core/widgets/bento_background.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../core/widgets/bento_mascot.dart';
import '../../../core/widgets/bento_rename_document_dialog.dart';
import '../../../core/widgets/bento_share_format_dialog.dart';
import '../../../core/widgets/bento_state_views.dart';

// View models have been moved to models/documents_ui_models.dart

/// State for the documents screen.
@immutable
class DocumentsScreenState {
  /// Creates a [DocumentsScreenState] with default values.
  const DocumentsScreenState({
    this.documents = const [],
    this.folders = const [],
    this.currentFolderId,
    this.currentFolder,
    this.viewMode = DocumentsViewMode.list,
    this.sortBy = DocumentsSortBy.createdDesc,
    this.filter = const DocumentsFilter(),
    this.searchQuery = '',
    this.isLoading = false,
    this.isRefreshing = false,
    this.isInitialized = false,
    this.error,
    this.selectedDocumentIds = const {},
    this.selectedFolderIds = const {},
    this.isSelectionMode = false,
    this.decryptedThumbnails = const {},
  });

  /// The list of documents to display.
  final List<Document> documents;

  /// The list of folders at the current level.
  final List<Folder> folders;

  /// The current folder ID (null for root level).
  final String? currentFolderId;

  /// The current folder object (null for root level).
  final Folder? currentFolder;

  /// Current view mode (grid or list).
  final DocumentsViewMode viewMode;

  /// Current sort option.
  final DocumentsSortBy sortBy;

  /// Current filter settings.
  final DocumentsFilter filter;

  /// Current search query (searches title and OCR text).
  final String searchQuery;

  /// Whether documents are being loaded.
  final bool isLoading;

  /// Whether documents are being refreshed.
  final bool isRefreshing;

  /// Whether the repository has been initialized.
  final bool isInitialized;

  /// Error message, if any.
  final String? error;

  /// Set of selected document IDs for multi-select mode.
  final Set<String> selectedDocumentIds;

  /// Set of selected folder IDs for multi-select mode.
  final Set<String> selectedFolderIds;

  /// Whether multi-select mode is active.
  final bool isSelectionMode;

  /// Map of document IDs to decrypted thumbnail paths.
  final Map<String, String> decryptedThumbnails;

  /// Whether we have any documents.
  bool get hasDocuments => documents.isNotEmpty;

  /// Whether we have any folders.
  bool get hasFolders => folders.isNotEmpty;

  /// Whether we're at the root level (not inside a folder).
  bool get isAtRoot => currentFolderId == null;

  /// Whether we should show folder view (folders + root documents).
  /// Returns false when searching or filtering by non-folder criteria.
  bool get shouldShowFolders =>
      isAtRoot &&
      searchQuery.isEmpty &&
      !filter.favoritesOnly &&
      !filter.hasOcrOnly &&
      filter.tagIds.isEmpty;

  /// Whether there's an active search.
  bool get hasSearch => searchQuery.isNotEmpty;

  /// Documents filtered by search query.
  List<Document> get filteredDocuments {
    if (searchQuery.isEmpty) return documents;
    final query = searchQuery.toLowerCase();
    return documents.where((doc) {
      // Search in title
      if (doc.title.toLowerCase().contains(query)) return true;
      // Search in OCR text
      if (doc.ocrText?.toLowerCase().contains(query) ?? false) return true;
      return false;
    }).toList();
  }

  /// Folders filtered by favorites and search query.
  List<Folder> get filteredFolders {
    var result = folders;

    // Apply favorites filter
    if (filter.favoritesOnly) {
      result = result.where((folder) => folder.isFavorite).toList();
    }

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result = result
          .where((folder) => folder.name.toLowerCase().contains(query))
          .toList();
    }

    return result;
  }

  /// Whether there's an error.
  bool get hasError => error != null;

  /// The count of documents.
  int get documentCount => documents.length;

  /// The count of selected documents.
  int get selectedDocumentCount => selectedDocumentIds.length;

  /// The count of selected folders.
  int get selectedFolderCount => selectedFolderIds.length;

  /// Total count of selected items (documents + folders).
  int get selectedCount =>
      selectedDocumentIds.length + selectedFolderIds.length;

  /// Whether all documents are selected.
  bool get allDocumentsSelected =>
      documents.isNotEmpty && selectedDocumentIds.length == documents.length;

  /// Whether all folders are selected.
  bool get allFoldersSelected =>
      folders.isNotEmpty && selectedFolderIds.length == folders.length;

  /// Whether all items (documents + folders) are selected.
  bool get allSelected => allDocumentsSelected && allFoldersSelected;

  /// Creates a copy with updated values.
  DocumentsScreenState copyWith({
    List<Document>? documents,
    List<Folder>? folders,
    String? currentFolderId,
    Folder? currentFolder,
    DocumentsViewMode? viewMode,
    DocumentsSortBy? sortBy,
    DocumentsFilter? filter,
    String? searchQuery,
    bool? isLoading,
    bool? isRefreshing,
    bool? isInitialized,
    String? error,
    Set<String>? selectedDocumentIds,
    Set<String>? selectedFolderIds,
    bool? isSelectionMode,
    Map<String, String>? decryptedThumbnails,
    bool clearError = false,
    bool clearSelection = false,
    bool clearCurrentFolder = false,
  }) {
    return DocumentsScreenState(
      documents: documents ?? this.documents,
      folders: folders ?? this.folders,
      currentFolderId:
          clearCurrentFolder ? null : (currentFolderId ?? this.currentFolderId),
      currentFolder:
          clearCurrentFolder ? null : (currentFolder ?? this.currentFolder),
      viewMode: viewMode ?? this.viewMode,
      sortBy: sortBy ?? this.sortBy,
      filter: filter ?? this.filter,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isInitialized: isInitialized ?? this.isInitialized,
      error: clearError ? null : (error ?? this.error),
      selectedDocumentIds: clearSelection
          ? const {}
          : (selectedDocumentIds ?? this.selectedDocumentIds),
      selectedFolderIds: clearSelection
          ? const {}
          : (selectedFolderIds ?? this.selectedFolderIds),
      isSelectionMode:
          clearSelection ? false : (isSelectionMode ?? this.isSelectionMode),
      decryptedThumbnails: decryptedThumbnails ?? this.decryptedThumbnails,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DocumentsScreenState &&
        other.viewMode == viewMode &&
        other.sortBy == sortBy &&
        other.filter == filter &&
        other.searchQuery == searchQuery &&
        other.isLoading == isLoading &&
        other.isRefreshing == isRefreshing &&
        other.isInitialized == isInitialized &&
        other.error == error &&
        other.isSelectionMode == isSelectionMode &&
        other.documentCount == documentCount;
  }

  @override
  int get hashCode => Object.hash(
        viewMode,
        sortBy,
        filter,
        searchQuery,
        isLoading,
        isRefreshing,
        isInitialized,
        error,
        isSelectionMode,
        documentCount,
      );
}

/// State notifier for the documents screen.
///
/// Manages document loading, filtering, sorting, and selection.
class DocumentsScreenNotifier extends StateNotifier<DocumentsScreenState> {
  /// Creates a [DocumentsScreenNotifier] with the given repository and folder service.
  DocumentsScreenNotifier(
    this._repository,
    this._folderService,
    this._shareService,
  ) : super(const DocumentsScreenState());

  final DocumentRepository _repository;
  final FolderService _folderService;
  final DocumentShareService _shareService;

  /// Initializes the screen and loads documents.
  Future<void> initialize() async {
    if (state.isInitialized) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _repository.initialize();
      state = state.copyWith(isInitialized: true);
      await loadDocuments();
    } on DocumentRepositoryException catch (e) {
      state = state.copyWith(
        isLoading: false,
        isInitialized: false,
        error: 'Failed to initialize: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isInitialized: false,
        error: 'Failed to initialize: $e',
      );
    }
  }

  /// Loads documents and folders from the repository.
  Future<void> loadDocuments() async {
    if (!state.isInitialized) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      List<Document> documents;
      List<Folder> folders = [];
      final filter = state.filter;

      // Load folders only when at root level and no special filters active
      final shouldLoadFolders = state.currentFolderId == null &&
          state.searchQuery.isEmpty &&
          !filter.favoritesOnly &&
          !filter.hasOcrOnly &&
          filter.tagIds.isEmpty;

      if (shouldLoadFolders) {
        // Load root folders (those with no parent)
        final allFolders = await _folderService.getAllFolders();
        folders = allFolders.roots.sortedByName();
      }

      // Load documents based on current context
      if (filter.favoritesOnly) {
        documents = await _repository.getFavoriteDocuments(includeTags: true);
        // Also load favorite folders
        final allFolders = await _folderService.getAllFolders();
        folders = allFolders.favorites.sortedByName();
      } else if (state.currentFolderId != null) {
        // Inside a folder - load folder's documents
        documents = await _repository.getDocumentsInFolder(
          state.currentFolderId,
          includeTags: true,
        );
        // Also load subfolders and refresh current folder
        final allFolders = await _folderService.getAllFolders();
        folders = allFolders.childrenOf(state.currentFolderId!).sortedByName();
        // Refresh current folder to get updated favorite status
        final refreshedFolder =
            await _folderService.getFolder(state.currentFolderId!);
        if (refreshedFolder != null) {
          state = state.copyWith(currentFolder: refreshedFolder);
        }
      } else if (filter.folderId != null) {
        documents = await _repository.getDocumentsInFolder(
          filter.folderId,
          includeTags: true,
        );
      } else {
        // At root or search/filter mode - load ALL documents
        documents = await _repository.getAllDocuments(includeTags: true);
      }

      // Apply client-side filters
      if (filter.hasOcrOnly) {
        documents = documents.where((doc) => doc.hasOcrText).toList();
      }
      if (filter.tagIds.isNotEmpty) {
        documents = documents.withAnyTag(filter.tagIds);
      }

      // Apply sorting
      documents = _sortDocuments(documents, state.sortBy);

      state = state.copyWith(
        documents: documents,
        folders: folders,
        isLoading: false,
      );

      // Load thumbnails in background
      _loadThumbnails(documents);
    } on DocumentRepositoryException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load documents: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load documents: $e',
      );
    }
  }

  /// Enters a folder to view its contents.
  Future<void> enterFolder(Folder folder) async {
    state = state.copyWith(
      currentFolderId: folder.id,
      currentFolder: folder,
      clearSelection: true,
    );
    await loadDocuments();
  }

  /// Exits the current folder and goes back to parent or root.
  Future<void> exitFolder() async {
    if (state.currentFolder?.parentId != null) {
      // Go to parent folder
      final parentFolder =
          await _folderService.getFolder(state.currentFolder!.parentId!);
      state = state.copyWith(
        currentFolderId: parentFolder?.id,
        currentFolder: parentFolder,
        clearSelection: true,
      );
    } else {
      // Go to root
      state = state.copyWith(
        clearCurrentFolder: true,
        clearSelection: true,
      );
    }
    await loadDocuments();
  }

  /// Moves a document to a different folder.
  Future<void> moveDocumentToFolder(String documentId, String? folderId) async {
    try {
      await _repository.moveToFolder(documentId, folderId);
      await loadDocuments();
    } on DocumentRepositoryException catch (e) {
      state = state.copyWith(error: 'Failed to move document: ${e.message}');
    }
  }

  /// Creates a new folder and optionally moves a document into it.
  Future<Folder?> createFolder(String name, {String? moveDocumentId}) async {
    try {
      final folder = await _folderService.createFolder(
        name: name,
        parentId: state.currentFolderId,
      );
      if (moveDocumentId != null) {
        await _repository.moveToFolder(moveDocumentId, folder.id);
      }
      await loadDocuments();
      return folder;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create folder: $e');
      return null;
    }
  }

  /// Refreshes the document list.
  Future<void> refresh() async {
    if (!state.isInitialized) return;

    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      await loadDocuments();
      state = state.copyWith(isRefreshing: false);
    } catch (_) {
      state = state.copyWith(isRefreshing: false);
    }
  }

  /// Loads decrypted thumbnails for documents.
  ///
  /// Only loads first batch of thumbnails to reduce initial memory usage.
  /// Additional thumbnails are loaded as needed (lazy loading).
  Future<void> _loadThumbnails(List<Document> documents) async {
    // Limit initial thumbnail load to reduce memory spike
    const maxInitialLoad = 12; // ~2 rows of grid
    final documentsToLoad = documents.take(maxInitialLoad).toList();

    for (final document in documentsToLoad) {
      if (!mounted) return; // Early exit if widget disposed
      if (document.thumbnailPath != null &&
          !state.decryptedThumbnails.containsKey(document.id)) {
        try {
          final decryptedPath = await _repository.getDecryptedThumbnailPath(
            document,
          );
          if (decryptedPath != null && mounted) {
            state = state.copyWith(
              decryptedThumbnails: {
                ...state.decryptedThumbnails,
                document.id: decryptedPath,
              },
            );
          }
        } catch (_) {
          // Ignore thumbnail loading errors
        }
      }
    }
  }

  /// Loads a single document's thumbnail on demand.
  ///
  /// Called when a document card becomes visible but its thumbnail isn't loaded.
  Future<void> loadThumbnailForDocument(Document document) async {
    if (document.thumbnailPath == null) return;
    if (state.decryptedThumbnails.containsKey(document.id)) return;

    try {
      final decryptedPath = await _repository.getDecryptedThumbnailPath(
        document,
      );
      if (decryptedPath != null && mounted) {
        state = state.copyWith(
          decryptedThumbnails: {
            ...state.decryptedThumbnails,
            document.id: decryptedPath,
          },
        );
      }
    } catch (_) {
      // Ignore thumbnail loading errors
    }
  }

  /// Sorts documents based on the sort option.
  List<Document> _sortDocuments(
    List<Document> documents,
    DocumentsSortBy sortBy,
  ) {
    switch (sortBy) {
      case DocumentsSortBy.createdDesc:
        return documents.sortedByCreatedDesc();
      case DocumentsSortBy.createdAsc:
        return documents.sortedByCreatedAsc();
      case DocumentsSortBy.title:
        return documents.sortedByTitle();
      case DocumentsSortBy.size:
        return documents.sortedBySize();
      case DocumentsSortBy.updatedDesc:
        return documents.sortedByUpdatedDesc();
    }
  }

  /// Sets the view mode.
  void setViewMode(DocumentsViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  /// Toggles between grid and list view.
  void toggleViewMode() {
    final newMode = state.viewMode == DocumentsViewMode.grid
        ? DocumentsViewMode.list
        : DocumentsViewMode.grid;
    setViewMode(newMode);
  }

  /// Sets the sort option.
  void setSortBy(DocumentsSortBy sortBy) {
    if (sortBy == state.sortBy) return;

    final sortedDocuments = _sortDocuments(state.documents, sortBy);
    state = state.copyWith(sortBy: sortBy, documents: sortedDocuments);
  }

  /// Sets the filter.
  void setFilter(DocumentsFilter filter) {
    if (filter == state.filter) return;
    state = state.copyWith(filter: filter);
    loadDocuments();
  }

  /// Sets the search query.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Clears the search query.
  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }

  /// Clears all filters.
  void clearFilters() {
    setFilter(const DocumentsFilter());
  }

  /// Toggles favorites-only filter.
  void toggleFavoritesFilter() {
    setFilter(
      state.filter.copyWith(favoritesOnly: !state.filter.favoritesOnly),
    );
  }

  /// Enters multi-select mode.
  void enterSelectionMode() {
    state = state.copyWith(isSelectionMode: true);
  }

  /// Exits multi-select mode.
  void exitSelectionMode() {
    state = state.copyWith(clearSelection: true);
  }

  /// Toggles selection of a document.
  /// Clears folder selection when selecting documents (mutually exclusive).
  void toggleDocumentSelection(String documentId) {
    final selected = Set<String>.from(state.selectedDocumentIds);
    if (selected.contains(documentId)) {
      selected.remove(documentId);
    } else {
      selected.add(documentId);
    }

    state = state.copyWith(
      selectedDocumentIds: selected,
      selectedFolderIds: {}, // Clear folder selection
      isSelectionMode: selected.isNotEmpty,
    );
  }

  /// Selects all documents.
  /// Clears folder selection (mutually exclusive).
  void selectAll() {
    state = state.copyWith(
      selectedDocumentIds: state.documents.map((d) => d.id).toSet(),
      selectedFolderIds: {}, // Clear folder selection
      isSelectionMode: true,
    );
  }

  /// Clears selection.
  void clearSelection() {
    state = state.copyWith(clearSelection: true);
  }

  /// Deletes selected documents.
  Future<void> deleteSelected() async {
    if (state.selectedDocumentIds.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _repository.deleteDocuments(state.selectedDocumentIds.toList());
      state = state.copyWith(clearSelection: true);
      await loadDocuments();
    } on DocumentRepositoryException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete documents: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete documents: $e',
      );
    }
  }

  /// Moves selected documents to a folder.
  ///
  /// Returns the number of documents successfully moved.
  Future<int> moveSelectedToFolder(String? folderId) async {
    if (state.selectedDocumentIds.isEmpty) return 0;

    state = state.copyWith(isLoading: true, clearError: true);
    int movedCount = 0;

    try {
      for (final documentId in state.selectedDocumentIds) {
        await _repository.moveToFolder(documentId, folderId);
        movedCount++;
      }
      state = state.copyWith(clearSelection: true);
      await loadDocuments();
      return movedCount;
    } on DocumentRepositoryException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to move documents: ${e.message}',
      );
      return movedCount;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to move documents: $e',
      );
      return movedCount;
    }
  }

  /// Toggles favorite status of a document.
  Future<void> toggleFavorite(String documentId) async {
    try {
      await _repository.toggleFavorite(documentId);
      await loadDocuments();
    } on DocumentRepositoryException catch (e) {
      state = state.copyWith(error: 'Failed to update favorite: ${e.message}');
    } catch (e) {
      state = state.copyWith(error: 'Failed to update favorite: $e');
    }
  }

  /// Renames a document.
  Future<void> renameDocument(String documentId, String newTitle) async {
    try {
      final document = await _repository.getDocument(documentId);
      if (document == null) {
        state = state.copyWith(error: 'Document not found');
        return;
      }
      await _repository.updateDocument(document.copyWith(title: newTitle));
      await loadDocuments();
    } on DocumentRepositoryException catch (e) {
      state = state.copyWith(error: 'Failed to rename document: ${e.message}');
    } catch (e) {
      state = state.copyWith(error: 'Failed to rename document: $e');
    }
  }

  /// Toggles favorite status for all selected documents.
  Future<void> toggleFavoriteSelected() async {
    if (state.selectedDocumentIds.isEmpty && state.selectedFolderIds.isEmpty)
      return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Toggle favorites for selected documents
      for (final id in state.selectedDocumentIds) {
        await _repository.toggleFavorite(id);
      }
      // Toggle favorites for selected folders
      for (final id in state.selectedFolderIds) {
        await _folderService.toggleFavorite(id);
      }
      state = state.copyWith(clearSelection: true);
      await loadDocuments();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Échec de la mise à jour des favoris : $e',
      );
    }
  }

  /// Shares all selected documents.
  Future<void> shareSelected() async {
    if (state.selectedDocumentIds.isEmpty) return;

    try {
      final documents = <Document>[];
      for (final id in state.selectedDocumentIds) {
        final doc = await _repository.getDocument(id);
        if (doc != null) documents.add(doc);
      }

      if (documents.isNotEmpty) {
        await _shareService.shareDocuments(documents);
      }
    } catch (e) {
      state = state.copyWith(error: 'Échec du partage : $e');
    }
  }

  // ============================================================
  // Folder Selection and Management Methods
  // ============================================================

  /// Toggles selection of a folder.
  /// Clears document selection when selecting folders (mutually exclusive).
  void toggleFolderSelection(String folderId) {
    final selected = Set<String>.from(state.selectedFolderIds);
    if (selected.contains(folderId)) {
      selected.remove(folderId);
    } else {
      selected.add(folderId);
    }

    state = state.copyWith(
      selectedFolderIds: selected,
      selectedDocumentIds: {}, // Clear document selection
      isSelectionMode: selected.isNotEmpty,
    );
  }

  /// Selects all folders.
  /// Clears document selection (mutually exclusive).
  void selectAllFolders() {
    state = state.copyWith(
      selectedFolderIds: state.folders.map((f) => f.id).toSet(),
      selectedDocumentIds: {}, // Clear document selection
      isSelectionMode: true,
    );
  }

  /// Selects all items (documents only since selection is mutually exclusive).
  void selectAllItems() {
    state = state.copyWith(
      selectedDocumentIds: state.documents.map((d) => d.id).toSet(),
      selectedFolderIds: {},
      isSelectionMode: true,
    );
  }

  /// Deletes selected folders.
  Future<void> deleteSelectedFolders() async {
    if (state.selectedFolderIds.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _folderService.deleteFolders(state.selectedFolderIds.toList());
      state = state.copyWith(
        selectedFolderIds: const {},
        isSelectionMode: state.selectedDocumentIds.isNotEmpty,
      );
      await loadDocuments();
    } on FolderServiceException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete folders: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete folders: $e',
      );
    }
  }

  /// Deletes all selected items (documents and folders).
  /// Documents in deleted folders are moved to root level.
  Future<void> deleteAllSelected() async {
    if (state.selectedDocumentIds.isEmpty && state.selectedFolderIds.isEmpty)
      return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Delete folders first (documents inside become root-level)
      if (state.selectedFolderIds.isNotEmpty) {
        await _folderService.deleteFolders(state.selectedFolderIds.toList());
      }
      // Then delete selected documents
      if (state.selectedDocumentIds.isNotEmpty) {
        await _repository.deleteDocuments(state.selectedDocumentIds.toList());
      }
      state = state.copyWith(clearSelection: true);
      await loadDocuments();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete selected items: $e',
      );
    }
  }

  /// Deletes all selected folders AND documents inside them.
  Future<void> deleteAllSelectedWithDocuments() async {
    if (state.selectedDocumentIds.isEmpty && state.selectedFolderIds.isEmpty)
      return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Collect all document IDs from folders being deleted
      final documentIdsToDelete = <String>{...state.selectedDocumentIds};
      for (final folderId in state.selectedFolderIds) {
        final docsInFolder = await _repository.getDocumentsInFolder(folderId);
        for (final doc in docsInFolder) {
          documentIdsToDelete.add(doc.id);
        }
      }

      // Delete folders first
      if (state.selectedFolderIds.isNotEmpty) {
        await _folderService.deleteFolders(state.selectedFolderIds.toList());
      }

      // Then delete all documents (including those that were in folders)
      if (documentIdsToDelete.isNotEmpty) {
        await _repository.deleteDocuments(documentIdsToDelete.toList());
      }

      state = state.copyWith(clearSelection: true);
      await loadDocuments();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete selected items: $e',
      );
    }
  }

  /// Updates a folder (name, color, icon).
  Future<void> updateFolder({
    required String folderId,
    String? name,
    String? color,
    String? icon,
    bool clearColor = false,
    bool clearIcon = false,
  }) async {
    try {
      // Find the folder - it might be the current folder or in the folders list
      Folder folder;
      if (state.currentFolderId == folderId && state.currentFolder != null) {
        folder = state.currentFolder!;
      } else {
        try {
          folder = state.folders.firstWhere((f) => f.id == folderId);
        } catch (_) {
          throw StateError('Folder not found');
        }
      }

      final updatedFolder = folder.copyWith(
        name: name ?? folder.name,
        color: color,
        clearColor: clearColor,
        icon: icon,
        clearIcon: clearIcon,
        updatedAt: DateTime.now(),
      );
      await _folderService.updateFolder(updatedFolder);
      await loadDocuments();
    } on FolderServiceException catch (e) {
      state = state.copyWith(error: 'Failed to update folder: ${e.message}');
    } catch (e) {
      state = state.copyWith(error: 'Failed to update folder: $e');
    }
  }

  /// Clears the current error.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Cleans up decrypted thumbnails.
  Future<void> cleanupThumbnails() async {
    for (final path in state.decryptedThumbnails.values) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Ignore cleanup errors
      }
    }
  }

  @override
  void dispose() {
    cleanupThumbnails();
    super.dispose();
  }
}

/// Riverpod provider for the documents screen state.
final documentsScreenProvider = StateNotifierProvider.autoDispose<
    DocumentsScreenNotifier, DocumentsScreenState>((ref) {
  final repository = ref.watch(documentRepositoryProvider);
  final folderService = ref.watch(folderServiceProvider);
  final shareService = ref.watch(documentShareServiceProvider);
  return DocumentsScreenNotifier(repository, folderService, shareService);
});

/// Main documents library screen.
///
/// Displays all scanned documents with:
/// - Grid and list view toggle
/// - Sorting options (date, title, size)
/// - Filtering options (favorites, OCR, tags, folder)
/// - Multi-select for batch operations
/// - Pull-to-refresh
/// - Quick scan FAB for one-click scanning
///
/// ## Usage
/// ```dart
/// // Navigate to documents screen
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => const DocumentsScreen()),
/// );
///
/// // With document selection callback
/// DocumentsScreen(
///   onDocumentSelected: (document) {
///     // Navigate to document detail
///   },
/// )
/// ```
class DocumentsScreen extends ConsumerStatefulWidget {
  /// Creates a [DocumentsScreen].
  const DocumentsScreen({
    super.key,
    this.onDocumentSelected,
    this.onScanPressed,
    this.initialFolderId,
  });

  /// Callback invoked when a document is tapped.
  final void Function(Document document)? onDocumentSelected;

  /// Callback invoked when the scan button is pressed.
  final VoidCallback? onScanPressed;

  /// Initial folder to filter by.
  final String? initialFolderId;

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // Initialize after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    final notifier = ref.read(documentsScreenProvider.notifier);
    final wasInitialized = ref.read(documentsScreenProvider).isInitialized;

    // Set initial folder filter if provided
    if (widget.initialFolderId != null) {
      notifier.setFilter(DocumentsFilter(folderId: widget.initialFolderId));
    }

    // Initialize if not already done
    await notifier.initialize();

    // If already initialized, force reload to catch any new data (e.g., after saving a new document)
    if (wasInitialized) {
      await notifier.loadDocuments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentsScreenProvider);
    final notifier = ref.read(documentsScreenProvider.notifier);
    final theme = Theme.of(context);

    // Listen for errors and show snackbar
    ref.listen<DocumentsScreenState>(documentsScreenProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: notifier.clearError,
            ),
          ),
        );
      }
    });

    return GestureDetector(
      onTap: () => _searchFocusNode.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _buildBody(context, state, notifier, theme),
        floatingActionButton: _buildFab(context, state),
      ),
    );
  }

  Widget _buildTopAppBar(
    BuildContext context,
    DocumentsScreenState state,
    DocumentsScreenNotifier notifier,
    ThemeData theme,
  ) {
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

  Widget _buildBentoHeader(
    BuildContext context,
    DocumentsScreenState state,
    DocumentsScreenNotifier notifier,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Speech Bubble (Left)
          Expanded(
            flex: 5,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                BentoCard(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                      : const Color(0xFFF1F5F9).withValues(alpha: 0.8),
                  borderRadius: 20,
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
                // The Bubble Tail (Pointing Right to Mascot)
                Positioned(
                  right: -9,
                  top: 12,
                  child: CustomPaint(
                    size: const Size(12, 16),
                    painter: _BubbleTailPainter(
                      color: isDark
                          ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                          : const Color(0xFFF1F5F9).withValues(alpha: 0.8),
                      borderColor: isDark
                          ? const Color(0xFFFFFFFF).withValues(alpha: 0.1)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              ],
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

  /// Builds the folder header card when inside a folder.
  Widget _buildFolderHeader(
    BuildContext context,
    Folder folder,
    DocumentsScreenNotifier notifier,
    ThemeData theme,
  ) {
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
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Dossier actuel',
                  style: GoogleFonts.outfit(
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
              notifier.loadDocuments();
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
            onPressed: () => _showEditFolderDialog(context, folder, notifier),
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

  Widget _buildBody(
    BuildContext context,
    DocumentsScreenState state,
    DocumentsScreenNotifier notifier,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    // Show loading while initializing (before first load completes)
    if (!state.isInitialized) {
      return const BentoLoadingView(
        message: 'Chargement de vos documents...',
      );
    }

    if (state.hasError && !state.hasDocuments) {
      return BentoErrorView(
        message: state.error!,
        onRetry: notifier.initialize,
      );
    }

    // If no documents and no folders at root, and not loading, and no active filters, go back
    // (shouldn't happen since we check before showing button)
    // Don't pop when filters are active - show empty state instead
    if (!state.hasDocuments &&
        !state.hasFolders &&
        !state.isLoading &&
        state.isAtRoot &&
        !state.filter.hasActiveFilters) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const BentoLoadingView();
    }

    // Still loading documents
    if (state.isLoading && !state.hasDocuments && !state.hasFolders) {
      return const BentoLoadingView(
        message: 'Chargement de vos documents...',
      );
    }

    return Stack(
      children: [
        const BentoBackground(),
        GestureDetector(
          onTap: () {
            if (state.isSelectionMode) {
              notifier.clearSelection();
            }
          },
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: Column(
              children: [
                _buildTopAppBar(context, state, notifier, theme),
                _buildBentoHeader(context, state, notifier, theme),
                // Integrated Search Bar with Controls & Selection Flip
                SizedBox(
                  height: 72,
                  child: BentoSearchBar(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: notifier.setSearchQuery,
                    onClear: () {
                      _searchController.clear();
                      notifier.clearSearch();
                    },
                    hasText: state.hasSearch,
                    onToggleViewMode: notifier.toggleViewMode,
                    onShowFilters: () =>
                        _showFilterSheet(context, state, notifier),
                    onToggleFavorites: () => notifier.setFilter(
                      state.filter
                          .copyWith(favoritesOnly: !state.filter.favoritesOnly),
                    ),
                    viewMode: state.viewMode,
                    isFavoritesOnly: state.filter.favoritesOnly,
                    hasActiveFilters: state.filter.hasActiveFilters,
                    // Selection
                    isSelectionMode: state.isSelectionMode,
                    selectedCount: state.selectedCount,
                    selectedDocumentCount: state.selectedDocumentCount,
                    selectedFolderCount: state.selectedFolderCount,
                    hasDocumentsSelected: state.selectedDocumentCount > 0,
                    onDeleteSelected: () =>
                        _showDeleteConfirmation(context, state, notifier),
                    onFavoriteSelected: notifier.toggleFavoriteSelected,
                    onShareSelected: () => _handleShareSelected(context, state),
                    onExportSelected: () =>
                        _handleExportSelected(context, state),
                    onMoveSelected: () => _showMoveSelectedToFolderDialog(
                        context, state, notifier),
                  ),
                ),
                // Active filters indicator
                if (state.filter.hasActiveFilters ||
                    state.sortBy != DocumentsSortBy.createdDesc)
                  _ActiveFiltersBar(
                    filter: state.filter,
                    sortBy: state.sortBy,
                    onClearAll: notifier.clearFilters,
                    onClearSort: () =>
                        notifier.setSortBy(DocumentsSortBy.createdDesc),
                    onClearFavorites: () => notifier
                        .setFilter(state.filter.copyWith(favoritesOnly: false)),
                    onClearOcr: () => notifier
                        .setFilter(state.filter.copyWith(hasOcrOnly: false)),
                    onClearFolder: () => notifier
                        .setFilter(state.filter.copyWith(clearFolderId: true)),
                    onClearTags: () => notifier
                        .setFilter(state.filter.copyWith(clearTags: true)),
                  ),

                // Folder View vs Root View
                Expanded(
                  child: !state.isAtRoot && state.currentFolder != null
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: BentoCard(
                            padding: EdgeInsets.zero,
                            backgroundColor: theme.brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.white.withValues(alpha: 0.7),
                            child: Column(
                              children: [
                                _buildFolderHeader(context,
                                    state.currentFolder!, notifier, theme),
                                const Divider(height: 1),
                                Expanded(
                                  child: _buildDocumentsSliverList(
                                      context, state, notifier, theme),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildDocumentsSliverList(
                          context, state, notifier, theme),
                ),
              ],
            ),
          ), // End SafeArea
        ), // End GestureDetector
      ],
    );
  }

  /// Helper to build the documents list/grid section, which can be reused
  Widget _buildDocumentsSliverList(
    BuildContext context,
    DocumentsScreenState state,
    DocumentsScreenNotifier notifier,
    ThemeData theme,
  ) {
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: CustomScrollView(
        slivers: [
          // Folders section (only at root)
          if (state.isAtRoot &&
              (state.filteredFolders.isNotEmpty || !state.filter.favoritesOnly))
            SliverToBoxAdapter(
              child: _FoldersSection(
                folders: state.filteredFolders,
                selectedFolderIds: state.selectedFolderIds,
                isSelectionMode: state.isSelectionMode,
                onFolderTap: (folder) =>
                    _handleFolderTap(folder, state, notifier),
                onFolderLongPress: (folder) =>
                    _handleFolderLongPress(folder, notifier),
                onCreateFolder: () =>
                    _showCreateNewFolderDialog(context, notifier),
                theme: theme,
              ),
            ),

          // Documents section
          if (state.filteredDocuments.isNotEmpty)
            state.viewMode == DocumentsViewMode.grid
                ? SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: _DocumentsGridSliver(
                      documents: state.filteredDocuments,
                      thumbnails: state.decryptedThumbnails,
                      selectedIds: state.selectedDocumentIds,
                      isSelectionMode: state.isSelectionMode,
                      onDocumentTap: (doc) =>
                          _handleDocumentTap(doc, state, notifier),
                      onDocumentLongPress: (doc) =>
                          _handleDocumentLongPress(doc, notifier),
                      onFavoriteToggle: notifier.toggleFavorite,
                      onRename: (id, title) =>
                          _showRenameDialog(context, id, title, notifier),
                      theme: theme,
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final doc = state.filteredDocuments[index];
                          return _DocumentListItem(
                            document: doc,
                            thumbnailPath: state.decryptedThumbnails[doc.id],
                            isSelected:
                                state.selectedDocumentIds.contains(doc.id),
                            isSelectionMode: state.isSelectionMode,
                            onTap: () =>
                                _handleDocumentTap(doc, state, notifier),
                            onLongPress: () =>
                                _handleDocumentLongPress(doc, notifier),
                            onFavoriteToggle: () =>
                                notifier.toggleFavorite(doc.id),
                            onRename: () => _showRenameDialog(
                                context, doc.id, doc.title, notifier),
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
                          ? 'Aucun résultat pour "${state.searchQuery}"'
                          : state.filter.favoritesOnly
                              ? 'Aucun favori'
                              : 'Aucun document correspondant',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        if (state.hasSearch) {
                          _searchController.clear();
                          notifier.clearSearch();
                        }
                        notifier.clearFilters();
                      },
                      child: const Text('Effacer les filtres'),
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
                      style: GoogleFonts.outfit(
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

  Widget? _buildFab(BuildContext context, DocumentsScreenState state) {
    if (state.isSelectionMode) return null;

    return BentoScanFab(
      onPressed: widget.onScanPressed ?? () => _navigateToScanner(context),
    );
  }

  void _navigateToScanner(BuildContext context) {
    HapticFeedback.lightImpact();
    ref.read(audioServiceProvider).playScanLaunch();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        opaque: true,
        barrierColor: isDark ? Colors.black : Colors.white,
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ScannerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return ColoredBox(
            color: isDark ? Colors.black : Colors.white,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _handleDocumentTap(
    Document document,
    DocumentsScreenState state,
    DocumentsScreenNotifier notifier,
  ) {
    if (state.isSelectionMode) {
      notifier.toggleDocumentSelection(document.id);
    } else if (widget.onDocumentSelected != null) {
      widget.onDocumentSelected?.call(document);
    } else {
      // Default navigation to document detail screen
      _navigateToDocumentDetail(context, document);
    }
  }

  void _navigateToDocumentDetail(BuildContext context, Document document) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (navContext) => DocumentDetailScreen(
          document: document,
          onDelete: () {
            Navigator.of(navContext).pop();
            // Refresh the documents list
            ref.read(documentsScreenProvider.notifier).loadDocuments();
          },
          onExport: (doc, imageBytes) async {
            final exportService = ref.read(documentExportServiceProvider);
            try {
              final result = await exportService.exportDocument(doc);
              if (!navContext.mounted) return;
              if (result.isSuccess) {
                ScaffoldMessenger.of(navContext).showSnackBar(
                  const SnackBar(content: Text('Document exporté')),
                );
              } else if (result.isFailed) {
                ScaffoldMessenger.of(navContext).showSnackBar(
                  SnackBar(
                      content: Text(
                          result.errorMessage ?? 'Échec de l\'exportation')),
                );
              }
            } on DocumentExportException catch (e) {
              if (navContext.mounted) {
                ScaffoldMessenger.of(navContext).showSnackBar(
                  SnackBar(content: Text(e.message)),
                );
              }
            }
          },
          onOcr: (doc, imageBytes) =>
              _navigateToOcr(navContext, doc, imageBytes),
          onEnhance: (doc, imageBytes) =>
              _navigateToEnhancement(navContext, doc, imageBytes),
        ),
      ),
    )
        .then((_) {
      // Refresh documents when returning from detail screen
      if (mounted) {
        ref.read(documentsScreenProvider.notifier).loadDocuments();
      }
    });
  }

  void _navigateToOcr(
      BuildContext context, Document document, Uint8List imageBytes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OcrResultsScreen(
          document: document,
          imageBytes: imageBytes,
          autoRunOcr: true,
          onOcrComplete: (result) async {
            // Save OCR text to the document
            if (result.hasText) {
              try {
                final repository = ref.read(documentRepositoryProvider);
                await repository.updateDocumentOcr(
                  document.id,
                  result.text,
                );
                // Refresh the documents list
                ref.read(documentsScreenProvider.notifier).loadDocuments();
              } catch (e) {
                debugPrint('Failed to save OCR text: $e');
              }
            }
          },
        ),
      ),
    );
  }

  void _navigateToEnhancement(
      BuildContext context, Document document, Uint8List imageBytes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EnhancementScreen(
          imageBytes: imageBytes,
          title: document.title,
        ),
      ),
    );
  }

  void _handleDocumentLongPress(
    Document document,
    DocumentsScreenNotifier notifier,
  ) {
    notifier.enterSelectionMode();
    notifier.toggleDocumentSelection(document.id);
  }

  // ============================================================
  // Folder Handlers
  // ============================================================

  void _handleFolderTap(
    Folder folder,
    DocumentsScreenState state,
    DocumentsScreenNotifier notifier,
  ) {
    if (state.isSelectionMode) {
      notifier.toggleFolderSelection(folder.id);
    } else {
      notifier.enterFolder(folder);
    }
  }

  void _handleFolderLongPress(
    Folder folder,
    DocumentsScreenNotifier notifier,
  ) {
    notifier.enterSelectionMode();
    notifier.toggleFolderSelection(folder.id);
  }

  Future<void> _showFolderEditDialog(
    BuildContext context,
    Folder folder,
    DocumentsScreenNotifier notifier,
  ) async {
    final result = await showDialog<BentoFolderDialogResult>(
      context: context,
      builder: (context) => BentoFolderDialog(folder: folder, isEditing: true),
    );

    if (result != null && mounted) {
      await notifier.updateFolder(
        folderId: folder.id,
        name: result.name,
        color: result.color,
        icon: result.icon,
        clearColor: result.clearColor,
        clearIcon: result.clearIcon,
      );
    }
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    DocumentsScreenState state,
    DocumentsScreenNotifier notifier,
  ) async {
    final folderCount = state.selectedFolderCount;
    final docCount = state.selectedDocumentCount;

    // If folders are selected, check if they contain documents
    int documentsInFoldersCount = 0;
    if (folderCount > 0) {
      final repository = ref.read(documentRepositoryProvider);
      for (final folderId in state.selectedFolderIds) {
        final docsInFolder = await repository.getDocumentsInFolder(folderId);
        documentsInFoldersCount += docsInFolder.length;
      }
    }

    if (!context.mounted) return;

    // If folders contain documents, show special dialog with options
    if (documentsInFoldersCount > 0) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete folders'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The selected ${folderCount == 1 ? 'folder contains' : 'folders contain'} '
                '$documentsInFoldersCount ${documentsInFoldersCount == 1 ? 'document' : 'documents'}.',
              ),
              const SizedBox(height: 12),
              const Text('What would you like to do?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('keep'),
              child: const Text('Keep documents'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('delete_all'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete all'),
            ),
          ],
        ),
      );

      if (result == 'delete_all' && mounted) {
        // Delete folders and their documents
        await notifier.deleteAllSelectedWithDocuments();
      } else if (result == 'keep' && mounted) {
        // Delete folders only, documents become root-level
        await notifier.deleteAllSelected();
      }
      return;
    }

    // Standard confirmation for documents only or empty folders
    String message;
    if (folderCount > 0 && docCount > 0) {
      message =
          'Delete $folderCount ${folderCount == 1 ? 'folder' : 'folders'} and '
          '$docCount ${docCount == 1 ? 'document' : 'documents'}?';
    } else if (folderCount > 0) {
      message =
          'Delete $folderCount ${folderCount == 1 ? 'folder' : 'folders'}?';
    } else {
      message = 'Delete $docCount ${docCount == 1 ? 'document' : 'documents'}?';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm deletion'),
        content: Text('$message\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await notifier.deleteAllSelected();
    }
  }

  void _showFilterSheet(
    BuildContext context,
    DocumentsScreenState state,
    DocumentsScreenNotifier notifier,
  ) {
    showFilterSheet(
      context: context,
      currentSortBy: state.sortBy,
      currentFilter: state.filter,
      onSortByChanged: notifier.setSortBy,
      onFilterChanged: notifier.setFilter,
    );
  }

  /// Shows dialog to move selected documents to a folder.
  Future<void> _showMoveSelectedToFolderDialog(
    BuildContext context,
    DocumentsScreenState state,
    DocumentsScreenNotifier notifier,
  ) async {
    final folderService = ref.read(folderServiceProvider);
    final folders = await folderService.getAllFolders();

    if (!context.mounted) return;

    final selectedFolderId = await showDialog<String>(
      context: context,
      builder: (context) => _MoveToFolderDialog(
        folders: folders,
        currentFolderId: state.currentFolderId,
        selectedCount: state.selectedCount,
        onCreateFolder: () async {
          final result = await _showCreateFolderForMoveDialog(context);
          if (result != null && result.name.isNotEmpty) {
            try {
              final newFolder = await folderService.createFolder(
                name: result.name,
                color: result.color,
              );
              if (context.mounted) {
                Navigator.of(context).pop(newFolder.id);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to create folder: $e')),
                );
              }
            }
          }
        },
      ),
    );

    // User cancelled
    if (selectedFolderId == '_cancelled_') return;

    // Move selected documents to folder
    final movedCount = await notifier.moveSelectedToFolder(selectedFolderId);
    if (context.mounted && movedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selectedFolderId == null
                ? 'Moved $movedCount ${movedCount == 1 ? 'document' : 'documents'} to My Documents'
                : 'Moved $movedCount ${movedCount == 1 ? 'document' : 'documents'} to folder',
          ),
        ),
      );
    }
  }

  /// Shows dialog to create a new folder when moving documents.
  Future<BentoFolderDialogResult?> _showCreateFolderForMoveDialog(
      BuildContext context) async {
    return showDialog<BentoFolderDialogResult>(
      context: context,
      builder: (context) => const BentoFolderDialog(),
    );
  }

  /// Shows dialog to create a new folder with color picker.
  Future<void> _showCreateNewFolderDialog(
    BuildContext context,
    DocumentsScreenNotifier notifier,
  ) async {
    final result = await showDialog<BentoFolderDialogResult>(
      context: context,
      builder: (context) => const BentoFolderDialog(),
    );

    if (result != null && result.name.isNotEmpty && mounted) {
      final folderService = ref.read(folderServiceProvider);
      try {
        await folderService.createFolder(
          name: result.name,
          color: result.color,
        );
        await notifier.loadDocuments();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Échec de la création du dossier: $e')),
          );
        }
      }
    }
  }

  /// Handles sharing selected documents.
  ///
  /// Shares documents directly via native Android share sheet.
  /// No storage permission is required on Android 10+ (API 29+) as
  /// share_plus uses FileProvider internally.
  Future<void> _handleShareSelected(
    BuildContext context,
    DocumentsScreenState state,
  ) async {
    final shareService = ref.read(documentShareServiceProvider);

    // Get selected documents
    final selectedDocuments = state.documents
        .where((doc) => state.selectedDocumentIds.contains(doc.id))
        .toList();

    if (selectedDocuments.isEmpty) {
      return;
    }

    // Show format selection dialog
    final format = await showBentoShareFormatDialog(context);
    if (format == null) return; // User cancelled

    // Share with selected format
    await _shareDocuments(context, shareService, selectedDocuments, format);
  }

  /// Performs the actual document sharing.
  Future<void> _shareDocuments(
    BuildContext context,
    DocumentShareService shareService,
    List<Document> documents,
    ShareFormat format,
  ) async {
    try {
      final result =
          await shareService.shareDocuments(documents, format: format);
      // Clean up temporary files after sharing
      await shareService.cleanupTempFiles(result.tempFilePaths);
    } on DocumentShareException catch (e) {
      if (context.mounted) {
        String message;
        if (e.message.contains('not found')) {
          message = 'Document file not found. It may have been deleted.';
        } else if (e.message.contains('prepare') ||
            e.message.contains('decrypt')) {
          message = 'Failed to prepare document for sharing. Please try again.';
        } else {
          message = 'Failed to share: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  /// Handles exporting selected documents to external storage.
  ///
  /// Opens SAF file picker for each selected document and exports as PDF.
  /// Shows success or error feedback via SnackBar.
  Future<void> _handleExportSelected(
    BuildContext context,
    DocumentsScreenState state,
  ) async {
    final exportService = ref.read(documentExportServiceProvider);

    // Get selected documents
    final selectedDocuments = state.documents
        .where((doc) => state.selectedDocumentIds.contains(doc.id))
        .toList();

    if (selectedDocuments.isEmpty) {
      return;
    }

    // Export documents
    try {
      final result = await exportService.exportDocuments(selectedDocuments);

      if (!context.mounted) return;

      if (result.isSuccess) {
        final message = result.exportedCount == 1
            ? 'Document exporté'
            : '${result.exportedCount} documents exportés';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } else if (result.isFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result.errorMessage ?? 'Échec de l\'exportation')),
        );
      }
      // If cancelled, do nothing
    } on DocumentExportException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    String documentId,
    String currentTitle,
    DocumentsScreenNotifier notifier,
  ) async {
    final newTitle = await showBentoRenameDocumentDialog(
      context,
      currentTitle: currentTitle,
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != currentTitle) {
      await notifier.renameDocument(documentId, newTitle);
    }
  }

  Color _parseHexColor(String? hexColor, ThemeData theme) {
    if (hexColor == null) return theme.colorScheme.secondary;
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return theme.colorScheme.secondary;
    }
  }

  /// Shows dialog to edit folder (name + color).
  Future<void> _showEditFolderDialog(
    BuildContext context,
    Folder folder,
    DocumentsScreenNotifier notifier,
  ) async {
    final result = await showDialog<BentoFolderDialogResult>(
      context: context,
      builder: (context) => BentoFolderDialog(
        folder: folder,
        isEditing: true,
      ),
    );

    if (result != null) {
      final hasNameChange =
          result.name != folder.name && result.name.isNotEmpty;
      final hasColorChange = result.color != folder.color;

      if (hasNameChange || hasColorChange) {
        await notifier.updateFolder(
          folderId: folder.id,
          name: hasNameChange ? result.name : null,
          color: hasColorChange ? result.color : null,
        );
      }
    }
  }
}

/// Grid view for documents.
class _DocumentsGrid extends StatelessWidget {
  const _DocumentsGrid({
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
        final thumbnailPath = thumbnails[document.id];
        final isSelected = selectedIds.contains(document.id);

        return _DocumentGridItem(
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

/// Single document grid item.
class _DocumentGridItem extends StatelessWidget {
  const _DocumentGridItem({
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
                thumbnailPath: thumbnailPath,
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
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
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
                        : Colors.white.withOpacity(0.9),
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

/// List view for documents.
class _DocumentsList extends StatelessWidget {
  const _DocumentsList({
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

        return _DocumentListItem(
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
class _DocumentListItem extends StatelessWidget {
  const _DocumentListItem({
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
            : (isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.7)),
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
                    color:
                        isSelected ? colorScheme.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outline,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check,
                          size: 16, color: colorScheme.onPrimary)
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
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.7),
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
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      if (document.hasOcrText) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer
                                .withValues(alpha: 0.5),
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
                  document.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 20,
                ),
                onPressed: onFavoriteToggle,
                color: document.isFavorite
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
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
/// Thumbnails are typically displayed at ~150-200px width in grid view.
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
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.description_outlined,
          size: 32,
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
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

/// Bar showing active filters with quick dismiss options.
class _ActiveFiltersBar extends StatelessWidget {
  const _ActiveFiltersBar({
    required this.filter,
    required this.sortBy,
    required this.onClearAll,
    required this.onClearSort,
    required this.onClearFavorites,
    required this.onClearOcr,
    required this.onClearFolder,
    required this.onClearTags,
  });

  final DocumentsFilter filter;
  final DocumentsSortBy sortBy;
  final VoidCallback onClearAll;
  final VoidCallback onClearSort;
  final VoidCallback onClearFavorites;
  final VoidCallback onClearOcr;
  final VoidCallback onClearFolder;
  final VoidCallback onClearTags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final chips = <Widget>[];

    // Sort chip (if not default)
    if (sortBy != DocumentsSortBy.createdDesc) {
      chips.add(
        _FilterChip(
          label: 'Sort: ${sortBy.label}',
          icon: sortBy.icon,
          onDelete: onClearSort,
        ),
      );
    }

    // Folder filter chip
    if (filter.folderId != null) {
      chips.add(
        _FilterChip(
          label: 'In folder',
          icon: Icons.folder,
          onDelete: onClearFolder,
        ),
      );
    }

    // Favorites filter chip
    if (filter.favoritesOnly) {
      chips.add(
        _FilterChip(
          label: 'Favorites',
          icon: Icons.favorite,
          iconColor: colorScheme.error,
          onDelete: onClearFavorites,
        ),
      );
    }

    // OCR filter chip
    if (filter.hasOcrOnly) {
      chips.add(
        _FilterChip(
          label: 'Has OCR',
          icon: Icons.text_fields,
          onDelete: onClearOcr,
        ),
      );
    }

    // Tags filter chip
    if (filter.tagIds.isNotEmpty) {
      chips.add(
        _FilterChip(
          label:
              '${filter.tagIds.length} tag${filter.tagIds.length > 1 ? 's' : ''}',
          icon: Icons.label,
          onDelete: onClearTags,
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: chips
                    .map(
                      (chip) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: chip,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          // Clear all button
          if (chips.length > 1)
            TextButton.icon(
              onPressed: () {
                onClearAll();
                // Also reset sort
                if (sortBy != DocumentsSortBy.createdDesc) {
                  onClearSort();
                }
              },
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}

/// Individual filter chip for the active filters bar.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.onDelete,
    this.iconColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback onDelete;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: iconColor ?? colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(10),
            child: Icon(
              Icons.close,
              size: 14,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Prominent floating action button for one-click scan workflow.
///
/// Features:
/// - Large, extended FAB with clear call-to-action
/// - Haptic feedback for tactile confirmation
/// - Semantic labels for accessibility
/// - Elevated styling to draw attention
class _QuickScanFab extends StatelessWidget {
  const _QuickScanFab({required this.onPressed});

  final VoidCallback? onPressed;

  void _handlePressed() {
    // Provide haptic feedback for immediate tactile response
    HapticFeedback.mediumImpact();
    onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: 'Scan new document',
      hint: 'Double tap to open camera scanner',
      child: FloatingActionButton.extended(
        onPressed: onPressed != null ? _handlePressed : null,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scan'),
        tooltip: 'Scan new document (one tap)',
        elevation: 6,
        highlightElevation: 8,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        // Extended width for easier tap target
        extendedPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        extendedTextStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Section displaying folders in a paginated 2x4 grid layout.
class _FoldersSection extends StatefulWidget {
  const _FoldersSection({
    required this.folders,
    required this.selectedFolderIds,
    required this.isSelectionMode,
    required this.onFolderTap,
    required this.onFolderLongPress,
    required this.onCreateFolder,
    required this.theme,
  });

  final List<Folder> folders;
  final Set<String> selectedFolderIds;
  final bool isSelectionMode;
  final void Function(Folder) onFolderTap;
  final void Function(Folder) onFolderLongPress;
  final VoidCallback onCreateFolder;
  final ThemeData theme;

  @override
  State<_FoldersSection> createState() => _FoldersSectionState();
}

class _FoldersSectionState extends State<_FoldersSection> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() {
        _currentPage = page;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(
            'Dossiers',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: widget.theme.colorScheme.onSurface,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            // +1 pour le bouton d'ajout sur la première page
            itemCount: ((widget.folders.length + 1) / 8).ceil(),
            itemBuilder: (context, pageIndex) {
              // Sur la première page, on a le bouton + puis les dossiers
              // Sur les autres pages, juste les dossiers
              final totalItemsWithButton = widget.folders.length + 1;
              final startIndex = pageIndex * 8;
              final endIndex = min(startIndex + 8, totalItemsWithButton);
              final itemsOnThisPage = endIndex - startIndex;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: itemsOnThisPage,
                  itemBuilder: (context, index) {
                    final globalIndex = startIndex + index;

                    // Premier élément = bouton d'ajout
                    if (globalIndex == 0) {
                      return _AddFolderButton(
                        onTap: widget.onCreateFolder,
                        theme: widget.theme,
                      );
                    }

                    // Les autres = dossiers (index - 1 car le bouton prend la place 0)
                    final folderIndex = globalIndex - 1;
                    final folder = widget.folders[folderIndex];
                    final isSelected =
                        widget.selectedFolderIds.contains(folder.id);
                    return _FolderCard(
                      folder: folder,
                      isSelected: isSelected,
                      isSelectionMode: widget.isSelectionMode,
                      onTap: () => widget.onFolderTap(folder),
                      onLongPress: () => widget.onFolderLongPress(folder),
                      theme: widget.theme,
                    );
                  },
                ),
              );
            },
          ),
        ),
        // Page indicator dots (only show if multiple pages)
        if (((widget.folders.length + 1) / 8).ceil() > 1)
          _PageIndicatorDots(
            totalPages: ((widget.folders.length + 1) / 8).ceil(),
            currentPage: _currentPage,
            theme: widget.theme,
          ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'Documents',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: widget.theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// Button to add a new folder.
class _AddFolderButton extends StatelessWidget {
  const _AddFolderButton({
    required this.onTap,
    required this.theme,
  });

  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.primary.withValues(alpha: 0.15)
                : colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.3),
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Nouveau',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual folder card widget.
class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.folder,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.theme,
  });

  final Folder folder;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ThemeData theme;

  Color _parseColor(String? hexColor) {
    if (hexColor == null) return theme.colorScheme.secondary;
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return theme.colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final folderColor = _parseColor(folder.color);
    final colorScheme = theme.colorScheme;

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: folderColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: colorScheme.primary, width: 2)
                          : null,
                    ),
                    child: Icon(
                      Icons.folder,
                      color: folderColor,
                      size: 28,
                    ),
                  ),
                  // Selection indicator (only in selection mode)
                  if (isSelectionMode)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outline,
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                size: 14,
                                color: colorScheme.onPrimary,
                              )
                            : null,
                      ),
                    ),
                  // Favorite indicator (show heart if favorite)
                  if (folder.isFavorite && !isSelectionMode)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 12,
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                folder.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : null,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page indicator dots for multi-page navigation feedback.
class _PageIndicatorDots extends StatelessWidget {
  const _PageIndicatorDots({
    required this.totalPages,
    required this.currentPage,
    required this.theme,
  });

  final int totalPages;
  final int currentPage;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          totalPages,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: index == currentPage ? 16 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: index == currentPage
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sliver version of the documents grid.
class _DocumentsGridSliver extends StatelessWidget {
  const _DocumentsGridSliver({
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
          final thumbnailPath = thumbnails[document.id];
          final isSelected = selectedIds.contains(document.id);

          return _DocumentGridItem(
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
        childCount: documents.length,
      ),
    );
  }
}

/// Dialog for moving documents to a different folder.
class _MoveToFolderDialog extends StatelessWidget {
  const _MoveToFolderDialog({
    required this.folders,
    required this.currentFolderId,
    required this.selectedCount,
    required this.onCreateFolder,
  });

  final List<Folder> folders;
  final String? currentFolderId;
  final int selectedCount;
  final VoidCallback onCreateFolder;

  Color _parseColor(String? hexColor, ThemeData theme) {
    if (hexColor == null) return theme.colorScheme.secondary;
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return theme.colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
          'Move ${selectedCount == 1 ? 'document' : '$selectedCount documents'}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Root folder option (no folder)
            ListTile(
              leading: Icon(
                Icons.home_outlined,
                color: currentFolderId == null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              title: const Text('My Documents'),
              subtitle: const Text('Root level (no folder)'),
              selected: currentFolderId == null,
              onTap: currentFolderId == null
                  ? null
                  : () => Navigator.of(context).pop(null),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            if (folders.isNotEmpty) ...[
              const Divider(),
              // Existing folders list
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    final isCurrentFolder = folder.id == currentFolderId;
                    return ListTile(
                      leading: Icon(
                        Icons.folder,
                        color: isCurrentFolder
                            ? theme.colorScheme.primary
                            : _parseColor(folder.color, theme),
                      ),
                      title: Text(folder.name),
                      selected: isCurrentFolder,
                      enabled: !isCurrentFolder,
                      onTap: isCurrentFolder
                          ? null
                          : () => Navigator.of(context).pop(folder.id),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Create new folder button
            OutlinedButton.icon(
              onPressed: onCreateFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Create new folder'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop('_cancelled_'),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _BubbleTailPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(size.width * 1.2, size.height / 2, 0, size.height);
    path.close();

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.03)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path.shift(const Offset(2, 4)), shadowPaint);

    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Option widget for share format selection dialog.
class _ShareFormatOption extends StatelessWidget {
  const _ShareFormatOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isDark,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Painter for share dialog speech bubble tail pointing down-left (toward mascot).
class _ShareBubbleTailPainter extends CustomPainter {
  final Color color;

  _ShareBubbleTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw tail pointing down-left (toward mascot on the left)
    final path = Path();
    path.moveTo(size.width, 0); // Top right (connected to bubble)
    path.lineTo(0, size.height); // Bottom left (pointing to mascot)
    path.lineTo(size.width, size.height * 0.6); // Right side
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
