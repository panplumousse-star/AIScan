import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/document_repository.dart';
import '../../sharing/domain/document_share_service.dart';
import '../domain/document_model.dart';
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
    this.viewMode = DocumentsViewMode.grid,
    this.sortBy = DocumentsSortBy.createdDesc,
    this.filter = const DocumentsFilter(),
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

  /// Current view mode (grid or list).
  final DocumentsViewMode viewMode;

  /// Current sort option.
  final DocumentsSortBy sortBy;

  /// Current filter settings.
  final DocumentsFilter filter;

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
    DocumentsViewMode? viewMode,
    DocumentsSortBy? sortBy,
    DocumentsFilter? filter,
    bool? isLoading,
    bool? isRefreshing,
    bool? isInitialized,
    String? error,
    Set<String>? selectedDocumentIds,
    bool? isSelectionMode,
    Map<String, String>? decryptedThumbnails,
    bool clearError = false,
    bool clearSelection = false,
  }) {
    return DocumentsScreenState(
      documents: documents ?? this.documents,
      viewMode: viewMode ?? this.viewMode,
      sortBy: sortBy ?? this.sortBy,
      filter: filter ?? this.filter,
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
  /// Creates a [DocumentsScreenNotifier] with the given repository.
  DocumentsScreenNotifier(this._repository)
    : super(const DocumentsScreenState());

  final DocumentRepository _repository;

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

  /// Loads documents from the repository.
  Future<void> loadDocuments() async {
    if (!state.isInitialized) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      List<Document> documents;
      final filter = state.filter;

      if (filter.favoritesOnly) {
        documents = await _repository.getFavoriteDocuments(includeTags: true);
      } else if (filter.folderId != null) {
        documents = await _repository.getDocumentsInFolder(
          filter.folderId,
          includeTags: true,
        );
      } else {
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

      state = state.copyWith(documents: documents, isLoading: false);

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
  Future<void> _loadThumbnails(List<Document> documents) async {
    for (final document in documents) {
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
      return DocumentsScreenNotifier(repository);
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
  @override
  void initState() {
    super.initState();

    // Initialize after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
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
      title: Text(state.filter.folderId != null ? 'Folder' : 'Documents'),
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
    );
  }

  Widget _buildBody(
    BuildContext context,
    DocumentsScreenState state,
    DocumentsScreenNotifier notifier,
    ThemeData theme,
  ) {
    if (!state.isInitialized && state.isLoading) {
      return const _LoadingView();
    }

    if (state.hasError && !state.hasDocuments) {
      return _ErrorView(message: state.error!, onRetry: notifier.initialize);
    }

    if (!state.hasDocuments) {
      return _EmptyView(
        hasFilters: state.filter.hasActiveFilters,
        onClearFilters: notifier.clearFilters,
        onScanPressed: widget.onScanPressed,
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
          child: RefreshIndicator(
            onRefresh: notifier.refresh,
            child: state.viewMode == DocumentsViewMode.grid
                ? _DocumentsGrid(
                    documents: state.documents,
                    thumbnails: state.decryptedThumbnails,
                    selectedIds: state.selectedDocumentIds,
                    isSelectionMode: state.isSelectionMode,
                    onDocumentTap: (doc) => _handleDocumentTap(doc, state, notifier),
                    onDocumentLongPress: (doc) =>
                        _handleDocumentLongPress(doc, notifier),
                    onFavoriteToggle: notifier.toggleFavorite,
                    theme: theme,
                  )
                : _DocumentsList(
                    documents: state.documents,
                    thumbnails: state.decryptedThumbnails,
                    selectedIds: state.selectedDocumentIds,
                    isSelectionMode: state.isSelectionMode,
                    onDocumentTap: (doc) => _handleDocumentTap(doc, state, notifier),
                    onDocumentLongPress: (doc) =>
                        _handleDocumentLongPress(doc, notifier),
                    onFavoriteToggle: notifier.toggleFavorite,
                    theme: theme,
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
    } else {
      widget.onDocumentSelected?.call(document);
    }
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
        if (e.message.contains('not found')) {
          showDocumentNotFoundSnackbar(context);
        } else if (e.message.contains('prepare') ||
            e.message.contains('decrypt')) {
          showDecryptionFailedSnackbar(context);
        } else {
          showShareErrorSnackbar(context, e.message);
        }
      }
    }
  }
}

/// Loading indicator view.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
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

/// Empty state view with prominent one-click scan action.
class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.hasFilters,
    required this.onClearFilters,
    this.onScanPressed,
  });

  final bool hasFilters;
  final VoidCallback onClearFilters;
  final VoidCallback? onScanPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasFilters) ...[
              Icon(
                Icons.filter_list_off,
                size: 80,
                color: theme.colorScheme.primary.withOpacity(0.6),
              ),
              const SizedBox(height: 24),
              Text(
                'No matching documents',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your filters to see more documents',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_list_off),
                label: const Text('Clear filters'),
              ),
            ] else ...[
              // Prominent one-click scan hero section
              _ScanHeroSection(onScanPressed: onScanPressed),
            ],
          ],
        ),
      ),
    );
  }
}

/// Hero section for one-click scan workflow on empty state.
///
/// Provides a large, accessible scan button that immediately triggers
/// the scanning workflow with minimal friction.
class _ScanHeroSection extends StatefulWidget {
  const _ScanHeroSection({this.onScanPressed});

  final VoidCallback? onScanPressed;

  @override
  State<_ScanHeroSection> createState() => _ScanHeroSectionState();
}

class _ScanHeroSectionState extends State<_ScanHeroSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleScanPressed() {
    // Provide haptic feedback for one-click action
    HapticFeedback.mediumImpact();
    widget.onScanPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated scan icon with pulse effect
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            );
          },
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withOpacity(0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.document_scanner_outlined,
              size: 56,
              color: colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Ready to Scan',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tap below to scan your first document.\nIt only takes one tap!',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Large, accessible scan button
        Semantics(
          button: true,
          label: 'Scan document. One tap to start scanning.',
          hint: 'Double tap to activate',
          child: Material(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(28),
            elevation: 4,
            shadowColor: colorScheme.primary.withOpacity(0.4),
            child: InkWell(
              onTap: widget.onScanPressed != null ? _handleScanPressed : null,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 20,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      color: colorScheme.onPrimary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Start Scanning',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Privacy reminder
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.security_outlined,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              'All scans are encrypted locally',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
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
    required this.theme,
  });

  final List<Document> documents;
  final Map<String, String> thumbnails;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final void Function(Document) onDocumentTap;
  final void Function(Document) onDocumentLongPress;
  final void Function(String) onFavoriteToggle;
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
    required this.theme,
  });

  final Document document;
  final String? thumbnailPath;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFavoriteToggle;
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

            // Favorite button
            Positioned(
              top: 8,
              right: 8,
              child: _FavoriteButton(
                isFavorite: document.isFavorite,
                onPressed: isSelectionMode ? null : onFavoriteToggle,
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
    required this.theme,
  });

  final List<Document> documents;
  final Map<String, String> thumbnails;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final void Function(Document) onDocumentTap;
  final void Function(Document) onDocumentLongPress;
  final void Function(String) onFavoriteToggle;
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
    required this.theme,
  });

  final Document document;
  final String? thumbnailPath;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFavoriteToggle;
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

              // Favorite button
              if (!isSelectionMode)
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
