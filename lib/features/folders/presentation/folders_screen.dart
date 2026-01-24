import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/bento_confirmation_dialog.dart';
import '../../../core/widgets/bento_state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/folder_model.dart';
import '../domain/folder_service.dart';
import 'widgets/bento_folder_dialog.dart';

/// Sort options for folders.
enum FoldersSortBy {
  /// Sort by name (alphabetically).
  name('Name', Icons.sort_by_alpha),

  /// Sort by creation date (newest first).
  createdDesc('Recent', Icons.schedule),

  /// Sort by creation date (oldest first).
  createdAsc('Oldest', Icons.history),

  /// Sort by last modified date.
  updatedDesc('Modified', Icons.update);

  const FoldersSortBy(this.label, this.icon);

  /// Display label for this sort option.
  final String label;

  /// Icon for this sort option.
  final IconData icon;
}

/// State for the folders screen.
@immutable
class FoldersScreenState {
  /// Creates a [FoldersScreenState] with default values.
  const FoldersScreenState({
    this.folders = const [],
    this.currentFolderId,
    this.breadcrumbs = const [],
    this.sortBy = FoldersSortBy.name,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isInitialized = false,
    this.error,
    this.selectedFolderIds = const {},
    this.isSelectionMode = false,
    this.folderStats = const {},
  });

  /// The list of folders at the current level.
  final List<Folder> folders;

  /// The current folder ID (null for root level).
  final String? currentFolderId;

  /// Breadcrumb path from root to current folder.
  final List<Folder> breadcrumbs;

  /// Current sort option.
  final FoldersSortBy sortBy;

  /// Whether folders are being loaded.
  final bool isLoading;

  /// Whether folders are being refreshed.
  final bool isRefreshing;

  /// Whether the service has been initialized.
  final bool isInitialized;

  /// Error message, if any.
  final String? error;

  /// Set of selected folder IDs for multi-select mode.
  final Set<String> selectedFolderIds;

  /// Whether multi-select mode is active.
  final bool isSelectionMode;

  /// Map of folder IDs to their document counts.
  final Map<String, int> folderStats;

  /// Whether we have any folders.
  bool get hasFolders => folders.isNotEmpty;

  /// Whether there's an error.
  bool get hasError => error != null;

  /// The count of folders.
  int get folderCount => folders.length;

  /// The count of selected folders.
  int get selectedCount => selectedFolderIds.length;

  /// Whether all folders are selected.
  bool get allSelected =>
      folders.isNotEmpty && selectedFolderIds.length == folders.length;

  /// Whether we're at the root level.
  bool get isAtRoot => currentFolderId == null;

  /// The current folder (null if at root).
  Folder? get currentFolder => breadcrumbs.isNotEmpty ? breadcrumbs.last : null;

  /// Creates a copy with updated values.
  FoldersScreenState copyWith({
    List<Folder>? folders,
    String? currentFolderId,
    List<Folder>? breadcrumbs,
    FoldersSortBy? sortBy,
    bool? isLoading,
    bool? isRefreshing,
    bool? isInitialized,
    String? error,
    Set<String>? selectedFolderIds,
    bool? isSelectionMode,
    Map<String, int>? folderStats,
    bool clearError = false,
    bool clearSelection = false,
    bool clearCurrentFolder = false,
  }) {
    return FoldersScreenState(
      folders: folders ?? this.folders,
      currentFolderId:
          clearCurrentFolder ? null : (currentFolderId ?? this.currentFolderId),
      breadcrumbs:
          clearCurrentFolder ? const [] : (breadcrumbs ?? this.breadcrumbs),
      sortBy: sortBy ?? this.sortBy,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isInitialized: isInitialized ?? this.isInitialized,
      error: clearError ? null : (error ?? this.error),
      selectedFolderIds: clearSelection
          ? const {}
          : (selectedFolderIds ?? this.selectedFolderIds),
      isSelectionMode:
          clearSelection ? false : (isSelectionMode ?? this.isSelectionMode),
      folderStats: folderStats ?? this.folderStats,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FoldersScreenState &&
        other.currentFolderId == currentFolderId &&
        other.sortBy == sortBy &&
        other.isLoading == isLoading &&
        other.isRefreshing == isRefreshing &&
        other.isInitialized == isInitialized &&
        other.error == error &&
        other.isSelectionMode == isSelectionMode &&
        other.folderCount == folderCount;
  }

  @override
  int get hashCode => Object.hash(
        currentFolderId,
        sortBy,
        isLoading,
        isRefreshing,
        isInitialized,
        error,
        isSelectionMode,
        folderCount,
      );
}

/// State notifier for the folders screen.
///
/// Manages folder loading, navigation, creation, and deletion.
class FoldersScreenNotifier extends StateNotifier<FoldersScreenState> {
  /// Creates a [FoldersScreenNotifier] with the given service.
  FoldersScreenNotifier(this._folderService)
      : super(const FoldersScreenState());

