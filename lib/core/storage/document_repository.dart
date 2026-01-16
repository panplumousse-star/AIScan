import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../features/documents/domain/document_model.dart';
import '../security/encryption_service.dart';
import 'database_helper.dart';

/// Riverpod provider for [DocumentRepository].
///
/// Provides a singleton instance of the document repository for
/// dependency injection throughout the application.
/// Depends on [EncryptionService] for file encryption and
/// [DatabaseHelper] for metadata storage.
final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  final encryption = ref.read(encryptionServiceProvider);
  final database = ref.read(databaseHelperProvider);
  return DocumentRepository(
    encryptionService: encryption,
    databaseHelper: database,
  );
});

/// Exception thrown when document repository operations fail.
///
/// Contains the original error message and optional underlying exception.
class DocumentRepositoryException implements Exception {
  /// Creates a [DocumentRepositoryException] with the given [message].
  const DocumentRepositoryException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'DocumentRepositoryException: $message (caused by: $cause)';
    }
    return 'DocumentRepositoryException: $message';
  }
}

/// Repository for managing documents with encrypted storage.
///
/// This repository handles all document operations including:
/// - Creating new documents with encrypted file storage
/// - Reading documents with automatic decryption
/// - Updating document metadata and files
/// - Deleting documents and their encrypted files
/// - Querying documents with various filters
/// - Managing document tags
///
/// ## Security Architecture
/// All document files are stored encrypted on disk using AES-256.
/// - Source files are encrypted using [EncryptionService.encryptFile]
/// - Encrypted files are stored with `.enc` extension in the documents directory
/// - Decryption happens on-demand when accessing document content
/// - Metadata is stored in SQLite via [DatabaseHelper]
///
/// ## Usage
/// ```dart
/// final repository = ref.read(documentRepositoryProvider);
///
/// // Create a new document from a scanned image
/// final document = await repository.createDocument(
///   title: 'My Scan',
///   sourceFilePath: '/path/to/scan.jpg',
/// );
///
/// // Get the decrypted file path for viewing
/// final decryptedPath = await repository.getDecryptedFilePath(document);
///
/// // Delete when done with decrypted file
/// await File(decryptedPath).delete();
///
/// // Update metadata
/// await repository.updateDocument(document.copyWith(title: 'New Title'));
///
/// // Delete document
/// await repository.deleteDocument(document.id);
/// ```
///
/// ## Important Notes
/// - Always delete temporary decrypted files after use
/// - Never store unencrypted document data permanently
/// - Thumbnail files are also encrypted
/// - Tags are managed separately from document metadata
class DocumentRepository {
  /// Creates a [DocumentRepository] with the required dependencies.
  DocumentRepository({
    required EncryptionService encryptionService,
    required DatabaseHelper databaseHelper,
    Uuid? uuid,
  })  : _encryption = encryptionService,
        _database = databaseHelper,
        _uuid = uuid ?? const Uuid();

  /// The encryption service for file operations.
  final EncryptionService _encryption;

  /// The database helper for metadata operations.
  final DatabaseHelper _database;

  /// UUID generator for document IDs.
  final Uuid _uuid;

  /// Directory name for storing encrypted documents.
  static const String _documentsDirectoryName = 'documents';

  /// Directory name for storing encrypted thumbnails.
  static const String _thumbnailsDirectoryName = 'thumbnails';

  /// Directory name for temporary decrypted files.
  static const String _tempDirectoryName = 'temp';

  /// File extension for encrypted files.
  static const String _encryptedExtension = '.enc';

  // ============================================================
  // Directory Management
  // ============================================================

