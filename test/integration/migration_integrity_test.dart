import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:aiscan/core/storage/database_helper.dart';
import 'package:aiscan/core/storage/database_migration_helper.dart';
import 'package:aiscan/core/security/secure_storage_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart';

@GenerateMocks([SecureStorageService])
import 'migration_integrity_test.mocks.dart';

/// Integration tests for data migration integrity from unencrypted to encrypted database.
///
/// These tests verify that the migration process:
/// 1. Preserves all row counts across all tables
/// 2. Maintains folder structure and relationships
/// 3. Preserves document metadata and OCR text
/// 4. Maintains tag associations
/// 5. Preserves foreign key relationships
/// 6. Handles complex scenarios (nested folders, multi-page docs, multiple tags)
/// 7. Ensures encrypted database is functional
///
/// This is a critical test suite for the security hardening feature.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Database Migration Integrity Tests', () {
    late MockSecureStorageService mockSecureStorage;
    late String testDbPath;
    late String oldDbPath;
    const testEncryptionKey = 'test-encryption-key-32-bytes-long!!';

    setUp(() async {
      // Setup mock secure storage
      mockSecureStorage = MockSecureStorageService();
      when(mockSecureStorage.getOrCreateEncryptionKey())
          .thenAnswer((_) async => testEncryptionKey);

      // Setup test database paths
      final databasesPath = await getDatabasesPath();
      testDbPath = join(databasesPath, 'test_migration_${DateTime.now().millisecondsSinceEpoch}.db');
      oldDbPath = join(databasesPath, 'aiscan.db');

      // Clean up any existing test databases
      await cleanupTestDatabases();
    });

    tearDown(() async {
      // Clean up all test databases
      await cleanupTestDatabases();
      DatabaseHelper.resetFtsVersion();
    });

    /// Cleans up all test database files
    Future<void> cleanupTestDatabases() async {
      final databasesPath = await getDatabasesPath();
      final files = [
        join(databasesPath, 'aiscan.db'),
        join(databasesPath, 'aiscan.db.backup'),
        join(databasesPath, 'aiscan_encrypted.db'),
      ];

      for (final filePath in files) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }

    /// Creates an old unencrypted database with test data
    Future<sqflite.Database> createOldDatabase() async {
      final db = await sqflite.openDatabase(
        oldDbPath,
        version: 3,
        onCreate: (db, version) async {
          // Create schema matching DatabaseHelper
          await createOldDatabaseSchema(db);
        },
      );

      return db;
    }

    /// Creates the database schema in old database
    Future<void> createOldDatabaseSchema(sqflite.Database db) async {
      // Create folders table
      await db.execute('''
        CREATE TABLE ${DatabaseHelper.tableFolders} (
          ${DatabaseHelper.columnId} TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          parent_id TEXT,
          color TEXT,
          icon TEXT,
          ${DatabaseHelper.columnIsFavorite} INTEGER NOT NULL DEFAULT 0,
          ${DatabaseHelper.columnCreatedAt} TEXT NOT NULL,
          ${DatabaseHelper.columnUpdatedAt} TEXT NOT NULL
        )
      ''');

      // Create main documents table
      await db.execute('''
        CREATE TABLE ${DatabaseHelper.tableDocuments} (
          ${DatabaseHelper.columnId} TEXT PRIMARY KEY,
          ${DatabaseHelper.columnTitle} TEXT NOT NULL,
          ${DatabaseHelper.columnDescription} TEXT,
          ${DatabaseHelper.columnThumbnailPath} TEXT,
          original_file_name TEXT,
          ${DatabaseHelper.columnFileSize} INTEGER NOT NULL DEFAULT 0,
          mime_type TEXT,
          ${DatabaseHelper.columnOcrText} TEXT,
          ocr_status TEXT DEFAULT 'pending',
          ${DatabaseHelper.columnCreatedAt} TEXT NOT NULL,
          ${DatabaseHelper.columnUpdatedAt} TEXT NOT NULL,
          ${DatabaseHelper.columnFolderId} TEXT,
          ${DatabaseHelper.columnIsFavorite} INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (${DatabaseHelper.columnFolderId}) REFERENCES ${DatabaseHelper.tableFolders}(${DatabaseHelper.columnId}) ON DELETE SET NULL
        )
      ''');

      // Create document_pages table
      await db.execute('''
        CREATE TABLE ${DatabaseHelper.tableDocumentPages} (
          ${DatabaseHelper.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${DatabaseHelper.columnDocumentId} TEXT NOT NULL,
          ${DatabaseHelper.columnPageNumber} INTEGER NOT NULL,
          ${DatabaseHelper.columnFilePath} TEXT NOT NULL,
          FOREIGN KEY (${DatabaseHelper.columnDocumentId}) REFERENCES ${DatabaseHelper.tableDocuments}(${DatabaseHelper.columnId}) ON DELETE CASCADE
        )
      ''');

      // Create tags table
      await db.execute('''
        CREATE TABLE ${DatabaseHelper.tableTags} (
          ${DatabaseHelper.columnId} TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          color TEXT,
          ${DatabaseHelper.columnCreatedAt} TEXT NOT NULL
        )
      ''');

      // Create document_tags junction table
      await db.execute('''
        CREATE TABLE ${DatabaseHelper.tableDocumentTags} (
          ${DatabaseHelper.columnDocumentId} TEXT NOT NULL,
          ${DatabaseHelper.columnTagId} TEXT NOT NULL,
          PRIMARY KEY (${DatabaseHelper.columnDocumentId}, ${DatabaseHelper.columnTagId}),
          FOREIGN KEY (${DatabaseHelper.columnDocumentId}) REFERENCES ${DatabaseHelper.tableDocuments}(${DatabaseHelper.columnId}) ON DELETE CASCADE,
          FOREIGN KEY (${DatabaseHelper.columnTagId}) REFERENCES ${DatabaseHelper.tableTags}(${DatabaseHelper.columnId}) ON DELETE CASCADE
        )
      ''');

      // Create signatures table
      await db.execute('''
        CREATE TABLE ${DatabaseHelper.tableSignatures} (
          ${DatabaseHelper.columnId} TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          ${DatabaseHelper.columnFilePath} TEXT NOT NULL,
          ${DatabaseHelper.columnCreatedAt} TEXT NOT NULL
        )
      ''');

      // Create search_history table
      await db.execute('''
        CREATE TABLE ${DatabaseHelper.tableSearchHistory} (
          ${DatabaseHelper.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${DatabaseHelper.columnQuery} TEXT NOT NULL,
          ${DatabaseHelper.columnTimestamp} TEXT NOT NULL,
          ${DatabaseHelper.columnResultCount} INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }

    /// Populates old database with test data
    Future<Map<String, int>> populateOldDatabase(sqflite.Database db) async {
      final timestamp = DateTime.now().toIso8601String();
      final rowCounts = <String, int>{};

      // Create folders with nested structure
      final folders = [
        {
          'id': 'folder-001',
          'name': 'Work Documents',
          'parent_id': null,
          'color': '#FF0000',
          'icon': 'work',
          'is_favorite': 0,
          'created_at': timestamp,
          'updated_at': timestamp,
        },
        {
          'id': 'folder-002',
          'name': 'Personal',
          'parent_id': null,
          'color': '#00FF00',
          'icon': 'person',
          'is_favorite': 1,
          'created_at': timestamp,
          'updated_at': timestamp,
        },
        {
          'id': 'folder-003',
          'name': 'Tax Documents',
          'parent_id': 'folder-001', // Nested under Work
          'color': '#0000FF',
          'icon': 'receipt',
          'is_favorite': 0,
          'created_at': timestamp,
          'updated_at': timestamp,
        },
      ];

      for (final folder in folders) {
        await db.insert(DatabaseHelper.tableFolders, folder);
      }
      rowCounts[DatabaseHelper.tableFolders] = folders.length;

      // Create tags
      final tags = [
        {
          'id': 'tag-001',
          'name': 'Important',
          'color': '#FF0000',
          'created_at': timestamp,
        },
        {
          'id': 'tag-002',
          'name': 'Confidential',
          'color': '#000000',
          'created_at': timestamp,
        },
        {
          'id': 'tag-003',
          'name': 'Receipt',
          'color': '#00FF00',
          'created_at': timestamp,
        },
      ];

      for (final tag in tags) {
        await db.insert(DatabaseHelper.tableTags, tag);
      }
      rowCounts[DatabaseHelper.tableTags] = tags.length;

      // Create documents in different folders with OCR text
      final documents = [
        {
          'id': 'doc-001',
          'title': 'Bank Statement January 2024',
          'description': 'Monthly bank statement',
          'thumbnail_path': '/thumb/doc-001.jpg',
          'original_file_name': 'statement.pdf',
          'file_size': 204800,
          'mime_type': 'application/pdf',
          'ocr_text': 'Bank Account Number: 1234567890 Balance: \$5,432.10',
          'ocr_status': 'completed',
          'created_at': timestamp,
          'updated_at': timestamp,
          'folder_id': 'folder-001',
          'is_favorite': 1,
        },
        {
          'id': 'doc-002',
          'title': 'Passport Scan',
          'description': 'Personal identification document',
          'thumbnail_path': '/thumb/doc-002.jpg',
          'original_file_name': 'passport.jpg',
          'file_size': 512000,
          'mime_type': 'image/jpeg',
          'ocr_text': 'PASSPORT USA John Doe DOB: 01/15/1980 ID: P1234567',
          'ocr_status': 'completed',
          'created_at': timestamp,
          'updated_at': timestamp,
          'folder_id': 'folder-002',
          'is_favorite': 0,
        },
        {
          'id': 'doc-003',
          'title': '2023 Tax Return',
          'description': 'Federal tax return form',
          'thumbnail_path': '/thumb/doc-003.jpg',
          'original_file_name': 'tax2023.pdf',
          'file_size': 1024000,
          'mime_type': 'application/pdf',
          'ocr_text': 'Form 1040 SSN: 123-45-6789 Adjusted Gross Income: \$75,000',
          'ocr_status': 'completed',
          'created_at': timestamp,
          'updated_at': timestamp,
          'folder_id': 'folder-003',
          'is_favorite': 1,
        },
        {
          'id': 'doc-004',
          'title': 'Medical Records',
          'description': 'Recent lab test results',
          'thumbnail_path': '/thumb/doc-004.jpg',
          'original_file_name': 'labs.pdf',
          'file_size': 307200,
          'mime_type': 'application/pdf',
          'ocr_text': null, // Document without OCR
          'ocr_status': 'pending',
          'created_at': timestamp,
          'updated_at': timestamp,
          'folder_id': null, // Document not in folder
          'is_favorite': 0,
        },
      ];

      for (final document in documents) {
        await db.insert(DatabaseHelper.tableDocuments, document);
      }
      rowCounts[DatabaseHelper.tableDocuments] = documents.length;

      // Create document pages (multi-page documents)
      final pages = [
        {
          'document_id': 'doc-001',
          'page_number': 1,
          'file_path': '/pages/doc-001-page-1.jpg',
        },
        {
          'document_id': 'doc-001',
          'page_number': 2,
          'file_path': '/pages/doc-001-page-2.jpg',
        },
        {
          'document_id': 'doc-003',
          'page_number': 1,
          'file_path': '/pages/doc-003-page-1.jpg',
        },
        {
          'document_id': 'doc-003',
          'page_number': 2,
          'file_path': '/pages/doc-003-page-2.jpg',
        },
        {
          'document_id': 'doc-003',
          'page_number': 3,
          'file_path': '/pages/doc-003-page-3.jpg',
        },
      ];

      for (final page in pages) {
        await db.insert(DatabaseHelper.tableDocumentPages, page);
      }
      rowCounts[DatabaseHelper.tableDocumentPages] = pages.length;

      // Create document-tag associations
      final documentTags = [
        {'document_id': 'doc-001', 'tag_id': 'tag-001'}, // Bank statement is Important
        {'document_id': 'doc-001', 'tag_id': 'tag-002'}, // Bank statement is Confidential
        {'document_id': 'doc-002', 'tag_id': 'tag-002'}, // Passport is Confidential
        {'document_id': 'doc-003', 'tag_id': 'tag-001'}, // Tax return is Important
        {'document_id': 'doc-003', 'tag_id': 'tag-002'}, // Tax return is Confidential
      ];

      for (final docTag in documentTags) {
        await db.insert(DatabaseHelper.tableDocumentTags, docTag);
      }
      rowCounts[DatabaseHelper.tableDocumentTags] = documentTags.length;

      // Create signatures
      final signatures = [
        {
          'id': 'sig-001',
          'name': 'John Doe Signature',
          'file_path': '/signatures/sig-001.png',
          'created_at': timestamp,
        },
      ];

      for (final signature in signatures) {
        await db.insert(DatabaseHelper.tableSignatures, signature);
      }
      rowCounts[DatabaseHelper.tableSignatures] = signatures.length;

      // Create search history
      final searchHistory = [
        {
          'query': 'bank statement',
          'timestamp': timestamp,
          'result_count': 1,
        },
        {
          'query': 'tax',
          'timestamp': timestamp,
          'result_count': 1,
        },
      ];

      for (final search in searchHistory) {
        await db.insert(DatabaseHelper.tableSearchHistory, search);
      }
      rowCounts[DatabaseHelper.tableSearchHistory] = searchHistory.length;

      return rowCounts;
    }

    group('Row Count Verification', () {
      test('should migrate all rows from all tables', () async {
        // Create and populate old database
        final oldDb = await createOldDatabase();
        final expectedCounts = await populateOldDatabase(oldDb);
        await oldDb.close();

        // Run migration
        final migrationHelper = DatabaseMigrationHelper(
          secureStorage: mockSecureStorage,
        );
        final result = await migrationHelper.migrateToEncrypted();

        // Verify migration succeeded
        expect(result.success, isTrue);
        expect(result.error, isNull);

        // Open encrypted database to verify row counts
        final dbHelper = DatabaseHelper(secureStorage: mockSecureStorage);
        final newDb = await dbHelper.database;

        // Verify each table has correct row count
        for (final entry in expectedCounts.entries) {
          final tableName = entry.key;
          final expectedCount = entry.value;

          final actualCount = Sqflite.firstIntValue(
            await newDb.rawQuery('SELECT COUNT(*) FROM $tableName'),
          ) ?? 0;

          expect(
            actualCount,
            equals(expectedCount),
            reason: 'Table $tableName should have $expectedCount rows',
          );
        }

        // Calculate total rows migrated
        final totalExpected = expectedCounts.values.reduce((a, b) => a + b);
        expect(result.rowsMigrated, equals(totalExpected));

        await newDb.close();
      });

      test('should handle empty tables gracefully', () async {
        // Create old database with no data
        final oldDb = await createOldDatabase();
        await oldDb.close();

        // Run migration
        final migrationHelper = DatabaseMigrationHelper(
          secureStorage: mockSecureStorage,
        );
        final result = await migrationHelper.migrateToEncrypted();

        // Verify migration succeeded with 0 rows
        expect(result.success, isTrue);
        expect(result.rowsMigrated, equals(0));
      });
    });

    group('Folder Structure Preservation', () {
      test('should preserve folder hierarchy and relationships', () async {
        // Create and populate old database
        final oldDb = await createOldDatabase();
        await populateOldDatabase(oldDb);
        await oldDb.close();

        // Run migration
        final migrationHelper = DatabaseMigrationHelper(
          secureStorage: mockSecureStorage,
        );
        final result = await migrationHelper.migrateToEncrypted();
        expect(result.success, isTrue);

        // Open encrypted database
        final dbHelper = DatabaseHelper(secureStorage: mockSecureStorage);
        final newDb = await dbHelper.database;

        // Verify root folders
        final rootFolders = await newDb.query(
          DatabaseHelper.tableFolders,
          where: 'parent_id IS NULL',
        );
        expect(rootFolders.length, equals(2)); // Work and Personal

        // Verify nested folder
        final nestedFolders = await newDb.query(
          DatabaseHelper.tableFolders,
          where: 'parent_id = ?',
          whereArgs: ['folder-001'],
        );
        expect(nestedFolders.length, equals(1)); // Tax Documents under Work
        expect(nestedFolders.first['name'], equals('Tax Documents'));

        // Verify folder properties preserved
        final workFolder = await newDb.query(
          DatabaseHelper.tableFolders,
          where: 'id = ?',
          whereArgs: ['folder-001'],
        );
        expect(workFolder.first['name'], equals('Work Documents'));
        expect(workFolder.first['color'], equals('#FF0000'));
        expect(workFolder.first['icon'], equals('work'));
        expect(workFolder.first['is_favorite'], equals(0));

        await newDb.close();
      });

      test('should preserve documents-to-folder relationships', () async {
        // Create and populate old database
        final oldDb = await createOldDatabase();
        await populateOldDatabase(oldDb);
        await oldDb.close();

        // Run migration
        final migrationHelper = DatabaseMigrationHelper(
          secureStorage: mockSecureStorage,
        );
        final result = await migrationHelper.migrateToEncrypted();
        expect(result.success, isTrue);

        // Open encrypted database
        final dbHelper = DatabaseHelper(secureStorage: mockSecureStorage);
        final newDb = await dbHelper.database;

        // Verify documents in Work folder
        final workDocs = await newDb.query(
          DatabaseHelper.tableDocuments,
          where: 'folder_id = ?',
          whereArgs: ['folder-001'],
        );
        expect(workDocs.length, equals(1)); // Bank statement
        expect(workDocs.first['title'], equals('Bank Statement January 2024'));

        // Verify documents in Tax Documents folder (nested)
        final taxDocs = await newDb.query(
          DatabaseHelper.tableDocuments,
          where: 'folder_id = ?',
          whereArgs: ['folder-003'],
        );
        expect(taxDocs.length, equals(1)); // Tax return
        expect(taxDocs.first['title'], equals('2023 Tax Return'));

        // Verify documents without folder
        final unfiledDocs = await newDb.query(
          DatabaseHelper.tableDocuments,
          where: 'folder_id IS NULL',
        );
        expect(unfiledDocs.length, equals(1)); // Medical records
        expect(unfiledDocs.first['title'], equals('Medical Records'));

        await newDb.close();
      });
    });

    group('Document Data Preservation', () {
      test('should preserve all document metadata', () async {
        // Create and populate old database
        final oldDb = await createOldDatabase();
        await populateOldDatabase(oldDb);
        await oldDb.close();

        // Run migration
        final migrationHelper = DatabaseMigrationHelper(
          secureStorage: mockSecureStorage,
        );
        final result = await migrationHelper.migrateToEncrypted();
        expect(result.success, isTrue);

        // Open encrypted database
        final dbHelper = DatabaseHelper(secureStorage: mockSecureStorage);
        final newDb = await dbHelper.database;

        // Verify bank statement metadata
        final bankDoc = await newDb.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['doc-001'],
        );

        expect(bankDoc.length, equals(1));
        final doc = bankDoc.first;
        expect(doc['title'], equals('Bank Statement January 2024'));
        expect(doc['description'], equals('Monthly bank statement'));
        expect(doc['original_file_name'], equals('statement.pdf'));
        expect(doc['file_size'], equals(204800));
        expect(doc['mime_type'], equals('application/pdf'));
        expect(doc['ocr_status'], equals('completed'));
        expect(doc['is_favorite'], equals(1));

        await newDb.close();
      });

      test('should preserve OCR text content', () async {
        // Create and populate old database
        final oldDb = await createOldDatabase();
        await populateOldDatabase(oldDb);
        await oldDb.close();

        // Run migration
        final migrationHelper = DatabaseMigrationHelper(
          secureStorage: mockSecureStorage,
        );
        final result = await migrationHelper.migrateToEncrypted();
        expect(result.success, isTrue);

        // Open encrypted database
        final dbHelper = DatabaseHelper(secureStorage: mockSecureStorage);
        final newDb = await dbHelper.database;

        // Verify OCR text for bank statement (contains sensitive data)
        final bankDoc = await newDb.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['doc-001'],
        );
        expect(
          bankDoc.first['ocr_text'],
          equals('Bank Account Number: 1234567890 Balance: \$5,432.10'),
        );

        // Verify OCR text for passport (contains PII)
        final passportDoc = await newDb.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['doc-002'],
        );
        expect(
          passportDoc.first['ocr_text'],
          equals('PASSPORT USA John Doe DOB: 01/15/1980 ID: P1234567'),
        );

        // Verify OCR text for tax return (contains SSN)
        final taxDoc = await newDb.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['doc-003'],
        );
        expect(
          taxDoc.first['ocr_text'],
          equals('Form 1040 SSN: 123-45-6789 Adjusted Gross Income: \$75,000'),
        );

        // Verify null OCR text preserved
        final medicalDoc = await newDb.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['doc-004'],
        );
        expect(medicalDoc.first['ocr_text'], isNull);

        await newDb.close();
      });

      test('should preserve multi-page document structure', () async {
        // Create and populate old database
        final oldDb = await createOldDatabase();
        await populateOldDatabase(oldDb);
        await oldDb.close();

        // Run migration
        final migrationHelper = DatabaseMigrationHelper(
          secureStorage: mockSecureStorage,
        );
        final result = await migrationHelper.migrateToEncrypted();
        expect(result.success, isTrue);

        // Open encrypted database
        final dbHelper = DatabaseHelper(secureStorage: mockSecureStorage);
        final newDb = await dbHelper.database;

        // Verify bank statement pages (2 pages)
        final bankPages = await newDb.query(
          DatabaseHelper.tableDocumentPages,
          where: 'document_id = ?',
          whereArgs: ['doc-001'],
          orderBy: 'page_number ASC',
        );
        expect(bankPages.length, equals(2));
        expect(bankPages[0]['page_number'], equals(1));
        expect(bankPages[0]['file_path'], equals('/pages/doc-001-page-1.jpg'));
        expect(bankPages[1]['page_number'], equals(2));
        expect(bankPages[1]['file_path'], equals('/pages/doc-001-page-2.jpg'));

        // Verify tax return pages (3 pages)
        final taxPages = await newDb.query(
          DatabaseHelper.tableDocumentPages,
          where: 'document_id = ?',
          whereArgs: ['doc-003'],
          orderBy: 'page_number ASC',
        );
        expect(taxPages.length, equals(3));
        expect(taxPages[0]['page_number'], equals(1));
        expect(taxPages[1]['page_number'], equals(2));
        expect(taxPages[2]['page_number'], equals(3));

        await newDb.close();
      });
    });

    group('Tag Association Preservation', () {
      test('should preserve all tag definitions', () async {
        // Create and populate old database
        final oldDb = await createOldDatabase();
        await populateOldDatabase(oldDb);
        await oldDb.close();

        // Run migration
        final migrationHelper = DatabaseMigrationHelper(
          secureStorage: mockSecureStorage,
        );
        final result = await migrationHelper.migrateToEncrypted();
        expect(result.success, isTrue);

        // Open encrypted database
        final dbHelper = DatabaseHelper(secureStorage: mockSecureStorage);
        final newDb = await dbHelper.database;

        // Verify all tags migrated
        final tags = await newDb.query(
          DatabaseHelper.tableTags,
          orderBy: 'name ASC',
        );
        expect(tags.length, equals(3));

        // Verify tag properties
        final confidentialTag = tags.firstWhere((t) => t['name'] == 'Confidential');
        expect(confidentialTag['color'], equals('#000000'));

        final importantTag = tags.firstWhere((t) => t['name'] == 'Important');
        expect(importantTag['color'], equals('#FF0000'));

        await newDb.close();
      });

      test('should preserve document-tag associations', () async {
        // Create and populate old database
        final oldDb = await createOldDatabase();
        await populateOldDatabase(oldDb);
        await oldDb.close();

        // Run migration
        final migrationHelper = DatabaseMigrationHelper(
          secureStorage: mockSecureStorage,
        );
        final result = await migrationHelper.migrateToEncrypted();
        expect(result.success, isTrue);

        // Open encrypted database
        final dbHelper = DatabaseHelper(secureStorage: mockSecureStorage);
        final newDb = await dbHelper.database;

        // Verify bank statement tags (Important + Confidential)
        final bankTags = await newDb.rawQuery('''
          SELECT t.name
          FROM ${DatabaseHelper.tableTags} t
          JOIN ${DatabaseHelper.tableDocumentTags} dt ON t.id = dt.tag_id
          WHERE dt.document_id = ?
          ORDER BY t.name ASC
        ''', ['doc-001']);
        expect(bankTags.length, equals(2));
        expect(bankTags[0]['name'], equals('Confidential'));
        expect(bankTags[1]['name'], equals('Important'));

        // Verify passport tags (Confidential only)
        final passportTags = await newDb.rawQuery('''
          SELECT t.name
          FROM ${DatabaseHelper.tableTags} t
          JOIN ${DatabaseHelper.tableDocumentTags} dt ON t.id = dt.tag_id
          WHERE dt.document_id = ?
        ''', ['doc-002']);
        expect(passportTags.length, equals(1));
        expect(passportTags[0]['name'], equals('Confidential'));

        // Verify tax return tags (Important + Confidential)
        final taxTags = await newDb.rawQuery('''
          SELECT t.name
          FROM ${DatabaseHelper.tableTags} t
          JOIN ${DatabaseHelper.tableDocumentTags} dt ON t.id = dt.tag_id
          WHERE dt.document_id = ?
          ORDER BY t.name ASC
        ''', ['doc-003']);
        expect(taxTags.length, equals(2));
        expect(taxTags[0]['name'], equals('Confidential'));
        expect(taxTags[1]['name'], equals('Important'));

        await newDb.close();
      });

      test('should handle documents with multiple tags', () async {
        // Create and populate old database
        final oldDb = await createOldDatabase();
        await populateOldDatabase(oldDb);
        await oldDb.close();

        // Run migration
        final migrationHelper = DatabaseMigrationHelper(
          secureStorage: mockSecureStorage,
        );
        final result = await migrationHelper.migrateToEncrypted();
        expect(result.success, isTrue);

        // Open encrypted database
        final dbHelper = DatabaseHelper(secureStorage: mockSecureStorage);
        final newDb = await dbHelper.database;

        // Count documents with multiple tags
        final multiTagDocs = await newDb.rawQuery('''
          SELECT document_id, COUNT(*) as tag_count
          FROM ${DatabaseHelper.tableDocumentTags}
          GROUP BY document_id
          HAVING tag_count > 1
        ''');
        expect(multiTagDocs.length, equals(2)); // Bank statement and tax return

        await newDb.close();
      });
    });

    group('Foreign Key Relationship Preservation', () {
      test('should preserve cascade delete relationships', () async {
        // Create and populate old database
        final oldDb = await createOldDatabase();
        await populateOldDatabase(oldDb);
        await oldDb.close();

        // Run migration
        final migrationHelper = DatabaseMigrationHelper(
          secureStorage: mockSecureStorage,
        );
        final result = await migrationHelper.migrateToEncrypted();
        expect(result.success, isTrue);

        // Open encrypted database
        final dbHelper = DatabaseHelper(secureStorage: mockSecureStorage);
        final newDb = await dbHelper.database;

        // Delete a document
        await newDb.delete(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['doc-001'],
        );

        // Verify pages were cascade deleted
        final remainingPages = await newDb.query(
          DatabaseHelper.tableDocumentPages,
          where: 'document_id = ?',
          whereArgs: ['doc-001'],
        );
        expect(remainingPages.length, equals(0));

        // Verify tags associations were cascade deleted
        final remainingTagAssocs = await newDb.query(
          DatabaseHelper.tableDocumentTags,
          where: 'document_id = ?',
          whereArgs: ['doc-001'],
        );
        expect(remainingTagAssocs.length, equals(0));

        await newDb.close();
      });

      test('should preserve SET NULL relationships', () async {
        // Create and populate old database
        final oldDb = await createOldDatabase();
        await populateOldDatabase(oldDb);
        await oldDb.close();

        // Run migration
        final migrationHelper = DatabaseMigrationHelper(
          secureStorage: mockSecureStorage,
        );
        final result = await migrationHelper.migrateToEncrypted();
        expect(result.success, isTrue);

        // Open encrypted database
        final dbHelper = DatabaseHelper(secureStorage: mockSecureStorage);
        final newDb = await dbHelper.database;

        // Delete a folder
        await newDb.delete(
          DatabaseHelper.tableFolders,
          where: 'id = ?',
          whereArgs: ['folder-001'],
        );

        // Verify document folder_id was set to NULL (not deleted)
        final doc = await newDb.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['doc-001'],
        );
        expect(doc.length, equals(1)); // Document still exists
        expect(doc.first['folder_id'], isNull); // But folder_id is NULL

        await newDb.close();
      });
    });

    group('Complex Scenario Testing', () {
      test('should handle complete real-world scenario', () async {
        // Create and populate old database
        final oldDb = await createOldDatabase();
        final expectedCounts = await populateOldDatabase(oldDb);
        await oldDb.close();

        // Run migration
        final migrationHelper = DatabaseMigrationHelper(
          secureStorage: mockSecureStorage,
        );
        final result = await migrationHelper.migrateToEncrypted();
        expect(result.success, isTrue);

        // Open encrypted database
        final dbHelper = DatabaseHelper(secureStorage: mockSecureStorage);
        final newDb = await dbHelper.database;

        // Verify complete data integrity
        // 1. All row counts match
        for (final entry in expectedCounts.entries) {
          final count = Sqflite.firstIntValue(
            await newDb.rawQuery('SELECT COUNT(*) FROM ${entry.key}'),
          ) ?? 0;
          expect(count, equals(entry.value));
        }

        // 2. Nested folder structure intact
        final nestedFolder = await newDb.query(
          DatabaseHelper.tableFolders,
          where: 'id = ? AND parent_id = ?',
          whereArgs: ['folder-003', 'folder-001'],
        );
        expect(nestedFolder.length, equals(1));

        // 3. Multi-page document intact
        final taxPages = await newDb.query(
          DatabaseHelper.tableDocumentPages,
          where: 'document_id = ?',
          whereArgs: ['doc-003'],
        );
        expect(taxPages.length, equals(3));

        // 4. Multiple tags per document intact
        final bankTags = await newDb.query(
          DatabaseHelper.tableDocumentTags,
          where: 'document_id = ?',
          whereArgs: ['doc-001'],
        );
        expect(bankTags.length, equals(2));

        // 5. Sensitive OCR data preserved
        final sensitiveDoc = await newDb.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: ['doc-002'],
        );
        expect(sensitiveDoc.first['ocr_text'], contains('PASSPORT'));
        expect(sensitiveDoc.first['ocr_text'], contains('P1234567'));

        // 6. Documents in correct folders
        final taxInFolder = await newDb.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ? AND folder_id = ?',
          whereArgs: ['doc-003', 'folder-003'],
        );
        expect(taxInFolder.length, equals(1));

        await newDb.close();
      });

      test('should verify encrypted database is functional', () async {
        // Create and populate old database
        final oldDb = await createOldDatabase();
        await populateOldDatabase(oldDb);
        await oldDb.close();

        // Run migration
        final migrationHelper = DatabaseMigrationHelper(
          secureStorage: mockSecureStorage,
        );
        final result = await migrationHelper.migrateToEncrypted();
        expect(result.success, isTrue);

        // Open encrypted database
        final dbHelper = DatabaseHelper(secureStorage: mockSecureStorage);
        final newDb = await dbHelper.database;

        // Perform CRUD operations to verify functionality
        // Create
        final newDocId = 'doc-new-001';
        await newDb.insert(DatabaseHelper.tableDocuments, {
          'id': newDocId,
          'title': 'Post-Migration Document',
          'description': 'Created after migration',
          'file_size': 1024,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_favorite': 0,
        });

        // Read
        final created = await newDb.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: [newDocId],
        );
        expect(created.length, equals(1));

        // Update
        await newDb.update(
          DatabaseHelper.tableDocuments,
          {'title': 'Updated Title'},
          where: 'id = ?',
          whereArgs: [newDocId],
        );

        // Delete
        await newDb.delete(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: [newDocId],
        );

        final deleted = await newDb.query(
          DatabaseHelper.tableDocuments,
          where: 'id = ?',
          whereArgs: [newDocId],
        );
        expect(deleted.length, equals(0));

        await newDb.close();
      });
    });

    group('Backup and Rollback Verification', () {
      test('should create backup before migration', () async {
        // Create old database
        final oldDb = await createOldDatabase();
        await populateOldDatabase(oldDb);
        await oldDb.close();

        // Run migration
        final migrationHelper = DatabaseMigrationHelper(
          secureStorage: mockSecureStorage,
        );
        final result = await migrationHelper.migrateToEncrypted();
        expect(result.success, isTrue);
        expect(result.backupPath, isNotNull);

        // Verify backup was created
        final backupFile = File(result.backupPath!);
        expect(await backupFile.exists(), isTrue);

        // Clean up backup
        await migrationHelper.deleteBackup();
      });

      test('should delete backup after successful migration', () async {
        // Create old database
        final oldDb = await createOldDatabase();
        await populateOldDatabase(oldDb);
        await oldDb.close();

        // Run migration
        final migrationHelper = DatabaseMigrationHelper(
          secureStorage: mockSecureStorage,
        );
        final result = await migrationHelper.migrateToEncrypted();
        expect(result.success, isTrue);

        // Delete backup
        await migrationHelper.deleteBackup();

        // Verify backup was deleted
        final backupExists = await migrationHelper.backupExists();
        expect(backupExists, isFalse);
      });
    });

    group('Performance Verification', () {
      test('should complete migration in reasonable time', () async {
        // Create old database with moderate data
        final oldDb = await createOldDatabase();
        await populateOldDatabase(oldDb);
        await oldDb.close();

        // Measure migration time
        final stopwatch = Stopwatch()..start();

        final migrationHelper = DatabaseMigrationHelper(
          secureStorage: mockSecureStorage,
        );
        final result = await migrationHelper.migrateToEncrypted();

        stopwatch.stop();

        expect(result.success, isTrue);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(10000), // Should complete in < 10 seconds
          reason: 'Migration should complete in reasonable time',
        );
      });
    });
  });
}
