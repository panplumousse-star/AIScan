import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/permissions/storage_permission_service.dart';
import '../../../core/storage/document_repository.dart';
import '../../documents/domain/document_model.dart';
import '../../export/domain/pdf_generator.dart';

/// Riverpod provider for [DocumentShareService].
///
/// Provides a singleton instance of the document share service for
/// dependency injection throughout the application.
/// Depends on [StoragePermissionService] for permission checks,
/// [DocumentRepository] for document decryption, and
/// [PDFGenerator] for PDF conversion.
final documentShareServiceProvider = Provider<DocumentShareService>((ref) {
  final permissionService = ref.read(storagePermissionServiceProvider);
  final documentRepository = ref.read(documentRepositoryProvider);
  final pdfGenerator = ref.read(pdfGeneratorProvider);
  return DocumentShareService(
    permissionService: permissionService,
    documentRepository: documentRepository,
    pdfGenerator: pdfGenerator,
  );
});

/// Result of a share permission check.
///
/// Contains the permission state and whether sharing can proceed.
enum SharePermissionResult {
  /// Permission is granted, sharing can proceed.
  granted,

  /// Permission needs to be requested from the system (first-time request).
  needsSystemRequest,

  /// Permission is blocked, user should be redirected to settings.
  blocked,

  /// Permission was denied by user during this session.
  denied,
}

/// Exception thrown when document share operations fail.
///
/// Contains the original error message and optional underlying exception.
class DocumentShareException implements Exception {
  /// Creates a [DocumentShareException] with the given [message].
  const DocumentShareException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'DocumentShareException: $message (caused by: $cause)';
    }
    return 'DocumentShareException: $message';
  }
}

/// Result of a document share operation.
///
/// Contains information about the shared files and cleanup paths.
@immutable
class ShareResult {
  /// Creates a [ShareResult].
  const ShareResult({
    required this.sharedCount,
    required this.tempFilePaths,
  });

  /// Number of files successfully shared.
  final int sharedCount;

  /// Paths to temporary decrypted files that need cleanup.
  final List<String> tempFilePaths;

  /// Whether any files were shared.
  bool get hasSharedFiles => sharedCount > 0;
}

/// Service for sharing PDF documents via the native Android share sheet.
///
/// This service handles all aspects of document sharing including:
/// - Storage permission checking and handling
/// - Document decryption for sharing
/// - Native share sheet integration via share_plus
/// - Cleanup of temporary decrypted files
///
/// ## Security Architecture
/// Documents are stored encrypted on disk. This service:
/// 1. Checks storage permission before any share operation
/// 2. Decrypts documents to temporary files for sharing
/// 3. Cleans up temporary files after sharing completes
///
/// ## Usage
/// ```dart
/// final shareService = ref.read(documentShareServiceProvider);
///
/// // Check if we can share (permission check)
/// final permissionResult = await shareService.checkSharePermission();
/// if (permissionResult == SharePermissionResult.granted) {
///   // Share a single document
///   final result = await shareService.shareDocument(document);
///
///   // Clean up after sharing
///   await shareService.cleanupTempFiles(result.tempFilePaths);
/// }
///
/// // Or share multiple documents
/// final result = await shareService.shareDocuments(selectedDocuments);
/// await shareService.cleanupTempFiles(result.tempFilePaths);
/// ```
///
/// ## Important Notes
/// - Always call [cleanupTempFiles] after sharing is complete
/// - Only PDF format is supported for sharing (documents must be PDFs)
/// - Uses the native Android share sheet without app filtering
class DocumentShareService {
  /// Creates a [DocumentShareService] with the required dependencies.
  DocumentShareService({
    required StoragePermissionService permissionService,
    required DocumentRepository documentRepository,
    required PDFGenerator pdfGenerator,
  })  : _permissionService = permissionService,
        _documentRepository = documentRepository,
        _pdfGenerator = pdfGenerator;

  /// The storage permission service for permission checks.
  final StoragePermissionService _permissionService;

  /// The document repository for file operations.
  final DocumentRepository _documentRepository;