  /// Gets the base documents storage directory.
  ///
  /// Creates the directory if it doesn't exist.
  Future<Directory> _getDocumentsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final documentsDir = Directory(
      path.join(appDir.path, _documentsDirectoryName),
    );
    if (!await documentsDir.exists()) {
      await documentsDir.create(recursive: true);
    }
    return documentsDir;
  }

  /// Gets the thumbnails storage directory.
  ///
  /// Creates the directory if it doesn't exist.
  Future<Directory> _getThumbnailsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final thumbnailsDir = Directory(
      path.join(appDir.path, _thumbnailsDirectoryName),
    );
    if (!await thumbnailsDir.exists()) {
      await thumbnailsDir.create(recursive: true);
    }
    return thumbnailsDir;
  }

  /// Gets the temporary directory for decrypted files.
  ///
  /// Creates the directory if it doesn't exist.
  Future<Directory> _getTempDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final aiscanTempDir = Directory(
      path.join(tempDir.path, _tempDirectoryName),
    );
    if (!await aiscanTempDir.exists()) {
      await aiscanTempDir.create(recursive: true);
    }
    return aiscanTempDir;
  }

  /// Generates an encrypted thumbnail path for a document.
  Future<String> _generateThumbnailPath(String documentId) async {
    final thumbnailsDir = await _getThumbnailsDirectory();
    final fileName = '$documentId.jpg$_encryptedExtension';
    return path.join(thumbnailsDir.path, fileName);
  }

  // ============================================================
  // Create Operations
  // ============================================================

  /// Creates a new document from multiple PNG source images.
  ///
  /// This method:
  /// 1. Generates a unique ID for the document
  /// 2. Encrypts each source image and stores it as a page
  /// 3. Optionally encrypts and stores a thumbnail
  /// 4. Creates the database record with metadata
  /// 5. Creates page records in document_pages table
  ///
  /// Parameters:
  /// - [title]: Display title for the document
  /// - [sourceImagePaths]: List of paths to unencrypted PNG source images
  /// - [description]: Optional description
  /// - [thumbnailSourcePath]: Optional path to thumbnail image
  /// - [folderId]: Optional folder ID for organization
  /// - [isFavorite]: Whether to mark as favorite
  ///
  /// Returns the created [Document] with all metadata.
  ///
  /// Throws [DocumentRepositoryException] if creation fails.
  Future<Document> createDocumentWithPages({
    required String title,
    required List<String> sourceImagePaths,
    String? description,
    String? thumbnailSourcePath,
    String? folderId,
    bool isFavorite = false,
  }) async {
    if (sourceImagePaths.isEmpty) {
      throw const DocumentRepositoryException(
        'At least one source image is required',
      );
    }

    final id = _uuid.v4();
    final now = DateTime.now();

    try {
      // Validate all source files exist
      int totalFileSize = 0;
      for (final sourcePath in sourceImagePaths) {
        final sourceFile = File(sourcePath);
        if (!await sourceFile.exists()) {
          throw DocumentRepositoryException(
            'Source file does not exist: $sourcePath',
          );
        }
        totalFileSize += await sourceFile.length();
      }

      // Get file info from first page
      final originalFileName = path.basename(sourceImagePaths.first);

      // Encrypt and store each page
      final encryptedPagePaths = <String>[];
      for (var i = 0; i < sourceImagePaths.length; i++) {
        final encryptedPath = await _generatePageFilePath(id, i);
        await _encryption.encryptFile(sourceImagePaths[i], encryptedPath);
        encryptedPagePaths.add(encryptedPath);
      }

      // Encrypt and store thumbnail if provided
      String? encryptedThumbnailPath;
      if (thumbnailSourcePath != null) {
        final thumbnailFile = File(thumbnailSourcePath);
        if (await thumbnailFile.exists()) {
          encryptedThumbnailPath = await _generateThumbnailPath(id);
          await _encryption.encryptFile(
            thumbnailSourcePath,
            encryptedThumbnailPath,
          );
        }
      }

      // Create document model
      final document = Document(
        id: id,
        title: title,
        description: description,
        pagesPaths: encryptedPagePaths,
        thumbnailPath: encryptedThumbnailPath,
        originalFileName: originalFileName,
        fileSize: totalFileSize,
        mimeType: 'image/png',
        ocrStatus: OcrStatus.pending,
        createdAt: now,
        updatedAt: now,
        folderId: folderId,
        isFavorite: isFavorite,
      );

      // Save document to database
      await _database.insert(
        DatabaseHelper.tableDocuments,
        document.toMap(),
      );

      // Save pages to document_pages table
      await _database.insertDocumentPages(id, encryptedPagePaths);

      return document;
    } catch (e) {
      // Clean up any partially created files on failure
      await _cleanupPartialCreate(id);

      if (e is DocumentRepositoryException) {
        rethrow;
      }
      throw DocumentRepositoryException(
        'Failed to create document: $title',
        cause: e,
      );
    }
  }

  /// Generates an encrypted file path for a document page.
  Future<String> _generatePageFilePath(String documentId, int pageNumber) async {
    final documentsDir = await _getDocumentsDirectory();
    final fileName = '${documentId}_page_$pageNumber.png$_encryptedExtension';
    return path.join(documentsDir.path, fileName);
  }

  /// Cleans up any partially created files during a failed create operation.
  Future<void> _cleanupPartialCreate(String documentId) async {
    try {
      final documentsDir = await _getDocumentsDirectory();
      final thumbnailsDir = await _getThumbnailsDirectory();

      // Delete any files starting with the document ID
      await for (final entity in documentsDir.list()) {
        if (entity is File && path.basename(entity.path).startsWith(documentId)) {
          await entity.delete();
        }
      }
      await for (final entity in thumbnailsDir.list()) {
        if (entity is File && path.basename(entity.path).startsWith(documentId)) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Ignore cleanup errors
    }
  }

  // ============================================================
  // Read Operations
  // ============================================================

  /// Gets a document by ID.
  ///
  /// Returns the [Document] if found, or `null` if not found.
  ///
  /// Optionally loads the document's tags if [includeTags] is true.
  ///
  /// Throws [DocumentRepositoryException] if the query fails.
  Future<Document?> getDocument(
    String id, {
    bool includeTags = false,
  }) async {
    try {
      final result = await _database.getById(
        DatabaseHelper.tableDocuments,
        id,
      );

      if (result == null) {
        return null;
      }

      // Load page paths from document_pages table
      final pagesPaths = await _database.getDocumentPagePaths(id);

      List<String>? tags;
      if (includeTags) {
        tags = await getDocumentTags(id);
      }

      return Document.fromMap(result, pagesPaths: pagesPaths, tags: tags);
    } catch (e) {
      if (e is DocumentRepositoryException) {
        rethrow;
      }
      throw DocumentRepositoryException(
        'Failed to get document: $id',
        cause: e,
      );
    }
  }

  /// Gets all documents.
  ///
  /// Returns a list of all documents, optionally with their tags.
  ///
  /// Parameters:
  /// - [includeTags]: Whether to load tags for each document
  /// - [orderBy]: SQL ORDER BY clause (default: created_at DESC)
  /// - [limit]: Maximum number of documents to return
  /// - [offset]: Number of documents to skip (for pagination)
  ///
  /// Throws [DocumentRepositoryException] if the query fails.
  Future<List<Document>> getAllDocuments({
    bool includeTags = false,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final results = await _database.query(
        DatabaseHelper.tableDocuments,
        orderBy: orderBy ?? '${DatabaseHelper.columnCreatedAt} DESC',
        limit: limit,
        offset: offset,
      );

      final documents = <Document>[];
      for (final result in results) {
        final docId = result[DatabaseHelper.columnId] as String;
        final pagesPaths = await _database.getDocumentPagePaths(docId);
        List<String>? tags;
        if (includeTags) {
          tags = await getDocumentTags(docId);
        }
        documents.add(Document.fromMap(result, pagesPaths: pagesPaths, tags: tags));
      }

      return documents;
    } catch (e) {
      throw DocumentRepositoryException(
        'Failed to get all documents',
        cause: e,
      );
    }
  }

  /// Gets documents in a specific folder.
  ///
  /// Parameters:
  /// - [folderId]: The folder ID, or null for root-level documents
  /// - [includeTags]: Whether to load tags for each document
  /// - [orderBy]: SQL ORDER BY clause
  ///
  /// Throws [DocumentRepositoryException] if the query fails.
  Future<List<Document>> getDocumentsInFolder(
    String? folderId, {
    bool includeTags = false,
    String? orderBy,
  }) async {
    try {
      final results = await _database.query(
        DatabaseHelper.tableDocuments,
        where: folderId != null
            ? '${DatabaseHelper.columnFolderId} = ?'
            : '${DatabaseHelper.columnFolderId} IS NULL',
        whereArgs: folderId != null ? [folderId] : null,
        orderBy: orderBy ?? '${DatabaseHelper.columnCreatedAt} DESC',
      );

      final documents = <Document>[];
      for (final result in results) {
        final docId = result[DatabaseHelper.columnId] as String;
        final pagesPaths = await _database.getDocumentPagePaths(docId);
        List<String>? tags;
        if (includeTags) {
          tags = await getDocumentTags(docId);
        }
        documents.add(Document.fromMap(result, pagesPaths: pagesPaths, tags: tags));
      }

      return documents;
    } catch (e) {
      throw DocumentRepositoryException(
        'Failed to get documents in folder: $folderId',
        cause: e,
      );
    }
  }

  /// Gets favorite documents.
  ///
  /// Throws [DocumentRepositoryException] if the query fails.
  Future<List<Document>> getFavoriteDocuments({
    bool includeTags = false,
  }) async {
    try {
      final results = await _database.query(
        DatabaseHelper.tableDocuments,
        where: '${DatabaseHelper.columnIsFavorite} = ?',
        whereArgs: [1],
        orderBy: '${DatabaseHelper.columnCreatedAt} DESC',
      );

      final documents = <Document>[];
      for (final result in results) {
        final docId = result[DatabaseHelper.columnId] as String;
        final pagesPaths = await _database.getDocumentPagePaths(docId);
        List<String>? tags;
        if (includeTags) {
          tags = await getDocumentTags(docId);
        }
        documents.add(Document.fromMap(result, pagesPaths: pagesPaths, tags: tags));
      }

      return documents;
    } catch (e) {
      throw DocumentRepositoryException(
        'Failed to get favorite documents',
        cause: e,
      );
    }
  }

  /// Gets the count of all documents.
  ///
  /// Throws [DocumentRepositoryException] if the query fails.
  Future<int> getDocumentCount() async {
    try {
      return await _database.count(DatabaseHelper.tableDocuments);
    } catch (e) {
      throw DocumentRepositoryException(
        'Failed to get document count',
        cause: e,
      );
    }
  }

  /// Decrypts a specific page of a document to a temporary location for viewing.
  ///
  /// **Important**: The caller is responsible for deleting the returned
  /// file after use to avoid leaving unencrypted data on disk.
  ///
  /// Parameters:
  /// - [document]: The document containing the page
  /// - [pageIndex]: Zero-based index of the page to decrypt (default: 0)
  ///
  /// Returns the path to the decrypted page image.
  ///
  /// Throws [DocumentRepositoryException] if decryption fails.
  Future<String> getDecryptedPagePath(Document document, {int pageIndex = 0}) async {
    try {
      if (pageIndex < 0 || pageIndex >= document.pageCount) {
        throw DocumentRepositoryException(
          'Invalid page index: $pageIndex (document has ${document.pageCount} pages)',
        );
      }

      final encryptedPath = document.pagesPaths[pageIndex];
      final encryptedFile = File(encryptedPath);
      if (!await encryptedFile.exists()) {
        throw const DocumentRepositoryException(
          'Encrypted document page file not found',
        );
      }

      final tempDir = await _getTempDirectory();
      final decryptedFileName =
          '${document.id}_page_${pageIndex}_${DateTime.now().millisecondsSinceEpoch}.png';
      final decryptedPath = path.join(tempDir.path, decryptedFileName);

      await _encryption.decryptFile(encryptedPath, decryptedPath);

      return decryptedPath;
    } catch (e) {
      if (e is DocumentRepositoryException) {
        rethrow;
      }
      throw DocumentRepositoryException(
        'Failed to decrypt document page: ${document.id} page $pageIndex',
        cause: e,
      );
    }
  }

  /// Decrypts all pages of a document to temporary locations.
  ///
  /// **Important**: The caller is responsible for deleting all returned
  /// files after use to avoid leaving unencrypted data on disk.
  ///
  /// Returns a list of paths to the decrypted page images, in order.
  ///
  /// Throws [DocumentRepositoryException] if decryption fails.
  Future<List<String>> getDecryptedAllPages(Document document) async {
    try {
      final decryptedPaths = <String>[];
      final tempDir = await _getTempDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (var i = 0; i < document.pagesPaths.length; i++) {
        final encryptedPath = document.pagesPaths[i];
        final encryptedFile = File(encryptedPath);
        if (!await encryptedFile.exists()) {
          throw DocumentRepositoryException(
            'Encrypted document page file not found: page $i',
          );
        }

        final decryptedFileName = '${document.id}_page_${i}_$timestamp.png';
        final decryptedPath = path.join(tempDir.path, decryptedFileName);

        await _encryption.decryptFile(encryptedPath, decryptedPath);
        decryptedPaths.add(decryptedPath);
      }

      return decryptedPaths;
    } catch (e) {
      if (e is DocumentRepositoryException) {
        rethrow;
      }
      throw DocumentRepositoryException(
        'Failed to decrypt document pages: ${document.id}',
        cause: e,
      );
    }
  }

  /// Decrypts a document page and returns the raw bytes.
  ///
  /// Decrypts the file to a temporary location, reads the bytes, then cleans up.
  ///
  /// Parameters:
  /// - [document]: The document containing the page
  /// - [pageIndex]: Zero-based index of the page (default: 0)
  ///
  /// Returns the decrypted image bytes.
  ///
  /// Throws [DocumentRepositoryException] if decryption fails.
  Future<List<int>> getDecryptedPageBytes(Document document, {int pageIndex = 0}) async {
    try {
      if (pageIndex < 0 || pageIndex >= document.pageCount) {
        throw DocumentRepositoryException(
          'Invalid page index: $pageIndex (document has ${document.pageCount} pages)',
        );
      }

      final encryptedPath = document.pagesPaths[pageIndex];
      final encryptedFile = File(encryptedPath);
      if (!await encryptedFile.exists()) {
        throw const DocumentRepositoryException(
          'Encrypted document page file not found',
        );
      }

      // Decrypt to temp file (encryptFile uses native AES-CTR, not in-memory AES-CBC)
      final tempDir = await _getTempDirectory();
      final decryptedFileName =
          '${document.id}_page_${pageIndex}_${DateTime.now().millisecondsSinceEpoch}.png';
      final decryptedPath = path.join(tempDir.path, decryptedFileName);

      await _encryption.decryptFile(encryptedPath, decryptedPath);

      // Read bytes from decrypted file
      final decryptedFile = File(decryptedPath);
      final bytes = await decryptedFile.readAsBytes();

      // Clean up temp file immediately
      try {
        await decryptedFile.delete();
      } catch (_) {
        // Ignore cleanup errors
      }

      return bytes.toList();
    } catch (e) {
      if (e is DocumentRepositoryException) {
        rethrow;
      }
      throw DocumentRepositoryException(
        'Failed to decrypt document page bytes: ${document.id} page $pageIndex',
        cause: e,
      );
    }
  }

  /// Decrypts a document thumbnail to a temporary location.
  ///
  /// Returns the path to the decrypted thumbnail, or `null` if
  /// the document has no thumbnail.
  ///
  /// **Important**: The caller is responsible for deleting the returned
  /// file after use.
  ///
  /// Throws [DocumentRepositoryException] if decryption fails.
  Future<String?> getDecryptedThumbnailPath(Document document) async {
    if (document.thumbnailPath == null) {
      return null;
    }

    try {
      final encryptedFile = File(document.thumbnailPath!);
      if (!await encryptedFile.exists()) {
        return null;
      }

      final tempDir = await _getTempDirectory();
      final decryptedFileName =
          '${document.id}_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final decryptedPath = path.join(tempDir.path, decryptedFileName);

      await _encryption.decryptFile(document.thumbnailPath!, decryptedPath);

      return decryptedPath;
    } catch (e) {
      throw DocumentRepositoryException(
        'Failed to decrypt thumbnail: ${document.id}',
        cause: e,
      );
    }
  }

  // ============================================================
  // Update Operations
  // ============================================================

  /// Updates a document's metadata.
  ///
  /// This method only updates the database record. To update the
  /// document file itself, use [updateDocumentFile].
  ///
  /// Returns the updated [Document].
  ///
  /// Throws [DocumentRepositoryException] if the update fails.
  Future<Document> updateDocument(Document document) async {
    try {
      final updatedDocument = document.copyWith(
        updatedAt: DateTime.now(),
      );

      final rowsAffected = await _database.update(
        DatabaseHelper.tableDocuments,
        updatedDocument.toMap(),
        where: '${DatabaseHelper.columnId} = ?',
        whereArgs: [document.id],
      );

      if (rowsAffected == 0) {
        throw DocumentRepositoryException(
          'Document not found: ${document.id}',
        );
      }

      return updatedDocument;
    } catch (e) {
      if (e is DocumentRepositoryException) {
        rethrow;
      }
      throw DocumentRepositoryException(
        'Failed to update document: ${document.id}',
        cause: e,
      );
    }
  }

  /// Updates a document's thumbnail.
  ///
  /// Parameters:
  /// - [document]: The document to update
  /// - [newThumbnailPath]: Path to the new thumbnail, or null to remove
  ///
  /// Returns the updated [Document].
  ///
  /// Throws [DocumentRepositoryException] if the update fails.
  Future<Document> updateDocumentThumbnail(
    Document document,
    String? newThumbnailPath,
  ) async {
    try {
      String? encryptedThumbnailPath;

      // Delete old thumbnail if exists
      if (document.thumbnailPath != null) {
        final oldThumbnail = File(document.thumbnailPath!);
        if (await oldThumbnail.exists()) {
          await oldThumbnail.delete();
        }
      }

      // Encrypt and store new thumbnail if provided
      if (newThumbnailPath != null) {
        final thumbnailFile = File(newThumbnailPath);
        if (await thumbnailFile.exists()) {
          encryptedThumbnailPath = await _generateThumbnailPath(document.id);
          await _encryption.encryptFile(
            newThumbnailPath,
            encryptedThumbnailPath,
          );
        }
      }

      // Update document
      final updatedDocument = document.copyWith(
        thumbnailPath: encryptedThumbnailPath,
        clearThumbnailPath: newThumbnailPath == null,
        updatedAt: DateTime.now(),
      );

      await _database.update(
        DatabaseHelper.tableDocuments,
        updatedDocument.toMap(),
        where: '${DatabaseHelper.columnId} = ?',
        whereArgs: [document.id],
      );

      return updatedDocument;
    } catch (e) {
      if (e is DocumentRepositoryException) {
        rethrow;
      }
      throw DocumentRepositoryException(
        'Failed to update document thumbnail: ${document.id}',
        cause: e,
      );
    }
  }

  /// Updates the OCR text for a document.
  ///
  /// Parameters:
  /// - [documentId]: The document ID
  /// - [ocrText]: The extracted OCR text
  /// - [status]: The new OCR status (default: completed)
  ///
  /// Returns the updated [Document].
  ///
  /// Throws [DocumentRepositoryException] if the update fails.
  Future<Document> updateDocumentOcr(
    String documentId,
    String? ocrText, {
    OcrStatus status = OcrStatus.completed,
  }) async {
    try {
      final document = await getDocument(documentId);
      if (document == null) {
        throw DocumentRepositoryException(
          'Document not found: $documentId',
        );
      }

      final updatedDocument = document.copyWith(
        ocrText: ocrText,
        ocrStatus: status,
        clearOcrText: ocrText == null,
        updatedAt: DateTime.now(),
      );

      await _database.update(
        DatabaseHelper.tableDocuments,
        updatedDocument.toMap(),
        where: '${DatabaseHelper.columnId} = ?',
        whereArgs: [documentId],
      );

      return updatedDocument;
    } catch (e) {
      if (e is DocumentRepositoryException) {
        rethrow;
      }
      throw DocumentRepositoryException(
        'Failed to update document OCR: $documentId',
        cause: e,
      );
    }
  }

  /// Toggles the favorite status of a document.
  ///
  /// Returns the updated [Document].
  ///
  /// Throws [DocumentRepositoryException] if the update fails.
  Future<Document> toggleFavorite(String documentId) async {
    try {
      final document = await getDocument(documentId);
      if (document == null) {
        throw DocumentRepositoryException(
          'Document not found: $documentId',
        );
      }

      return await updateDocument(
        document.copyWith(isFavorite: !document.isFavorite),
      );
    } catch (e) {
      if (e is DocumentRepositoryException) {
        rethrow;
      }
      throw DocumentRepositoryException(
        'Failed to toggle favorite: $documentId',
        cause: e,
      );
    }
  }

  /// Moves a document to a folder.
  ///
  /// Parameters:
  /// - [documentId]: The document ID
  /// - [folderId]: The target folder ID, or null for root
  ///
  /// Returns the updated [Document].
  ///
  /// Throws [DocumentRepositoryException] if the update fails.
  Future<Document> moveToFolder(String documentId, String? folderId) async {
    try {
      final document = await getDocument(documentId);
      if (document == null) {
        throw DocumentRepositoryException(
          'Document not found: $documentId',
        );
      }

      return await updateDocument(
        document.copyWith(
          folderId: folderId,
          clearFolderId: folderId == null,
        ),
      );
    } catch (e) {
      if (e is DocumentRepositoryException) {
        rethrow;
      }
      throw DocumentRepositoryException(
        'Failed to move document: $documentId',
        cause: e,
      );
    }
  }

  // ============================================================
  // Delete Operations
  // ============================================================

  /// Deletes a document and its associated files.
  ///
  /// This method:
  /// 1. Deletes all encrypted page files
  /// 2. Deletes the encrypted thumbnail (if exists)
  /// 3. Removes all tag associations
  /// 4. Removes all page records
  /// 5. Deletes the database record
  ///
  /// Throws [DocumentRepositoryException] if deletion fails.
  Future<void> deleteDocument(String documentId) async {
    try {
      // Get document to find file paths
      final document = await getDocument(documentId);
      if (document == null) {
        throw DocumentRepositoryException(
          'Document not found: $documentId',
        );
      }

      // Delete all encrypted page files
      for (final pagePath in document.pagesPaths) {
        final pageFile = File(pagePath);
        if (await pageFile.exists()) {
          await pageFile.delete();
        }
      }

      // Delete encrypted thumbnail
      if (document.thumbnailPath != null) {
        final thumbnailFile = File(document.thumbnailPath!);
        if (await thumbnailFile.exists()) {
          await thumbnailFile.delete();
        }
      }

      // Delete page records (handled by CASCADE, but explicit for safety)
      await _database.deleteDocumentPages(documentId);

      // Delete tag associations and database record (CASCADE handles tags)
      await _database.delete(
        DatabaseHelper.tableDocuments,
        where: '${DatabaseHelper.columnId} = ?',
        whereArgs: [documentId],
      );
    } catch (e) {
      if (e is DocumentRepositoryException) {
        rethrow;
      }
      throw DocumentRepositoryException(
        'Failed to delete document: $documentId',
        cause: e,
      );
    }
  }

  /// Deletes multiple documents.
  ///
  /// Throws [DocumentRepositoryException] if any deletion fails.
  Future<void> deleteDocuments(List<String> documentIds) async {
    try {
      for (final id in documentIds) {
        await deleteDocument(id);
      }
    } catch (e) {
      if (e is DocumentRepositoryException) {
        rethrow;
      }
      throw DocumentRepositoryException(
        'Failed to delete documents',
        cause: e,
      );
    }
  }

  // ============================================================
  // Tag Operations
  // ============================================================

  /// Gets all tags for a document.
  ///
  /// Returns a list of tag IDs.
  ///
  /// Throws [DocumentRepositoryException] if the query fails.
  Future<List<String>> getDocumentTags(String documentId) async {
    try {
      final results = await _database.query(
        DatabaseHelper.tableDocumentTags,
        columns: [DatabaseHelper.columnTagId],
        where: '${DatabaseHelper.columnDocumentId} = ?',
        whereArgs: [documentId],
      );

      return results
          .map((row) => row[DatabaseHelper.columnTagId] as String)
          .toList();
    } catch (e) {
      throw DocumentRepositoryException(
        'Failed to get document tags: $documentId',
        cause: e,
      );
    }
  }

  /// Adds a tag to a document.
  ///
  /// Throws [DocumentRepositoryException] if the operation fails.
  Future<void> addTagToDocument(String documentId, String tagId) async {
    try {
      await _database.insert(
        DatabaseHelper.tableDocumentTags,
        {
          DatabaseHelper.columnDocumentId: documentId,
          DatabaseHelper.columnTagId: tagId,
          DatabaseHelper.columnCreatedAt: DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      throw DocumentRepositoryException(
        'Failed to add tag to document: $documentId',
        cause: e,
      );
    }
  }

  /// Removes a tag from a document.
  ///
  /// Throws [DocumentRepositoryException] if the operation fails.
  Future<void> removeTagFromDocument(String documentId, String tagId) async {
    try {
      await _database.delete(
        DatabaseHelper.tableDocumentTags,
        where:
            '${DatabaseHelper.columnDocumentId} = ? AND ${DatabaseHelper.columnTagId} = ?',
        whereArgs: [documentId, tagId],
      );
    } catch (e) {
      throw DocumentRepositoryException(
        'Failed to remove tag from document: $documentId',
        cause: e,
      );
    }
  }

  /// Gets all documents with a specific tag.
  ///
  /// Throws [DocumentRepositoryException] if the query fails.
  Future<List<Document>> getDocumentsByTag(
    String tagId, {
    bool includeTags = false,
  }) async {
    try {
      // Join documents with document_tags
      final results = await _database.rawQuery(
        '''
        SELECT d.* FROM ${DatabaseHelper.tableDocuments} d
        INNER JOIN ${DatabaseHelper.tableDocumentTags} dt
          ON d.${DatabaseHelper.columnId} = dt.${DatabaseHelper.columnDocumentId}
        WHERE dt.${DatabaseHelper.columnTagId} = ?
        ORDER BY d.${DatabaseHelper.columnCreatedAt} DESC
        ''',
        [tagId],
      );

      final documents = <Document>[];
      for (final result in results) {
        final docId = result[DatabaseHelper.columnId] as String;
        final pagesPaths = await _database.getDocumentPagePaths(docId);
        List<String>? tags;
        if (includeTags) {
          tags = await getDocumentTags(docId);
        }
        documents.add(Document.fromMap(result, pagesPaths: pagesPaths, tags: tags));
      }

      return documents;
    } catch (e) {
      throw DocumentRepositoryException(
        'Failed to get documents by tag: $tagId',
        cause: e,
      );
    }
  }

  // ============================================================
  // Search Operations
  // ============================================================

  /// Searches documents using full-text search.
  ///
  /// Searches across title, description, and OCR text.
  ///
  /// Returns documents matching the search query.
  ///
  /// Throws [DocumentRepositoryException] if the search fails.
  Future<List<Document>> searchDocuments(
    String query, {
    bool includeTags = false,
  }) async {
    try {
      final documentIds = await _database.searchDocuments(query);

      final documents = <Document>[];
      for (final id in documentIds) {
        final document = await getDocument(id, includeTags: includeTags);
        if (document != null) {
          documents.add(document);
        }
      }

      return documents;
    } catch (e) {
      throw DocumentRepositoryException(
        'Failed to search documents: $query',
        cause: e,
      );
    }
  }

  // ============================================================
  // Utility Methods
  // ============================================================

  /// Gets the MIME type for a file extension.
  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.pdf':
        return 'application/pdf';
      case '.heic':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }

  /// Cleans up temporary decrypted files from the temp directory.
  ///
  /// Call this periodically to free up disk space from temporary files.
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await _getTempDirectory();
      final tempFiles = await tempDir.list().toList();
      for (final entity in tempFiles) {
        if (entity is File) {
          try {
            await entity.delete();
          } catch (_) {
            // Ignore individual file deletion errors
          }
        }
      }
    } catch (_) {
      // Ignore cleanup errors
    }
  }

  /// Checks if the encryption service is ready.
  ///
  /// Returns true if the encryption key is initialized.
  Future<bool> isReady() async {
    return await _encryption.isReady();
  }

  /// Initializes the repository.
  ///
  /// This should be called during app startup to ensure:
  /// - The database is initialized
  /// - The encryption key is available
  /// - Storage directories exist
  ///
  /// Returns true if initialization was successful.
  Future<bool> initialize() async {
    try {
      // Ensure database is initialized
      await _database.initialize();

      // Ensure encryption key is ready
      await _encryption.ensureKeyInitialized();

      // Create storage directories
      await _getDocumentsDirectory();
      await _getThumbnailsDirectory();
      await _getTempDirectory();

      return true;
    } catch (e) {
      throw DocumentRepositoryException(
        'Failed to initialize document repository',
        cause: e,
      );
    }
  }

  /// Gets storage usage information.
  ///
  /// Returns a map with:
  /// - documentCount: Number of documents
  /// - documentsSize: Total size of encrypted documents in bytes
  /// - thumbnailsSize: Total size of encrypted thumbnails in bytes
  /// - tempSize: Total size of temporary files in bytes
  ///
  /// Throws [DocumentRepositoryException] if the operation fails.
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final documentCount = await getDocumentCount();

      int documentsSize = 0;
      int thumbnailsSize = 0;
      int tempSize = 0;

      final documentsDir = await _getDocumentsDirectory();
      await for (final entity in documentsDir.list()) {
        if (entity is File) {
          documentsSize += await entity.length();
        }
      }

      final thumbnailsDir = await _getThumbnailsDirectory();
      await for (final entity in thumbnailsDir.list()) {
        if (entity is File) {
          thumbnailsSize += await entity.length();
        }
      }

      final tempDir = await _getTempDirectory();
      await for (final entity in tempDir.list()) {
        if (entity is File) {
          tempSize += await entity.length();
        }
      }

      return {
        'documentCount': documentCount,
        'documentsSize': documentsSize,
        'thumbnailsSize': thumbnailsSize,
        'tempSize': tempSize,
        'totalSize': documentsSize + thumbnailsSize,
      };
    } catch (e) {
      throw DocumentRepositoryException(
        'Failed to get storage info',
        cause: e,
      );
    }
  }
}
