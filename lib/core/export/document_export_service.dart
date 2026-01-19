import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../features/documents/domain/document_model.dart';
import '../../features/export/domain/pdf_generator.dart';
import '../storage/document_repository.dart';
import 'export_preferences.dart';

/// Riverpod provider for [DocumentExportService].
///
/// Provides a singleton instance of the document export service for
/// dependency injection throughout the application.
/// Depends on [DocumentRepository] for document decryption,
/// [PDFGenerator] for PDF generation, and
/// [ExportPreferences] for remembering export settings.
final documentExportServiceProvider = Provider<DocumentExportService>((ref) {
  final documentRepository = ref.read(documentRepositoryProvider);
  final pdfGenerator = ref.read(pdfGeneratorProvider);
  final exportPreferences = ref.read(exportPreferencesProvider);
  return DocumentExportService(
    documentRepository: documentRepository,
    pdfGenerator: pdfGenerator,
    exportPreferences: exportPreferences,
  );
});

/// Exception thrown when document export operations fail.
///
/// Contains the original error message and optional underlying exception.
class DocumentExportException implements Exception {
  /// Creates a [DocumentExportException] with the given [message].
  const DocumentExportException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'DocumentExportException: $message (caused by: $cause)';
    }
    return 'DocumentExportException: $message';
  }
}

/// Status of an export operation.
enum ExportStatus {
  /// Export completed successfully.
  success,

  /// User cancelled the export operation.
  cancelled,

  /// Export failed due to an error.
  failed,
}

/// Result of a document export operation.
///
/// Contains information about the exported files and operation status.
@immutable
class ExportResult {
  /// Creates an [ExportResult].
  const ExportResult({
    required this.status,
    this.exportedCount = 0,
    this.exportedPaths = const [],
    this.folderPath,
    this.folderDisplayName,
    this.errorMessage,
  });

  /// Creates a successful export result.
  const ExportResult.success({
    required int exportedCount,
    required List<String> exportedPaths,
    String? folderPath,
    String? folderDisplayName,
  }) : this(
          status: ExportStatus.success,
          exportedCount: exportedCount,
          exportedPaths: exportedPaths,
          folderPath: folderPath,
          folderDisplayName: folderDisplayName,
        );

  /// Creates a cancelled export result.
  const ExportResult.cancelled()
      : this(
          status: ExportStatus.cancelled,
        );

  /// Creates a failed export result.
  const ExportResult.failed(String errorMessage)
      : this(
          status: ExportStatus.failed,
          errorMessage: errorMessage,
        );

  /// The status of the export operation.
  final ExportStatus status;

  /// Number of documents successfully exported.
  final int exportedCount;

  /// Paths to the exported files.
  final List<String> exportedPaths;

  /// The folder path where documents were exported.
  final String? folderPath;

  /// User-friendly display name of the export folder.
  final String? folderDisplayName;

  /// Error message if the export failed.
  final String? errorMessage;

  /// Whether the export was successful.
  bool get isSuccess => status == ExportStatus.success;

  /// Whether the export was cancelled by the user.
  bool get isCancelled => status == ExportStatus.cancelled;

  /// Whether the export failed.
  bool get isFailed => status == ExportStatus.failed;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExportResult &&
        other.status == status &&
        other.exportedCount == exportedCount &&
        listEquals(other.exportedPaths, exportedPaths) &&
        other.folderPath == folderPath &&
        other.folderDisplayName == folderDisplayName &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(
        status,
        exportedCount,
        Object.hashAll(exportedPaths),
        folderPath,
        folderDisplayName,
        errorMessage,
      );

  @override
  String toString() => 'ExportResult(status: $status, '
      'exportedCount: $exportedCount, '
      'folderPath: $folderPath)';
}

/// Service for exporting PDF documents to external storage via SAF.
///
/// This service handles all aspects of document export including:
/// - Document decryption for export
/// - PDF generation from document pages
/// - SAF (Storage Access Framework) integration via file_picker
/// - Remembering last export folder preference
/// - Cleanup of temporary decrypted files
///
/// ## Security Architecture
/// Documents are stored encrypted on disk. This service:
/// 1. Decrypts documents to temporary files for PDF generation
/// 2. Generates PDFs from decrypted pages
/// 3. Exports PDFs via SAF to user-selected location
/// 4. Cleans up temporary files after export completes
///
/// ## Usage
/// ```dart
/// final exportService = ref.read(documentExportServiceProvider);
///
/// // Export a single document
/// final result = await exportService.exportDocument(document);
/// if (result.isSuccess) {
///   showSuccessMessage('Document exporté vers ${result.folderDisplayName}');
/// } else if (result.isCancelled) {
///   // User cancelled, no action needed
/// } else {
///   showErrorMessage(result.errorMessage);
/// }
///
/// // Export multiple documents
/// final result = await exportService.exportDocuments(selectedDocuments);
/// ```
///
/// ## Important Notes
/// - Uses SAF via `FilePicker.platform.saveFile()` for Android compatibility
/// - Temporary files are automatically cleaned up after export
/// - Last export folder is remembered across sessions
/// - All user-facing strings are in French
class DocumentExportService {
  /// Creates a [DocumentExportService] with the required dependencies.
  DocumentExportService({
    required DocumentRepository documentRepository,
    required PDFGenerator pdfGenerator,
    required ExportPreferences exportPreferences,
  })  : _documentRepository = documentRepository,
        _pdfGenerator = pdfGenerator,
        _exportPreferences = exportPreferences;

