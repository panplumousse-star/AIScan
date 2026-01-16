import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/storage/document_repository.dart';
import '../../folders/domain/folder_model.dart';
import '../../folders/domain/folder_service.dart';
import '../../sharing/domain/document_share_service.dart';
// TODO: Re-enable when signature feature is fixed
// import '../../signature/presentation/widgets/signature_overlay.dart';
import '../domain/document_model.dart';

/// State for the document detail screen.
@immutable
class DocumentDetailScreenState {
  /// Creates a [DocumentDetailScreenState] with default values.
  const DocumentDetailScreenState({
    this.document,
    this.decryptedFilePath,
    this.decryptedThumbnailPath,
    this.imageBytes,
    this.currentPage = 0,
    this.isLoading = false,
    this.isDecrypting = false,
    this.isDeleting = false,
    this.isFullScreen = false,
    this.error,
  });

  /// The document being displayed.
  final Document? document;

  /// Path to the decrypted document file.
  final String? decryptedFilePath;

  /// Path to the decrypted thumbnail.
  final String? decryptedThumbnailPath;

  /// Decrypted image bytes for display.
  final Uint8List? imageBytes;

  /// Current page index (for multi-page documents).
  final int currentPage;

  /// Whether document is being loaded.
  final bool isLoading;

  /// Whether document is being decrypted.
  final bool isDecrypting;

  /// Whether document is being deleted.
  final bool isDeleting;

  /// Whether fullscreen mode is active.
  final bool isFullScreen;

  /// Error message, if any.
  final String? error;

  /// Whether we have a document loaded.
  bool get hasDocument => document != null;

  /// Whether we have an error.
  bool get hasError => error != null;

  /// Whether content is ready to display.
  bool get isReady => hasDocument && imageBytes != null;

  /// Whether any operation is in progress.
  bool get isBusy => isLoading || isDecrypting || isDeleting;

  /// Total number of pages.
  int get pageCount => document?.pageCount ?? 1;

  /// Whether document has multiple pages.
  bool get hasMultiplePages => pageCount > 1;

