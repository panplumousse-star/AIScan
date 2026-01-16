import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/document_repository.dart';
import '../../folders/domain/folder_model.dart';
import '../../folders/domain/folder_service.dart';
import '../../ocr/presentation/ocr_results_screen.dart';
import '../../sharing/domain/document_share_service.dart';
import '../domain/document_model.dart';
import 'document_detail_screen.dart';
import 'widgets/filter_sheet.dart';

/// View mode for the documents list.
enum DocumentsViewMode {
  /// Display documents in a grid layout with large thumbnails.
  grid,

  /// Display documents in a list layout with smaller thumbnails.
  list,
}

/// Sort options for documents.
enum DocumentsSortBy {
  /// Sort by creation date (newest first).
  createdDesc('Recent', Icons.schedule),

  /// Sort by creation date (oldest first).
  createdAsc('Oldest', Icons.history),

  /// Sort by title (alphabetically).
  title('Title', Icons.sort_by_alpha),

  /// Sort by file size (largest first).
  size('Size', Icons.storage),

  /// Sort by last modified date.
  updatedDesc('Modified', Icons.update);

  const DocumentsSortBy(this.label, this.icon);

  /// Display label for this sort option.
  final String label;

  /// Icon for this sort option.
  final IconData icon;
}

/// Filter options for documents.
@immutable
class DocumentsFilter {
  /// Creates a [DocumentsFilter] with default values.
  const DocumentsFilter({
    this.folderId,
    this.favoritesOnly = false,
    this.hasOcrOnly = false,
    this.tagIds = const [],
  });

  /// Filter to a specific folder. Null means all documents.
  final String? folderId;

  /// Show only favorite documents.
  final bool favoritesOnly;

  /// Show only documents with OCR text.
  final bool hasOcrOnly;

  /// Filter to documents with specific tags.
  final List<String> tagIds;

  /// Whether any filter is active.
  bool get hasActiveFilters =>
      folderId != null || favoritesOnly || hasOcrOnly || tagIds.isNotEmpty;

  /// Creates a copy with updated values.
  DocumentsFilter copyWith({
    String? folderId,
    bool? favoritesOnly,
    bool? hasOcrOnly,
    List<String>? tagIds,
    bool clearFolderId = false,
    bool clearTags = false,
  }) {
    return DocumentsFilter(
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      hasOcrOnly: hasOcrOnly ?? this.hasOcrOnly,
      tagIds: clearTags ? const [] : (tagIds ?? this.tagIds),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DocumentsFilter) return false;
    return folderId == other.folderId &&
        favoritesOnly == other.favoritesOnly &&
        hasOcrOnly == other.hasOcrOnly &&
        _listEquals(tagIds, other.tagIds);
  }

  @override
  int get hashCode =>
      Object.hash(folderId, favoritesOnly, hasOcrOnly, Object.hashAll(tagIds));

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

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

  /// Whether there's an error.
  bool get hasError => error != null;

  /// The count of documents.
  int get documentCount => documents.length;

  /// The count of selected documents.
  int get selectedCount => selectedDocumentIds.length;

  /// Whether all documents are selected.
  bool get allSelected =>
      documents.isNotEmpty && selectedDocumentIds.length == documents.length;

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
    bool? isSelectionMode,
    Map<String, String>? decryptedThumbnails,
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
  DocumentsScreenNotifier(this._repository, this._folderService)
    : super(const DocumentsScreenState());