  /// The document repository for file operations.
  final DocumentRepository _documentRepository;

  /// The PDF generator for creating PDFs.
  final PDFGenerator _pdfGenerator;

  /// The export preferences for remembering last folder.
  final ExportPreferences _exportPreferences;


  // ============================================================
  // Export Operations
  // ============================================================

  /// Exports a single document as a PDF to external storage.
  ///
  /// This method:
  /// 1. Decrypts the document pages to temporary files
  /// 2. Generates a PDF from the pages
  /// 3. Opens the SAF file picker for the user to select a save location
  /// 4. Saves the PDF to the selected location
  /// 5. Cleans up temporary files
  ///
  /// Returns an [ExportResult] with the operation status and details.
  ///
  /// ## Example
  /// ```dart
  /// final result = await exportService.exportDocument(document);
  /// if (result.isSuccess) {
  ///   showSnackbar('Document exporté');
  /// }
  /// ```
  Future<ExportResult> exportDocument(Document document) async {
    return exportDocuments([document]);
  }

  /// Exports multiple documents as separate PDFs to external storage.
  ///
  /// This method:
  /// 1. Decrypts each document's pages to temporary files
  /// 2. Generates a PDF for each document
  /// 3. Opens the SAF file picker for each document
  /// 4. Saves each PDF to the selected location
  /// 5. Cleans up temporary files
  ///
  /// Returns an [ExportResult] with the operation status and details.
  ///
  /// Throws [DocumentExportException] if export fails for critical errors.
  ///
  /// ## Example
  /// ```dart
  /// final result = await exportService.exportDocuments(selectedDocuments);
  /// if (result.isSuccess) {
  ///   showSnackbar('${result.exportedCount} documents exportés');
  /// }
  /// ```
  Future<ExportResult> exportDocuments(List<Document> documents) async {
    if (documents.isEmpty) {
      throw const DocumentExportException('Aucun document à exporter');
    }

    final tempFilePaths = <String>[];
    final exportedPaths = <String>[];
    String? lastFolderPath;
    String? lastFolderDisplayName;

    // Select directory once for all documents
    String? exportDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Sélectionner le dossier d\'exportation',
    );
    
    if (exportDir == null) {
      return const ExportResult.cancelled();
    }

