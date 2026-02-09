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
/// - Premium feature gating (document limit for free users)
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
import '../../../premium/domain/premium_service.dart';
import '../../../premium/domain/scan_usage_service.dart';
import '../../domain/scanner_service.dart';
import 'scanner_screen_state.dart';

/// Notifier for the scanner screen.
///
/// Handles the scanning process, preview, and saving workflow.
/// Integrates premium feature gating for free tier limitations.
class ScannerScreenNotifier extends AutoDisposeNotifier<ScannerScreenState> {
  late final ScannerService _scannerService;
  late final ScannerStorageService _storageService;

  @override
  ScannerScreenState build() {
    _scannerService = ref.watch(scannerServiceProvider);
    _storageService = ref.watch(scannerStorageServiceProvider);

    ref.onDispose(() {
      if (state.scanResult != null) {
        unawaited(_scannerService.cleanupScanResult(state.scanResult!));
      }
    });

    return const ScannerScreenState();
  }

  /// Checks if the user has premium access.
  bool get _isPremium => ref.read(isPremiumProvider);

  /// Starts a document scan with the given options.
  ///
  /// For free users:
  /// - Scans are always allowed (no limit on scanning)
  /// - Forces single-page mode (multipage disabled)
  /// - Document limit is checked at save time, not scan time
  Future<void> startScan(
      {ScannerOptions options = const ScannerOptions()}) async {
    if (state.isLoading) return;

    // Clear any previous block state
    state = state.copyWith(
      isScanning: true,
      error: null,
      scanResult: null,
      savedDocument: null,
      blocked: ScanBlockReason.none,
    );

    // For free users, force single-page mode
    final effectiveOptions = _isPremium
        ? options
        : const ScannerOptions.quickScan(); // pageLimit: 1

    try {
      final result = await _scannerService.scanDocument(options: effectiveOptions);

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
  ///
  /// Note: For free users, this will be converted to single-page mode in [startScan].
  Future<void> multiPageScan({
    int maxPages = 100,
    bool allowGalleryImport = true,
  }) async {
    // Premium check - free users cannot use multi-page
    if (!_isPremium) {
      // Still allow scan but it will be converted to single page
      await quickScan();
      return;
    }

    await startScan(
      options: ScannerOptions(
        pageLimit: maxPages,
        allowGalleryImport: allowGalleryImport,
      ),
    );
  }

  /// Clears the blocked state.
  void clearBlocked() {
    state = state.copyWith(blocked: ScanBlockReason.none);
  }

  /// Returns true if the user has premium access.
  bool get isPremium => _isPremium;

  /// Returns the number of documents remaining for free users.
  int get documentsRemaining {
    final usage = ref.read(scanUsageProvider);
    return usage.documentsRemaining;
  }

  /// @deprecated Use [documentsRemaining] instead.
  int get scansRemaining => documentsRemaining;

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

  /// Checks if the user can save a document.
  ///
  /// Returns true if the user is premium or has not reached the document limit.
  Future<bool> _canSaveDocument() async {
    if (_isPremium) return true;

    // Refresh the document count from repository
    await ref.read(scanUsageProvider.notifier).refresh();
    final usage = ref.read(scanUsageProvider);
    return usage.canSaveDocument;
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
  /// For free users, this will fail if the document limit (10) is reached.
  /// The [blocked] state will be set to [ScanBlockReason.documentLimitReached].
  ///
  /// Throws [ScannerException] if saving fails.
  Future<Document?> saveToStorage({
    String? title,
    String? description,
    String? folderId,
    bool isFavorite = false,
  }) async {
    if (state.scanResult == null || state.isLoading) return null;

    // Check document limit for free users
    if (!await _canSaveDocument()) {
      state = state.copyWith(blocked: ScanBlockReason.documentLimitReached);
      return null;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      final savedResult = await _storageService.saveScanResult(
        state.scanResult!,
        title: title,
        description: description,
        folderId: folderId,
        isFavorite: isFavorite,
      );

      // Refresh document count after saving
      unawaited(ref.read(scanUsageProvider.notifier).refresh());

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
}

/// Riverpod provider for the scanner screen state.
final scannerScreenProvider = NotifierProvider.autoDispose<
    ScannerScreenNotifier, ScannerScreenState>(
  ScannerScreenNotifier.new,
);
