part of 'document_repository.dart';

/// Tag management operations for [DocumentRepository].
///
/// Includes getting, adding, and removing tags from documents.
extension DocumentRepositoryTags on DocumentRepository {
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
}
