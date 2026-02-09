part of 'document_repository.dart';

/// CRUD (Create, Read, Update, Delete) operations for [DocumentRepository].
///
/// Includes document creation with encrypted file storage, metadata updates,
/// favorite toggling, folder management, and document deletion.
extension DocumentRepositoryCrud on DocumentRepository {
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
      // SEC-10: Validate all source paths are safe before processing
      for (final sourcePath in sourceImagePaths) {
        await _validateSourcePath(sourcePath);
      }
      if (thumbnailSourcePath != null) {
        await _validateSourcePath(thumbnailSourcePath);
      }

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

      // Encrypt and store each page (parallelized for performance)
      final encryptionTasks =
          List.generate(sourceImagePaths.length, (i) async {
        final encryptedPath = await _generatePageFilePath(id, i);
        await _encryption.encryptFile(sourceImagePaths[i], encryptedPath);
        return encryptedPath;
      });

      // Execute all encryption tasks in parallel
      final encryptedPagePaths = await Future.wait(encryptionTasks);

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

  /// Deletes a document and its associated files.
  ///
  /// This method:
  /// 1. Deletes all encrypted page files
  /// 2. Deletes the encrypted thumbnail (if exists)
  /// 3. Removes thumbnail from cache
  /// 4. Removes all tag associations
  /// 5. Removes all page records
  /// 6. Deletes the database record
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

      // Remove thumbnail from cache
      _thumbnailCache.removeThumbnail(documentId);

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
    if (documentIds.isEmpty) {
      return;
    }

    try {
      // Create parallel deletion tasks for all documents
      final deletionTasks =
          documentIds.map((id) => deleteDocument(id)).toList();

      // Execute all deletion tasks in parallel
      await Future.wait(deletionTasks);
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
}