  /// The PDF generator for converting images to PDF.
  final PDFGenerator _pdfGenerator;

  /// MIME type for PDF documents.
  static const String _pdfMimeType = 'application/pdf';

  // ============================================================
  // Permission Checking
  // ============================================================

  /// Checks the current storage permission state for sharing.
  ///
  /// Returns a [SharePermissionResult] indicating whether sharing can proceed
  /// and what action may be needed.
  ///
  /// Use this method before attempting to share documents to determine
  /// the appropriate user flow:
  /// - [SharePermissionResult.granted]: Proceed with sharing
  /// - [SharePermissionResult.needsSystemRequest]: Show system permission dialog
  /// - [SharePermissionResult.blocked]: Show settings redirect dialog
  /// - [SharePermissionResult.denied]: Show permission denied snackbar
  ///
  /// ## Example
  /// ```dart
  /// final result = await shareService.checkSharePermission();
  /// switch (result) {
  ///   case SharePermissionResult.granted:
  ///     await shareService.shareDocument(document);
  ///     break;
  ///   case SharePermissionResult.needsSystemRequest:
  ///     final state = await shareService.requestPermission();
  ///     if (state == StoragePermissionState.granted) {
  ///       await shareService.shareDocument(document);
  ///     }
  ///     break;
  ///   case SharePermissionResult.blocked:
  ///     await showStorageSettingsDialog(context);
  ///     break;
  ///   case SharePermissionResult.denied:
  ///     showStoragePermissionDeniedSnackbar(context);
  ///     break;
  /// }
  /// ```
  Future<SharePermissionResult> checkSharePermission() async {
    final state = await _permissionService.checkPermission();

    switch (state) {
      case StoragePermissionState.granted:
      case StoragePermissionState.sessionOnly:
        return SharePermissionResult.granted;

      case StoragePermissionState.unknown:
        // For unknown state, check if this is a first-time request
        if (await _permissionService.isFirstTimeRequest()) {
          return SharePermissionResult.needsSystemRequest;
        }
        return SharePermissionResult.blocked;

      case StoragePermissionState.denied:
        // Check if permission is blocked (needs settings) or can be requested
        if (await _permissionService.isPermissionBlocked()) {
          return SharePermissionResult.blocked;
        }
        // Permission was denied but can still be requested
        if (await _permissionService.isFirstTimeRequest()) {
          return SharePermissionResult.needsSystemRequest;
        }
        return SharePermissionResult.blocked;

      case StoragePermissionState.restricted:
      case StoragePermissionState.permanentlyDenied:
        return SharePermissionResult.blocked;
    }
  }

  /// Requests storage permission from the system.
  ///
  /// This will show the native Android permission dialog.
  ///
  /// Returns the resulting [StoragePermissionState].
  ///
  /// ## Example
  /// ```dart
  /// final state = await shareService.requestPermission();
  /// if (state == StoragePermissionState.granted ||
  ///     state == StoragePermissionState.sessionOnly) {
  ///   await shareService.shareDocument(document);
  /// }
  /// ```
  Future<StoragePermissionState> requestPermission() async {
    return _permissionService.requestSystemPermission();
  }

  /// Opens the app settings page for manual permission grant.
  ///
  /// Returns `true` if settings was opened successfully.
  Future<bool> openSettings() async {
    return _permissionService.openSettings();
  }

  /// Clears the permission cache.
  ///
  /// Call this after returning from system settings to force
  /// a fresh permission check.
  void clearPermissionCache() {
    _permissionService.clearCache();
  }

  // ============================================================
  // Share Operations
  // ============================================================

