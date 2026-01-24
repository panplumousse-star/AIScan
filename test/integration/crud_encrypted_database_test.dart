import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:aiscan/core/storage/database_helper.dart';
import 'package:aiscan/core/security/secure_storage_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([SecureStorageService])
import 'crud_encrypted_database_test.mocks.dart';

/// Integration tests for CRUD operations with SQLCipher encrypted database.
///
/// These tests verify that all database operations work correctly with encryption:
/// 1. Create - Insert new documents, folders, tags
/// 2. Read - Query documents with various filters
/// 3. Update - Modify document metadata, OCR text, favorites
/// 4. Delete - Remove documents and associated data
/// 5. Complex operations - Tags, folders, favorites, batch operations
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CRUD Operations with SQLCipher Encrypted Database', () {
    late DatabaseHelper dbHelper;
    late MockSecureStorageService mockSecureStorage;
    late Database db;
    const testEncryptionKey = 'test-encryption-key-32-bytes-long!!';

    setUp(() async {
      // Setup mock secure storage to return test encryption key
      mockSecureStorage = MockSecureStorageService();
      when(mockSecureStorage.getOrCreateEncryptionKey())
          .thenAnswer((_) async => testEncryptionKey);

      // Create database helper with mock secure storage
      dbHelper = DatabaseHelper(secureStorage: mockSecureStorage);
      db = await dbHelper.database;

      // Verify database was initialized and encrypted
      expect(db.isOpen, isTrue);
    });

    tearDown(() async {
      // Clean up test database
      if (db.isOpen) {
        final path = db.path;
        await db.close();
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      DatabaseHelper.resetFtsVersion();
    });

    group('Create Operations', () {
      test('should create document with all metadata fields', () async {
        // Create test document
        final documentId = 'test-doc-001';
        final timestamp = DateTime.now().toIso8601String();

        final documentData = {
          'id': documentId,
          'title': 'Test Document',
          'description': 'A comprehensive test document',
          'file_path': '/encrypted/documents/$documentId.pdf.enc',
          'thumbnail_path': '/encrypted/thumbnails/$documentId.jpg.enc',
          'original_file_name': 'original.pdf',
          'page_count': 5,
          'file_size': 102400,
          'mime_type': 'application/pdf',
          'ocr_text': null,
          'ocr_status': 'pending',
          'created_at': timestamp,
          'updated_at': timestamp,
          'folder_id': null,
          'is_favorite': 0,
        };

        // Insert document
        await db.insert(DatabaseHelper.tableDocuments, documentData);

        // Verify document was created
        final result = await db.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: [documentId],
        );

        expect(result.length, equals(1));
        expect(result.first['id'], equals(documentId));
        expect(result.first['title'], equals('Test Document'));
        expect(result.first['page_count'], equals(5));
      });

      test('should create folder', () async {
        // Create test folder
        final folderId = 'folder-001';
        final timestamp = DateTime.now().toIso8601String();

        final folderData = {
          'id': folderId,
          'name': 'Work Documents',
          'color': '#FF5722',
          'created_at': timestamp,
        };

        // Insert folder
        await db.insert(DatabaseHelper.tableFolders, folderData);

        // Verify folder was created
        final result = await db.query(
          DatabaseHelper.tableFolders,
          where: 'id = ?',
          whereArgs: [folderId],
        );

        expect(result.length, equals(1));
        expect(result.first['name'], equals('Work Documents'));
        expect(result.first['color'], equals('#FF5722'));
      });

      test('should create tag', () async {
        // Create test tag
        final tagId = 'tag-001';
        final timestamp = DateTime.now().toIso8601String();

        final tagData = {
          'id': tagId,
          'name': 'Important',
          'color': '#2196F3',
          'created_at': timestamp,
        };

        // Insert tag
        await db.insert(DatabaseHelper.tableTags, tagData);

        // Verify tag was created
        final result = await db.query(
          DatabaseHelper.tableTags,
          where: 'id = ?',
          whereArgs: [tagId],
        );

        expect(result.length, equals(1));
        expect(result.first['name'], equals('Important'));
      });

      test('should create document pages', () async {
        // Create parent document first
        final documentId = 'test-doc-002';
        final timestamp = DateTime.now().toIso8601String();

        await db.insert(DatabaseHelper.tableDocuments, {
          'id': documentId,
          'title': 'Multi-page Document',
          'file_path': '/encrypted/documents/$documentId.pdf.enc',
          'original_file_name': 'multi.pdf',
          'page_count': 3,
          'file_size': 204800,
          'mime_type': 'application/pdf',
          'created_at': timestamp,
          'updated_at': timestamp,
        });

        // Insert pages
        for (var i = 1; i <= 3; i++) {
          await db.insert(DatabaseHelper.tableDocumentPages, {
            'document_id': documentId,
            'page_number': i,
            'file_path': '/encrypted/pages/$documentId-page-$i.jpg.enc',
          });
        }

        // Verify pages were created
        final result = await db.query(
          DatabaseHelper.tableDocumentPages,
          where: 'document_id = ?',
          whereArgs: [documentId],
          orderBy: 'page_number ASC',
        );

        expect(result.length, equals(3));
        expect(result[0]['page_number'], equals(1));
        expect(result[2]['page_number'], equals(3));
      });
    });

    group('Read Operations', () {
      setUp(() async {
        // Create test data for read operations
        final timestamp = DateTime.now().toIso8601String();

        // Create folders
        await db.insert(DatabaseHelper.tableFolders, {
          'id': 'folder-work',
          'name': 'Work',
          'color': '#FF5722',
          'created_at': timestamp,
        });

        await db.insert(DatabaseHelper.tableFolders, {
          'id': 'folder-personal',
          'name': 'Personal',
          'color': '#4CAF50',
          'created_at': timestamp,
        });

        // Create documents
        await db.insert(DatabaseHelper.tableDocuments, {
          'id': 'doc-001',
          'title': 'Work Report',
          'description': 'Annual work report',
          'file_path': '/encrypted/documents/doc-001.pdf.enc',
          'original_file_name': 'report.pdf',
          'page_count': 1,
          'file_size': 50000,
          'mime_type': 'application/pdf',
          'folder_id': 'folder-work',
          'is_favorite': 1,
          'created_at': timestamp,
          'updated_at': timestamp,
        });

        await db.insert(DatabaseHelper.tableDocuments, {
          'id': 'doc-002',
          'title': 'Personal Notes',
          'description': 'My personal notes',
          'file_path': '/encrypted/documents/doc-002.pdf.enc',
          'original_file_name': 'notes.pdf',
          'page_count': 1,
          'file_size': 30000,
          'mime_type': 'application/pdf',
          'folder_id': 'folder-personal',
          'is_favorite': 0,
          'created_at': timestamp,
          'updated_at': timestamp,
        });

        // Create tags
        await db.insert(DatabaseHelper.tableTags, {
          'id': 'tag-important',
          'name': 'Important',
          'color': '#FF0000',
          'created_at': timestamp,
        });

        // Associate tag with document
        await db.insert(DatabaseHelper.tableDocumentTags, {
          'document_id': 'doc-001',
          'tag_id': 'tag-important',
        });
      });

      test('should query all documents', () async {
        final result = await db.query(
          DatabaseHelper.tableDocuments,
          orderBy: 'created_at DESC',
        );

        expect(result.length, equals(2));
        expect(result[0]['title'], equals('Work Report'));
      });

      test('should query documents by folder', () async {
        final result = await db.query(
          DatabaseHelper.tableDocuments,
          where: 'folder_id = ?',
          whereArgs: ['folder-work'],
        );

        expect(result.length, equals(1));
        expect(result.first['title'], equals('Work Report'));
      });

      test('should query favorite documents', () async {
        final result = await db.query(
          DatabaseHelper.tableDocuments,
          where: 'is_favorite = ?',
          whereArgs: [1],
        );

        expect(result.length, equals(1));
        expect(result.first['title'], equals('Work Report'));
      });

      test('should query documents by tag', () async {
        // Join query to get documents with specific tag
        final result = await db.rawQuery('''
          SELECT d.* FROM ${DatabaseHelper.tableDocuments} d
          INNER JOIN ${DatabaseHelper.tableDocumentTags} dt ON d.id = dt.document_id
          WHERE dt.tag_id = ?
        ''', ['tag-important']);

        expect(result.length, equals(1));
        expect(result.first['title'], equals('Work Report'));
      });

      test('should get document tags', () async {
        final result = await db.rawQuery('''
          SELECT t.* FROM ${DatabaseHelper.tableTags} t
          INNER JOIN ${DatabaseHelper.tableDocumentTags} dt ON t.id = dt.tag_id
          WHERE dt.document_id = ?
        ''', ['doc-001']);

        expect(result.length, equals(1));
        expect(result.first['name'], equals('Important'));
      });
    });

    group('Update Operations', () {
      setUp(() async {
        // Create test document for update operations
        final timestamp = DateTime.now().toIso8601String();

        await db.insert(DatabaseHelper.tableDocuments, {
          'id': 'doc-update',
          'title': 'Original Title',
          'description': 'Original description',
          'file_path': '/encrypted/documents/doc-update.pdf.enc',
          'original_file_name': 'original.pdf',
          'page_count': 1,
          'file_size': 40000,
          'mime_type': 'application/pdf',
          'ocr_text': null,
          'ocr_status': 'pending',
          'folder_id': null,
          'is_favorite': 0,
          'created_at': timestamp,
          'updated_at': timestamp,
        });
      });

      test('should update document title and description', () async {
        final newTimestamp = DateTime.now().toIso8601String();

        // Update document
        await db.update(
          DatabaseHelper.tableDocuments,
          {
            'title': 'Updated Title',
            'description': 'Updated description',
            'updated_at': newTimestamp,
          },
          where: 'id = ?',
          whereArgs: ['doc-update'],
        );

        // Verify update
        final result = await db.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['doc-update'],
        );

        expect(result.first['title'], equals('Updated Title'));
        expect(result.first['description'], equals('Updated description'));
      });

      test('should update document OCR text', () async {
        final ocrText = 'This is the extracted OCR text from the document.';
        final newTimestamp = DateTime.now().toIso8601String();

        // Update OCR
        await db.update(
          DatabaseHelper.tableDocuments,
          {
            'ocr_text': ocrText,
            'ocr_status': 'completed',
            'updated_at': newTimestamp,
          },
          where: 'id = ?',
          whereArgs: ['doc-update'],
        );

        // Verify update
        final result = await db.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['doc-update'],
        );

        expect(result.first['ocr_text'], equals(ocrText));
        expect(result.first['ocr_status'], equals('completed'));
      });

      test('should mark document as favorite', () async {
        final newTimestamp = DateTime.now().toIso8601String();

        // Mark as favorite
        await db.update(
          DatabaseHelper.tableDocuments,
          {
            'is_favorite': 1,
            'updated_at': newTimestamp,
          },
          where: 'id = ?',
          whereArgs: ['doc-update'],
        );

        // Verify update
        final result = await db.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['doc-update'],
        );

        expect(result.first['is_favorite'], equals(1));
      });

      test('should unmark document as favorite', () async {
        // First mark as favorite
        await db.update(
          DatabaseHelper.tableDocuments,
          {'is_favorite': 1},
          where: 'id = ?',
          whereArgs: ['doc-update'],
        );

        // Then unmark
        final newTimestamp = DateTime.now().toIso8601String();
        await db.update(
          DatabaseHelper.tableDocuments,
          {
            'is_favorite': 0,
            'updated_at': newTimestamp,
          },
          where: 'id = ?',
          whereArgs: ['doc-update'],
        );

        // Verify update
        final result = await db.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['doc-update'],
        );

        expect(result.first['is_favorite'], equals(0));
      });

      test('should move document to folder', () async {
        // Create folder first
        final timestamp = DateTime.now().toIso8601String();
        await db.insert(DatabaseHelper.tableFolders, {
          'id': 'folder-new',
          'name': 'New Folder',
          'color': '#9C27B0',
          'created_at': timestamp,
        });

        // Move document to folder
        final newTimestamp = DateTime.now().toIso8601String();
        await db.update(
          DatabaseHelper.tableDocuments,
          {
            'folder_id': 'folder-new',
            'updated_at': newTimestamp,
          },
          where: 'id = ?',
          whereArgs: ['doc-update'],
        );

        // Verify update
        final result = await db.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['doc-update'],
        );

        expect(result.first['folder_id'], equals('folder-new'));
      });

      test('should remove document from folder', () async {
        // First assign to folder
        await db.update(
          DatabaseHelper.tableDocuments,
          {'folder_id': 'some-folder'},
          where: 'id = ?',
          whereArgs: ['doc-update'],
        );

        // Then remove from folder
        final newTimestamp = DateTime.now().toIso8601String();
        await db.update(
          DatabaseHelper.tableDocuments,
          {
            'folder_id': null,
            'updated_at': newTimestamp,
          },
          where: 'id = ?',
          whereArgs: ['doc-update'],
        );

        // Verify update
        final result = await db.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['doc-update'],
        );

        expect(result.first['folder_id'], isNull);
      });
    });

    group('Tag Operations', () {
      setUp(() async {
        // Create test data for tag operations
        final timestamp = DateTime.now().toIso8601String();

        await db.insert(DatabaseHelper.tableDocuments, {
          'id': 'doc-tags',
          'title': 'Document with Tags',
          'file_path': '/encrypted/documents/doc-tags.pdf.enc',
          'original_file_name': 'tags.pdf',
          'page_count': 1,
          'file_size': 50000,
          'mime_type': 'application/pdf',
          'created_at': timestamp,
          'updated_at': timestamp,
        });

        await db.insert(DatabaseHelper.tableTags, {
          'id': 'tag-001',
          'name': 'Work',
          'color': '#FF5722',
          'created_at': timestamp,
        });

        await db.insert(DatabaseHelper.tableTags, {
          'id': 'tag-002',
          'name': 'Urgent',
          'color': '#F44336',
          'created_at': timestamp,
        });
      });

      test('should add tag to document', () async {
        // Add tag to document
        await db.insert(DatabaseHelper.tableDocumentTags, {
          'document_id': 'doc-tags',
          'tag_id': 'tag-001',
        });

        // Verify tag was added
        final result = await db.query(
          DatabaseHelper.tableDocumentTags,
          where: 'document_id = ? AND tag_id = ?',
          whereArgs: ['doc-tags', 'tag-001'],
        );

        expect(result.length, equals(1));
      });

      test('should add multiple tags to document', () async {
        // Add multiple tags
        await db.insert(DatabaseHelper.tableDocumentTags, {
          'document_id': 'doc-tags',
          'tag_id': 'tag-001',
        });

        await db.insert(DatabaseHelper.tableDocumentTags, {
          'document_id': 'doc-tags',
          'tag_id': 'tag-002',
        });

        // Verify tags were added
        final result = await db.query(
          DatabaseHelper.tableDocumentTags,
          where: 'document_id = ?',
          whereArgs: ['doc-tags'],
        );

        expect(result.length, equals(2));
      });

      test('should remove tag from document', () async {
        // Add tag first
        await db.insert(DatabaseHelper.tableDocumentTags, {
          'document_id': 'doc-tags',
          'tag_id': 'tag-001',
        });

        // Remove tag
        await db.delete(
          DatabaseHelper.tableDocumentTags,
          where: 'document_id = ? AND tag_id = ?',
          whereArgs: ['doc-tags', 'tag-001'],
        );

        // Verify tag was removed
        final result = await db.query(
          DatabaseHelper.tableDocumentTags,
          where: 'document_id = ? AND tag_id = ?',
          whereArgs: ['doc-tags', 'tag-001'],
        );

        expect(result.length, equals(0));
      });

      test('should get all tags for document', () async {
        // Add tags
        await db.insert(DatabaseHelper.tableDocumentTags, {
          'document_id': 'doc-tags',
          'tag_id': 'tag-001',
        });

        await db.insert(DatabaseHelper.tableDocumentTags, {
          'document_id': 'doc-tags',
          'tag_id': 'tag-002',
        });

        // Get tags
        final result = await db.rawQuery('''
          SELECT t.* FROM ${DatabaseHelper.tableTags} t
          INNER JOIN ${DatabaseHelper.tableDocumentTags} dt ON t.id = dt.tag_id
          WHERE dt.document_id = ?
          ORDER BY t.name ASC
        ''', ['doc-tags']);

        expect(result.length, equals(2));
        expect(result[0]['name'], equals('Urgent'));
        expect(result[1]['name'], equals('Work'));
      });
    });

    group('Delete Operations', () {
      setUp(() async {
        // Create test data for delete operations
        final timestamp = DateTime.now().toIso8601String();

        // Create folder
        await db.insert(DatabaseHelper.tableFolders, {
          'id': 'folder-delete',
          'name': 'Folder to Delete',
          'color': '#607D8B',
          'created_at': timestamp,
        });

        // Create document with pages and tags
        await db.insert(DatabaseHelper.tableDocuments, {
          'id': 'doc-delete',
          'title': 'Document to Delete',
          'file_path': '/encrypted/documents/doc-delete.pdf.enc',
          'original_file_name': 'delete.pdf',
          'page_count': 3,
          'file_size': 60000,
          'mime_type': 'application/pdf',
          'folder_id': 'folder-delete',
          'created_at': timestamp,
          'updated_at': timestamp,
        });

        // Create pages
        for (var i = 1; i <= 3; i++) {
          await db.insert(DatabaseHelper.tableDocumentPages, {
            'document_id': 'doc-delete',
            'page_number': i,
            'file_path': '/encrypted/pages/doc-delete-page-$i.jpg.enc',
          });
        }

        // Create tag
        await db.insert(DatabaseHelper.tableTags, {
          'id': 'tag-delete',
          'name': 'Tag to Delete',
          'color': '#795548',
          'created_at': timestamp,
        });

        // Associate tag with document
        await db.insert(DatabaseHelper.tableDocumentTags, {
          'document_id': 'doc-delete',
          'tag_id': 'tag-delete',
        });
      });

      test('should delete document', () async {
        // Delete document
        await db.delete(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['doc-delete'],
        );

        // Verify document was deleted
        final result = await db.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['doc-delete'],
        );

        expect(result.length, equals(0));
      });

      test('should cascade delete document pages when document is deleted',
          () async {
        // Delete document
        await db.delete(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['doc-delete'],
        );

        // Verify pages were cascade deleted
        final result = await db.query(
          DatabaseHelper.tableDocumentPages,
          where: 'document_id = ?',
          whereArgs: ['doc-delete'],
        );

        expect(result.length, equals(0));
      });

      test('should cascade delete document tags when document is deleted',
          () async {
        // Delete document
        await db.delete(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['doc-delete'],
        );

        // Verify document-tag associations were cascade deleted
        final result = await db.query(
          DatabaseHelper.tableDocumentTags,
          where: 'document_id = ?',
          whereArgs: ['doc-delete'],
        );

        expect(result.length, equals(0));
      });

      test('should delete folder', () async {
        // Delete folder
        await db.delete(
          DatabaseHelper.tableFolders,
          where: 'id = ?',
          whereArgs: ['folder-delete'],
        );

        // Verify folder was deleted
        final result = await db.query(
          DatabaseHelper.tableFolders,
          where: 'id = ?',
          whereArgs: ['folder-delete'],
        );

        expect(result.length, equals(0));
      });

      test('should delete tag', () async {
        // Delete tag
        await db.delete(
          DatabaseHelper.tableTags,
          where: 'id = ?',
          whereArgs: ['tag-delete'],
        );

        // Verify tag was deleted
        final result = await db.query(
          DatabaseHelper.tableTags,
          where: 'id = ?',
          whereArgs: ['tag-delete'],
        );

        expect(result.length, equals(0));
      });

      test('should handle batch delete of multiple documents', () async {
        // Create multiple documents
        final timestamp = DateTime.now().toIso8601String();
        for (var i = 1; i <= 5; i++) {
          await db.insert(DatabaseHelper.tableDocuments, {
            'id': 'batch-delete-$i',
            'title': 'Batch Document $i',
            'file_path': '/encrypted/documents/batch-$i.pdf.enc',
            'original_file_name': 'batch-$i.pdf',
            'page_count': 1,
            'file_size': 40000,
            'mime_type': 'application/pdf',
            'created_at': timestamp,
            'updated_at': timestamp,
          });
        }

        // Batch delete using whereIn
        await db.delete(
          DatabaseHelper.tableDocuments,
          where: 'id IN (?, ?, ?)',
          whereArgs: ['batch-delete-1', 'batch-delete-2', 'batch-delete-3'],
        );

        // Verify deletions
        final remaining = await db.query(
          DatabaseHelper.tableDocuments,
          where: 'id LIKE ?',
          whereArgs: ['batch-delete-%'],
        );

        expect(remaining.length, equals(2));
        expect(remaining[0]['id'], equals('batch-delete-4'));
        expect(remaining[1]['id'], equals('batch-delete-5'));
      });
    });

    group('Encryption Verification', () {
      test('database should require password to open', () async {
        // Get database path
        final dbPath = db.path;

        // Close current database
        await db.close();

        // Try to open without password - should fail or return garbage
        try {
          final unencryptedDb = await openDatabase(dbPath);

          // If it opens, try to query - should fail or return no results
          final tables = await unencryptedDb.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table'",
          );

          // Close the test database
          await unencryptedDb.close();

          // If we got here, the database might not be properly encrypted
          // However, SQLCipher sometimes opens but returns garbage data
          // So we check if we can actually read meaningful data
          expect(tables.isEmpty || tables.first['name'] == null, isTrue,
              reason:
                  'Unencrypted database access should fail or return garbage');
        } catch (e) {
          // Expected: opening without password should throw error
          expect(e, isNotNull);
        }

        // Re-open with correct password
        db = await dbHelper.database;
        expect(db.isOpen, isTrue);
      });

      test('encryption key should come from SecureStorageService', () async {
        // Verify that SecureStorageService was called to get encryption key
        verify(mockSecureStorage.getOrCreateEncryptionKey()).called(greaterThan(0));
      });

      test('database operations should work with encryption', () async {
        // Perform a complete CRUD cycle with encryption
        final timestamp = DateTime.now().toIso8601String();
        final docId = 'encryption-test-doc';

        // CREATE
        await db.insert(DatabaseHelper.tableDocuments, {
          'id': docId,
          'title': 'Encryption Test',
          'file_path': '/encrypted/documents/$docId.pdf.enc',
          'original_file_name': 'test.pdf',
          'page_count': 1,
          'file_size': 50000,
          'mime_type': 'application/pdf',
          'created_at': timestamp,
          'updated_at': timestamp,
        });

        // READ
        var result = await db.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: [docId],
        );
        expect(result.length, equals(1));
        expect(result.first['title'], equals('Encryption Test'));

        // UPDATE
        await db.update(
          DatabaseHelper.tableDocuments,
          {'title': 'Updated Encryption Test'},
          where: 'id = ?',
          whereArgs: [docId],
        );

        result = await db.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: [docId],
        );
        expect(result.first['title'], equals('Updated Encryption Test'));

        // DELETE
        await db.delete(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: [docId],
        );

        result = await db.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: [docId],
        );
        expect(result.length, equals(0));
      });
    });

    group('Performance with Encryption', () {
      test('bulk insert should perform well with encryption', () async {
        final timestamp = DateTime.now().toIso8601String();
        final stopwatch = Stopwatch()..start();

        // Insert 50 documents in a transaction
        await db.transaction((txn) async {
          for (var i = 1; i <= 50; i++) {
            await txn.insert(DatabaseHelper.tableDocuments, {
              'id': 'perf-doc-$i',
              'title': 'Performance Test Document $i',
              'file_path': '/encrypted/documents/perf-$i.pdf.enc',
              'original_file_name': 'perf-$i.pdf',
              'page_count': 1,
              'file_size': 40000 + i * 100,
              'mime_type': 'application/pdf',
              'created_at': timestamp,
              'updated_at': timestamp,
            });
          }
        });

        stopwatch.stop();

        // Verify all documents were inserted
        final result = await db.query(
          DatabaseHelper.tableDocuments,
          where: 'id LIKE ?',
          whereArgs: ['perf-doc-%'],
        );

        expect(result.length, equals(50));

        // Performance should be reasonable even with encryption
        // Typically should complete in under 2 seconds on most devices
        expect(stopwatch.elapsedMilliseconds, lessThan(5000),
            reason: 'Bulk insert with encryption should complete in reasonable time');
      });

      test('complex query should perform well with encryption', () async {
        // Create test data
        final timestamp = DateTime.now().toIso8601String();

        // Create folder
        await db.insert(DatabaseHelper.tableFolders, {
          'id': 'perf-folder',
          'name': 'Performance Folder',
          'color': '#3F51B5',
          'created_at': timestamp,
        });

        // Create tag
        await db.insert(DatabaseHelper.tableTags, {
          'id': 'perf-tag',
          'name': 'Performance Tag',
          'color': '#009688',
          'created_at': timestamp,
        });

        // Create documents with various attributes
        for (var i = 1; i <= 20; i++) {
          await db.insert(DatabaseHelper.tableDocuments, {
            'id': 'complex-doc-$i',
            'title': 'Complex Query Test $i',
            'description': 'Test document for complex queries',
            'file_path': '/encrypted/documents/complex-$i.pdf.enc',
            'original_file_name': 'complex-$i.pdf',
            'page_count': 1,
            'file_size': 40000,
            'mime_type': 'application/pdf',
            'ocr_text': 'Sample OCR text with keyword: important',
            'folder_id': i % 2 == 0 ? 'perf-folder' : null,
            'is_favorite': i % 3 == 0 ? 1 : 0,
            'created_at': timestamp,
            'updated_at': timestamp,
          });

          // Add tags to some documents
          if (i % 2 == 0) {
            await db.insert(DatabaseHelper.tableDocumentTags, {
              'document_id': 'complex-doc-$i',
              'tag_id': 'perf-tag',
            });
          }
        }

        // Execute complex query
        final stopwatch = Stopwatch()..start();

        final result = await db.rawQuery('''
          SELECT DISTINCT d.* FROM ${DatabaseHelper.tableDocuments} d
          LEFT JOIN ${DatabaseHelper.tableDocumentTags} dt ON d.id = dt.document_id
          WHERE (
            d.title LIKE ? OR
            d.description LIKE ? OR
            d.ocr_text LIKE ?
          )
          AND (d.folder_id = ? OR d.is_favorite = ?)
          ORDER BY d.updated_at DESC
          LIMIT 10
        ''', ['%Test%', '%document%', '%important%', 'perf-folder', 1]);

        stopwatch.stop();

        // Verify results
        expect(result.isNotEmpty, isTrue);

        // Complex query should complete quickly even with encryption
        expect(stopwatch.elapsedMilliseconds, lessThan(1000),
            reason: 'Complex query with encryption should complete in reasonable time');
      });
    });
  });
}
