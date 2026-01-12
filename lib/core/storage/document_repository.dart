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

  /// Generates an encrypted file path for a document.
  Future<String> _generateEncryptedFilePath(
    String documentId,
    String originalExtension,
  ) async {
    final documentsDir = await _getDocumentsDirectory();
    final fileName = '$documentId$originalExtension$_encryptedExtension';
    return path.join(documentsDir.path, fileName);
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

  /// Creates a new document from a source file.
  ///
  /// This method:
  /// 1. Generates a unique ID for the document
  /// 2. Encrypts the source file and stores it
  /// 3. Optionally encrypts and stores a thumbnail
  /// 4. Creates the database record with metadata
  ///
  /// Parameters:
  /// - [title]: Display title for the document
  /// - [sourceFilePath]: Path to the unencrypted source file
  /// - [description]: Optional description
  /// - [thumbnailSourcePath]: Optional path to thumbnail image
  /// - [pageCount]: Number of pages (default 1)
  /// - [folderId]: Optional folder ID for organization
  /// - [isFavorite]: Whether to mark as favorite
  ///
  /// Returns the created [Document] with all metadata.
  ///
  /// Throws [DocumentRepositoryException] if creation fails.
  Future<Document> createDocument({
    required String title,
    required String sourceFilePath,
    String? description,
    String? thumbnailSourcePath,
    int pageCount = 1,
    String? folderId,
    bool isFavorite = false,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    try {
      // Validate source file exists
      final sourceFile = File(sourceFilePath);
      if (!await sourceFile.exists()) {
        throw const DocumentRepositoryException(
          'Source file does not exist',
        );
      }

      // Get file info
      final fileSize = await sourceFile.length();
      final originalFileName = path.basename(sourceFilePath);
      final fileExtension = path.extension(sourceFilePath);
      final mimeType = _getMimeType(fileExtension);

      // Encrypt and store the document file
      final encryptedFilePath = await _generateEncryptedFilePath(
        id,
        fileExtension,
      );
      await _encryption.encryptFile(sourceFilePath, encryptedFilePath);

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
        filePath: encryptedFilePath,
        thumbnailPath: encryptedThumbnailPath,
        originalFileName: originalFileName,
        pageCount: pageCount,
        fileSize: fileSize,
        mimeType: mimeType,
        ocrStatus: OcrStatus.pending,
        createdAt: now,
        updatedAt: now,
        folderId: folderId,
        isFavorite: isFavorite,
      );

      // Save to database
      await _database.insert(
        DatabaseHelper.tableDocuments,
        document.toMap(),
      );

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

      List<String>? tags;
      if (includeTags) {
        tags = await getDocumentTags(id);
      }

      return Document.fromMap(result, tags: tags);
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
        List<String>? tags;
        if (includeTags) {
          tags = await getDocumentTags(result[DatabaseHelper.columnId] as String);
        }
        documents.add(Document.fromMap(result, tags: tags));
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
        List<String>? tags;
        if (includeTags) {
          tags = await getDocumentTags(result[DatabaseHelper.columnId] as String);
        }
        documents.add(Document.fromMap(result, tags: tags));
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
        List<String>? tags;
        if (includeTags) {
          tags = await getDocumentTags(result[DatabaseHelper.columnId] as String);
        }
        documents.add(Document.fromMap(result, tags: tags));
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

  /// Decrypts a document file to a temporary location for viewing.
  ///
  /// **Important**: The caller is responsible for deleting the returned
  /// file after use to avoid leaving unencrypted data on disk.
  ///
  /// Returns the path to the decrypted file.
  ///
  /// Throws [DocumentRepositoryException] if decryption fails.
  Future<String> getDecryptedFilePath(Document document) async {
    try {
      final encryptedFile = File(document.filePath);
      if (!await encryptedFile.exists()) {
        throw const DocumentRepositoryException(
          'Encrypted document file not found',
        );
      }

      final tempDir = await _getTempDirectory();
      final originalExtension = document.originalFileName != null
          ? path.extension(document.originalFileName!)
          : '.jpg';
      final decryptedFileName =
          '${document.id}_${DateTime.now().millisecondsSinceEpoch}$originalExtension';
      final decryptedPath = path.join(tempDir.path, decryptedFileName);

      await _encryption.decryptFile(document.filePath, decryptedPath);

      return decryptedPath;
    } catch (e) {
      if (e is DocumentRepositoryException) {
        rethrow;
      }
      throw DocumentRepositoryException(
        'Failed to decrypt document: ${document.id}',
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

  /// Updates a document's file with a new source file.
  ///
  /// This method:
  /// 1. Encrypts the new source file
  /// 2. Deletes the old encrypted file
  /// 3. Updates the database record with the new file info
  ///
  /// Parameters:
  /// - [document]: The document to update
  /// - [newSourceFilePath]: Path to the new unencrypted source file
  ///
  /// Returns the updated [Document].
  ///
  /// Throws [DocumentRepositoryException] if the update fails.
  Future<Document> updateDocumentFile(
    Document document,
    String newSourceFilePath,
  ) async {
    try {
      final sourceFile = File(newSourceFilePath);
      if (!await sourceFile.exists()) {
        throw const DocumentRepositoryException(
          'New source file does not exist',
        );
      }

      // Get new file info
      final fileSize = await sourceFile.length();
      final originalFileName = path.basename(newSourceFilePath);
      final fileExtension = path.extension(newSourceFilePath);
      final mimeType = _getMimeType(fileExtension);

      // Generate new encrypted file path
      final newEncryptedPath = await _generateEncryptedFilePath(
        document.id,
        fileExtension,
      );

      // Encrypt new file
      await _encryption.encryptFile(newSourceFilePath, newEncryptedPath);

      // Delete old encrypted file (if different path)
      if (document.filePath != newEncryptedPath) {
        final oldFile = File(document.filePath);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }

      // Update document
      final updatedDocument = document.copyWith(
        filePath: newEncryptedPath,
        originalFileName: originalFileName,
        fileSize: fileSize,
        mimeType: mimeType,
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
        'Failed to update document file: ${document.id}',
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
  /// 1. Deletes the encrypted document file
  /// 2. Deletes the encrypted thumbnail (if exists)
  /// 3. Removes all tag associations
  /// 4. Deletes the database record
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

      // Delete encrypted document file
      final encryptedFile = File(document.filePath);
      if (await encryptedFile.exists()) {
        await encryptedFile.delete();
      }

      // Delete encrypted thumbnail
      if (document.thumbnailPath != null) {
        final thumbnailFile = File(document.thumbnailPath!);
        if (await thumbnailFile.exists()) {
          await thumbnailFile.delete();
        }
      }

      // Delete tag associations (handled by CASCADE in database)
      // Delete database record
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

  /// Cleans up temporary decrypted files.
  ///
  /// This should be called periodically or when the app goes to background.
  ///
  /// Throws [DocumentRepositoryException] if cleanup fails.
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await _getTempDirectory();
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      throw DocumentRepositoryException(
        'Failed to cleanup temp files',
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
        List<String>? tags;
        if (includeTags) {
          tags = await getDocumentTags(result[DatabaseHelper.columnId] as String);
        }
        documents.add(Document.fromMap(result, tags: tags));
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
