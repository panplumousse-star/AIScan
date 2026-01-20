import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/storage/document_repository.dart';
import '../../../core/widgets/bento_background.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../core/widgets/bento_mascot.dart';
import '../../../core/widgets/bento_rename_document_dialog.dart';
import '../../../core/widgets/bento_share_format_dialog.dart';
import '../../../core/widgets/bento_state_views.dart';
import '../../folders/domain/folder_model.dart';
import '../../folders/domain/folder_service.dart';
import '../../folders/presentation/widgets/bento_folder_dialog.dart';
import '../../sharing/domain/document_share_service.dart';
import '../domain/document_model.dart';
import 'widgets/document_info_panel.dart';
import 'widgets/document_preview.dart';

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
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const BentoBackground(),
          Column(
            children: [
              Expanded(
                child: _buildBody(context, state, notifier, theme),
              ),
              if (state.isReady)
                _buildActionBar(context, state, theme),
            ],
          ),
          _buildCustomHeader(context, state, notifier, theme),
        ],
      ),
    );
  }

  Widget _buildCustomHeader(
    BuildContext context,
    DocumentDetailScreenState state,
    DocumentDetailScreenNotifier notifier,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 12,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top row: back button + action icons
            Row(
              children: [
                // Back button with white background
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                    onPressed: () => Navigator.of(context).pop(),
                    iconSize: 22,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                ),
                const Spacer(),
                // Action icons: favorite, info, delete (no background)
                if (state.hasDocument) ...[
                  // Favorite button
                  IconButton(
                    icon: Icon(
                      state.document!.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: state.document!.isFavorite
                          ? Colors.redAccent
                          : (isDark ? Colors.white : const Color(0xFF1E1B4B)),
                    ),
                    onPressed: notifier.toggleFavorite,
                    iconSize: 24,
                  ),
                  // Info button
                  IconButton(
                    icon: Icon(
                      Icons.info_outline_rounded,
                      color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                    ),
                    onPressed: () => _handleMenuAction(context, 'info', state, notifier),
                    iconSize: 24,
                  ),
                  // Delete button
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _handleMenuAction(context, 'delete', state, notifier),
                    iconSize: 24,
                  ),
                ],
              ],
            ),
            // Title row below
            if (state.hasDocument) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showRenameDialog(context, state.document!, notifier),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        state.document?.title ?? 'Chargement...',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    DocumentDetailScreenState state,
    DocumentDetailScreenNotifier notifier,
    ThemeData theme,
  ) {
    if (state.isLoading || state.isDecrypting) {
      return BentoLoadingView(
        message: state.isDecrypting ? 'Déchiffrement...' : 'Chargement...',
      );
    }

    if (state.hasError && !state.hasDocument) {
      return BentoErrorView(
        message: state.error!,
        onRetry: _initializeDocument,
      );
    }

    if (!state.isReady) {
      return BentoErrorView(
        message: 'Contenu du document non disponible',
        onRetry: _initializeDocument,
      );
    }

    return Column(
      children: [
        SizedBox(height: MediaQuery.of(context).padding.top + 100),
        // Document preview
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: BentoCard(
              padding: EdgeInsets.zero,
              borderRadius: 24,
              backgroundColor: theme.brightness == Brightness.dark 
                  ? Colors.white.withValues(alpha: 0.05) 
                  : Colors.white.withValues(alpha: 0.8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: GestureDetector(
                  onDoubleTap: notifier.toggleFullScreen,
                  child: DocumentPreview(
                    imageBytes: state.imageBytes!,
                    transformationController: _transformationController,
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Document info panel
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: DocumentInfoPanel(
            document: state.document!,
            currentPage: state.currentPage,
            onPageChanged: (page) => notifier.goToPage(page),
            onPreviousPage: () => notifier.previousPage(),
            onNextPage: () => notifier.nextPage(),
            isLoading: state.isDecrypting,
            theme: theme,
          ),
        ),

        // OCR text panel (if available)
        if (state.document!.hasOcrText)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _OcrTextPanel(ocrText: state.document!.ocrText!, theme: theme),
          ),
        
        const SizedBox(height: 12),

        // Mascot interaction with speech bubble
        Builder(
          builder: (context) {
            final isDark = theme.brightness == Brightness.dark;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            'Besoin d\'aide ?',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -8,
                          right: 8,
                          child: CustomPaint(
                            size: const Size(12, 12),
                            painter: _BubbleTailPainterRight(
                              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  BentoLevitationWidget(
                    child: BentoMascot(
                      height: 50,
                      variant: BentoMascotVariant.waving,
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildActionBar(
    BuildContext context,
    DocumentDetailScreenState state,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.black.withValues(alpha: 0.4) 
                : Colors.white.withValues(alpha: 0.4),
            border: Border(
              top: BorderSide(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.05) 
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BentoActionButton(
                icon: Icons.share_rounded,
                label: 'Partager',
                onPressed: () => _handleShare(context, state),
                theme: theme,
              ),
              _BentoActionButton(
                icon: Icons.save_alt_rounded,
                label: 'Exporter',
                onPressed: () => _handleExport(context, state),
                theme: theme,
              ),
              _BentoActionButton(
                icon: Icons.drive_file_move_rounded,
                label: 'Déplacer',
                onPressed: () => _showMoveToFolderDialog(context, state),
                theme: theme,
              ),
              _BentoActionButton(
                icon: Icons.text_snippet_rounded,
                label: 'OCR',
                onPressed: () => _handleOcr(context, state),
                badge: state.document!.hasOcrText ? null : '!',
                theme: theme,
              ),
              _BentoActionButton(
                icon: Icons.auto_fix_high_rounded,
                label: 'Magie',
                onPressed: () => _handleEnhance(context, state),
                theme: theme,
                isPrimary: true,
              ),
            ],
          ),
        ),
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
    final format = await showBentoShareFormatDialog(context);
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

  Future<void> _handleExport(BuildContext context, DocumentDetailScreenState state) async {
    if (state.document == null) return;
    final notifier = ref.read(documentDetailScreenProvider.notifier);
    final bytes = await notifier.loadImageBytes();
    if (bytes != null && mounted) {
      widget.onExport?.call(state.document!, bytes);
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
    final newTitle = await showBentoRenameDocumentDialog(
      context,
      currentTitle: document.title,
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != document.title) {
      await notifier.updateTitle(newTitle);
    }
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    DocumentDetailScreenNotifier notifier,
  ) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              color: Colors.transparent,
              child: BentoCard(
                padding: const EdgeInsets.all(24),
                backgroundColor: isDark 
                    ? Colors.white.withValues(alpha: 0.1) 
                    : Colors.white.withValues(alpha: 0.9),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BentoLevitationWidget(
                      child: Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 48),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Supprimer le document ?',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Cette action est irréversible. Le document sera définitivement supprimé.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text('Annuler', style: GoogleFonts.outfit()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(true),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                              ),
                              child: Center(
                                child: Text(
                                  'Supprimer',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
      builder: (dialogContext) => _MoveToFolderDialog(
        folders: folders,
        currentFolderId: state.document!.folderId,
        onCreateFolder: (name, color) async {
          try {
            final newFolder = await folderService.createFolder(
              name: name,
              color: color,
            );
            return newFolder;
          } catch (e) {
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(content: Text('Erreur lors de la création du dossier: $e')),
              );
            }
            return null;
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
    final isDark = widget.theme.brightness == Brightness.dark;

    return BentoCard(
      padding: EdgeInsets.zero,
      backgroundColor: isDark 
          ? Colors.white.withValues(alpha: 0.05) 
          : Colors.white.withValues(alpha: 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.text_snippet_rounded,
                    size: 20,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Texte OCR',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_all_rounded, size: 20),
                    onPressed: _copyText,
                    visualDensity: VisualDensity.compact,
                  ),
                  Icon(
                    _isExpanded 
                        ? Icons.keyboard_arrow_up_rounded 
                        : Icons.keyboard_arrow_down_rounded,
                    color: widget.theme.colorScheme.onSurface.withValues(alpha: 0.3),
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
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: widget.theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
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
/// Action button for bottom bar.
class _BentoActionButton extends StatelessWidget {
  const _BentoActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.theme,
    this.badge,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final ThemeData theme;
  final String? badge;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: isPrimary ? BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [const Color(0xFF312E81), const Color(0xFF3730A3)] 
                    : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : const Color(0xFF4F46E5)).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ) : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon, 
                      size: 24, 
                      color: isPrimary 
                          ? Colors.white 
                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    if (badge != null)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
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
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
                    color: isPrimary 
                        ? Colors.white 
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
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
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                const BentoLevitationWidget(
                  child: Icon(Icons.info_rounded, color: Color(0xFF4F46E5), size: 28),
                ),
                const SizedBox(width: 16),
                Text(
                  'Informations Document',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                _BentoInfoRow(icon: Icons.title_rounded, label: 'Titre', value: document.title, theme: theme),
                _BentoInfoRow(
                  icon: Icons.straighten_rounded,
                  label: 'Taille du fichier',
                  value: document.fileSizeFormatted,
                  theme: theme,
                ),
                _BentoInfoRow(
                  icon: Icons.pages_rounded,
                  label: 'Pages',
                  value: '${document.pageCount}',
                  theme: theme,
                ),
                _BentoInfoRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Créé le',
                  value: _formatFullDate(document.createdAt),
                  theme: theme,
                ),
                _BentoInfoRow(
                  icon: Icons.history_rounded,
                  label: 'Modifié le',
                  value: _formatFullDate(document.updatedAt),
                  theme: theme,
                ),
                if (document.mimeType != null)
                  _BentoInfoRow(
                    icon: Icons.code_rounded,
                    label: 'Format',
                    value: document.mimeType!,
                    theme: theme,
                  ),
                _BentoInfoRow(
                  icon: Icons.font_download_rounded,
                  label: 'Statut OCR',
                  value: document.ocrStatus.value.toUpperCase(),
                  theme: theme,
                ),
                if (document.folderId != null)
                  _BentoInfoRow(
                    icon: Icons.folder_rounded,
                    label: 'Dossier',
                    value: document.folderId!,
                    theme: theme,
                  ),
                _BentoInfoRow(
                  icon: document.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: 'Favori',
                  value: document.isFavorite ? 'Oui' : 'Non',
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

class _BentoInfoRow extends StatelessWidget {
  const _BentoInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BentoCard(
        padding: const EdgeInsets.all(16),
        backgroundColor: theme.brightness == Brightness.dark 
            ? Colors.white.withValues(alpha: 0.05) 
            : Colors.black.withValues(alpha: 0.02),
        child: Row(
          children: [
            Icon(
              icon, 
              size: 20, 
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for moving a document to a different folder.
class _MoveToFolderDialog extends StatefulWidget {
  const _MoveToFolderDialog({
    required this.folders,
    required this.currentFolderId,
    required this.onCreateFolder,
  });

  final List<Folder> folders;
  final String? currentFolderId;
  final Future<Folder?> Function(String name, String? color) onCreateFolder;

  @override
  State<_MoveToFolderDialog> createState() => _MoveToFolderDialogState();
}

class _MoveToFolderDialogState extends State<_MoveToFolderDialog> {
  late String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.currentFolderId;
  }

  Future<void> _showCreateFolderDialog() async {
    final result = await showBentoFolderDialog(context);
    if (result != null && result.name.isNotEmpty && mounted) {
      final newFolder = await widget.onCreateFolder(result.name, result.color);
      if (newFolder != null && mounted) {
        setState(() => _selectedFolderId = newFolder.id);
      }
    }
  }

  void _save() {
    Navigator.of(context).pop(_selectedFolderId);
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null) return const Color(0xFF4F46E5);
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF4F46E5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Material(
              color: Colors.transparent,
              child: BentoCard(
                elevation: 6,
                padding: const EdgeInsets.all(24),
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.9),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with title and mascot
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title on left
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enregistrer sous...',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Choisis un dossier de destination',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Mascot on right with speech bubble
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            BentoLevitationWidget(
                              child: BentoMascot(
                                height: 70,
                                variant: BentoMascotVariant.folderEdit,
                              ),
                            ),
                            // Speech bubble positioned above
                            Positioned(
                              top: -8,
                              right: 60,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFEEF2FF),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(4),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Je range !',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Folder list
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.35,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // "My Documents" option
                            _FolderOptionTile(
                              onTap: () => setState(() => _selectedFolderId = null),
                              icon: Icons.description_rounded,
                              title: 'Mes Documents',
                              color: const Color(0xFF4F46E5),
                              isSelected: _selectedFolderId == null,
                              theme: theme,
                            ),
                            const SizedBox(height: 8),
                            // Specific folders
                            ...widget.folders.map((folder) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _FolderOptionTile(
                                onTap: () => setState(() => _selectedFolderId = folder.id),
                                icon: Icons.folder_rounded,
                                title: folder.name,
                                color: _parseColor(folder.color),
                                isSelected: _selectedFolderId == folder.id,
                                theme: theme,
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Create new folder button
                    InkWell(
                      onTap: _showCreateFolderDialog,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.add_circle_outline_rounded,
                              size: 24,
                              color: theme.colorScheme.primary.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Nouveau Dossier',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop('_cancelled_'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              'Annuler',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _save,
                                borderRadius: BorderRadius.circular(14),
                                child: Center(
                                  child: Text(
                                    'Enregistrer',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onPrimary,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderOptionTile extends StatelessWidget {
  const _FolderOptionTile({
    required this.onTap,
    required this.icon,
    required this.title,
    required this.color,
    required this.isSelected,
    required this.theme,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final Color color;
  final bool isSelected;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withValues(alpha: 0.1) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? color.withValues(alpha: 0.3) 
                : theme.colorScheme.onSurface.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Painter for speech bubble tail pointing to the right (toward mascot).
class _BubbleTailPainterRight extends CustomPainter {
  final Color color;

  _BubbleTailPainterRight({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw tail pointing down-right (toward mascot on the right)
    final path = Path();
    path.moveTo(0, 0); // Top left (connected to bubble)
    path.lineTo(size.width, size.height); // Bottom right (pointing to mascot)
    path.lineTo(0, size.height * 0.6); // Left side
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
