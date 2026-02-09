part of 'document_repository.dart';

/// Query operations for [DocumentRepository].
///
/// Includes listing, filtering, searching, and counting documents.
/// All list methods use batch queries to eliminate N+1 query problems.
extension DocumentRepositoryQueries on DocumentRepository {
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
  ///
  /// ## Performance
  /// This method uses batch queries to eliminate N+1 query problems:
  /// - Before: 1 + N + N queries (1 for documents, N for page paths, N for tags)
  /// - After: 1 + 1 + 1 = 3 queries total (1 for documents, 1 batch for all page paths, 1 batch for all tags)
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

      if (results.isEmpty) {
        return [];
      }

      return _buildDocumentsFromResults(results, includeTags: includeTags);
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
  ///
  /// ## Performance
  /// This method uses batch queries to eliminate N+1 query problems:
  /// - Before: 1 + N + N queries (1 for documents, N for page paths, N for tags)
  /// - After: 1 + 1 + 1 = 3 queries total (1 for documents, 1 batch for all page paths, 1 batch for all tags)
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

      if (results.isEmpty) {
        return [];
      }

      return _buildDocumentsFromResults(results, includeTags: includeTags);
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
  ///
  /// ## Performance
  /// This method uses batch queries to eliminate N+1 query problems:
  /// - Before: 1 + N + N queries (1 for documents, N for page paths, N for tags)
  /// - After: 1 + 1 + 1 = 3 queries total (1 for documents, 1 batch for all page paths, 1 batch for all tags)
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

      if (results.isEmpty) {
        return [];
      }

      return _buildDocumentsFromResults(results, includeTags: includeTags);
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

  /// Gets the count of documents created since the start of the current month.
  ///
  /// Throws [DocumentRepositoryException] if the query fails.
  Future<int> getMonthlyDocumentCount() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month).toIso8601String();
      return await _database.count(
        DatabaseHelper.tableDocuments,
        where: '${DatabaseHelper.columnCreatedAt} >= ?',
        whereArgs: [startOfMonth],
      );
    } catch (e) {
      throw DocumentRepositoryException(
        'Failed to get monthly document count',
        cause: e,
      );
    }
  }

  /// Searches documents using full-text search.
  ///
  /// Searches across title, description, and OCR text.
  ///
  /// Returns documents matching the search query.
  ///
  /// Throws [DocumentRepositoryException] if the search fails.
  ///
  /// ## Performance
  /// This method uses batch queries to eliminate N+1 query problems:
  /// - Before: 1 + N + N + N queries (1 for search, N for documents, N for page paths, N for tags)
  /// - After: 1 + 1 + 1 + 1 = 4 queries total (1 for search, 1 for documents, 1 batch for all page paths, 1 batch for all tags)
  Future<List<Document>> searchDocuments(
    String query, {
    bool includeTags = false,
  }) async {
    try {
      final documentIds = await _database.searchDocuments(query);

      if (documentIds.isEmpty) {
        return [];
      }

      // Batch fetch full document records for all search results
      final placeholders = List.filled(documentIds.length, '?').join(', ');
      final results = await _database.rawQuery(
        '''
        SELECT * FROM ${DatabaseHelper.tableDocuments}
        WHERE ${DatabaseHelper.columnId} IN ($placeholders)
        ORDER BY ${DatabaseHelper.columnCreatedAt} DESC
        ''',
        documentIds,
      );

      if (results.isEmpty) {
        return [];
      }

      return _buildDocumentsFromResults(results, includeTags: includeTags);
    } catch (e) {
      throw DocumentRepositoryException(
        'Failed to search documents: $query',
        cause: e,
      );
    }
  }

  /// Gets all documents with a specific tag.
  ///
  /// Throws [DocumentRepositoryException] if the query fails.
  ///
  /// ## Performance
  /// This method uses batch queries to eliminate N+1 query problems:
  /// - Before: 1 + N + N queries (1 for documents, N for page paths, N for tags)
  /// - After: 1 + 1 + 1 = 3 queries total (1 for documents, 1 batch for all page paths, 1 batch for all tags)
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

      if (results.isEmpty) {
        return [];
      }

      return _buildDocumentsFromResults(results, includeTags: includeTags);
    } catch (e) {
      throw DocumentRepositoryException(
        'Failed to get documents by tag: $tagId',
        cause: e,
      );
    }
  }

  /// Gets documents by a list of IDs using batch queries.
  ///
  /// Returns a map of document ID to [Document] for O(1) lookups.
  /// Documents not found in the database are silently omitted.
  ///
  /// ## Performance
  /// Uses batch queries: 1 + 1 + 1 = 3 queries total
  /// (1 for documents, 1 batch for page paths, 1 batch for tags).
  Future<Map<String, Document>> getDocumentsByIds(
    List<String> ids, {
    bool includeTags = false,
  }) async {
    try {
      if (ids.isEmpty) {
        return {};
      }

      // Batch fetch full document records
      final placeholders = List.filled(ids.length, '?').join(', ');
      final results = await _database.rawQuery(
        '''
        SELECT * FROM ${DatabaseHelper.tableDocuments}
        WHERE ${DatabaseHelper.columnId} IN ($placeholders)
        ''',
        ids,
      );

      if (results.isEmpty) {
        return {};
      }

      // Extract actual document IDs from results
      final documentIds = results
          .map((result) => result[DatabaseHelper.columnId] as String)
          .toList();

      // Batch fetch page paths and tags
      final allPagesPaths =
          await _database.getBatchDocumentPagePaths(documentIds);

      Map<String, List<String>>? allTags;
      if (includeTags) {
        allTags = await _database.getBatchDocumentTags(documentIds);
      }

      // Build map of ID -> Document
      final documentMap = <String, Document>{};
      for (final result in results) {
        final docId = result[DatabaseHelper.columnId] as String;
        final pagesPaths = allPagesPaths[docId] ?? [];
        final tags = includeTags ? allTags![docId] : null;
        documentMap[docId] =
            Document.fromMap(result, pagesPaths: pagesPaths, tags: tags);
      }

      return documentMap;
    } catch (e) {
      throw DocumentRepositoryException(
        'Failed to get documents by IDs',
        cause: e,
      );
    }
  }

  /// Builds a list of [Document] objects from raw database results,
  /// using batch queries for page paths and tags.
  ///
  /// This is a shared helper used by all list/query methods to eliminate
  /// duplicated batch-fetch logic.
  Future<List<Document>> _buildDocumentsFromResults(
    List<Map<String, dynamic>> results, {
    bool includeTags = false,
  }) async {
    // Extract all document IDs
    final documentIds = results
        .map((result) => result[DatabaseHelper.columnId] as String)
        .toList();

    // Batch fetch page paths for all documents in a single query
    final allPagesPaths =
        await _database.getBatchDocumentPagePaths(documentIds);

    // Batch fetch tags for all documents in a single query if requested
    Map<String, List<String>>? allTags;
    if (includeTags) {
      allTags = await _database.getBatchDocumentTags(documentIds);
    }

    // Build document objects using the batch-fetched data
    final documents = <Document>[];
    for (final result in results) {
      final docId = result[DatabaseHelper.columnId] as String;
      final pagesPaths = allPagesPaths[docId] ?? [];
      final tags = includeTags ? allTags![docId] : null;
      documents
          .add(Document.fromMap(result, pagesPaths: pagesPaths, tags: tags));
    }

    return documents;
  }
}