  /// Shares a single document via the native share sheet.
  ///
  /// This method:
  /// 1. Decrypts the document to a temporary file
  /// 2. Creates an XFile with PDF mime type
  /// 3. Opens the native share sheet
  ///
  /// **Important**: Call [cleanupTempFiles] with the returned paths
  /// after sharing is complete to remove decrypted files.
  ///
  /// Parameters:
  /// - [document]: The document to share
  /// - [subject]: Optional subject line for email sharing
  ///
  /// Returns a [ShareResult] with sharing details and cleanup paths.
  ///
  /// Throws [DocumentShareException] if sharing fails.
  ///
  /// ## Example
  /// ```dart
  /// try {
  ///   final result = await shareService.shareDocument(
  ///     document,
  ///     subject: 'Document: ${document.title}',
  ///   );
  ///   // Clean up temp files
  ///   await shareService.cleanupTempFiles(result.tempFilePaths);
  /// } on DocumentShareException catch (e) {
  ///   showShareErrorSnackbar(context, e.message);
  /// }
  /// ```
  Future<ShareResult> shareDocument(
    Document document, {
    String? subject,
  }) async {
    return shareDocuments([document], subject: subject);
  }

  /// Shares multiple documents via the native share sheet.
  ///
  /// This method:
  /// 1. Decrypts all documents to temporary files
  /// 2. Creates XFile instances with PDF mime type
  /// 3. Opens the native share sheet with all files
  ///
  /// **Important**: Call [cleanupTempFiles] with the returned paths
  /// after sharing is complete to remove decrypted files.
  ///
  /// Parameters:
  /// - [documents]: List of documents to share
  /// - [subject]: Optional subject line for email sharing
  ///
  /// Returns a [ShareResult] with sharing details and cleanup paths.
  ///
  /// Throws [DocumentShareException] if:
  /// - Documents list is empty
  /// - Any document file is not found
  /// - Decryption fails for any document
  /// - Share operation fails
  ///
  /// ## Example
  /// ```dart
  /// try {
  ///   final result = await shareService.shareDocuments(
  ///     selectedDocuments,
  ///     subject: 'Shared Documents',
  ///   );
  ///   print('Shared ${result.sharedCount} documents');
  ///   // Clean up temp files
  ///   await shareService.cleanupTempFiles(result.tempFilePaths);
  /// } on DocumentShareException catch (e) {
  ///   showShareErrorSnackbar(context, e.message);
  /// }
  /// ```
  Future<ShareResult> shareDocuments(
    List<Document> documents, {
    String? subject,
  }) async {
    if (documents.isEmpty) {
      throw const DocumentShareException('No documents to share');
    }

    final tempFilePaths = <String>[];
    final xFiles = <XFile>[];

    try {
      // Get temp directory for PDF files
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Process each document: decrypt image and convert to PDF
      for (final document in documents) {
        // Get decrypted image bytes
        final imageBytes = await _getDecryptedImageBytes(document);

        // Generate PDF from image
        final pdfResult = await _pdfGenerator.generateFromBytes(
          imageBytesList: [imageBytes],
          options: PDFGeneratorOptions(
            title: document.title,
            imageQuality: 95,
            pageSize: PDFPageSize.a4,
            orientation: PDFOrientation.auto,
            imageFit: PDFImageFit.contain,
          ),
        );

        // Save PDF to temp file
        final fileName = _getShareFileName(document);
        final pdfPath = path.join(tempDir.path, '${timestamp}_$fileName');
        final pdfFile = File(pdfPath);
        await pdfFile.writeAsBytes(pdfResult.bytes);

        tempFilePaths.add(pdfPath);

        // Create XFile with PDF mime type
        final xFile = XFile(
          pdfPath,
          mimeType: _pdfMimeType,
          name: fileName,
        );
        xFiles.add(xFile);
      }

      // Generate subject if not provided
      final shareSubject = subject ?? _generateSubject(documents);

      // Share via native share sheet
      await Share.shareXFiles(
        xFiles,
        subject: shareSubject,
      );

      return ShareResult(
        sharedCount: documents.length,
        tempFilePaths: tempFilePaths,
      );
    } catch (e) {
      // Clean up any temp files created before the error
      await cleanupTempFiles(tempFilePaths);

      if (e is DocumentShareException) {
        rethrow;
      }
      throw DocumentShareException(
        'Failed to share documents',
        cause: e,
      );
    }
  }