    try {
      for (final document in documents) {
        // Get decrypted page paths
        final pagePaths = await _getDecryptedPagePaths(document);
        tempFilePaths.addAll(pagePaths);

        // Generate PDF from pages
        final pdfBytes = await _generatePdfFromPages(document, pagePaths);

        // Get suggested filename
        final suggestedFileName = _getSafeFileName(document, extension: 'pdf');

        // Determine unique save path in the selected directory
        String savedPath = p.join(exportDir, suggestedFileName);
        
        // Ensure unique filename if it already exists
        int counter = 1;
        while (await File(savedPath).exists()) {
           final nameWithoutExt = p.basenameWithoutExtension(suggestedFileName);
           final ext = p.extension(suggestedFileName);
           savedPath = p.join(exportDir, '${nameWithoutExt}_$counter$ext');
           counter++;
        }
        
        // Write the PDF bytes
        final outputFile = File(savedPath);
        await outputFile.writeAsBytes(pdfBytes);
        
        exportedPaths.add(savedPath);

        // Extract folder information from the saved path
        final folderPath = p.dirname(savedPath);
        final folderName = p.basename(folderPath);
        lastFolderPath = folderPath;
        lastFolderDisplayName = folderName;
      }

      // Save last export folder preference
      if (lastFolderPath != null) {
        await _exportPreferences.setLastExportFolder(
          lastFolderPath,
          displayName: lastFolderDisplayName,
        );
      }

      // Clean up temp files
      await _cleanupTempFiles(tempFilePaths);

      return ExportResult.success(
        exportedCount: exportedPaths.length,
        exportedPaths: exportedPaths,
        folderPath: lastFolderPath,
        folderDisplayName: lastFolderDisplayName,
      );
    } on DocumentExportException {
      // Clean up temp files before rethrowing
      await _cleanupTempFiles(tempFilePaths);
      rethrow;
    } catch (e) {
      // Clean up temp files before returning error
      await _cleanupTempFiles(tempFilePaths);

      // Handle specific error types with French messages
      String errorMessage;
      if (e.toString().contains('No space left') ||
          e.toString().contains('storage') ||
          e.toString().contains('ENOSPC')) {
        errorMessage = 'Stockage insuffisant';
      } else if (e.toString().contains('Permission denied') ||
          e.toString().contains('permission')) {
        errorMessage = 'Permission refusée';
      } else if (e is DocumentRepositoryException) {
        if (e.message.contains('not found')) {
          errorMessage = 'Document introuvable';
        } else {
          errorMessage = 'Échec du déchiffrement';
        }
      } else if (e is PDFGeneratorException) {
        errorMessage = 'Échec de la génération PDF';
      } else {
        errorMessage = 'Échec de l\'exportation';
      }

      return ExportResult.failed(errorMessage);
    }
  }

  /// Exports a document directly to bytes without user interaction.
  ///
  /// This is useful for programmatic export or sharing where the
  /// destination is already known.
  ///
  /// Returns the PDF bytes for the document.
  ///
  /// Throws [DocumentExportException] if export fails.
  Future<Uint8List> exportDocumentToBytes(Document document) async {
    final tempFilePaths = <String>[];

    try {
      // Get decrypted page paths
      final pagePaths = await _getDecryptedPagePaths(document);
      tempFilePaths.addAll(pagePaths);

      // Generate PDF from pages
      final pdfBytes = await _generatePdfFromPages(document, pagePaths);

      // Clean up temp files
      await _cleanupTempFiles(tempFilePaths);

      return pdfBytes;
    } catch (e) {
      // Clean up temp files
      await _cleanupTempFiles(tempFilePaths);

      if (e is DocumentExportException) {
        rethrow;
      }
      throw DocumentExportException(
        'Échec de l\'exportation',
        cause: e,
      );
    }
  }

  // ============================================================
  // Preferences
  // ============================================================

  /// Gets the last export folder path.
  ///
  /// Returns the stored folder path, or `null` if no folder has been selected.
  Future<String?> getLastExportFolder() async {
    return _exportPreferences.getLastExportFolder();
  }

  /// Gets the last export folder display name.
  ///
  /// Returns the stored folder name, or `null` if no folder has been selected.
  Future<String?> getLastExportFolderName() async {
    return _exportPreferences.getLastExportFolderName();
  }

  /// Clears the stored last export folder preference.
  Future<void> clearLastExportFolder() async {
    await _exportPreferences.clearLastExportFolder();
  }

  // ============================================================
  // Private Helper Methods
  // ============================================================

  /// Gets all decrypted page paths for a document.
  ///
  /// Throws [DocumentExportException] if the document cannot be decrypted.
  Future<List<String>> _getDecryptedPagePaths(Document document) async {
    try {
      return await _documentRepository.getDecryptedAllPages(document);
    } on DocumentRepositoryException catch (e) {
      if (e.message.contains('not found')) {
        throw DocumentExportException(
          'Document introuvable: ${document.title}',
          cause: e,
        );
      }
      throw DocumentExportException(
        'Échec du déchiffrement: ${document.title}',
        cause: e,
      );
    }
  }

  /// Generates a PDF from decrypted page images.
  ///
  /// Returns the PDF bytes.
  Future<Uint8List> _generatePdfFromPages(
    Document document,
    List<String> pagePaths,
  ) async {
    try {
      // Read page images
      final imageBytesList = <Uint8List>[];
      for (final pagePath in pagePaths) {
        final file = File(pagePath);
        final bytes = await file.readAsBytes();
        imageBytesList.add(bytes);
      }

      // Generate PDF with high quality settings
      final pdfResult = await _pdfGenerator.generateFromBytes(
        imageBytesList: imageBytesList,
        options: PDFGeneratorOptions(
          title: document.title,
          imageQuality: 95,
        ),
      );

      return pdfResult.bytes;
    } catch (e) {
      throw DocumentExportException(
        'Échec de la génération PDF: ${document.title}',
        cause: e,
      );
    }
  }

  /// Generates a safe file name for export.
  ///
  /// Sanitizes the document title to remove invalid file system characters.
  String _getSafeFileName(Document document, {required String extension}) {
    final title = document.title.isNotEmpty ? document.title : 'Document';
    final sanitized = title
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    return '$sanitized.$extension';
  }

  /// Cleans up temporary decrypted files.
  ///
  /// This method does not throw exceptions - cleanup errors are silently
  /// ignored as they are not critical to the user experience.
  Future<void> _cleanupTempFiles(List<String> filePaths) async {
    for (final filePath in filePaths) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Ignore cleanup errors - not critical
      }
    }

    // Also call repository cleanup for any orphaned temp files
    try {
      await _documentRepository.cleanupTempFiles();
    } catch (_) {
      // Ignore cleanup errors
    }
  }
}
