import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/signature_service.dart';
import 'signature_screen.dart';

/// Sort options for saved signatures.
enum SignaturesSortBy {
  /// Sort by label (alphabetically).
  label('Label', Icons.sort_by_alpha),

  /// Sort by creation date (newest first).
  createdDesc('Recent', Icons.schedule),

  /// Sort by creation date (oldest first).
  createdAsc('Oldest', Icons.history);

  const SignaturesSortBy(this.label, this.icon);

  /// Display label for this sort option.
  final String label;

  /// Icon for this sort option.
  final IconData icon;
}

/// State for the saved signatures screen.
@immutable
class SavedSignaturesScreenState {
  /// Creates a [SavedSignaturesScreenState] with default values.
  const SavedSignaturesScreenState({
    this.signatures = const [],
    this.sortBy = SignaturesSortBy.createdDesc,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isInitialized = false,
    this.error,
    this.selectedSignatureIds = const {},
    this.isSelectionMode = false,
    this.signatureImages = const {},
    this.storageSize,
  });

  /// The list of saved signatures.
  final List<SavedSignature> signatures;

  /// Current sort option.
  final SignaturesSortBy sortBy;

  /// Whether signatures are being loaded.
  final bool isLoading;

  /// Whether signatures are being refreshed.
  final bool isRefreshing;

  /// Whether the service has been initialized.
  final bool isInitialized;

  /// Error message, if any.
  final String? error;

  /// Set of selected signature IDs for multi-select mode.
  final Set<String> selectedSignatureIds;

  /// Whether multi-select mode is active.
  final bool isSelectionMode;

  /// Cache of loaded signature images (id -> bytes).
  final Map<String, Uint8List> signatureImages;

  /// Total storage size used by signatures.
  final String? storageSize;

  /// Whether we have any signatures.
  bool get hasSignatures => signatures.isNotEmpty;

  /// Whether there's an error.
  bool get hasError => error != null;

  /// The count of signatures.
  int get signatureCount => signatures.length;

  /// The count of selected signatures.
  int get selectedCount => selectedSignatureIds.length;

  /// Whether all signatures are selected.
  bool get allSelected =>
      signatures.isNotEmpty && selectedSignatureIds.length == signatures.length;

  /// The default signature, if any.
  SavedSignature? get defaultSignature =>
      signatures.where((s) => s.isDefault).firstOrNull;