  /// Shares a file that is already decrypted/exported.
  ///
  /// Use this method when sharing from the export screen where the
  /// file is already in a shareable format.
  ///
  /// Parameters:
  /// - [filePath]: Path to the file to share
  /// - [fileName]: Display name for the file
  /// - [subject]: Optional subject line for email sharing
  ///
  /// Throws [DocumentShareException] if sharing fails.
  ///
  /// ## Example
  /// ```dart
  /// await shareService.shareExportedFile(
  ///   exportResult.filePath,
  ///   fileName: exportResult.fileName,
  ///   subject: 'Exported Document',
  /// );
  /// ```
  Future<void> shareExportedFile(
    String filePath, {
    required String fileName,
    String? subject,
  }) async {
    try {
      // Verify file exists
      final file = File(filePath);
      if (!await file.exists()) {
        throw const DocumentShareException('File not found');
      }

      final xFile = XFile(
        filePath,
        mimeType: _pdfMimeType,
        name: fileName,
      );

      await Share.shareXFiles(
        [xFile],
        subject: subject ?? fileName,
      );
    } catch (e) {
      if (e is DocumentShareException) {
        rethrow;
      }
      throw DocumentShareException(
        'Failed to share file',
        cause: e,
      );
    }
  }

  // ============================================================
  // Cleanup Operations
  // ============================================================

  /// Cleans up temporary decrypted files after sharing.
  ///
  /// This method should always be called after a successful share operation
  /// to remove any unencrypted temporary files from disk.
  ///
  /// Parameters:
  /// - [filePaths]: List of temporary file paths to delete
  ///
  /// This method does not throw exceptions - cleanup errors are silently
  /// ignored as they are not critical to the user experience.
  ///
  /// ## Example
  /// ```dart
  /// final result = await shareService.shareDocuments(documents);
  /// // Share sheet is now open...
  ///
  /// // When done, clean up
  /// await shareService.cleanupTempFiles(result.tempFilePaths);
  /// ```
  Future<void> cleanupTempFiles(List<String> filePaths) async {
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
  }

  /// Cleans up all temporary share files.
  ///
  /// This method uses the document repository's temp file cleanup.
  /// Call this when the app goes to background or on startup.
  Future<void> cleanupAllTempFiles() async {
    try {
      await _documentRepository.cleanupTempFiles();
    } catch (_) {
      // Ignore cleanup errors
    }
  }

  // ============================================================
  // Private Helper Methods
  // ============================================================

  /// Gets the decrypted file path for a document.
  ///
  /// Throws [DocumentShareException] if the document cannot be decrypted.
  Future<String> _getDecryptedFilePath(Document document) async {
    try {
      return await _documentRepository.getDecryptedFilePath(document);
    } on DocumentRepositoryException catch (e) {
      if (e.message.contains('not found')) {
        throw DocumentShareException(
          'Document file not found: ${document.title}',
          cause: e,
        );
      }
      throw DocumentShareException(
        'Failed to prepare document for sharing: ${document.title}',
        cause: e,
      );
    }
  }

  /// Gets the decrypted image bytes for a document.
  ///
  /// Throws [DocumentShareException] if the document cannot be decrypted.
  Future<Uint8List> _getDecryptedImageBytes(Document document) async {
    try {
      final decryptedPath = await _documentRepository.getDecryptedFilePath(document);
      final file = File(decryptedPath);
      return await file.readAsBytes();
    } on DocumentRepositoryException catch (e) {
      if (e.message.contains('not found')) {
        throw DocumentShareException(
          'Document file not found: ${document.title}',
          cause: e,
        );
      }
      throw DocumentShareException(
        'Failed to prepare document for sharing: ${document.title}',
        cause: e,
      );
    }
  }

  /// Generates a file name for sharing.
  ///
  /// Uses the document title with .pdf extension, sanitized for file system.
  String _getShareFileName(Document document) {
    final title = document.title.isNotEmpty ? document.title : 'Document';
    final sanitized = title
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    return '$sanitized.pdf';
  }

  /// Generates a subject line for sharing multiple documents.
  String _generateSubject(List<Document> documents) {
    if (documents.length == 1) {
      return documents.first.title;
    }
    return '${documents.length} Documents';
  }
}