  /// Creates a copy with updated values.
  DocumentDetailScreenState copyWith({
    Document? document,
    String? decryptedFilePath,
    String? decryptedThumbnailPath,
    Uint8List? imageBytes,
    int? currentPage,
    bool? isLoading,
    bool? isDecrypting,
    bool? isDeleting,
    bool? isFullScreen,
    String? error,
    bool clearError = false,
    bool clearDecryptedPaths = false,
    bool clearImageBytes = false,
  }) {
    return DocumentDetailScreenState(
      document: document ?? this.document,
      decryptedFilePath: clearDecryptedPaths
          ? null
          : (decryptedFilePath ?? this.decryptedFilePath),
      decryptedThumbnailPath: clearDecryptedPaths
          ? null
          : (decryptedThumbnailPath ?? this.decryptedThumbnailPath),
      imageBytes: clearImageBytes ? null : (imageBytes ?? this.imageBytes),
      currentPage: currentPage ?? this.currentPage,
      isLoading: isLoading ?? this.isLoading,
      isDecrypting: isDecrypting ?? this.isDecrypting,
      isDeleting: isDeleting ?? this.isDeleting,
      isFullScreen: isFullScreen ?? this.isFullScreen,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DocumentDetailScreenState &&
        other.document?.id == document?.id &&
        other.currentPage == currentPage &&
        other.isLoading == isLoading &&
        other.isDecrypting == isDecrypting &&
        other.isDeleting == isDeleting &&
        other.isFullScreen == isFullScreen &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(
    document?.id,
    currentPage,
    isLoading,
    isDecrypting,
    isDeleting,
    isFullScreen,
    error,
  );
}

/// State notifier for the document detail screen.
///
/// Manages document loading, decryption, and actions.
class DocumentDetailScreenNotifier
    extends StateNotifier<DocumentDetailScreenState> {
  /// Creates a [DocumentDetailScreenNotifier] with the given repository.
  DocumentDetailScreenNotifier(this._repository)
    : super(const DocumentDetailScreenState());

  final DocumentRepository _repository;

  /// Loads a document by ID.
  Future<void> loadDocument(String documentId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final document = await _repository.getDocument(documentId);
      if (document == null) {
        state = state.copyWith(isLoading: false, error: 'Document not found');
        return;
      }

      state = state.copyWith(document: document, isLoading: false);

      // Decrypt the document file for viewing
      await _decryptDocument(document);
    } on DocumentRepositoryException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load document: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load document: $e',
      );
    }
  }

  /// Sets the document directly (when navigating from documents screen).
  Future<void> setDocument(Document document) async {
    state = state.copyWith(
      document: document,
      isLoading: false,
      clearError: true,
    );

    // Decrypt the document file for viewing
    await _decryptDocument(document);
  }

  /// Decrypts the current page for viewing.
  ///
  /// Loads image bytes for display with Image.memory.
  /// Uses page-on-demand loading for memory efficiency.
  Future<void> _decryptDocument(Document document) async {
    state = state.copyWith(isDecrypting: true);

    try {
      // Get decrypted bytes for the current page
      final pageBytes = await _repository.getDecryptedPageBytes(
        document,
        pageIndex: state.currentPage,
      );

      // Also get thumbnail if available
      String? thumbnailPath;
      if (document.thumbnailPath != null) {
        thumbnailPath = await _repository.getDecryptedThumbnailPath(document);
      }

      state = state.copyWith(
        decryptedThumbnailPath: thumbnailPath,
        imageBytes: Uint8List.fromList(pageBytes),
        isDecrypting: false,
      );
    } on DocumentRepositoryException catch (e) {
      state = state.copyWith(
        isDecrypting: false,
        error: 'Failed to decrypt document: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        isDecrypting: false,
        error: 'Failed to decrypt document: $e',
      );
    }
  }

  /// Loads a specific page of the document.
  ///
  /// Decrypts and loads the page bytes for the given index.
  Future<void> loadPage(int pageIndex) async {
    if (state.document == null) return;
    if (pageIndex < 0 || pageIndex >= state.pageCount) return;

    // Update current page first
    state = state.copyWith(currentPage: pageIndex, isDecrypting: true);

    try {
      final pageBytes = await _repository.getDecryptedPageBytes(
        state.document!,
        pageIndex: pageIndex,
      );

      state = state.copyWith(
        imageBytes: Uint8List.fromList(pageBytes),
        isDecrypting: false,
      );
    } on DocumentRepositoryException catch (e) {
      state = state.copyWith(
        isDecrypting: false,
        error: 'Failed to load page: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        isDecrypting: false,
        error: 'Failed to load page: $e',
      );
    }
  }

  /// Loads image bytes into memory when needed (for OCR, export, etc.).
  ///
  /// This is a lazy operation - bytes are only loaded when explicitly requested.
  /// After use, consider calling [clearImageBytes] to free memory.
  Future<Uint8List?> loadImageBytes() async {
    if (state.imageBytes != null) return state.imageBytes;
    if (state.decryptedFilePath == null) return null;

    try {
      final file = File(state.decryptedFilePath!);
      final bytes = await file.readAsBytes();
      state = state.copyWith(imageBytes: bytes);
      return bytes;
    } catch (e) {
      state = state.copyWith(error: 'Failed to load image: $e');
      return null;
    }
  }

  /// Clears imageBytes from memory to free resources.
  void clearImageBytes() {
    if (state.imageBytes != null) {
      state = state.copyWith(clearImageBytes: true);
    }
  }

  /// Navigates to a specific page.
  ///
  /// Loads the page content from encrypted storage.
  Future<void> goToPage(int page) async {
    if (page < 0 || page >= state.pageCount) return;
    if (page == state.currentPage) return;
    await loadPage(page);
  }

  /// Goes to the next page.
  Future<void> nextPage() async {
    if (state.currentPage < state.pageCount - 1) {
      await goToPage(state.currentPage + 1);
    }
  }

  /// Goes to the previous page.
  Future<void> previousPage() async {
    if (state.currentPage > 0) {
      await goToPage(state.currentPage - 1);
    }
  }

  /// Toggles fullscreen mode.
  void toggleFullScreen() {
    state = state.copyWith(isFullScreen: !state.isFullScreen);
  }

  /// Toggles favorite status.
  Future<void> toggleFavorite() async {
    if (state.document == null) return;

    try {
      await _repository.toggleFavorite(state.document!.id);

      // Reload the document to get updated state
      final updatedDoc = await _repository.getDocument(state.document!.id);
      if (updatedDoc != null) {
        state = state.copyWith(document: updatedDoc);
      }
    } on DocumentRepositoryException catch (e) {
      state = state.copyWith(error: 'Failed to update favorite: ${e.message}');
    } catch (e) {
      state = state.copyWith(error: 'Failed to update favorite: $e');
    }
  }

  /// Updates the document title.
  Future<void> updateTitle(String newTitle) async {
    if (state.document == null) return;

    try {
      final updatedDoc = state.document!.copyWith(
        title: newTitle,
        updatedAt: DateTime.now(),
      );
      await _repository.updateDocument(updatedDoc);
      state = state.copyWith(document: updatedDoc);
    } on DocumentRepositoryException catch (e) {
      state = state.copyWith(error: 'Failed to update title: ${e.message}');
    } catch (e) {
      state = state.copyWith(error: 'Failed to update title: $e');
    }
  }

  /// Deletes the document.
  ///
  /// Returns true if deletion was successful.
  Future<bool> deleteDocument() async {
    if (state.document == null) return false;

    state = state.copyWith(isDeleting: true, clearError: true);

    try {
      await _repository.deleteDocument(state.document!.id);
      state = state.copyWith(isDeleting: false);
      return true;
    } on DocumentRepositoryException catch (e) {
      state = state.copyWith(
        isDeleting: false,
        error: 'Failed to delete document: ${e.message}',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isDeleting: false,
        error: 'Failed to delete document: $e',
      );
      return false;
    }
  }

  /// Clears the current error.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // Note: updateDocumentImage functionality removed since pages are now
  // stored as immutable PNG files. Signature features would need to create
  // a new document with the signed image.

  /// Cleans up decrypted files.
  Future<void> cleanup() async {
    // Delete temporary decrypted thumbnail if any
    if (state.decryptedThumbnailPath != null) {
      try {
        final file = File(state.decryptedThumbnailPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Ignore cleanup errors
      }
    }

    // Clean up any temp files from repository
    try {
      await _repository.cleanupTempFiles();
    } catch (_) {
      // Ignore cleanup errors
    }
  }

  @override
  void dispose() {
    cleanup();
    super.dispose();
  }
}

