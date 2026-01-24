import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:aiscan/core/storage/database_helper.dart';
import 'package:aiscan/core/security/secure_storage_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([SecureStorageService])
import 'fts_encrypted_database_test.mocks.dart';

/// Integration tests for FTS (Full-Text Search) with SQLCipher encrypted database.
///
/// These tests verify that:
/// 1. FTS5/FTS4 virtual tables work correctly with encrypted database
/// 2. Search functionality performs well with encryption overhead
/// 3. FTS triggers maintain index synchronization
/// 4. All search features (ranking, snippets, filters) work with encrypted DB
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FTS with SQLCipher Encrypted Database', () {
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

      // Verify database was initialized
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

    group('FTS Module Availability with Encryption', () {
      test('FTS5 or FTS4 should be available with encrypted database', () async {
        // Verify that FTS module is detected and initialized
        final ftsVersion = DatabaseHelper.ftsVersion;
        expect(ftsVersion, isIn([4, 5]),
            reason: 'FTS5 or FTS4 should be available with SQLCipher');
      });

      test('FTS virtual table should be created in encrypted database',
          () async {
        // Query sqlite_master to verify FTS table exists
        final tables = await db.rawQuery(
          "SELECT name, type FROM sqlite_master WHERE type='table' AND name LIKE '%fts%'",
        );

        expect(tables.isNotEmpty, isTrue,
            reason: 'FTS virtual table should exist');
        expect(tables.first['name'], equals('documents_fts'));
      });
    });

    group('FTS Index Synchronization with Encrypted DB', () {
      test('FTS index should update when inserting document', () async {
        // Insert a test document
        await db.insert(DatabaseHelper.tableDocuments, {
          'id': 'test-doc-1',
          'title': 'Financial Report Q4 2024',
          'description': 'Annual financial statement',
          'ocr_text': 'Revenue increased by 25% compared to last year',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_favorite': 0,
          'file_size': 1024,
        });

        // Search for the document using FTS
        final ftsVersion = DatabaseHelper.ftsVersion;
        List<Map<String, Object?>> results;

        if (ftsVersion == 5) {
          // FTS5 query
          results = await db.rawQuery('''
            SELECT d.id, d.title, d.description, d.ocr_text, rank
            FROM ${DatabaseHelper.tableDocumentsFts} fts
            INNER JOIN ${DatabaseHelper.tableDocuments} d ON d.rowid = fts.rowid
            WHERE ${DatabaseHelper.tableDocumentsFts} MATCH ?
            ORDER BY rank
          ''', ['revenue']);
        } else if (ftsVersion == 4) {
          // FTS4 query
          results = await db.rawQuery('''
            SELECT d.id, d.title, d.description, d.ocr_text
            FROM ${DatabaseHelper.tableDocumentsFts} fts
            INNER JOIN ${DatabaseHelper.tableDocuments} d ON d.rowid = fts.docid
            WHERE ${DatabaseHelper.tableDocumentsFts} MATCH ?
          ''', ['revenue']);
        } else {
          fail('FTS should be available for this test');
        }

        expect(results.length, equals(1),
            reason: 'Search should find the inserted document');
        expect(results.first['title'], contains('Financial Report'));
      });

      test('FTS index should update when updating document', () async {
        // Insert initial document
        await db.insert(DatabaseHelper.tableDocuments, {
          'id': 'test-doc-2',
          'title': 'Old Title',
          'description': 'Old description',
          'ocr_text': 'Old content',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_favorite': 0,
          'file_size': 1024,
        });

        // Update the document
        await db.update(
          DatabaseHelper.tableDocuments,
          {
            'title': 'New Title with Encrypted',
            'ocr_text': 'New content about encryption',
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: ['test-doc-2'],
        );

        // Search for the updated content
        final ftsVersion = DatabaseHelper.ftsVersion;
        List<Map<String, Object?>> results;

        if (ftsVersion == 5) {
          results = await db.rawQuery('''
            SELECT d.id, d.title
            FROM ${DatabaseHelper.tableDocumentsFts} fts
            INNER JOIN ${DatabaseHelper.tableDocuments} d ON d.rowid = fts.rowid
            WHERE ${DatabaseHelper.tableDocumentsFts} MATCH ?
          ''', ['encrypted']);
        } else if (ftsVersion == 4) {
          results = await db.rawQuery('''
            SELECT d.id, d.title
            FROM ${DatabaseHelper.tableDocumentsFts} fts
            INNER JOIN ${DatabaseHelper.tableDocuments} d ON d.rowid = fts.docid
            WHERE ${DatabaseHelper.tableDocumentsFts} MATCH ?
          ''', ['encrypted']);
        } else {
          fail('FTS should be available');
        }

        expect(results.isNotEmpty, isTrue,
            reason: 'Updated content should be searchable');
        expect(results.first['title'], contains('Encrypted'));
      });

      test('FTS index should update when deleting document', () async {
        // Insert a document
        await db.insert(DatabaseHelper.tableDocuments, {
          'id': 'test-doc-3',
          'title': 'Document to Delete',
          'description': 'This will be deleted',
          'ocr_text': 'Temporary content',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_favorite': 0,
          'file_size': 1024,
        });

        // Delete the document
        await db.delete(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['test-doc-3'],
        );

        // Try to search for the deleted document
        final ftsVersion = DatabaseHelper.ftsVersion;
        List<Map<String, Object?>> results;

        if (ftsVersion == 5) {
          results = await db.rawQuery('''
            SELECT d.id
            FROM ${DatabaseHelper.tableDocumentsFts} fts
            INNER JOIN ${DatabaseHelper.tableDocuments} d ON d.rowid = fts.rowid
            WHERE ${DatabaseHelper.tableDocumentsFts} MATCH ?
          ''', ['temporary']);
        } else if (ftsVersion == 4) {
          results = await db.rawQuery('''
            SELECT d.id
            FROM ${DatabaseHelper.tableDocumentsFts} fts
            INNER JOIN ${DatabaseHelper.tableDocuments} d ON d.rowid = fts.docid
            WHERE ${DatabaseHelper.tableDocumentsFts} MATCH ?
          ''', ['temporary']);
        } else {
          fail('FTS should be available');
        }

        expect(results.isEmpty, isTrue,
            reason: 'Deleted document should not appear in search results');
      });
    });

    group('FTS Search Features with Encrypted Database', () {
      setUp(() async {
        // Insert test documents with various content
        final testDocs = [
          {
            'id': 'doc-1',
            'title': 'Medical Record Patient 12345',
            'description': 'Annual checkup results',
            'ocr_text': 'Blood pressure: 120/80, Cholesterol: Normal',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'is_favorite': 1,
            'file_size': 2048,
          },
          {
            'id': 'doc-2',
            'title': 'Bank Statement January 2024',
            'description': 'Monthly banking summary',
            'ocr_text': 'Account balance: \$5,432.10, Deposits: \$3,200',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'is_favorite': 0,
            'file_size': 1536,
          },
          {
            'id': 'doc-3',
            'title': 'Passport Copy',
            'description': 'Travel document',
            'ocr_text': 'Passport Number: AB1234567, Expiry: 2030-12-31',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'is_favorite': 1,
            'file_size': 3072,
          },
        ];

        for (final doc in testDocs) {
          await db.insert(DatabaseHelper.tableDocuments, doc);
        }
      });

      test('FTS should search across title, description, and OCR text',
          () async {
        // Search for "patient" which appears in title
        final titleResults = await _performFtsSearch(db, 'patient');
        expect(titleResults.isNotEmpty, isTrue);
        expect(titleResults.first['id'], equals('doc-1'));

        // Search for "banking" which appears in description
        final descResults = await _performFtsSearch(db, 'banking');
        expect(descResults.isNotEmpty, isTrue);
        expect(descResults.first['id'], equals('doc-2'));

        // Search for "passport" which appears in OCR text
        final ocrResults = await _performFtsSearch(db, 'passport');
        expect(ocrResults.isNotEmpty, isTrue);
        expect(ocrResults.first['id'], equals('doc-3'));
      });

      test('FTS should handle special characters in search queries', () async {
        // Search for dollar amount
        final results = await _performFtsSearch(db, '5432');
        expect(results.isNotEmpty, isTrue,
            reason: 'Should find bank statement with amount');
        expect(results.first['id'], equals('doc-2'));
      });

      test('FTS should support multi-word searches', () async {
        // Search for "bank statement"
        final results = await _performFtsSearch(db, 'bank statement');
        expect(results.isNotEmpty, isTrue);
        expect(results.first['title'], contains('Bank Statement'));
      });

      test('FTS ranking should work with encrypted database', () async {
        // Insert multiple documents with varying relevance
        await db.insert(DatabaseHelper.tableDocuments, {
          'id': 'doc-high-relevance',
          'title': 'Medical Medical Medical',
          'description': 'Medical information medical medical',
          'ocr_text': 'Medical records medical medical medical',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_favorite': 0,
          'file_size': 1024,
        });

        await db.insert(DatabaseHelper.tableDocuments, {
          'id': 'doc-low-relevance',
          'title': 'General Document',
          'description': 'Some information',
          'ocr_text': 'Various content including the word medical',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_favorite': 0,
          'file_size': 1024,
        });

        final results = await _performFtsSearch(db, 'medical');

        if (DatabaseHelper.ftsVersion == 5) {
          // FTS5 provides rank ordering (lower rank = more relevant)
          expect(results.isNotEmpty, isTrue);
          // First result should be the high-relevance document
          expect(results.first['id'], equals('doc-high-relevance'),
              reason: 'FTS5 ranking should prioritize documents with more matches');
        } else {
          // FTS4 doesn't have built-in ranking, just verify results exist
          expect(results.isNotEmpty, isTrue);
        }
      });

      test('FTS should handle case-insensitive search', () async {
        // Search with different cases
        final lowerResults = await _performFtsSearch(db, 'passport');
        final upperResults = await _performFtsSearch(db, 'PASSPORT');
        final mixedResults = await _performFtsSearch(db, 'PasSpoRt');

        expect(lowerResults.isNotEmpty, isTrue);
        expect(upperResults.isNotEmpty, isTrue);
        expect(mixedResults.isNotEmpty, isTrue);
        expect(lowerResults.length, equals(upperResults.length));
        expect(lowerResults.length, equals(mixedResults.length));
      });

      test('FTS should work with filters (favorites, folder)', () async {
        // Search with favorites filter
        final ftsVersion = DatabaseHelper.ftsVersion;
        List<Map<String, Object?>> results;

        if (ftsVersion == 5) {
          results = await db.rawQuery('''
            SELECT d.id, d.title, d.is_favorite
            FROM ${DatabaseHelper.tableDocumentsFts} fts
            INNER JOIN ${DatabaseHelper.tableDocuments} d ON d.rowid = fts.rowid
            WHERE ${DatabaseHelper.tableDocumentsFts} MATCH ?
            AND d.${DatabaseHelper.columnIsFavorite} = 1
            ORDER BY rank
          ''', ['passport']);
        } else if (ftsVersion == 4) {
          results = await db.rawQuery('''
            SELECT d.id, d.title, d.is_favorite
            FROM ${DatabaseHelper.tableDocumentsFts} fts
            INNER JOIN ${DatabaseHelper.tableDocuments} d ON d.rowid = fts.docid
            WHERE ${DatabaseHelper.tableDocumentsFts} MATCH ?
            AND d.${DatabaseHelper.columnIsFavorite} = 1
          ''', ['passport']);
        } else {
          fail('FTS should be available');
        }

        expect(results.isNotEmpty, isTrue,
            reason: 'Should find favorite documents matching search');
        expect(results.first['is_favorite'], equals(1));
      });
    });

    group('FTS Performance with Encrypted Database', () {
      test('FTS search should complete in reasonable time with encryption',
          () async {
        // Insert multiple documents
        for (int i = 0; i < 50; i++) {
          await db.insert(DatabaseHelper.tableDocuments, {
            'id': 'perf-doc-$i',
            'title': 'Test Document $i',
            'description': 'Description for document $i',
            'ocr_text':
                'This is test content for performance testing. Document number $i contains searchable text.',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'is_favorite': i % 2,
            'file_size': 1024 * (i + 1),
          });
        }

        // Measure search time
        final stopwatch = Stopwatch()..start();
        final results = await _performFtsSearch(db, 'test');
        stopwatch.stop();

        expect(results.isNotEmpty, isTrue);
        expect(stopwatch.elapsedMilliseconds, lessThan(1000),
            reason: 'Search should complete in less than 1 second');
      });
    });

    group('FTS Edge Cases with Encrypted Database', () {
      test('FTS should handle empty search query gracefully', () async {
        // Empty search should not crash
        expect(
          () async => await _performFtsSearch(db, ''),
          returnsNormally,
        );
      });

      test('FTS should handle documents with null OCR text', () async {
        await db.insert(DatabaseHelper.tableDocuments, {
          'id': 'doc-no-ocr',
          'title': 'Document Without OCR',
          'description': 'No OCR processing',
          'ocr_text': null,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_favorite': 0,
          'file_size': 512,
        });

        // Search should not crash
        final results = await _performFtsSearch(db, 'without');
        expect(results.isNotEmpty, isTrue);
        expect(results.first['id'], equals('doc-no-ocr'));
      });

      test('FTS should handle very long search queries', () async {
        final longQuery = 'medical ' * 100; // Very long query
        expect(
          () async => await _performFtsSearch(db, longQuery.trim()),
          returnsNormally,
          reason: 'Should handle long queries without crashing',
        );
      });

      test('FTS should handle special OCR content (numbers, symbols)', () async {
        await db.insert(DatabaseHelper.tableDocuments, {
          'id': 'doc-special',
          'title': 'Invoice #12345',
          'description': 'Payment details',
          'ocr_text':
              'Amount: \$1,234.56\nTax: 8.5%\nTotal: \$1,339.51\nRef: INV-2024-001',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_favorite': 0,
          'file_size': 2048,
        });

        // Search for various special content
        final amountResults = await _performFtsSearch(db, '1234');
        expect(amountResults.isNotEmpty, isTrue);

        final refResults = await _performFtsSearch(db, 'INV');
        expect(refResults.isNotEmpty, isTrue);
      });
    });

    group('Database Encryption Verification', () {
      test('Database should be encrypted (password required)', () async {
        // The database is already open with password
        // Try to open the same database without password should fail
        final dbPath = db.path;

        expect(
          () async {
            // Attempt to open without password (should fail with encrypted DB)
            final unencryptedDb = await openDatabase(dbPath);
            await unencryptedDb.close();
          },
          throwsA(anything),
          reason: 'Opening encrypted database without password should fail',
        );
      });

      test('Encryption key should be retrieved from SecureStorageService',
          () {
        // Verify mock was called to get encryption key
        verify(mockSecureStorage.getOrCreateEncryptionKey()).called(greaterThan(0));
      });
    });
  });
}

/// Helper function to perform FTS search based on available FTS version.
Future<List<Map<String, Object?>>> _performFtsSearch(
  Database db,
  String query,
) async {
  final ftsVersion = DatabaseHelper.ftsVersion;

  if (ftsVersion == 5) {
    return await db.rawQuery('''
      SELECT d.id, d.title, d.description, d.ocr_text, rank
      FROM ${DatabaseHelper.tableDocumentsFts} fts
      INNER JOIN ${DatabaseHelper.tableDocuments} d ON d.rowid = fts.rowid
      WHERE ${DatabaseHelper.tableDocumentsFts} MATCH ?
      ORDER BY rank
    ''', [query]);
  } else if (ftsVersion == 4) {
    return await db.rawQuery('''
      SELECT d.id, d.title, d.description, d.ocr_text
      FROM ${DatabaseHelper.tableDocumentsFts} fts
      INNER JOIN ${DatabaseHelper.tableDocuments} d ON d.rowid = fts.docid
      WHERE ${DatabaseHelper.tableDocumentsFts} MATCH ?
    ''', [query]);
  } else {
    throw Exception('FTS not available for testing');
  }
}
