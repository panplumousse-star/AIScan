/// State management for the scanner screen using Riverpod.
///
/// This file provides the state notifier and provider for managing the
/// complete document scanning workflow, from initiating scans to saving
/// documents to encrypted storage.
///
/// Features:
/// - Document scanning (quick scan, multi-page scan)
/// - Scan result preview and page navigation
/// - Save to encrypted storage with metadata
/// - Error handling and recovery
/// - State cleanup on disposal
///
/// Usage:
/// ```dart
/// final notifier = ref.read(scannerScreenProvider.notifier);
/// await notifier.quickScan();
/// await notifier.saveToStorage(title: 'My Scan');
/// ```
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../documents/domain/document_model.dart';
import '../../domain/scanner_service.dart';
import 'scanner_screen_state.dart';

/// State notifier for the scanner screen.
///
/// Handles the scanning process, preview, and saving workflow.
class ScannerScreenNotifier extends StateNotifier<ScannerScreenState> {
  /// Creates a [ScannerScreenNotifier] with the given services.
  ScannerScreenNotifier(
    this._scannerService,
    this._storageService,
  ) : super(const ScannerScreenState());

  final ScannerService _scannerService;
  final ScannerStorageService _storageService;

  /// Starts a document scan with the given options.
  Future<void> startScan(
      {ScannerOptions options = const ScannerOptions()}) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isScanning: true,
      error: null,
      scanResult: null,
      savedDocument: null,
    );

    try {
      final result = await _scannerService.scanDocument(options: options);

      if (result != null && result.isNotEmpty) {
        state = state.copyWith(
          scanResult: result,
          isScanning: false,
          selectedPageIndex: 0,
        );
      } else {
        // User cancelled
        state = state.copyWith(isScanning: false);
      }
    } on ScannerException catch (e) {
      state = state.copyWith(
        isScanning: false,
        error: e.message,
      );
    } on Object catch (_) {
      state = state.copyWith(
        isScanning: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  /// Performs a quick single-page scan.
  Future<void> quickScan() async {
    await startScan(options: const ScannerOptions.quickScan());
  }

  /// Performs a multi-page scan.
  ///
  /// [allowGalleryImport] controls whether the gallery import button is shown.
  /// Set to false if storage permission is not granted.
  Future<void> multiPageScan({
    int maxPages = 100,
    bool allowGalleryImport = true,
  }) async {
    await startScan(
      options: ScannerOptions(
        pageLimit: maxPages,
        allowGalleryImport: allowGalleryImport,
      ),
    );
  }

  /// Selects a page for preview.
  void selectPage(int index) {
    if (state.scanResult == null) return;
    if (index < 0 || index >= state.scanResult!.pageCount) return;
    state = state.copyWith(selectedPageIndex: index);
  }

  /// Discards the current scan result.
  Future<void> discardScan() async {
    if (state.scanResult != null) {
      await _scannerService.cleanupScanResult(state.scanResult!);
    }
    state = state.copyWith(
      scanResult: null,
      savedDocument: null,
      selectedPageIndex: 0,
    );
  }

  /// Saves the current scan result to encrypted document storage.
  ///
  /// Parameters:
  /// - [title]: Optional title for the document (auto-generated if not provided)
  /// - [description]: Optional description
  /// - [folderId]: Optional folder to save the document in
  /// - [isFavorite]: Whether to mark the document as favorite
  ///
  /// Returns the saved [Document] if successful.
  ///
  /// Throws [ScannerException] if saving fails.
  Future<Document?> saveToStorage({
    String? title,
    String? description,
    String? folderId,
    bool isFavorite = false,
  }) async {
    if (state.scanResult == null || state.isLoading) return null;

    state = state.copyWith(isSaving: true, error: null);

    try {
      final savedResult = await _storageService.saveScanResult(
        state.scanResult!,
        title: title,
        description: description,
        folderId: folderId,
        isFavorite: isFavorite,
      );

      state = state.copyWith(
        isSaving: false,
        savedDocument: savedResult.document,
      );

      return savedResult.document;
    } on ScannerException catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: e.message,
      );
      return null;
    } on Object catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to save document: $e',
      );
      return null;
    }
  }

  /// Saves the current scan as a quick scan with auto-generated title.
  ///
  /// This is optimized for the one-click scan workflow.
  Future<Document?> quickSave() async {
    return saveToStorage();
  }

  /// Clears the error state.
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Sets the saving state.
  void setSaving(bool saving) {
    state = state.copyWith(isSaving: saving);
  }

  /// Gets the saved document, if any.
  Document? get savedDocument => state.savedDocument;

  @override
  void dispose() {
    if (state.scanResult != null) {
      _scannerService.cleanupScanResult(state.scanResult!);
    }
    super.dispose();
  }
}

/// Riverpod provider for the scanner screen state.
final scannerScreenProvider = StateNotifierProvider.autoDispose<
    ScannerScreenNotifier, ScannerScreenState>(
  (ref) {
    final scannerService = ref.watch(scannerServiceProvider);
    final storageService = ref.watch(scannerStorageServiceProvider);
    return ScannerScreenNotifier(scannerService, storageService);
  },
);
