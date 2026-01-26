import 'dart:async';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/document_repository.dart';
import '../../domain/document_model.dart';

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
    } on Object catch (e) {
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
    } on Object catch (e) {
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
    } on Object catch (e) {
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
    } on Object catch (e) {
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
    } on Object catch (e) {
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
    } on Object catch (e) {
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
    } on Object catch (e) {
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
      } on Object catch (_) {
        // Ignore cleanup errors
      }
    }

    // Clean up any temp files from repository
    try {
      await _repository.cleanupTempFiles();
    } on Object catch (_) {
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
final documentDetailScreenProvider = StateNotifierProvider.autoDispose<
    DocumentDetailScreenNotifier, DocumentDetailScreenState>((ref) {
  final repository = ref.watch(documentRepositoryProvider);
  return DocumentDetailScreenNotifier(repository);
});
