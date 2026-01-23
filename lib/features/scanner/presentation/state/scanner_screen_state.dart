/// Immutable state model for the scanner screen workflow.
///
/// This file defines the state representation for document scanning,
/// including scan results, loading states, errors, and saved documents.
///
/// Features:
/// - Scan result management
/// - Loading state tracking (scanning, saving)
/// - Error handling
/// - Page selection for multi-page documents
/// - Saved document reference
library;

import 'package:flutter/foundation.dart';

import '../../../documents/domain/document_model.dart';
import '../../domain/scanner_service.dart';

/// State for the scanner screen.
@immutable
class ScannerScreenState {
  /// Creates a [ScannerScreenState] with default values.
  const ScannerScreenState({
    this.scanResult,
    this.savedDocument,
    this.isScanning = false,
    this.isSaving = false,
    this.error,
    this.selectedPageIndex = 0,
  });

  /// The current scan result, if any.
  final ScanResult? scanResult;

  /// The document created after saving to encrypted storage.
  final Document? savedDocument;

  /// Whether a scan is currently in progress.
  final bool isScanning;

  /// Whether the scan is being saved.
  final bool isSaving;

  /// Error message, if any.
  final String? error;

  /// Currently selected page index for preview.
  final int selectedPageIndex;

  /// Whether we have a scan result to preview.
  bool get hasResult => scanResult != null && scanResult!.isNotEmpty;

  /// Whether a document was saved to storage.
  bool get hasSavedDocument => savedDocument != null;

  /// Whether we're in a loading state.
  bool get isLoading => isScanning || isSaving;

  /// Whether we have an error.
  bool get hasError => error != null;

  /// Creates a copy with updated fields.
  ScannerScreenState copyWith({
    ScanResult? scanResult,
    Document? savedDocument,
    bool? isScanning,
    bool? isSaving,
    String? error,
    int? selectedPageIndex,
    bool clearResult = false,
    bool clearError = false,
    bool clearSavedDocument = false,
  }) {
    return ScannerScreenState(
      scanResult: clearResult ? null : (scanResult ?? this.scanResult),
      savedDocument:
          clearSavedDocument ? null : (savedDocument ?? this.savedDocument),
      isScanning: isScanning ?? this.isScanning,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      selectedPageIndex: selectedPageIndex ?? this.selectedPageIndex,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScannerScreenState &&
        other.scanResult == scanResult &&
        other.savedDocument?.id == savedDocument?.id &&
        other.isScanning == isScanning &&
        other.isSaving == isSaving &&
        other.error == error &&
        other.selectedPageIndex == selectedPageIndex;
  }

  @override
  int get hashCode => Object.hash(
        scanResult,
        savedDocument?.id,
        isScanning,
        isSaving,
        error,
        selectedPageIndex,
      );
}
