part of 'document_repository.dart';

/// Utility operations for [DocumentRepository].
///
/// Includes temp file cleanup, readiness checks, initialization,
/// and storage information.
extension DocumentRepositoryUtils on DocumentRepository {
  /// Cleans up temporary decrypted files from the temp directory.
  ///
  /// Call this periodically to free up disk space from temporary files.
  /// Uses secure deletion to prevent forensic recovery of sensitive data.
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await _getTempDirectory();
      final tempFiles = await tempDir.list().toList();
      final filePaths = <String>[];

      // Collect all file paths
      for (final entity in tempFiles) {
        if (entity is File) {
          filePaths.add(entity.path);
        }
      }

      // Securely delete all files in batch
      if (filePaths.isNotEmpty) {
        try {
          await _secureFileDeletion.secureDeleteFiles(filePaths);
        } catch (_) {
          // Ignore batch deletion errors
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
