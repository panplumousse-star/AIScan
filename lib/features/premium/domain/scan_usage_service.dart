import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/document_repository.dart';
import 'scan_usage_model.dart';

/// Service for tracking document usage for free users.
///
/// The document count is retrieved directly from the [DocumentRepository],
/// ensuring accurate counts even if documents are deleted.
class ScanUsageService {
  ScanUsageService(this._repository);

  final DocumentRepository _repository;

  /// Loads the current document usage from the repository.
  Future<ScanUsage> loadUsage() async {
    final documents = await _repository.getAllDocuments();
    return ScanUsage(documentCount: documents.length);
  }

  /// Checks if the user can save a new document.
  Future<bool> canSaveDocument() async {
    final usage = await loadUsage();
    return usage.canSaveDocument;
  }
}

/// Provider for the ScanUsageService.
final scanUsageServiceProvider = Provider<ScanUsageService>((ref) {
  final repository = ref.read(documentRepositoryProvider);
  return ScanUsageService(repository);
});

/// StateNotifier for managing document usage state reactively.
class ScanUsageNotifier extends StateNotifier<ScanUsage> {
  ScanUsageNotifier(this._service) : super(const ScanUsage());

  final ScanUsageService _service;

  /// Refreshes the document count from the repository.
  Future<void> refresh() async {
    state = await _service.loadUsage();
  }

  /// Checks if a new document can be saved.
  Future<bool> canSaveDocument() async {
    await refresh();
    return state.canSaveDocument;
  }
}

/// Provider for the scan usage state notifier.
final scanUsageProvider =
    StateNotifierProvider<ScanUsageNotifier, ScanUsage>((ref) {
  final service = ref.watch(scanUsageServiceProvider);
  return ScanUsageNotifier(service);
});

/// Provider that exposes the current document count.
final documentCountProvider = Provider<int>((ref) {
  final usage = ref.watch(scanUsageProvider);
  return usage.documentCount;
});

/// Provider that exposes the maximum free documents allowed.
final maxFreeDocumentsProvider = Provider<int>((ref) {
  final usage = ref.watch(scanUsageProvider);
  return usage.maxFreeDocuments;
});

/// Provider that exposes whether the user can save more documents.
final canSaveDocumentProvider = Provider<bool>((ref) {
  final usage = ref.watch(scanUsageProvider);
  return usage.canSaveDocument;
});

// Legacy providers for backward compatibility
/// @deprecated Use [canSaveDocumentProvider] instead.
final canScanProvider = Provider<bool>((ref) {
  final usage = ref.watch(scanUsageProvider);
  return usage.canSaveDocument;
});

/// @deprecated Use [documentCountProvider] instead.
final scansRemainingProvider = Provider<int>((ref) {
  final usage = ref.watch(scanUsageProvider);
  return usage.documentsRemaining;
});