  final FolderService _folderService;

  /// Initializes the screen and loads folders.
  Future<void> initialize() async {
    if (state.isInitialized) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _folderService.initialize();
      state = state.copyWith(isInitialized: true);
      await loadFolders();
    } on FolderServiceException catch (e) {
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

  /// Loads folders at the current level.
  Future<void> loadFolders() async {
    if (!state.isInitialized) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      List<Folder> folders;

      if (state.currentFolderId == null) {
        folders = await _folderService.getRootFolders();
      } else {
        folders = await _folderService.getChildFolders(state.currentFolderId!);
      }

      // Apply sorting
      folders = _sortFolders(folders, state.sortBy);

      state = state.copyWith(folders: folders, isLoading: false);

      // Load folder stats in background
      _loadFolderStats(folders);
    } on FolderServiceException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load folders: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load folders: $e',
      );
    }
  }

  /// Refreshes the folder list.
  Future<void> refresh() async {
    if (!state.isInitialized) return;

    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      await loadFolders();
      state = state.copyWith(isRefreshing: false);
    } catch (_) {
      state = state.copyWith(isRefreshing: false);
    }
  }

  /// Loads document counts for folders.
  Future<void> _loadFolderStats(List<Folder> folders) async {
    final stats = <String, int>{};

    for (final folder in folders) {
      try {
        final count = await _folderService.getDocumentCount(folder.id);
        if (mounted) {
          stats[folder.id] = count;
        }
      } catch (_) {
        // Ignore stats loading errors
      }
    }

    if (mounted && stats.isNotEmpty) {
      state = state.copyWith(folderStats: {...state.folderStats, ...stats});
    }
  }

  /// Sorts folders based on the sort option.
  List<Folder> _sortFolders(List<Folder> folders, FoldersSortBy sortBy) {
    switch (sortBy) {
      case FoldersSortBy.name:
        return folders.sortedByName();
      case FoldersSortBy.createdDesc:
        return folders.sortedByCreatedDesc();
      case FoldersSortBy.createdAsc:
        return folders.sortedByCreatedAsc();
      case FoldersSortBy.updatedDesc:
        return folders.sortedByUpdatedDesc();
    }
  }

  /// Sets the sort option.
  void setSortBy(FoldersSortBy sortBy) {
    if (sortBy == state.sortBy) return;

    final sortedFolders = _sortFolders(state.folders, sortBy);
    state = state.copyWith(sortBy: sortBy, folders: sortedFolders);
  }

  /// Navigates into a folder.
  Future<void> navigateToFolder(Folder folder) async {
    state = state.copyWith(
      currentFolderId: folder.id,
      breadcrumbs: [...state.breadcrumbs, folder],
      clearSelection: true,
    );
    await loadFolders();
  }

  /// Navigates back to parent folder.
  Future<void> navigateBack() async {
    if (state.breadcrumbs.isEmpty) return;

    final newBreadcrumbs = List<Folder>.from(state.breadcrumbs);
    newBreadcrumbs.removeLast();

    state = state.copyWith(
      currentFolderId:
          newBreadcrumbs.isNotEmpty ? newBreadcrumbs.last.id : null,
      breadcrumbs: newBreadcrumbs,
      clearSelection: true,
    );
    await loadFolders();
  }

  /// Navigates to a specific breadcrumb.
  Future<void> navigateToBreadcrumb(int index) async {
    if (index < 0) {
      // Navigate to root
      state = state.copyWith(clearCurrentFolder: true, clearSelection: true);
    } else if (index < state.breadcrumbs.length) {
      final newBreadcrumbs = state.breadcrumbs.sublist(0, index + 1);
      state = state.copyWith(
        currentFolderId: newBreadcrumbs.last.id,
        breadcrumbs: newBreadcrumbs,
        clearSelection: true,
      );
    }
    await loadFolders();
  }

  /// Creates a new folder.
  Future<Folder?> createFolder({
    required String name,
    String? color,
    String? icon,
  }) async {
    try {
      final folder = await _folderService.createFolder(
        name: name,
        parentId: state.currentFolderId,
        color: color,
        icon: icon,
      );
      await loadFolders();
      return folder;
    } on FolderServiceException catch (e) {
      state = state.copyWith(error: 'Failed to create folder: ${e.message}');
      return null;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create folder: $e');
      return null;
    }
  }

  /// Renames a folder.
  Future<bool> renameFolder(String folderId, String newName) async {
    try {
      await _folderService.renameFolder(folderId, newName);
      await loadFolders();
      return true;
    } on FolderServiceException catch (e) {
      state = state.copyWith(error: 'Failed to rename folder: ${e.message}');
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to rename folder: $e');
      return false;
    }
  }

  /// Updates a folder's color.
  Future<bool> updateFolderColor(String folderId, String? color) async {
    try {
      await _folderService.updateFolderColor(folderId, color);
      await loadFolders();
      return true;
    } on FolderServiceException catch (e) {
      state = state.copyWith(error: 'Failed to update folder: ${e.message}');
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update folder: $e');
      return false;
    }
  }

  /// Deletes a folder.
  Future<bool> deleteFolder(String folderId) async {
    try {
      await _folderService.deleteFolder(folderId);
      await loadFolders();
      return true;
    } on FolderServiceException catch (e) {
      state = state.copyWith(error: 'Failed to delete folder: ${e.message}');
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete folder: $e');
      return false;
    }
  }

  /// Enters multi-select mode.
  void enterSelectionMode() {
    state = state.copyWith(isSelectionMode: true);
  }

  /// Exits multi-select mode.
  void exitSelectionMode() {
    state = state.copyWith(clearSelection: true);
  }

  /// Toggles selection of a folder.
  void toggleFolderSelection(String folderId) {
    final selected = Set<String>.from(state.selectedFolderIds);
    if (selected.contains(folderId)) {
      selected.remove(folderId);
    } else {
      selected.add(folderId);
    }

    state = state.copyWith(
      selectedFolderIds: selected,
      isSelectionMode: selected.isNotEmpty,
    );
  }

  /// Selects all folders.
  void selectAll() {
    state = state.copyWith(
      selectedFolderIds: state.folders.map((f) => f.id).toSet(),
      isSelectionMode: true,
    );
  }

  /// Clears selection.
  void clearSelection() {
    state = state.copyWith(clearSelection: true);
  }

  /// Deletes selected folders.
  Future<void> deleteSelected() async {
    if (state.selectedFolderIds.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _folderService.deleteFolders(state.selectedFolderIds.toList());
      state = state.copyWith(clearSelection: true);
      await loadFolders();
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

  /// Clears the current error.
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Riverpod provider for the folders screen state.
final foldersScreenProvider = StateNotifierProvider.autoDispose<
    FoldersScreenNotifier, FoldersScreenState>((ref) {
  final folderService = ref.watch(folderServiceProvider);
  return FoldersScreenNotifier(folderService);
});

/// Main folder management screen.
///
/// Provides functionality for:
/// - Viewing folders in a list
/// - Creating new folders
/// - Renaming folders
/// - Deleting folders
/// - Navigating folder hierarchy
/// - Multi-select for batch operations
///
/// ## Usage
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => const FoldersScreen()),
/// );
/// ```
class FoldersScreen extends ConsumerStatefulWidget {
  /// Creates a [FoldersScreen].
  const FoldersScreen({
    super.key,
    this.onFolderSelected,
    this.selectionMode = false,
    this.excludeFolderId,
  });

  /// Callback invoked when a folder is selected.
  /// If provided, tapping a folder calls this instead of navigating.
  final void Function(Folder folder)? onFolderSelected;

  /// Whether to operate in selection mode (for folder pickers).
  final bool selectionMode;

  /// Folder ID to exclude from the list (with its descendants).
  final String? excludeFolderId;

  @override
  ConsumerState<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends ConsumerState<FoldersScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(foldersScreenProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(foldersScreenProvider);
    final notifier = ref.read(foldersScreenProvider.notifier);
    final theme = Theme.of(context);

    // Listen for errors and show snackbar
    ref.listen<FoldersScreenState>(foldersScreenProvider, (prev, next) {
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
      floatingActionButton: _buildFab(context, state, notifier),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    FoldersScreenState state,
    FoldersScreenNotifier notifier,
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
      leading: widget.selectionMode || !state.isAtRoot
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (widget.selectionMode) {
                  Navigator.of(context).pop();
                } else if (!state.isAtRoot) {
                  notifier.navigateBack();
                }
              },
              tooltip: 'Back',
            )
          : null,
      title: Text(state.currentFolder?.name ?? 'Folders'),
      actions: [
        // Sort button
        PopupMenuButton<FoldersSortBy>(
          icon: const Icon(Icons.sort),
          tooltip: 'Sort folders',
          onSelected: notifier.setSortBy,
          itemBuilder: (context) => FoldersSortBy.values.map((sort) {
            return PopupMenuItem(
              value: sort,
              child: Row(
                children: [
                  Icon(
                    sort.icon,
                    size: 20,
                    color:
                        state.sortBy == sort ? theme.colorScheme.primary : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    sort.label,
                    style: TextStyle(
                      fontWeight: state.sortBy == sort
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: state.sortBy == sort
                          ? theme.colorScheme.primary
                          : null,
                    ),
                  ),
                  if (state.sortBy == sort) ...[
                    const Spacer(),
                    Icon(
                      Icons.check,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    FoldersScreenState state,
    FoldersScreenNotifier notifier,
    ThemeData theme,
  ) {
    final l10n = AppLocalizations.of(context);
    if (!state.isInitialized && state.isLoading) {
      return BentoLoadingView(
        message: l10n?.loading ?? 'Loading...',
      );
    }

    if (state.hasError && !state.hasFolders) {
      return BentoErrorView(
        message: state.error!,
        onRetry: notifier.initialize,
      );
    }

    return Column(
      children: [
        // Breadcrumb navigation
        if (!state.isAtRoot)
          _BreadcrumbBar(
            breadcrumbs: state.breadcrumbs,
            onTap: notifier.navigateToBreadcrumb,
          ),
        // Folder list
        Expanded(
          child: state.hasFolders
              ? RefreshIndicator(
                  onRefresh: notifier.refresh,
                  child: _FoldersList(
                    folders: _filterFolders(state.folders),
                    folderStats: state.folderStats,
                    selectedIds: state.selectedFolderIds,
                    isSelectionMode: state.isSelectionMode,
                    onFolderTap: (folder) =>
                        _handleFolderTap(folder, state, notifier),
                    onFolderLongPress: (folder) =>
                        _handleFolderLongPress(folder, notifier),
                    onRename: (folder) =>
                        _showRenameDialog(context, folder, notifier),
                    onDelete: (folder) => _showDeleteSingleConfirmation(
                      context,
                      folder,
                      notifier,
                    ),
                    onChangeColor: (folder) =>
                        _showColorPicker(context, folder, notifier),
                    theme: theme,
                  ),
                )
              : BentoEmptyView(
                  title: state.isAtRoot
                      ? (l10n?.noFoldersYet ?? 'No folders yet')
                      : (l10n?.noDocuments ?? 'This folder is empty'),
                  description: l10n?.createFolderToOrganize ??
                      'Create a folder to organize your documents',
                  icon: Icons.folder_outlined,
                  actionLabel: l10n?.createFolder ?? 'Create folder',
                  onAction: () => _showCreateDialog(context, notifier),
                ),
        ),
      ],
    );
  }

  List<Folder> _filterFolders(List<Folder> folders) {
    if (widget.excludeFolderId == null) return folders;

    // Exclude the folder and its descendants
    return folders.where((f) {
      if (f.id == widget.excludeFolderId) return false;
      return !folders.isDescendantOf(f.id, widget.excludeFolderId!);
    }).toList();
  }

  Widget? _buildFab(
    BuildContext context,
    FoldersScreenState state,
    FoldersScreenNotifier notifier,
  ) {
    if (state.isSelectionMode || widget.selectionMode) return null;

    return FloatingActionButton.extended(
      onPressed: () => _showCreateDialog(context, notifier),
      icon: const Icon(Icons.create_new_folder_outlined),
      label: const Text('New Folder'),
      tooltip: 'Create new folder',
    );
  }

  void _handleFolderTap(
    Folder folder,
    FoldersScreenState state,
    FoldersScreenNotifier notifier,
  ) {
    if (state.isSelectionMode) {
      notifier.toggleFolderSelection(folder.id);
    } else if (widget.onFolderSelected != null) {
      widget.onFolderSelected!(folder);
    } else if (widget.selectionMode) {
      Navigator.of(context).pop(folder);
    } else {
      notifier.navigateToFolder(folder);
    }
  }

  void _handleFolderLongPress(Folder folder, FoldersScreenNotifier notifier) {
    if (widget.selectionMode) return;

    notifier.enterSelectionMode();
    notifier.toggleFolderSelection(folder.id);
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    FoldersScreenNotifier notifier,
  ) async {
    final result = await showBentoFolderDialog(context);

    if (result != null && result.name.isNotEmpty && mounted) {
      await notifier.createFolder(name: result.name, color: result.color);
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    Folder folder,
    FoldersScreenNotifier notifier,
  ) async {
    final result = await showBentoFolderDialog(context, folder: folder);

    if (result != null && result.name.isNotEmpty && mounted) {
      if (result.name != folder.name) {
        await notifier.renameFolder(folder.id, result.name);
      }
      if (result.color != folder.color || result.clearColor) {
        await notifier.updateFolderColor(folder.id, result.color);
      }
    }
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    FoldersScreenState state,
    FoldersScreenNotifier notifier,
  ) async {
    final confirmed = await showBentoConfirmationDialog(
      context,
      title: 'Delete folders?',
      message: 'Are you sure you want to delete ${state.selectedCount} '
          '${state.selectedCount == 1 ? 'folder' : 'folders'}?\n\n'
          'Documents inside will be moved to the root level.',
      confirmButtonText: 'Delete',
      isDestructive: true,
      mascotAssetPath: 'assets/images/scanai_sad.png',
      speechBubbleText: 'Are you sure?',
    );

    if (confirmed == true) {
      await notifier.deleteSelected();
    }
  }

  Future<void> _showDeleteSingleConfirmation(
    BuildContext context,
    Folder folder,
    FoldersScreenNotifier notifier,
  ) async {
    final confirmed = await showBentoConfirmationDialog(
      context,
      title: 'Delete folder?',
      message: 'Are you sure you want to delete "${folder.name}"?\n\n'
          'Documents inside will be moved to the root level.',
      confirmButtonText: 'Delete',
      isDestructive: true,
      mascotAssetPath: 'assets/images/scanai_sad.png',
      speechBubbleText: 'Are you sure?',
    );

    if (confirmed == true) {
      await notifier.deleteFolder(folder.id);
    }
  }

  Future<void> _showColorPicker(
    BuildContext context,
    Folder folder,
    FoldersScreenNotifier notifier,
  ) async {
    final color = await showDialog<String?>(
      context: context,
      builder: (context) => _ColorPickerDialog(currentColor: folder.color),
    );

    if (mounted && color != folder.color) {
      await notifier.updateFolderColor(folder.id, color);
    }
  }
}

/// Breadcrumb navigation bar.
class _BreadcrumbBar extends StatelessWidget {
  const _BreadcrumbBar({required this.breadcrumbs, required this.onTap});

  final List<Folder> breadcrumbs;
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Root button
            InkWell(
              onTap: () => onTap(-1),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.home_outlined,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Folders',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Breadcrumb items
            for (int i = 0; i < breadcrumbs.length; i++) ...[
              Icon(
                Icons.chevron_right,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              InkWell(
                onTap: i < breadcrumbs.length - 1 ? () => onTap(i) : null,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    breadcrumbs[i].name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: i < breadcrumbs.length - 1
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                      fontWeight: i < breadcrumbs.length - 1
                          ? FontWeight.w500
                          : FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// List view for folders.
class _FoldersList extends StatelessWidget {
  const _FoldersList({
    required this.folders,
    required this.folderStats,
    required this.selectedIds,
    required this.isSelectionMode,
    required this.onFolderTap,
    required this.onFolderLongPress,
    required this.onRename,
    required this.onDelete,
    required this.onChangeColor,
    required this.theme,
  });

  final List<Folder> folders;
  final Map<String, int> folderStats;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final void Function(Folder) onFolderTap;
  final void Function(Folder) onFolderLongPress;
  final void Function(Folder) onRename;
  final void Function(Folder) onDelete;
  final void Function(Folder) onChangeColor;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        final isSelected = selectedIds.contains(folder.id);
        final documentCount = folderStats[folder.id];

        return _FolderListItem(
          folder: folder,
          documentCount: documentCount,
          isSelected: isSelected,
          isSelectionMode: isSelectionMode,
          onTap: () => onFolderTap(folder),
          onLongPress: () => onFolderLongPress(folder),
          onRename: () => onRename(folder),
          onDelete: () => onDelete(folder),
          onChangeColor: () => onChangeColor(folder),
          theme: theme,
        );
      },
    );
  }
}

/// Single folder list item.
class _FolderListItem extends StatelessWidget {
  const _FolderListItem({
    required this.folder,
    required this.documentCount,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onRename,
    required this.onDelete,
    required this.onChangeColor,
    required this.theme,
  });

  final Folder folder;
  final int? documentCount;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onChangeColor;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final folderColor =
        folder.hasColor ? _parseColor(folder.color!) : colorScheme.primary;

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withOpacity(0.3)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: colorScheme.onPrimary,
                          )
                        : null,
                  ),
                ),

              // Folder icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: folderColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.folder, color: folderColor, size: 28),
              ),
              const SizedBox(width: 16),

              // Folder info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      documentCount != null
                          ? '$documentCount ${documentCount == 1 ? 'document' : 'documents'}'
                          : 'Loading...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Options menu
              if (!isSelectionMode)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'More options',
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        onRename();
                        break;
                      case 'color':
                        onChangeColor();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Rename'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'color',
                      child: Row(
                        children: [
                          Icon(Icons.palette_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Change color'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Delete',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                const SizedBox(width: 48),

              // Navigation arrow
              if (!isSelectionMode)
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {
      // Fall through to default
    }
    return Colors.blue;
  }
}

/// Color picker dialog.
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({this.currentColor});

  final String? currentColor;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  String? _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.currentColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Color'),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          // No color option
          _ColorOption(
            color: null,
            isSelected: _selectedColor == null,
            onTap: () => setState(() => _selectedColor = null),
            size: 48,
          ),
          // Predefined colors
          for (final color in _folderColors)
            _ColorOption(
              color: color,
              isSelected: _selectedColor == color,
              onTap: () => setState(() => _selectedColor = color),
              size: 48,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(widget.currentColor),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedColor),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

/// Color option widget.
class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.size = 36,
  });

  final String? color;
  final bool isSelected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final displayColor =
        color != null ? _parseColor(color!) : colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color != null
              ? displayColor
              : colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: color == null
            ? Icon(
                Icons.block,
                size: size * 0.5,
                color: colorScheme.onSurfaceVariant,
              )
            : isSelected
                ? Icon(
                    Icons.check,
                    size: size * 0.5,
                    color: _getContrastColor(displayColor),
                  )
                : null,
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {
      // Fall through to default
    }
    return Colors.blue;
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

/// Predefined folder colors.
const _folderColors = [
  '#E53935', // Red
  '#FB8C00', // Orange
  '#FDD835', // Yellow
  '#43A047', // Green
  '#00ACC1', // Cyan
  '#1E88E5', // Blue
  '#5E35B1', // Deep Purple
  '#8E24AA', // Purple
  '#D81B60', // Pink
  '#6D4C41', // Brown
  '#757575', // Grey
];