  /// Creates a copy with updated values.
  SavedSignaturesScreenState copyWith({
    List<SavedSignature>? signatures,
    SignaturesSortBy? sortBy,
    bool? isLoading,
    bool? isRefreshing,
    bool? isInitialized,
    String? error,
    Set<String>? selectedSignatureIds,
    bool? isSelectionMode,
    Map<String, Uint8List>? signatureImages,
    String? storageSize,
    bool clearError = false,
    bool clearSelection = false,
    bool clearImages = false,
  }) {
    return SavedSignaturesScreenState(
      signatures: signatures ?? this.signatures,
      sortBy: sortBy ?? this.sortBy,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isInitialized: isInitialized ?? this.isInitialized,
      error: clearError ? null : (error ?? this.error),
      selectedSignatureIds: clearSelection
          ? const {}
          : (selectedSignatureIds ?? this.selectedSignatureIds),
      isSelectionMode: clearSelection
          ? false
          : (isSelectionMode ?? this.isSelectionMode),
      signatureImages: clearImages
          ? const {}
          : (signatureImages ?? this.signatureImages),
      storageSize: storageSize ?? this.storageSize,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedSignaturesScreenState &&
        other.sortBy == sortBy &&
        other.isLoading == isLoading &&
        other.isRefreshing == isRefreshing &&
        other.isInitialized == isInitialized &&
        other.error == error &&
        other.isSelectionMode == isSelectionMode &&
        other.signatureCount == signatureCount &&
        other.storageSize == storageSize;
  }

  @override
  int get hashCode => Object.hash(
    sortBy,
    isLoading,
    isRefreshing,
    isInitialized,
    error,
    isSelectionMode,
    signatureCount,
    storageSize,
  );
}

/// State notifier for the saved signatures screen.
///
/// Manages signature loading, selection, and deletion.
class SavedSignaturesScreenNotifier
    extends StateNotifier<SavedSignaturesScreenState> {
  /// Creates a [SavedSignaturesScreenNotifier] with the given service.
  SavedSignaturesScreenNotifier(this._signatureService)
    : super(const SavedSignaturesScreenState());

  final SignatureService _signatureService;

  /// Initializes the screen and loads signatures.
  Future<void> initialize() async {
    if (state.isInitialized) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _signatureService.initialize();
      state = state.copyWith(isInitialized: true);
      await loadSignatures();
      await _loadStorageSize();
    } on SignatureException catch (e) {
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

  /// Loads all saved signatures.
  Future<void> loadSignatures() async {
    if (!state.isInitialized) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      var signatures = await _signatureService.getAllSignatures();

      // Apply sorting
      signatures = _sortSignatures(signatures, state.sortBy);

      state = state.copyWith(signatures: signatures, isLoading: false);

      // Load signature images in background
      _loadSignatureImages(signatures);
    } on SignatureException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load signatures: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load signatures: $e',
      );
    }
  }

  /// Refreshes the signature list.
  Future<void> refresh() async {
    if (!state.isInitialized) return;

    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      await loadSignatures();
      await _loadStorageSize();
      state = state.copyWith(isRefreshing: false);
    } catch (_) {
      state = state.copyWith(isRefreshing: false);
    }
  }

  /// Loads signature images for display.
  Future<void> _loadSignatureImages(List<SavedSignature> signatures) async {
    final images = <String, Uint8List>{...state.signatureImages};

    for (final signature in signatures) {
      if (images.containsKey(signature.id)) continue;

      try {
        final bytes = await _signatureService.loadSignatureImage(signature);
        if (mounted) {
          images[signature.id] = bytes;
        }
      } catch (_) {
        // Ignore image loading errors
      }
    }

    if (mounted && images.length > state.signatureImages.length) {
      state = state.copyWith(signatureImages: images);
    }
  }

  /// Loads the total storage size.
  Future<void> _loadStorageSize() async {
    try {
      final size = await _signatureService.getStorageSizeFormatted();
      if (mounted) {
        state = state.copyWith(storageSize: size);
      }
    } catch (_) {
      // Ignore storage size errors
    }
  }

  /// Sorts signatures based on the sort option.
  List<SavedSignature> _sortSignatures(
    List<SavedSignature> signatures,
    SignaturesSortBy sortBy,
  ) {
    // Always put default signature first
    final defaultSig = signatures.where((s) => s.isDefault).toList();
    final otherSigs = signatures.where((s) => !s.isDefault).toList();

    switch (sortBy) {
      case SignaturesSortBy.label:
        otherSigs.sort(
          (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
        );
      case SignaturesSortBy.createdDesc:
        otherSigs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case SignaturesSortBy.createdAsc:
        otherSigs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    return [...defaultSig, ...otherSigs];
  }

  /// Sets the sort option.
  void setSortBy(SignaturesSortBy sortBy) {
    if (sortBy == state.sortBy) return;

    final sortedSignatures = _sortSignatures(state.signatures, sortBy);
    state = state.copyWith(sortBy: sortBy, signatures: sortedSignatures);
  }

  /// Sets a signature as the default.
  Future<bool> setDefault(String signatureId) async {
    try {
      await _signatureService.setDefaultSignature(signatureId);
      await loadSignatures();
      return true;
    } on SignatureException catch (e) {
      state = state.copyWith(error: 'Failed to set default: ${e.message}');
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to set default: $e');
      return false;
    }
  }

  /// Clears the default signature.
  Future<bool> clearDefault() async {
    try {
      await _signatureService.clearDefaultSignature();
      await loadSignatures();
      return true;
    } on SignatureException catch (e) {
      state = state.copyWith(error: 'Failed to clear default: ${e.message}');
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to clear default: $e');
      return false;
    }
  }

  /// Renames a signature.
  Future<bool> renameSignature(String signatureId, String newLabel) async {
    try {
      await _signatureService.updateSignatureLabel(signatureId, newLabel);
      await loadSignatures();
      return true;
    } on SignatureException catch (e) {
      state = state.copyWith(error: 'Failed to rename: ${e.message}');
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to rename: $e');
      return false;
    }
  }

  /// Deletes a signature.
  Future<bool> deleteSignature(String signatureId) async {
    try {
      await _signatureService.deleteSignature(signatureId);

      // Remove from image cache
      final images = Map<String, Uint8List>.from(state.signatureImages);
      images.remove(signatureId);

      state = state.copyWith(signatureImages: images);
      await loadSignatures();
      await _loadStorageSize();
      return true;
    } on SignatureException catch (e) {
      state = state.copyWith(error: 'Failed to delete: ${e.message}');
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete: $e');
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

  /// Toggles selection of a signature.
  void toggleSignatureSelection(String signatureId) {
    final selected = Set<String>.from(state.selectedSignatureIds);
    if (selected.contains(signatureId)) {
      selected.remove(signatureId);
    } else {
      selected.add(signatureId);
    }

    state = state.copyWith(
      selectedSignatureIds: selected,
      isSelectionMode: selected.isNotEmpty,
    );
  }

  /// Selects all signatures.
  void selectAll() {
    state = state.copyWith(
      selectedSignatureIds: state.signatures.map((s) => s.id).toSet(),
      isSelectionMode: true,
    );
  }

  /// Clears selection.
  void clearSelection() {
    state = state.copyWith(clearSelection: true);
  }

  /// Deletes selected signatures.
  Future<void> deleteSelected() async {
    if (state.selectedSignatureIds.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _signatureService.deleteSignatures(
        state.selectedSignatureIds.toList(),
      );

      // Remove from image cache
      final images = Map<String, Uint8List>.from(state.signatureImages);
      for (final id in state.selectedSignatureIds) {
        images.remove(id);
      }

      state = state.copyWith(signatureImages: images, clearSelection: true);
      await loadSignatures();
      await _loadStorageSize();
    } on SignatureException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete signatures: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete signatures: $e',
      );
    }
  }

  /// Clears all signatures.
  Future<bool> clearAllSignatures() async {
    try {
      await _signatureService.clearAllSignatures();
      state = state.copyWith(clearImages: true);
      await loadSignatures();
      await _loadStorageSize();
      return true;
    } on SignatureException catch (e) {
      state = state.copyWith(error: 'Failed to clear signatures: ${e.message}');
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to clear signatures: $e');
      return false;
    }
  }

  /// Clears the current error.
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Riverpod provider for the saved signatures screen state.
final savedSignaturesScreenProvider =
    StateNotifierProvider.autoDispose<
      SavedSignaturesScreenNotifier,
      SavedSignaturesScreenState
    >((ref) {
      final signatureService = ref.watch(signatureServiceProvider);
      return SavedSignaturesScreenNotifier(signatureService);
    });

/// Saved signatures management screen.
///
/// Provides functionality for:
/// - Viewing saved signatures with thumbnails
/// - Setting a default signature
/// - Renaming signatures
/// - Deleting signatures (single and batch)
/// - Creating new signatures
/// - Selecting a signature for use
///
/// ## Usage
/// ```dart
/// // View/manage signatures
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => const SavedSignaturesScreen()),
/// );
///
/// // Select a signature for use
/// final signature = await Navigator.push<SavedSignature>(
///   context,
///   MaterialPageRoute(
///     builder: (_) => const SavedSignaturesScreen(selectionMode: true),
///   ),
/// );
/// ```
class SavedSignaturesScreen extends ConsumerStatefulWidget {
  /// Creates a [SavedSignaturesScreen].
  const SavedSignaturesScreen({
    super.key,
    this.onSignatureSelected,
    this.selectionMode = false,
    this.title,
  });

  /// Callback invoked when a signature is selected.
  final void Function(SavedSignature signature, Uint8List imageBytes)?
  onSignatureSelected;

  /// Whether to operate in selection mode.
  final bool selectionMode;

  /// Optional custom title.
  final String? title;

  @override
  ConsumerState<SavedSignaturesScreen> createState() =>
      _SavedSignaturesScreenState();
}

class _SavedSignaturesScreenState extends ConsumerState<SavedSignaturesScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(savedSignaturesScreenProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(savedSignaturesScreenProvider);
    final notifier = ref.read(savedSignaturesScreenProvider.notifier);
    final theme = Theme.of(context);

    // Listen for errors and show snackbar
    ref.listen<SavedSignaturesScreenState>(savedSignaturesScreenProvider, (
      prev,
      next,
    ) {
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
    SavedSignaturesScreenState state,
    SavedSignaturesScreenNotifier notifier,
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
      leading: widget.selectionMode
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Close',
            )
          : null,
      title: Text(widget.title ?? 'Saved Signatures'),
      actions: [
        // Sort button
        PopupMenuButton<SignaturesSortBy>(
          icon: const Icon(Icons.sort),
          tooltip: 'Sort signatures',
          onSelected: notifier.setSortBy,
          itemBuilder: (context) => SignaturesSortBy.values.map((sort) {
            return PopupMenuItem(
              value: sort,
              child: Row(
                children: [
                  Icon(
                    sort.icon,
                    size: 20,
                    color: state.sortBy == sort
                        ? theme.colorScheme.primary
                        : null,
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
        // More options menu
        if (!widget.selectionMode)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            onSelected: (value) {
              switch (value) {
                case 'clear_all':
                  _showClearAllConfirmation(context, notifier);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear_all',
                enabled: state.hasSignatures,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_sweep_outlined,
                      size: 20,
                      color: state.hasSignatures
                          ? theme.colorScheme.error
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Clear all',
                      style: TextStyle(
                        color: state.hasSignatures
                            ? theme.colorScheme.error
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    SavedSignaturesScreenState state,
    SavedSignaturesScreenNotifier notifier,
    ThemeData theme,
  ) {
    if (!state.isInitialized && state.isLoading) {
      return const _LoadingView();
    }

    if (state.hasError && !state.hasSignatures) {
      return _ErrorView(message: state.error!, onRetry: notifier.initialize);
    }

    return Column(
      children: [
        // Storage info bar
        if (state.storageSize != null && !widget.selectionMode)
          _StorageInfoBar(
            signatureCount: state.signatureCount,
            storageSize: state.storageSize!,
            theme: theme,
          ),
        // Signature list
        Expanded(
          child: state.hasSignatures
              ? RefreshIndicator(
                  onRefresh: notifier.refresh,
                  child: _SignaturesList(
                    signatures: state.signatures,
                    signatureImages: state.signatureImages,
                    selectedIds: state.selectedSignatureIds,
                    isSelectionMode: state.isSelectionMode,
                    selectionPickerMode: widget.selectionMode,
                    onSignatureTap: (sig) =>
                        _handleSignatureTap(context, sig, state, notifier),
                    onSignatureLongPress: (sig) =>
                        _handleSignatureLongPress(sig, notifier),
                    onRename: (sig) =>
                        _showRenameDialog(context, sig, notifier),
                    onDelete: (sig) =>
                        _showDeleteSingleConfirmation(context, sig, notifier),
                    onSetDefault: (sig) => notifier.setDefault(sig.id),
                    onClearDefault: () => notifier.clearDefault(),
                    theme: theme,
                  ),
                )
              : _EmptyView(
                  onCreateSignature: () => _navigateToCreateSignature(context),
                ),
        ),
      ],
    );
  }

  Widget? _buildFab(
    BuildContext context,
    SavedSignaturesScreenState state,
    SavedSignaturesScreenNotifier notifier,
  ) {
    if (state.isSelectionMode) return null;

    return FloatingActionButton.extended(
      onPressed: () => _navigateToCreateSignature(context),
      icon: const Icon(Icons.add),
      label: const Text('New Signature'),
      tooltip: 'Create new signature',
    );
  }

  void _handleSignatureTap(
    BuildContext context,
    SavedSignature signature,
    SavedSignaturesScreenState state,
    SavedSignaturesScreenNotifier notifier,
  ) {
    if (state.isSelectionMode) {
      notifier.toggleSignatureSelection(signature.id);
    } else if (widget.selectionMode) {
      // Return selected signature
      final imageBytes = state.signatureImages[signature.id];
      if (imageBytes != null) {
        widget.onSignatureSelected?.call(signature, imageBytes);
        Navigator.of(context).pop(signature);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Loading signature...')));
      }
    } else {
      // Show signature detail bottom sheet
      _showSignatureDetailSheet(context, signature, state, notifier);
    }
  }

  void _handleSignatureLongPress(
    SavedSignature signature,
    SavedSignaturesScreenNotifier notifier,
  ) {
    if (widget.selectionMode) return;

    notifier.enterSelectionMode();
    notifier.toggleSignatureSelection(signature.id);
  }

  Future<void> _navigateToCreateSignature(BuildContext context) async {
    final result = await Navigator.of(context).push<SavedSignature>(
      MaterialPageRoute(builder: (context) => const SignatureScreen()),
    );

    if (result != null && mounted) {
      // Refresh the list
      ref.read(savedSignaturesScreenProvider.notifier).refresh();
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    SavedSignature signature,
    SavedSignaturesScreenNotifier notifier,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(currentLabel: signature.label),
    );

    if (result != null && result.isNotEmpty && mounted) {
      await notifier.renameSignature(signature.id, result);
    }
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    SavedSignaturesScreenState state,
    SavedSignaturesScreenNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete signatures?'),
        content: Text(
          'Are you sure you want to delete ${state.selectedCount} '
          '${state.selectedCount == 1 ? 'signature' : 'signatures'}?\n\n'
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

  Future<void> _showDeleteSingleConfirmation(
    BuildContext context,
    SavedSignature signature,
    SavedSignaturesScreenNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete signature?'),
        content: Text(
          'Are you sure you want to delete "${signature.label}"?\n\n'
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
      await notifier.deleteSignature(signature.id);
    }
  }

  Future<void> _showClearAllConfirmation(
    BuildContext context,
    SavedSignaturesScreenNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all signatures?'),
        content: const Text(
          'Are you sure you want to delete ALL saved signatures?\n\n'
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
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await notifier.clearAllSignatures();
    }
  }

  void _showSignatureDetailSheet(
    BuildContext context,
    SavedSignature signature,
    SavedSignaturesScreenState state,
    SavedSignaturesScreenNotifier notifier,
  ) {
    final theme = Theme.of(context);
    final imageBytes = state.signatureImages[signature.id];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Signature preview
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: imageBytes != null
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Image.memory(
                        imageBytes,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 16),

            // Label with default badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  signature.label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (signature.isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Default',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Created date
            Text(
              'Created ${_formatDate(signature.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showRenameDialog(context, signature, notifier);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Rename'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: signature.isDefault
                      ? OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            notifier.clearDefault();
                          },
                          icon: const Icon(Icons.star_outline, size: 18),
                          label: const Text('Unset Default'),
                        )
                      : FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            notifier.setDefault(signature.id);
                          },
                          icon: const Icon(Icons.star, size: 18),
                          label: const Text('Set Default'),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showDeleteSingleConfirmation(context, signature, notifier);
                },
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                label: Text(
                  'Delete',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.colorScheme.error),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
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

/// Empty state view.
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onCreateSignature});

  final VoidCallback onCreateSignature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.draw_outlined,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.6),
            ),
            const SizedBox(height: 24),
            Text(
              'No signatures saved',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first signature to use when signing documents',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onCreateSignature,
              icon: const Icon(Icons.add),
              label: const Text('Create Signature'),
              style: FilledButton.styleFrom(minimumSize: const Size(200, 56)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Storage info bar.
class _StorageInfoBar extends StatelessWidget {
  const _StorageInfoBar({
    required this.signatureCount,
    required this.storageSize,
    required this.theme,
  });

  final int signatureCount;
  final String storageSize;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.draw_outlined,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '$signatureCount ${signatureCount == 1 ? 'signature' : 'signatures'}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.storage_outlined,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            storageSize,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// List view for signatures.
class _SignaturesList extends StatelessWidget {
  const _SignaturesList({
    required this.signatures,
    required this.signatureImages,
    required this.selectedIds,
    required this.isSelectionMode,
    required this.selectionPickerMode,
    required this.onSignatureTap,
    required this.onSignatureLongPress,
    required this.onRename,
    required this.onDelete,
    required this.onSetDefault,
    required this.onClearDefault,
    required this.theme,
  });

  final List<SavedSignature> signatures;
  final Map<String, Uint8List> signatureImages;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final bool selectionPickerMode;
  final void Function(SavedSignature) onSignatureTap;
  final void Function(SavedSignature) onSignatureLongPress;
  final void Function(SavedSignature) onRename;
  final void Function(SavedSignature) onDelete;
  final void Function(SavedSignature) onSetDefault;
  final VoidCallback onClearDefault;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: signatures.length,
      itemBuilder: (context, index) {
        final signature = signatures[index];
        final isSelected = selectedIds.contains(signature.id);
        final imageBytes = signatureImages[signature.id];

        return _SignatureListItem(
          signature: signature,
          imageBytes: imageBytes,
          isSelected: isSelected,
          isSelectionMode: isSelectionMode,
          selectionPickerMode: selectionPickerMode,
          onTap: () => onSignatureTap(signature),
          onLongPress: () => onSignatureLongPress(signature),
          onRename: () => onRename(signature),
          onDelete: () => onDelete(signature),
          onSetDefault: () => onSetDefault(signature),
          onClearDefault: onClearDefault,
          theme: theme,
        );
      },
    );
  }
}

/// Single signature list item.
class _SignatureListItem extends StatelessWidget {
  const _SignatureListItem({
    required this.signature,
    required this.imageBytes,
    required this.isSelected,
    required this.isSelectionMode,
    required this.selectionPickerMode,
    required this.onTap,
    required this.onLongPress,
    required this.onRename,
    required this.onDelete,
    required this.onSetDefault,
    required this.onClearDefault,
    required this.theme,
  });

  final SavedSignature signature;
  final Uint8List? imageBytes;
  final bool isSelected;
  final bool isSelectionMode;
  final bool selectionPickerMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;
  final VoidCallback onClearDefault;
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
        onLongPress: selectionPickerMode ? null : onLongPress,
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

              // Signature thumbnail
              Container(
                width: 80,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: signature.isDefault
                        ? colorScheme.primary
                        : colorScheme.outline.withOpacity(0.3),
                    width: signature.isDefault ? 2 : 1,
                  ),
                ),
                child: imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Image.memory(
                            imageBytes,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      )
                    : Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 16),

              // Signature info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            signature.label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (signature.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 12,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Default',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(signature.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Options menu
              if (!isSelectionMode && !selectionPickerMode)
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
                      case 'set_default':
                        onSetDefault();
                        break;
                      case 'clear_default':
                        onClearDefault();
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
                    if (!signature.isDefault)
                      const PopupMenuItem(
                        value: 'set_default',
                        child: Row(
                          children: [
                            Icon(Icons.star_outline, size: 20),
                            SizedBox(width: 12),
                            Text('Set as default'),
                          ],
                        ),
                      )
                    else
                      const PopupMenuItem(
                        value: 'clear_default',
                        child: Row(
                          children: [
                            Icon(Icons.star_border, size: 20),
                            SizedBox(width: 12),
                            Text('Remove default'),
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
              else if (selectionPickerMode)
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant)
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Created today';
    } else if (diff.inDays == 1) {
      return 'Created yesterday';
    } else if (diff.inDays < 7) {
      return 'Created ${diff.inDays} days ago';
    } else {
      return 'Created ${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Rename dialog.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.currentLabel});

  final String currentLabel;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentLabel);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Signature'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Label',
          hintText: 'Enter signature label',
          errorText: _error,
          prefixIcon: const Icon(Icons.label_outline),
          border: const OutlineInputBorder(),
        ),
        textCapitalization: TextCapitalization.words,
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
        FilledButton(onPressed: _submit, child: const Text('Rename')),
      ],
    );
  }

  void _submit() {
    final label = _controller.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Label cannot be empty');
      return;
    }

    Navigator.of(context).pop(label);
  }
}