/// Riverpod provider for the document detail screen state.
final documentDetailScreenProvider =
    StateNotifierProvider.autoDispose<
      DocumentDetailScreenNotifier,
      DocumentDetailScreenState
    >((ref) {
      final repository = ref.watch(documentRepositoryProvider);
      return DocumentDetailScreenNotifier(repository);
    });

/// Document detail/preview screen.
///
/// Displays a full document with metadata, actions, and OCR text:
/// - Full-screen image preview with zoom
/// - Document title, date, size, and page count
/// - OCR text panel (if available)
/// - Actions: share, export, edit, delete, enhance, OCR, signature
/// - Page navigation for multi-page documents
///
/// ## Usage
/// ```dart
/// // Navigate with document ID
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => DocumentDetailScreen(documentId: 'doc-id'),
///   ),
/// );
///
/// // Navigate with document object
/// DocumentDetailScreen(
///   document: document,
///   onDelete: () => Navigator.pop(context),
/// )
/// ```
class DocumentDetailScreen extends ConsumerStatefulWidget {
  /// Creates a [DocumentDetailScreen].
  const DocumentDetailScreen({
    super.key,
    this.documentId,
    this.document,
    this.onDelete,
    this.onEdit,
    this.onExport,
    this.onOcr,
    this.onEnhance,
    this.onSign,
  }) : assert(
         documentId != null || document != null,
         'Either documentId or document must be provided',
       );

  /// Document ID to load. Takes precedence if both provided.
  final String? documentId;

  /// Document object to display directly.
  final Document? document;

  /// Callback when document is deleted.
  final VoidCallback? onDelete;

  /// Callback to navigate to edit screen.
  final void Function(Document document)? onEdit;

