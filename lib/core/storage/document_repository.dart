import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../features/documents/domain/document_model.dart';
import '../exceptions/base_exception.dart';
import '../performance/cache/thumbnail_cache_service.dart';
import '../security/encryption_service.dart';
import '../security/secure_file_deletion_service.dart';
import 'database_helper.dart';

part 'document_repository_crud.dart';
part 'document_repository_queries.dart';
part 'document_repository_files.dart';
part 'document_repository_tags.dart';
part 'document_repository_utils.dart';

/// Riverpod provider for [DocumentRepository].
///
/// Provides a singleton instance of the document repository for
/// dependency injection throughout the application.
/// Depends on [EncryptionService] for file encryption,
/// [DatabaseHelper] for metadata storage, [ThumbnailCacheService]
/// for in-memory thumbnail caching, and [SecureFileDeletionService]
/// for secure deletion of temporary decrypted files.
final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  final encryption = ref.read(encryptionServiceProvider);
  final database = ref.read(databaseHelperProvider);
  final thumbnailCache = ref.read(thumbnailCacheProvider);
  final secureFileDeletion = ref.read(secureFileDeletionServiceProvider);
  return DocumentRepository(
    encryptionService: encryption,
    databaseHelper: database,
    thumbnailCacheService: thumbnailCache,
    secureFileDeletionService: secureFileDeletion,
  );
});

/// Exception thrown when document repository operations fail.
///
/// Contains the original error message and optional underlying exception.
class DocumentRepositoryException extends BaseException {
  /// Creates a [DocumentRepositoryException] with the given [message].
  const DocumentRepositoryException(super.message, {super.cause});
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
/// ## Performance
/// All document list methods use batch queries to eliminate N+1 query problems:
/// - [getAllDocuments], [getDocumentsInFolder], [getFavoriteDocuments], [getDocumentsByTag]:
///   Query count reduced from **1 + N + N** to **3 queries** total (for N documents)
/// - [searchDocuments]:
///   Query count reduced from **1 + N + N + N** to **4 queries** total
///
/// ### N+1 Query Elimination
/// Previously, fetching a list of documents would result in O(N) database queries:
/// - 1 query to fetch document metadata
/// - N queries to fetch page paths for each document individually
/// - N queries to fetch tags for each document individually (if includeTags = true)
///
/// With batch query optimization:
/// - 1 query to fetch document metadata
/// - 1 batch query to fetch ALL page paths using SQL IN clause
/// - 1 batch query to fetch ALL tags using SQL IN clause
///
/// **Example**: Loading 50 documents with tags
/// - Before: 1 + 50 + 50 = **101 queries**
/// - After: 1 + 1 + 1 = **3 queries**
/// - Improvement: **97% reduction** in database queries
///
/// This dramatically improves performance, especially on mobile devices where
/// database query overhead (context switching, lock acquisition) is significant.
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
///
/// ## File Organization
/// The repository implementation is split across multiple part files:
/// - [document_repository_crud.dart]: Create, read, update, delete operations
/// - [document_repository_queries.dart]: Listing, filtering, search, counting
/// - [document_repository_files.dart]: File decryption (pages and thumbnails)
/// - [document_repository_tags.dart]: Tag management
/// - [document_repository_utils.dart]: Temp cleanup, initialization, storage info
class DocumentRepository {
  /// Creates a [DocumentRepository] with the required dependencies.
  DocumentRepository({
    required EncryptionService encryptionService,
    required DatabaseHelper databaseHelper,
    required ThumbnailCacheService thumbnailCacheService,
    required SecureFileDeletionService secureFileDeletionService,
    Uuid? uuid,
  })  : _encryption = encryptionService,
        _database = databaseHelper,
        _thumbnailCache = thumbnailCacheService,
        _secureFileDeletion = secureFileDeletionService,
        _uuid = uuid ?? const Uuid();

  /// The encryption service for file operations.
  final EncryptionService _encryption;

  /// The database helper for metadata operations.
  final DatabaseHelper _database;

  /// The thumbnail cache service for in-memory caching.
  final ThumbnailCacheService _thumbnailCache;

  /// The secure file deletion service for temporary file cleanup.
  final SecureFileDeletionService _secureFileDeletion;

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
  // SEC-10: Path Validation (prevent path traversal attacks)
  // ============================================================

  /// Validates that a file path is within an allowed directory.
  ///
  /// SEC-10: Prevents path traversal attacks by canonicalizing the path
  /// (resolving . and ..) and checking it's within allowed boundaries.
  ///
  /// Parameters:
  /// - [filePath]: The path to validate
  /// - [allowedDirs]: List of allowed base directories
  ///
  /// Returns the canonicalized path if valid.
  ///
  /// Throws [DocumentRepositoryException] if the path is outside allowed directories.
  String _validatePathWithinAllowed(String filePath, List<String> allowedDirs) {
    // Canonicalize the path to resolve .. and .
    final canonicalPath = path.canonicalize(filePath);

    // Check if the canonicalized path starts with any allowed directory
    final isAllowed = allowedDirs.any((dir) {
      final canonicalDir = path.canonicalize(dir);
      return canonicalPath.startsWith(canonicalDir);
    });

    if (!isAllowed) {
      throw DocumentRepositoryException(
        'SEC-10: Path traversal attempt detected. Path is outside allowed directories.',
      );
    }

    return canonicalPath;
  }

  /// Validates that a source file path is safe to read from.
  ///
  /// SEC-10: Source files must be in temp, cache, or external storage directories.
  Future<void> _validateSourcePath(String sourcePath) async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = await getApplicationCacheDirectory();
    final appDir = await getApplicationDocumentsDirectory();

    // Allow temp, cache, and app directories (where scanner saves files)
    final allowedDirs = [
      tempDir.path,
      cacheDir.path,
      appDir.path,
      // Also allow external storage paths on Android for file picker imports
      '/storage/emulated/',
      '/sdcard/',
      '/data/user/',
    ];

    _validatePathWithinAllowed(sourcePath, allowedDirs);
  }

  /// Validates that an encrypted file path is within our storage directories.
  ///
  /// SEC-10: Encrypted paths must be within our documents or thumbnails directory.
  Future<void> _validateEncryptedPath(String encryptedPath) async {
    final documentsDir = await _getDocumentsDirectory();
    final thumbnailsDir = await _getThumbnailsDirectory();

    final allowedDirs = [documentsDir.path, thumbnailsDir.path];

    _validatePathWithinAllowed(encryptedPath, allowedDirs);
  }

  /// Generates an encrypted file path for a document page.
  Future<String> _generatePageFilePath(
      String documentId, int pageNumber) async {
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
        if (entity is File &&
            path.basename(entity.path).startsWith(documentId)) {
          await entity.delete();
        }
      }
      await for (final entity in thumbnailsDir.list()) {
        if (entity is File &&
            path.basename(entity.path).startsWith(documentId)) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Ignore cleanup errors
    }
  }
}
