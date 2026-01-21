import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/document_repository.dart';
import '../../../core/utils/performance_utils.dart';
import '../../folders/domain/folder_model.dart';
import '../../folders/domain/folder_service.dart';
import '../../sharing/domain/document_share_service.dart';
import '../../../core/export/document_export_service.dart';
import '../domain/document_model.dart';
import 'models/documents_ui_models.dart';
import 'widgets/app_bar_widgets.dart';
import 'widgets/bento_documents_widgets.dart';
import 'widgets/body_widgets.dart';
import 'widgets/filter_widgets.dart';
import 'controllers/documents_dialog_controller.dart';
import 'controllers/documents_navigation_controller.dart';
import '../../../core/widgets/bento_background.dart';
import '../../../core/widgets/bento_card.dart';
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

  /// Map of document IDs to decrypted thumbnail bytes.
  final Map<String, Uint8List> decryptedThumbnails;

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
      result = result.where((folder) =>
        folder.name.toLowerCase().contains(query)
      ).toList();
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
  int get selectedCount => selectedDocumentIds.length + selectedFolderIds.length;

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
    Map<String, Uint8List>? decryptedThumbnails,
    bool clearError = false,
    bool clearSelection = false,
    bool clearCurrentFolder = false,
  }) {
    return DocumentsScreenState(
      documents: documents ?? this.documents,
      folders: folders ?? this.folders,
      currentFolderId: clearCurrentFolder ? null : (currentFolderId ?? this.currentFolderId),
      currentFolder: clearCurrentFolder ? null : (currentFolder ?? this.currentFolder),
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
      isSelectionMode: clearSelection
          ? false
          : (isSelectionMode ?? this.isSelectionMode),
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
        final refreshedFolder = await _folderService.getFolder(state.currentFolderId!);
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
      final parentFolder = await _folderService.getFolder(state.currentFolder!.parentId!);
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

  /// Loads decrypted thumbnails for documents in parallel.
  ///
  /// Only loads first batch of thumbnails to reduce initial memory usage.
  /// Additional thumbnails are loaded as needed (lazy loading).
  /// Uses parallel decryption to reduce loading time from ~1000ms to ~200ms.
  Future<void> _loadThumbnails(List<Document> documents) async {
    // Limit initial thumbnail load to reduce memory spike
    const maxInitialLoad = 12; // ~2 rows of grid
    final documentsToLoad = documents.take(maxInitialLoad).toList();

    // Filter documents that need thumbnails loaded
    final documentsNeedingThumbnails = documentsToLoad
        .where((doc) =>
            doc.thumbnailPath != null &&
            !state.decryptedThumbnails.containsKey(doc.id))
        .toList();

    if (documentsNeedingThumbnails.isEmpty) return;
    if (!mounted) return;

    try {
      // Load all thumbnails in parallel using batch method
      final decryptedThumbnails = await _repository.getBatchDecryptedThumbnailBytes(
        documentsNeedingThumbnails,
      );

      // Update state once with all results
      if (decryptedThumbnails.isNotEmpty && mounted) {
        state = state.copyWith(
          decryptedThumbnails: {
            ...state.decryptedThumbnails,
            ...decryptedThumbnails,
          },
        );
      }
    } catch (_) {
      // Ignore thumbnail loading errors
    }
  }

  /// Loads a single document's thumbnail on demand.
  ///
  /// Called when a document card becomes visible but its thumbnail isn't loaded.
  Future<void> loadThumbnailForDocument(Document document) async {
    if (document.thumbnailPath == null) return;
    if (state.decryptedThumbnails.containsKey(document.id)) return;

    try {
      final decryptedBytes = await _repository.getDecryptedThumbnailBytes(
        document,
      );
      if (decryptedBytes != null && mounted) {
        state = state.copyWith(
          decryptedThumbnails: {
            ...state.decryptedThumbnails,
            document.id: decryptedBytes,
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
    if (state.selectedDocumentIds.isEmpty && state.selectedFolderIds.isEmpty) return;

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
    if (state.selectedDocumentIds.isEmpty && state.selectedFolderIds.isEmpty) return;

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
    if (state.selectedDocumentIds.isEmpty && state.selectedFolderIds.isEmpty) return;

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
}

/// Riverpod provider for the documents screen state.
final documentsScreenProvider =
    StateNotifierProvider.autoDispose<
      DocumentsScreenNotifier,
      DocumentsScreenState
    >((ref) {
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

class _DocumentsScreenState extends ConsumerState<DocumentsScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // Add lifecycle observer for cache management
    WidgetsBinding.instance.addObserver(this);

    // Initialize after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Handle cache lifecycle based on app state
    _handleCacheLifecycle(state);
  }

  /// Manages thumbnail cache based on app lifecycle events.
  ///
  /// - When app goes to background (paused): Trim cache to 50% to free memory
  /// - When app goes to inactive: Light trim to 75%
  /// - When app resumes: No action needed (cache remains for fast return)
  void _handleCacheLifecycle(AppLifecycleState state) {
    final thumbnailCache = ref.read(thumbnailCacheProvider);

    switch (state) {
      case AppLifecycleState.paused:
        // App is in background - aggressively trim cache to free memory
        // Keep 50% for quick resume, but free up memory for system
        final targetSize = (thumbnailCache.currentSizeBytes * 0.5).round();
        thumbnailCache.trimToSize(targetSize);
        break;

      case AppLifecycleState.inactive:
        // App is transitioning or partially visible - light trim
        final targetSize = (thumbnailCache.currentSizeBytes * 0.75).round();
        thumbnailCache.trimToSize(targetSize);
        break;

      case AppLifecycleState.resumed:
        // App is back in foreground - no action needed
        // Cache remains for fast thumbnail display
        break;

      case AppLifecycleState.detached:
        // App is about to terminate - clear all cache
        thumbnailCache.clearCache();
        break;

      case AppLifecycleState.hidden:
        // App is hidden but still running - treat like inactive
        final targetSize = (thumbnailCache.currentSizeBytes * 0.75).round();
        thumbnailCache.trimToSize(targetSize);
        break;
    }
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


  Widget _buildBody(
    BuildContext context,
    DocumentsScreenState state,
    DocumentsScreenNotifier notifier,
    ThemeData theme,
  ) {
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
    if (!state.hasDocuments && !state.hasFolders && !state.isLoading && state.isAtRoot && !state.filter.hasActiveFilters) {
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
                DocumentsAppBar(state: state, notifier: notifier, theme: theme),
                DocumentsBentoHeader(state: state, notifier: notifier, theme: theme),
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
                  onShowFilters: () => DocumentsDialogController.showFilterSheet(context, state, notifier),
                  onToggleFavorites: () => notifier.setFilter(
                    state.filter.copyWith(favoritesOnly: !state.filter.favoritesOnly),
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
                      DocumentsDialogController.showDeleteConfirmation(context, state, notifier, ref),
                  onFavoriteSelected: notifier.toggleFavoriteSelected,
                  onShareSelected: () => _handleShareSelected(context, state),
                  onExportSelected: () => _handleExportSelected(context, state),
                  onMoveSelected: () =>
                      DocumentsDialogController.showMoveSelectedToFolderDialog(context, state, notifier, ref),
                ),
              ),
              // Active filters indicator
              if (state.filter.hasActiveFilters ||
                  state.sortBy != DocumentsSortBy.createdDesc)
                FilterSummaryBar(
                  filter: state.filter,
                  sortBy: state.sortBy,
                  onClearAll: notifier.clearFilters,
                  onClearSort: () => notifier.setSortBy(DocumentsSortBy.createdDesc),
                  onClearFavorites: () =>
                      notifier.setFilter(state.filter.copyWith(favoritesOnly: false)),
                  onClearOcr: () =>
                      notifier.setFilter(state.filter.copyWith(hasOcrOnly: false)),
                  onClearFolder: () =>
                      notifier.setFilter(state.filter.copyWith(clearFolderId: true)),
                  onClearTag: (tagId) =>
                      notifier.setFilter(state.filter.copyWith(
                        tagIds: state.filter.tagIds.where((id) => id != tagId).toList(),
                      )),
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
                              FolderHeaderWidget(
                                folder: state.currentFolder!,
                                notifier: notifier,
                                theme: theme,
                                onEditFolder: (folder) => DocumentsDialogController.showEditFolderDialog(context, folder, notifier),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: DocumentsSliverList(
                                  state: state,
                                  notifier: notifier,
                                  theme: theme,
                                  onFolderTap: (Folder folder) => _handleFolderTap(folder, state, notifier),
                                  onFolderLongPress: (Folder folder) => _handleFolderLongPress(folder, notifier),
                                  onDocumentTap: (Document doc) => _handleDocumentTap(doc, state, notifier),
                                  onDocumentLongPress: (Document doc) => _handleDocumentLongPress(doc, notifier),
                                  onRename: (String docId, String title) => DocumentsDialogController.showRenameDialog(context, docId, title, notifier),
                                  onCreateFolder: () => DocumentsDialogController.showCreateNewFolderDialog(context, notifier, ref),
                                  searchController: _searchController,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : DocumentsSliverList(
                        state: state,
                        notifier: notifier,
                        theme: theme,
                        onFolderTap: (Folder folder) => _handleFolderTap(folder, state, notifier),
                        onFolderLongPress: (Folder folder) => _handleFolderLongPress(folder, notifier),
                        onDocumentTap: (Document doc) => _handleDocumentTap(doc, state, notifier),
                        onDocumentLongPress: (Document doc) => _handleDocumentLongPress(doc, notifier),
                        onRename: (String docId, String title) => DocumentsDialogController.showRenameDialog(context, docId, title, notifier),
                        onCreateFolder: () => DocumentsDialogController.showCreateNewFolderDialog(context, notifier, ref),
                        searchController: _searchController,
                      ),
              ),
            ],
          ),
        ), // End SafeArea
      ), // End GestureDetector
    ],
    );
  }

  Widget? _buildFab(BuildContext context, DocumentsScreenState state) {
    if (state.isSelectionMode) return null;

    return BentoScanFab(
      onPressed: widget.onScanPressed ?? () => DocumentsNavigationController.navigateToScanner(context, ref),
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
      DocumentsNavigationController.navigateToDocumentDetail(context, document, ref);
    }
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
      final result = await shareService.shareDocuments(documents, format: format);
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
          SnackBar(content: Text(result.errorMessage ?? 'Échec de l\'exportation')),
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
}