  /// Callback to navigate to export screen.
  final void Function(Document document, Uint8List imageBytes)? onExport;

  /// Callback to run OCR on the document.
  final void Function(Document document, Uint8List imageBytes)? onOcr;

  /// Callback to navigate to enhancement screen.
  final void Function(Document document, Uint8List imageBytes)? onEnhance;

  /// Callback to navigate to signature screen.
  final void Function(Document document, Uint8List imageBytes)? onSign;

  @override
  ConsumerState<DocumentDetailScreen> createState() =>
      _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();

    // Load document after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDocument();
    });
  }

  Future<void> _initializeDocument() async {
    final notifier = ref.read(documentDetailScreenProvider.notifier);

    if (widget.documentId != null) {
      await notifier.loadDocument(widget.documentId!);
    } else if (widget.document != null) {
      await notifier.setDocument(widget.document!);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentDetailScreenProvider);
    final notifier = ref.read(documentDetailScreenProvider.notifier);
    final theme = Theme.of(context);

    // Listen for errors and show snackbar
    ref.listen<DocumentDetailScreenState>(documentDetailScreenProvider, (
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

    // Fullscreen mode
    if (state.isFullScreen && state.imageBytes != null) {
      return _FullScreenView(
        imageBytes: state.imageBytes!,
        transformationController: _transformationController,
        onClose: notifier.toggleFullScreen,
        theme: theme,
      );
    }

    return Scaffold(
      appBar: _buildAppBar(context, state, notifier, theme),
      body: _buildBody(context, state, notifier, theme),
      bottomNavigationBar: state.isReady
          ? _buildActionBar(context, state, theme)
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    DocumentDetailScreenState state,
    DocumentDetailScreenNotifier notifier,
    ThemeData theme,
  ) {
    return AppBar(
      title: GestureDetector(
        onTap: state.hasDocument
            ? () => _showRenameDialog(context, state.document!, notifier)
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                state.document?.title ?? 'Document',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (state.hasDocument) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.edit_outlined,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (state.hasDocument)
          IconButton(
            icon: Icon(
              state.document!.isFavorite
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: state.document!.isFavorite
                  ? theme.colorScheme.error
                  : null,
            ),
            onPressed: notifier.toggleFavorite,
            tooltip: state.document!.isFavorite
                ? 'Remove from favorites'
                : 'Add to favorites',
          ),
        PopupMenuButton<String>(
          onSelected: (action) =>
              _handleMenuAction(context, action, state, notifier),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'share',
              child: ListTile(
                leading: Icon(Icons.share_outlined),
                title: Text('Share'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'info',
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Document info'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'move',
              child: ListTile(
                leading: Icon(Icons.drive_file_move_outlined),
                title: Text('Move to folder'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    DocumentDetailScreenState state,
    DocumentDetailScreenNotifier notifier,
    ThemeData theme,
  ) {
    if (state.isLoading || state.isDecrypting) {
      return _LoadingView(
        message: state.isDecrypting ? 'Decrypting...' : 'Loading...',
        theme: theme,
      );
    }

    if (state.hasError && !state.hasDocument) {
      return _ErrorView(
        message: state.error!,
        onRetry: _initializeDocument,
        theme: theme,
      );
    }

    if (!state.isReady) {
      return _ErrorView(
        message: 'Document content not available',
        onRetry: _initializeDocument,
        theme: theme,
      );
    }

    return Column(
      children: [
        // Document preview
        Expanded(
          child: GestureDetector(
            onDoubleTap: notifier.toggleFullScreen,
            child: _DocumentPreview(
              imageBytes: state.imageBytes!,
              transformationController: _transformationController,
              theme: theme,
            ),
          ),
        ),

        // Document info panel
        _DocumentInfoPanel(
          document: state.document!,
          currentPage: state.currentPage,
          onPageChanged: (page) => notifier.goToPage(page),
          onPreviousPage: () => notifier.previousPage(),
          onNextPage: () => notifier.nextPage(),
          isLoading: state.isDecrypting,
          theme: theme,
        ),

        // OCR text panel (if available)
        if (state.document!.hasOcrText)
          _OcrTextPanel(ocrText: state.document!.ocrText!, theme: theme),
      ],
    );
  }

  Widget _buildActionBar(
    BuildContext context,
    DocumentDetailScreenState state,
    ThemeData theme,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onPressed: () => _handleShare(context, state),
            theme: theme,
          ),
          _ActionButton(
            icon: Icons.drive_file_move_outlined,
            label: 'Move',
            onPressed: () => _showMoveToFolderDialog(context, state),
            theme: theme,
          ),
          _ActionButton(
            icon: Icons.text_fields,
            label: 'OCR',
            onPressed: () => _handleOcr(context, state),
            badge: state.document!.hasOcrText ? null : '!',
            theme: theme,
          ),
          _ActionButton(
            icon: Icons.auto_fix_high_outlined,
            label: 'Enhance',
            onPressed: () => _handleEnhance(context, state),
            theme: theme,
          ),
          // TODO: Re-enable when signature feature is fixed
          // _ActionButton(
          //   icon: Icons.draw_outlined,
          //   label: 'Sign',
          //   onPressed: () => _handleSign(context, state),
          //   theme: theme,
          // ),
        ],
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    String action,
    DocumentDetailScreenState state,
    DocumentDetailScreenNotifier notifier,
  ) {
    switch (action) {
      case 'share':
        _handleShare(context, state);
        break;
      case 'info':
        _showDocumentInfo(context, state, Theme.of(context));
        break;
      case 'move':
        _showMoveToFolderDialog(context, state);
        break;
      case 'delete':
        _showDeleteConfirmation(context, notifier);
        break;
    }
  }

  Future<void> _handleShare(
    BuildContext context,
    DocumentDetailScreenState state,
  ) async {
    if (state.document == null) return;

    // Show format selection dialog
    final format = await _showShareFormatDialog(context);
    if (format == null) return; // User cancelled

    try {
      final shareService = ref.read(documentShareServiceProvider);
      final result = await shareService.shareDocument(
        state.document!,
        format: format,
        subject: state.document?.title ?? 'Scanned Document',
      );

      // Clean up temp files
      await shareService.cleanupTempFiles(result.tempFilePaths);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    }
  }

  Future<ShareFormat?> _showShareFormatDialog(BuildContext context) {
    final theme = Theme.of(context);
    return showDialog<ShareFormat>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share as'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: theme.colorScheme.error),
              title: const Text('PDF'),
              subtitle: const Text('Single document file'),
              onTap: () => Navigator.pop(context, ShareFormat.pdf),
            ),
            ListTile(
              leading: Icon(Icons.image, color: theme.colorScheme.primary),
              title: const Text('Images (PNG)'),
              subtitle: const Text('Original quality'),
              onTap: () => Navigator.pop(context, ShareFormat.images),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(BuildContext context, DocumentDetailScreenState state) async {
    if (state.document == null) return;
    final notifier = ref.read(documentDetailScreenProvider.notifier);
    final bytes = await notifier.loadImageBytes();
    if (bytes != null && mounted) {
      widget.onExport?.call(state.document!, bytes);
    }
  }

  Future<void> _handleOcr(BuildContext context, DocumentDetailScreenState state) async {
    if (state.document == null) return;
    final notifier = ref.read(documentDetailScreenProvider.notifier);
    final bytes = await notifier.loadImageBytes();
    if (bytes != null && mounted) {
      widget.onOcr?.call(state.document!, bytes);
    }
  }

  Future<void> _handleEnhance(BuildContext context, DocumentDetailScreenState state) async {
    if (state.document == null) return;
    final notifier = ref.read(documentDetailScreenProvider.notifier);
    final bytes = await notifier.loadImageBytes();
    if (bytes != null && mounted) {
      widget.onEnhance?.call(state.document!, bytes);
    }
  }

  // TODO: Re-enable when signature feature is fixed
  // Future<void> _handleSign(
  //   BuildContext context,
  //   DocumentDetailScreenState state,
  // ) async {
  //   if (state.document == null || state.imageBytes == null) return;
  //
  //   // Allow external handler if provided
  //   if (widget.onSign != null) {
  //     widget.onSign?.call(state.document!, state.imageBytes!);
  //     return;
  //   }
  //
  //   // Navigate to signature overlay screen
  //   final signedBytes = await Navigator.of(context).push<Uint8List>(
  //     MaterialPageRoute(
  //       builder: (context) => SignatureOverlayScreen(
  //         documentBytes: state.imageBytes!,
  //         onSave: (bytes) {
  //           // Result will be returned via Navigator.pop
  //         },
  //         onCancel: () {
  //           // User cancelled
  //         },
  //       ),
  //     ),
  //   );
  //
  //   // Save the signed document if we got a result
  //   if (signedBytes != null && mounted) {
  //     final notifier = ref.read(documentDetailScreenProvider.notifier);
  //     final success = await notifier.updateDocumentImage(signedBytes);
  //
  //     if (success && mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Document signed successfully'),
  //           duration: Duration(seconds: 2),
  //         ),
  //       );
  //     }
  //   }
  // }

  Future<void> _showRenameDialog(
    BuildContext context,
    Document document,
    DocumentDetailScreenNotifier notifier,
  ) async {
    final controller = TextEditingController(text: document.title);
    final theme = Theme.of(context);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != document.title) {
      await notifier.updateTitle(newTitle);
    }

    controller.dispose();
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    DocumentDetailScreenNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: const Text(
          'This action cannot be undone. The document and all associated '
          'data will be permanently deleted.',
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
      final success = await notifier.deleteDocument();
      if (success && mounted) {
        widget.onDelete?.call();
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _showMoveToFolderDialog(
    BuildContext context,
    DocumentDetailScreenState state,
  ) async {
    if (state.document == null) return;

    final folderService = ref.read(folderServiceProvider);
    final repository = ref.read(documentRepositoryProvider);
    final folders = await folderService.getAllFolders();

    if (!mounted) return;

    final selectedFolderId = await showDialog<String>(
      context: context,
      builder: (context) => _MoveToFolderDialog(
        folders: folders,
        currentFolderId: state.document!.folderId,
        onCreateFolder: () async {
          final newFolderName = await _showCreateFolderDialog(context);
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

    try {
      await repository.moveToFolder(state.document!.id, selectedFolderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selectedFolderId == null
                  ? 'Moved to My Documents'
                  : 'Moved to folder',
            ),
          ),
        );
        // Refresh document state
        ref.read(documentDetailScreenProvider.notifier).loadDocument(state.document!.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to move document: $e')),
        );
      }
    }
  }

  Future<String?> _showCreateFolderDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (context) => const _CreateFolderDialog(),
    );
  }

  void _showDocumentInfo(
    BuildContext context,
    DocumentDetailScreenState state,
    ThemeData theme,
  ) {
    final document = state.document;
    if (document == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => _DocumentInfoSheet(
          document: document,
          scrollController: scrollController,
          theme: theme,
        ),
      ),
    );
  }
}

/// Loading view with message.
class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.message, required this.theme});

  final String message;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Error view with retry button.
class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.theme,
  });

  final String message;
  final VoidCallback onRetry;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
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

/// Interactive document preview with zoom.
class _DocumentPreview extends StatelessWidget {
  const _DocumentPreview({
    required this.imageBytes,
    required this.transformationController,
    required this.theme,
  });

  final Uint8List imageBytes;
  final TransformationController transformationController;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.colorScheme.surfaceContainerLowest,
      child: InteractiveViewer(
        transformationController: transformationController,
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.memory(
            imageBytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load image',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full screen image view.
class _FullScreenView extends StatelessWidget {
  const _FullScreenView({
    required this.imageBytes,
    required this.transformationController,
    required this.onClose,
    required this.theme,
  });

  final Uint8List imageBytes;
  final TransformationController transformationController;
  final VoidCallback onClose;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image
          InteractiveViewer(
            transformationController: transformationController,
            minScale: 0.5,
            maxScale: 6.0,
            child: Center(
              child: Image.memory(
                imageBytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onClose,
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

/// Document info panel showing metadata and page navigation.
class _DocumentInfoPanel extends StatelessWidget {
  const _DocumentInfoPanel({
    required this.document,
    required this.currentPage,
    required this.onPageChanged,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.isLoading,
    required this.theme,
  });

  final Document document;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final bool isLoading;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          // Page navigation for multi-page documents
          if (document.isMultiPage) ...[
            // Previous page button
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: currentPage > 0 && !isLoading
                  ? onPreviousPage
                  : null,
              tooltip: 'Previous page',
              visualDensity: VisualDensity.compact,
            ),
            // Page indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    )
                  : Text(
                      'Page ${currentPage + 1} of ${document.pageCount}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
            // Next page button
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: currentPage < document.pageCount - 1 && !isLoading
                  ? onNextPage
                  : null,
              tooltip: 'Next page',
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
          ],

          // Size and date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  document.fileSizeFormatted,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _formatDate(document.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Status badges
          if (document.hasOcrText)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'OCR',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          if (document.isFavorite)
            Icon(Icons.favorite, size: 16, color: theme.colorScheme.error),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${_formatTime(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${_formatTime(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Expandable OCR text panel.
class _OcrTextPanel extends StatefulWidget {
  const _OcrTextPanel({required this.ocrText, required this.theme});

  final String ocrText;
  final ThemeData theme;

  @override
  State<_OcrTextPanel> createState() => _OcrTextPanelState();
}

class _OcrTextPanelState extends State<_OcrTextPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.theme.colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: widget.theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.text_fields,
                    size: 18,
                    color: widget.theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'OCR Text',
                      style: widget.theme.textTheme.titleSmall?.copyWith(
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: _copyText,
                    tooltip: 'Copy text',
                    visualDensity: VisualDensity.compact,
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: widget.theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.ocrText,
                  style: widget.theme.textTheme.bodySmall?.copyWith(
                    color: widget.theme.colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: widget.ocrText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

/// Action button for bottom bar.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.theme,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final ThemeData theme;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 24, color: theme.colorScheme.onSurfaceVariant),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          badge!,
                          style: TextStyle(
                            color: theme.colorScheme.onError,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Document info bottom sheet.
class _DocumentInfoSheet extends StatelessWidget {
  const _DocumentInfoSheet({
    required this.document,
    required this.scrollController,
    required this.theme,
  });

  final Document document;
  final ScrollController scrollController;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Document Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
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
              padding: const EdgeInsets.all(16),
              children: [
                _InfoRow(label: 'Title', value: document.title, theme: theme),
                _InfoRow(
                  label: 'File size',
                  value: document.fileSizeFormatted,
                  theme: theme,
                ),
                _InfoRow(
                  label: 'Pages',
                  value: '${document.pageCount}',
                  theme: theme,
                ),
                _InfoRow(
                  label: 'Created',
                  value: _formatFullDate(document.createdAt),
                  theme: theme,
                ),
                _InfoRow(
                  label: 'Modified',
                  value: _formatFullDate(document.updatedAt),
                  theme: theme,
                ),
                if (document.mimeType != null)
                  _InfoRow(
                    label: 'Type',
                    value: document.mimeType!,
                    theme: theme,
                  ),
                _InfoRow(
                  label: 'OCR Status',
                  value: document.ocrStatus.value.toUpperCase(),
                  theme: theme,
                ),
                if (document.folderId != null)
                  _InfoRow(
                    label: 'Folder',
                    value: document.folderId!,
                    theme: theme,
                  ),
                _InfoRow(
                  label: 'Favorite',
                  value: document.isFavorite ? 'Yes' : 'No',
                  theme: theme,
                ),
                if (document.tags.isNotEmpty)
                  _InfoRow(
                    label: 'Tags',
                    value: '${document.tags.length} tags',
                    theme: theme,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    final months = [
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

/// Single info row in the document info sheet.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for moving a document to a different folder.
class _MoveToFolderDialog extends StatelessWidget {
  const _MoveToFolderDialog({
    required this.folders,
    required this.currentFolderId,
    required this.onCreateFolder,
  });

  final List<Folder> folders;
  final String? currentFolderId;
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
      title: const Text('Move to folder'),
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

/// Dialog for creating a new folder.
///
/// Uses StatefulWidget to properly manage the TextEditingController lifecycle
/// and check mounted state before navigation.
class _CreateFolderDialog extends StatefulWidget {
  const _CreateFolderDialog();

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
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
