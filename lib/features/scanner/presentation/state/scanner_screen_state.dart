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

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../documents/domain/document_model.dart';
import '../../domain/scanner_service.dart';

part 'scanner_screen_state.freezed.dart';

/// State for the scanner screen.
@freezed
class ScannerScreenState with _$ScannerScreenState {
  const ScannerScreenState._();

  /// Creates a [ScannerScreenState] with default values.
  const factory ScannerScreenState({
    /// The current scan result, if any.
    ScanResult? scanResult,

    /// The document created after saving to encrypted storage.
    Document? savedDocument,

    /// Whether a scan is currently in progress.
    @Default(false) bool isScanning,

    /// Whether the scan is being saved.
    @Default(false) bool isSaving,

    /// Error message, if any.
    String? error,

    /// Currently selected page index for preview.
    @Default(0) int selectedPageIndex,
  }) = _ScannerScreenState;

  /// Whether we have a scan result to preview.
  bool get hasResult => scanResult != null && scanResult!.isNotEmpty;

  /// Whether a document was saved to storage.
  bool get hasSavedDocument => savedDocument != null;

  /// Whether we're in a loading state.
  bool get isLoading => isScanning || isSaving;

  /// Whether we have an error.
  bool get hasError => error != null;
}
