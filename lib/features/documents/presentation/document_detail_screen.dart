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
import '../../folders/domain/folder_service.dart';
import '../../sharing/domain/document_share_service.dart';
import '../domain/document_model.dart';
import 'widgets/document_action_button.dart';
import 'widgets/document_info_panel.dart';
import 'widgets/document_info_sheet.dart';
import 'widgets/document_preview.dart';
import 'widgets/move_to_folder_dialog.dart';
import 'widgets/ocr_text_panel.dart';

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
            child: OcrTextPanel(ocrText: state.document!.ocrText!, theme: theme),
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
                            painter: BubbleTailPainterRight(
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
              DocumentActionButton(
                icon: Icons.share_rounded,
                label: 'Partager',
                onPressed: () => _handleShare(context, state),
                theme: theme,
              ),
              DocumentActionButton(
                icon: Icons.save_alt_rounded,
                label: 'Exporter',
                onPressed: () => _handleExport(context, state),
                theme: theme,
              ),
              DocumentActionButton(
                icon: Icons.drive_file_move_rounded,
                label: 'Déplacer',
                onPressed: () => _showMoveToFolderDialog(context, state),
                theme: theme,
              ),
              DocumentActionButton(
                icon: Icons.text_snippet_rounded,
                label: 'OCR',
                onPressed: () => _handleOcr(context, state),
                badge: state.document!.hasOcrText ? null : '!',
                theme: theme,
              ),
              DocumentActionButton(
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

    final selectedFolderId = await showMoveToFolderDialog(
      context,
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
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur lors de la création du dossier: $e')),
              );
            }
            return null;
          }
        },
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
        builder: (context, scrollController) => DocumentInfoSheet(
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