  final DocumentRepository _repository;
  final FolderService _folderService;

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
      } else if (state.currentFolderId != null) {
        // Inside a folder - load folder's documents
        documents = await _repository.getDocumentsInFolder(
          state.currentFolderId,
          includeTags: true,
        );
        // Also load subfolders
        final allFolders = await _folderService.getAllFolders();
        folders = allFolders.childrenOf(state.currentFolderId!).sortedByName();
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
  void toggleDocumentSelection(String documentId) {
    final selected = Set<String>.from(state.selectedDocumentIds);
    if (selected.contains(documentId)) {
      selected.remove(documentId);
    } else {
      selected.add(documentId);
    }

    state = state.copyWith(
      selectedDocumentIds: selected,
      isSelectionMode: selected.isNotEmpty,
    );
  }

  /// Selects all documents.
  void selectAll() {
    state = state.copyWith(
      selectedDocumentIds: state.documents.map((d) => d.id).toSet(),
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
final documentsScreenProvider =
    StateNotifierProvider.autoDispose<
      DocumentsScreenNotifier,
      DocumentsScreenState
    >((ref) {
      final repository = ref.watch(documentRepositoryProvider);
      final folderService = ref.watch(folderServiceProvider);
      return DocumentsScreenNotifier(repository, folderService);
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
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    final notifier = ref.read(documentsScreenProvider.notifier);

    // Set initial folder filter if provided
    if (widget.initialFolderId != null) {
      notifier.setFilter(DocumentsFilter(folderId: widget.initialFolderId));
    }

    await notifier.initialize();
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

    return Scaffold(
      appBar: _buildAppBar(context, state, notifier, theme),
      body: _buildBody(context, state, notifier, theme),
      floatingActionButton: _buildFab(context, state),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    DocumentsScreenState state,
    DocumentsScreenNotifier notifier,
    ThemeData theme,
  ) {
    if (state.isSelectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: notifier.exitSelectionMode,
          tooltip: 'Cancel selection',
        ),
        title: Text('${state.selectedCount} selected'),
        actions: [
          IconButton(
            icon: Icon(state.allSelected ? Icons.deselect : Icons.select_all),
            onPressed: state.allSelected
                ? notifier.clearSelection
                : notifier.selectAll,
            tooltip: state.allSelected ? 'Deselect all' : 'Select all',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: state.selectedCount > 0
                ? () => _handleShareSelected(context, state)
                : null,
            tooltip: 'Share selected',
          ),
          IconButton(
            icon: const Icon(Icons.drive_file_move_outlined),
            onPressed: state.selectedCount > 0
                ? () => _showMoveSelectedToFolderDialog(context, state, notifier)
                : null,
            tooltip: 'Move to folder',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: state.selectedCount > 0
                ? () => _showDeleteConfirmation(context, state, notifier)
                : null,
            tooltip: 'Delete selected',
          ),
        ],
      );
    }

    return AppBar(
      leading: state.isAtRoot
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: notifier.exitFolder,
              tooltip: 'Back',
            ),
      title: Text(state.currentFolder?.name ?? 'My Documents'),
      actions: [
        // View mode toggle
        IconButton(
          icon: Icon(
            state.viewMode == DocumentsViewMode.grid
                ? Icons.view_list_outlined
                : Icons.grid_view_outlined,
          ),
          onPressed: notifier.toggleViewMode,
          tooltip: state.viewMode == DocumentsViewMode.grid
              ? 'Switch to list view'
              : 'Switch to grid view',
        ),
        // Filter button with badge indicator
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: () => _showFilterSheet(context, state, notifier),
              tooltip: 'Sort & Filter',
            ),
            // Active filter indicator
            if (state.filter.hasActiveFilters ||
                state.sortBy != DocumentsSortBy.createdDesc)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Quick favorites filter toggle
        IconButton(
          icon: Icon(
            state.filter.favoritesOnly ? Icons.favorite : Icons.favorite_border,
            color: state.filter.favoritesOnly ? theme.colorScheme.error : null,
          ),
          onPressed: notifier.toggleFavoritesFilter,
          tooltip: state.filter.favoritesOnly
              ? 'Show all documents'
              : 'Show favorites only',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: notifier.setSearchQuery,
            decoration: InputDecoration(
              hintText: 'Search by name or OCR text...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: state.hasSearch
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        notifier.clearSearch();
                      },
                    )
                  : null,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
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
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.hasError && !state.hasDocuments) {
      return _ErrorView(message: state.error!, onRetry: notifier.initialize);
    }

    // If no documents and no folders at root, and not loading, go back
    // (shouldn't happen since we check before showing button)
    if (!state.hasDocuments && !state.hasFolders && !state.isLoading && state.isAtRoot) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Center(child: CircularProgressIndicator());
    }

    // Still loading documents
    if (state.isLoading && !state.hasDocuments && !state.hasFolders) {
      return const Center(child: CircularProgressIndicator());
    }

    // Empty folder message
    if (!state.hasDocuments && !state.hasFolders && !state.isAtRoot) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'This folder is empty',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => notifier.exitFolder(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go back'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Active filters indicator
        if (state.filter.hasActiveFilters ||
            state.sortBy != DocumentsSortBy.createdDesc)
          _ActiveFiltersBar(
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
            onClearTags: () =>
                notifier.setFilter(state.filter.copyWith(clearTags: true)),
          ),
        // Document list/grid
        Expanded(
          child: state.filteredDocuments.isEmpty && state.hasSearch
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No results for "${state.searchQuery}"',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          notifier.clearSearch();
                        },
                        child: const Text('Clear search'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: notifier.refresh,
                  child: CustomScrollView(
                    slivers: [
                      // Folders section (if any)
                      if (state.hasFolders)
                        SliverToBoxAdapter(
                          child: _FoldersSection(
                            folders: state.folders,
                            onFolderTap: notifier.enterFolder,
                            theme: theme,
                          ),
                        ),
                      // Documents section
                      if (state.filteredDocuments.isNotEmpty)
                        state.viewMode == DocumentsViewMode.grid
                            ? SliverPadding(
                                padding: const EdgeInsets.all(8),
                                sliver: _DocumentsGridSliver(
                                  documents: state.filteredDocuments,
                                  thumbnails: state.decryptedThumbnails,
                                  selectedIds: state.selectedDocumentIds,
                                  isSelectionMode: state.isSelectionMode,
                                  onDocumentTap: (doc) => _handleDocumentTap(doc, state, notifier),
                                  onDocumentLongPress: (doc) =>
                                      _handleDocumentLongPress(doc, notifier),
                                  onFavoriteToggle: notifier.toggleFavorite,
                                  onRename: (id, title) => _showRenameDialog(context, id, title, notifier),
                                  theme: theme,
                                ),
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final doc = state.filteredDocuments[index];
                                    return _DocumentListItem(
                                      document: doc,
                                      thumbnailPath: state.decryptedThumbnails[doc.id],
                                      isSelected: state.selectedDocumentIds.contains(doc.id),
                                      isSelectionMode: state.isSelectionMode,
                                      onTap: () => _handleDocumentTap(doc, state, notifier),
                                      onLongPress: () => _handleDocumentLongPress(doc, notifier),
                                      onFavoriteToggle: () => notifier.toggleFavorite(doc.id),
                                      onRename: () => _showRenameDialog(context, doc.id, doc.title, notifier),
                                      theme: theme,
                                    );
                                  },
                                  childCount: state.filteredDocuments.length,
                                ),
                              ),
                      // Empty documents message when filters are active
                      if (state.filteredDocuments.isEmpty && (state.filter.hasActiveFilters || state.hasSearch))
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.filter_list_off,
                                  size: 64,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  state.hasSearch
                                      ? 'No results for "${state.searchQuery}"'
                                      : 'No matching documents',
                                  style: theme.textTheme.titleMedium,
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
                                  child: Text(state.hasSearch ? 'Clear search' : 'Clear filters'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget? _buildFab(BuildContext context, DocumentsScreenState state) {
    if (state.isSelectionMode) return null;

    return _QuickScanFab(
      onPressed: widget.onScanPressed,
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (navContext) => DocumentDetailScreen(
          document: document,
          onDelete: () {
            Navigator.of(navContext).pop();
            // Refresh the documents list
            ref.read(documentsScreenProvider.notifier).loadDocuments();
          },
          onOcr: (doc, imageBytes) => _navigateToOcr(navContext, doc, imageBytes),
        ),
      ),
    );
  }

  void _navigateToOcr(BuildContext context, Document document, Uint8List imageBytes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OcrResultsScreen(
          document: document,
          imageBytes: imageBytes,
          autoRunOcr: true,
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

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    DocumentsScreenState state,
    DocumentsScreenNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete documents?'),
        content: Text(
          'Are you sure you want to delete ${state.selectedCount} '
          '${state.selectedCount == 1 ? 'document' : 'documents'}? '
          'This action cannot be undone.',
        ),
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

    if (confirmed == true) {
      await notifier.deleteSelected();
    }
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
          final newFolderName = await _showCreateFolderForMoveDialog(context);
          if (newFolderName != null && newFolderName.isNotEmpty) {
            try {
              final newFolder = await folderService.createFolder(name: newFolderName);
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
  Future<String?> _showCreateFolderForMoveDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (context) => const _CreateFolderForMoveDialog(),
    );
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

    // Share directly - no permission needed for share_plus on modern Android
    await _shareDocuments(context, shareService, selectedDocuments);
  }

  /// Performs the actual document sharing.
  Future<void> _shareDocuments(
    BuildContext context,
    DocumentShareService shareService,
    List<Document> documents,
  ) async {
    try {
      final result = await shareService.shareDocuments(documents);
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

  Future<void> _showRenameDialog(
    BuildContext context,
    String documentId,
    String currentTitle,
    DocumentsScreenNotifier notifier,
  ) async {
    final controller = TextEditingController(text: currentTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Document name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != currentTitle) {
      await notifier.renameDocument(documentId, newTitle);
    }
    controller.dispose();
  }
}

/// Error state view.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
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

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withOpacity(0.3)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      color: isSelected
                          ? colorScheme.primary
                          : Colors.transparent,
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

              // Thumbnail
              Container(
                width: 56,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: colorScheme.surfaceContainerHighest,
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          document.fileSizeFormatted,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
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
                            style: theme.textTheme.bodySmall?.copyWith(
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
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (document.hasOcrText) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'OCR',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w500,
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
                  icon: Icon(
                    Icons.edit_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onRename,
                  tooltip: 'Rename',
                ),
                IconButton(
                  icon: Icon(
                    document.isFavorite
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: document.isFavorite
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onFavoriteToggle,
                  tooltip: document.isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
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
          label: '${filter.tagIds.length} tag${filter.tagIds.length > 1 ? 's' : ''}',
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
    required this.onFolderTap,
    required this.theme,
  });

  final List<Folder> folders;
  final void Function(Folder) onFolderTap;
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Folders',
            style: widget.theme.textTheme.titleSmall?.copyWith(
              color: widget.theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            itemCount: (widget.folders.length / 8).ceil(),
            itemBuilder: (context, pageIndex) {
              final startIndex = pageIndex * 8;
              final endIndex = min(startIndex + 8, widget.folders.length);
              final pageFolders = widget.folders.sublist(startIndex, endIndex);

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
                  itemCount: pageFolders.length,
                  itemBuilder: (context, index) {
                    final folder = pageFolders[index];
                    return _FolderCard(
                      folder: folder,
                      onTap: () => widget.onFolderTap(folder),
                      theme: widget.theme,
                    );
                  },
                ),
              );
            },
          ),
        ),
        // Page indicator dots (only show if multiple pages)
        if ((widget.folders.length / 8).ceil() > 1)
          _PageIndicatorDots(
            totalPages: (widget.folders.length / 8).ceil(),
            currentPage: _currentPage,
            theme: widget.theme,
          ),
        const Divider(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Documents',
            style: widget.theme.textTheme.titleSmall?.copyWith(
              color: widget.theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Individual folder card widget.
class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.folder,
    required this.onTap,
    required this.theme,
  });

  final Folder folder;
  final VoidCallback onTap;
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: folderColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.folder,
                  color: folderColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                folder.name,
                style: theme.textTheme.bodySmall,
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
      title: Text('Move ${selectedCount == 1 ? 'document' : '$selectedCount documents'}'),
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

/// Dialog for creating a new folder when moving documents.
///
/// Uses StatefulWidget to properly manage the TextEditingController lifecycle
/// and check mounted state before navigation.
class _CreateFolderForMoveDialog extends StatefulWidget {
  const _CreateFolderForMoveDialog();

  @override
  State<_CreateFolderForMoveDialog> createState() => _CreateFolderForMoveDialogState();
}

class _CreateFolderForMoveDialogState extends State<_CreateFolderForMoveDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Folder name cannot be empty');
      return;
    }

    // Unfocus to dismiss keyboard before popping to avoid _dependents.isEmpty
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Folder'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Folder name',
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) {
          if (_error != null) {
            setState(() => _error = null);
          }
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
