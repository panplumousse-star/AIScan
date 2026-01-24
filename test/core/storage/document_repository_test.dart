import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';

import 'package:aiscan/core/security/encryption_service.dart';
import 'package:aiscan/core/storage/database_helper.dart';
import 'package:aiscan/core/storage/document_repository.dart';
import 'package:aiscan/core/utils/performance_utils.dart';
import 'package:aiscan/features/documents/domain/document_model.dart';

import 'document_repository_test.mocks.dart';

/// Mock ThumbnailCacheService for testing.
class MockThumbnailCacheService extends Mock implements ThumbnailCacheService {}

@GenerateNiceMocks([
  MockSpec<EncryptionService>(),
  MockSpec<DatabaseHelper>(),
])
void main() {
  late MockEncryptionService mockEncryption;
  late MockDatabaseHelper mockDatabase;
  late DocumentRepository repository;

  // Test data
  final testDocumentMap = {
    'id': 'test-uuid-123',
    'title': 'Test Document',
    'description': 'A test document',
    'file_path': '/encrypted/documents/test-uuid-123.jpg.enc',
    'thumbnail_path': '/encrypted/thumbnails/test-uuid-123.jpg.enc',
    'original_file_name': 'original.jpg',
    'page_count': 1,
    'file_size': 1024,
    'mime_type': 'image/jpeg',
    'ocr_text': null,
    'ocr_status': 'pending',
    'created_at': '2026-01-11T10:00:00.000Z',
    'updated_at': '2026-01-11T10:00:00.000Z',
    'folder_id': null,
    'is_favorite': 0,
  };

  final testDocumentWithOcr = {
    'id': 'test-uuid-456',
    'title': 'OCR Document',
    'description': 'A document with OCR text',
    'file_path': '/encrypted/documents/test-uuid-456.jpg.enc',
    'thumbnail_path': null,
    'original_file_name': 'scan.jpg',
    'page_count': 3,
    'file_size': 5120,
    'mime_type': 'image/jpeg',
    'ocr_text': 'This is some extracted text from the document.',
    'ocr_status': 'completed',
    'created_at': '2026-01-10T08:30:00.000Z',
    'updated_at': '2026-01-11T14:00:00.000Z',
    'folder_id': 'folder-abc',
    'is_favorite': 1,
  };

  final testDocument = Document.fromMap(
    testDocumentMap,
    pagesPaths: ['/encrypted/documents/test-uuid-123.jpg.enc'],
  );

  setUp(() {
    mockEncryption = MockEncryptionService();
    mockDatabase = MockDatabaseHelper();
    final mockThumbnailCache = MockThumbnailCacheService();

    repository = DocumentRepository(
      encryptionService: mockEncryption,
      databaseHelper: mockDatabase,
      thumbnailCacheService: mockThumbnailCache,
    );

    // Default mock behaviors
    when(mockEncryption.isReady()).thenAnswer((_) async => true);
    when(mockEncryption.ensureKeyInitialized()).thenAnswer((_) async => false);
    when(mockEncryption.encryptFile(any, any)).thenAnswer((_) async {});
    when(mockEncryption.decryptFile(any, any)).thenAnswer((_) async {});
    when(mockDatabase.initialize()).thenAnswer((_) async => false);

    // Default mock for single document page paths
    when(mockDatabase.getDocumentPagePaths(any)).thenAnswer((_) async => []);
  });

  group('DocumentRepository', () {
    group('getDocument', () {
      test('should return document when found', () async {
        // Arrange
        when(mockDatabase.getById(
                DatabaseHelper.tableDocuments, 'test-uuid-123'))
            .thenAnswer((_) async => testDocumentMap);

        // Act
        final result = await repository.getDocument('test-uuid-123');

        // Assert
        expect(result, isNotNull);
        expect(result!.id, equals('test-uuid-123'));
        expect(result.title, equals('Test Document'));
        verify(mockDatabase.getById(
                DatabaseHelper.tableDocuments, 'test-uuid-123'))
            .called(1);
      });

      test('should return null when document not found', () async {
        // Arrange
        when(mockDatabase.getById(
                DatabaseHelper.tableDocuments, 'non-existent'))
            .thenAnswer((_) async => null);

        // Act
        final result = await repository.getDocument('non-existent');

        // Assert
        expect(result, isNull);
      });

      test('should include tags when requested', () async {
        // Arrange
        when(mockDatabase.getById(
                DatabaseHelper.tableDocuments, 'test-uuid-123'))
            .thenAnswer((_) async => testDocumentMap);
        when(mockDatabase.query(
          DatabaseHelper.tableDocumentTags,
          columns: anyNamed('columns'),
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => [
              {'tag_id': 'tag-1'},
              {'tag_id': 'tag-2'},
            ]);

        // Act
        final result = await repository.getDocument(
          'test-uuid-123',
          includeTags: true,
        );

        // Assert
        expect(result, isNotNull);
        expect(result!.tags, contains('tag-1'));
        expect(result.tags, contains('tag-2'));
      });

      test('should throw DocumentRepositoryException on database error',
          () async {
        // Arrange
        when(mockDatabase.getById(any, any))
            .thenThrow(Exception('Database error'));

        // Act & Assert
        expect(
          () => repository.getDocument('test-uuid-123'),
          throwsA(isA<DocumentRepositoryException>()),
        );
      });
    });

    group('getAllDocuments', () {
      test('should return all documents', () async {
        // Arrange
        when(mockDatabase.query(
          DatabaseHelper.tableDocuments,
          orderBy: anyNamed('orderBy'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => [testDocumentMap]);
        when(mockDatabase.getBatchDocumentPagePaths(['test-uuid-123']))
            .thenAnswer((_) async => {
                  'test-uuid-123': [
                    '/encrypted/documents/test-uuid-123.jpg.enc'
                  ],
                });
        when(mockDatabase.getBatchDocumentTags(['test-uuid-123']))
            .thenAnswer((_) async => {});

        // Act
        final result = await repository.getAllDocuments();

        // Assert
        expect(result, hasLength(1));
        expect(result.first.id, equals('test-uuid-123'));
      });

      test('should return empty list when no documents', () async {
        // Arrange
        when(mockDatabase.query(
          DatabaseHelper.tableDocuments,
          orderBy: anyNamed('orderBy'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);
        when(mockDatabase.getBatchDocumentPagePaths([]))
            .thenAnswer((_) async => {});
        when(mockDatabase.getBatchDocumentTags([])).thenAnswer((_) async => {});

        // Act
        final result = await repository.getAllDocuments();

        // Assert
        expect(result, isEmpty);
      });

      test('should apply pagination parameters', () async {
        // Arrange
        when(mockDatabase.query(
          DatabaseHelper.tableDocuments,
          orderBy: anyNamed('orderBy'),
          limit: 10,
          offset: 20,
        )).thenAnswer((_) async => [testDocumentMap]);
        when(mockDatabase.getBatchDocumentPagePaths(['test-uuid-123']))
            .thenAnswer((_) async => {
                  'test-uuid-123': [
                    '/encrypted/documents/test-uuid-123.jpg.enc'
                  ],
                });
        when(mockDatabase.getBatchDocumentTags(['test-uuid-123']))
            .thenAnswer((_) async => {});

        // Act
        await repository.getAllDocuments(limit: 10, offset: 20);

        // Assert
        verify(mockDatabase.query(
          DatabaseHelper.tableDocuments,
          orderBy: anyNamed('orderBy'),
          limit: 10,
          offset: 20,
        )).called(1);
      });
    });

    group('getDocumentsInFolder', () {
      test('should return documents in folder', () async {
        // Arrange
        final mapWithFolder = Map<String, dynamic>.from(testDocumentMap);
        mapWithFolder['folder_id'] = 'folder-123';

        when(mockDatabase.query(
          DatabaseHelper.tableDocuments,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          orderBy: anyNamed('orderBy'),
        )).thenAnswer((_) async => [mapWithFolder]);

        // Act
        final result = await repository.getDocumentsInFolder('folder-123');

        // Assert
        expect(result, hasLength(1));
        expect(result.first.folderId, equals('folder-123'));
      });

      test('should return root documents when folderId is null', () async {
        // Arrange
        when(mockDatabase.query(
          DatabaseHelper.tableDocuments,
          where: '${DatabaseHelper.columnFolderId} IS NULL',
          whereArgs: null,
          orderBy: anyNamed('orderBy'),
        )).thenAnswer((_) async => [testDocumentMap]);

        // Act
        final result = await repository.getDocumentsInFolder(null);

        // Assert
        expect(result, hasLength(1));
        expect(result.first.folderId, isNull);
      });
    });

    group('getFavoriteDocuments', () {
      test('should return only favorite documents', () async {
        // Arrange
        final favoriteMap = Map<String, dynamic>.from(testDocumentMap);
        favoriteMap['is_favorite'] = 1;

        when(mockDatabase.query(
          DatabaseHelper.tableDocuments,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          orderBy: anyNamed('orderBy'),
        )).thenAnswer((_) async => [favoriteMap]);

        // Act
        final result = await repository.getFavoriteDocuments();

        // Assert
        expect(result, hasLength(1));
        expect(result.first.isFavorite, isTrue);
      });
    });

    group('getDocumentCount', () {
      test('should return document count', () async {
        // Arrange
        when(mockDatabase.count(DatabaseHelper.tableDocuments))
            .thenAnswer((_) async => 5);

        // Act
        final result = await repository.getDocumentCount();

        // Assert
        expect(result, equals(5));
      });
    });

    group('updateDocument', () {
      test('should update document metadata', () async {
        // Arrange
        when(mockDatabase.update(
          DatabaseHelper.tableDocuments,
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);

        // Act
        final result = await repository.updateDocument(
          testDocument.copyWith(title: 'Updated Title'),
        );

        // Assert
        expect(result.title, equals('Updated Title'));
        verify(mockDatabase.update(
          DatabaseHelper.tableDocuments,
          any,
          where: '${DatabaseHelper.columnId} = ?',
          whereArgs: ['test-uuid-123'],
        )).called(1);
      });

      test('should throw when document not found', () async {
        // Arrange
        when(mockDatabase.update(
          any,
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 0);

        // Act & Assert
        expect(
          () => repository.updateDocument(testDocument),
          throwsA(isA<DocumentRepositoryException>()),
        );
      });

      test('should update updatedAt timestamp', () async {
        // Arrange
        when(mockDatabase.update(
          any,
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);

        final originalUpdatedAt = testDocument.updatedAt;

        // Act
        final result = await repository.updateDocument(testDocument);

        // Assert - updatedAt should be different (later)
        expect(result.updatedAt, isNot(equals(originalUpdatedAt)));
      });
    });

    group('updateDocumentOcr', () {
      test('should update OCR text and status', () async {
        // Arrange
        when(mockDatabase.getById(
                DatabaseHelper.tableDocuments, 'test-uuid-123'))
            .thenAnswer((_) async => testDocumentMap);
        when(mockDatabase.update(
          any,
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);

        // Act
        final result = await repository.updateDocumentOcr(
          'test-uuid-123',
          'Extracted text from document',
        );

        // Assert
        expect(result.ocrText, equals('Extracted text from document'));
        expect(result.ocrStatus, equals(OcrStatus.completed));
      });

      test('should clear OCR text when null is provided', () async {
        // Arrange
        final docWithOcr = Map<String, dynamic>.from(testDocumentMap);
        docWithOcr['ocr_text'] = 'Previous OCR text';
        docWithOcr['ocr_status'] = 'completed';

        when(mockDatabase.getById(
                DatabaseHelper.tableDocuments, 'test-uuid-123'))
            .thenAnswer((_) async => docWithOcr);
        when(mockDatabase.update(
          any,
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);

        // Act
        final result = await repository.updateDocumentOcr(
          'test-uuid-123',
          null,
          status: OcrStatus.failed,
        );

        // Assert
        expect(result.ocrText, isNull);
        expect(result.ocrStatus, equals(OcrStatus.failed));
      });
    });

    group('toggleFavorite', () {
      test('should toggle favorite from false to true', () async {
        // Arrange
        when(mockDatabase.getById(
                DatabaseHelper.tableDocuments, 'test-uuid-123'))
            .thenAnswer((_) async => testDocumentMap);
        when(mockDatabase.update(
          any,
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);

        // Act
        final result = await repository.toggleFavorite('test-uuid-123');

        // Assert
        expect(result.isFavorite, isTrue);
      });

      test('should toggle favorite from true to false', () async {
        // Arrange
        final favoriteMap = Map<String, dynamic>.from(testDocumentMap);
        favoriteMap['is_favorite'] = 1;

        when(mockDatabase.getById(
                DatabaseHelper.tableDocuments, 'test-uuid-123'))
            .thenAnswer((_) async => favoriteMap);
        when(mockDatabase.update(
          any,
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);

        // Act
        final result = await repository.toggleFavorite('test-uuid-123');

        // Assert
        expect(result.isFavorite, isFalse);
      });
    });

    group('moveToFolder', () {
      test('should move document to folder', () async {
        // Arrange
        when(mockDatabase.getById(
                DatabaseHelper.tableDocuments, 'test-uuid-123'))
            .thenAnswer((_) async => testDocumentMap);
        when(mockDatabase.update(
          any,
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);

        // Act
        final result =
            await repository.moveToFolder('test-uuid-123', 'folder-456');

        // Assert
        expect(result.folderId, equals('folder-456'));
      });

      test('should move document to root when folderId is null', () async {
        // Arrange
        final docInFolder = Map<String, dynamic>.from(testDocumentMap);
        docInFolder['folder_id'] = 'folder-123';

        when(mockDatabase.getById(
                DatabaseHelper.tableDocuments, 'test-uuid-123'))
            .thenAnswer((_) async => docInFolder);
        when(mockDatabase.update(
          any,
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);

        // Act
        final result = await repository.moveToFolder('test-uuid-123', null);

        // Assert
        expect(result.folderId, isNull);
      });
    });

    group('deleteDocument', () {
      test('should delete document and files', () async {
        // Arrange
        when(mockDatabase.getById(
                DatabaseHelper.tableDocuments, 'test-uuid-123'))
            .thenAnswer((_) async => testDocumentMap);
        when(mockDatabase.delete(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);

        // Act & Assert - should not throw
        await expectLater(
          repository.deleteDocument('test-uuid-123'),
          completes,
        );

        verify(mockDatabase.delete(
          DatabaseHelper.tableDocuments,
          where: '${DatabaseHelper.columnId} = ?',
          whereArgs: ['test-uuid-123'],
        )).called(1);
      });

      test('should throw when document not found', () async {
        // Arrange
        when(mockDatabase.getById(any, any)).thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () => repository.deleteDocument('non-existent'),
          throwsA(isA<DocumentRepositoryException>()),
        );
      });
    });

    group('deleteDocuments', () {
      test('should delete multiple documents', () async {
        // Arrange
        when(mockDatabase.getById(DatabaseHelper.tableDocuments, any))
            .thenAnswer((_) async => testDocumentMap);
        when(mockDatabase.delete(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);

        // Act
        await repository.deleteDocuments(['id-1', 'id-2', 'id-3']);

        // Assert
        verify(mockDatabase.delete(
          DatabaseHelper.tableDocuments,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).called(3);
      });
    });

    group('Tag Operations', () {
      test('getDocumentTags should return tag IDs', () async {
        // Arrange
        when(mockDatabase.query(
          DatabaseHelper.tableDocumentTags,
          columns: anyNamed('columns'),
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => [
              {'tag_id': 'tag-1'},
              {'tag_id': 'tag-2'},
            ]);

        // Act
        final result = await repository.getDocumentTags('test-uuid-123');

        // Assert
        expect(result, hasLength(2));
        expect(result, contains('tag-1'));
        expect(result, contains('tag-2'));
      });

      test('addTagToDocument should insert tag association', () async {
        // Arrange
        when(mockDatabase.insert(DatabaseHelper.tableDocumentTags, any))
            .thenAnswer((_) async => 1);

        // Act
        await repository.addTagToDocument('test-uuid-123', 'tag-1');

        // Assert
        verify(mockDatabase.insert(
          DatabaseHelper.tableDocumentTags,
          argThat(
            predicate<Map<String, dynamic>>((map) =>
                map['document_id'] == 'test-uuid-123' &&
                map['tag_id'] == 'tag-1'),
          ),
        )).called(1);
      });

      test('removeTagFromDocument should delete tag association', () async {
        // Arrange
        when(mockDatabase.delete(
          DatabaseHelper.tableDocumentTags,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);

        // Act
        await repository.removeTagFromDocument('test-uuid-123', 'tag-1');

        // Assert
        verify(mockDatabase.delete(
          DatabaseHelper.tableDocumentTags,
          where:
              '${DatabaseHelper.columnDocumentId} = ? AND ${DatabaseHelper.columnTagId} = ?',
          whereArgs: ['test-uuid-123', 'tag-1'],
        )).called(1);
      });

      test('getDocumentsByTag should return documents with tag', () async {
        // Arrange
        when(mockDatabase.rawQuery(any, any))
            .thenAnswer((_) async => [testDocumentMap]);

        // Act
        final result = await repository.getDocumentsByTag('tag-1');

        // Assert
        expect(result, hasLength(1));
        expect(result.first.id, equals('test-uuid-123'));
      });
    });

    group('searchDocuments', () {
      test('should return matching documents', () async {
        // Arrange
        when(mockDatabase.searchDocuments('test query'))
            .thenAnswer((_) async => ['test-uuid-123']);
        when(mockDatabase.rawQuery(any, any))
            .thenAnswer((_) async => [testDocumentMap]);
        when(mockDatabase.getBatchDocumentPagePaths(['test-uuid-123']))
            .thenAnswer((_) async => {
                  'test-uuid-123': [
                    '/encrypted/documents/test-uuid-123.jpg.enc'
                  ],
                });
        when(mockDatabase.getBatchDocumentTags(['test-uuid-123']))
            .thenAnswer((_) async => {});

        // Act
        final result = await repository.searchDocuments('test query');

        // Assert
        expect(result, hasLength(1));
        expect(result.first.id, equals('test-uuid-123'));
      });

      test('should return empty list for no matches', () async {
        // Arrange
        when(mockDatabase.searchDocuments('no match'))
            .thenAnswer((_) async => []);

        // Act
        final result = await repository.searchDocuments('no match');

        // Assert
        expect(result, isEmpty);
      });
    });

    group('isReady', () {
      test('should return true when encryption is ready', () async {
        // Arrange
        when(mockEncryption.isReady()).thenAnswer((_) async => true);

        // Act
        final result = await repository.isReady();

        // Assert
        expect(result, isTrue);
      });

      test('should return false when encryption is not ready', () async {
        // Arrange
        when(mockEncryption.isReady()).thenAnswer((_) async => false);

        // Act
        final result = await repository.isReady();

        // Assert
        expect(result, isFalse);
      });
    });

    group('initialize', () {
      test('should initialize database and encryption', () async {
        // Ensure Flutter bindings are initialized for this test
        TestWidgetsFlutterBinding.ensureInitialized();

        // Arrange
        when(mockDatabase.initialize()).thenAnswer((_) async => true);
        when(mockEncryption.ensureKeyInitialized())
            .thenAnswer((_) async => true);

        // Act
        final result = await repository.initialize();

        // Assert
        expect(result, isTrue);
        verify(mockDatabase.initialize()).called(1);
        verify(mockEncryption.ensureKeyInitialized()).called(1);
      }, skip: 'Requires platform method channel mocking (path_provider)');
    });
  });

  group('DocumentRepositoryException', () {
    test('should format message without cause', () {
      // Arrange
      const exception = DocumentRepositoryException('Test error');

      // Act
      final message = exception.toString();

      // Assert
      expect(message, equals('DocumentRepositoryException: Test error'));
    });

    test('should format message with cause', () {
      // Arrange
      final cause = Exception('Root cause');
      final exception = DocumentRepositoryException('Test error', cause: cause);

      // Act
      final message = exception.toString();

      // Assert
      expect(
        message,
        equals(
          'DocumentRepositoryException: Test error (caused by: Exception: Root cause)',
        ),
      );
    });

    test('should store message and cause', () {
      // Arrange
      final cause = Exception('Root cause');
      const errorMessage = 'Test error';
      final exception = DocumentRepositoryException(errorMessage, cause: cause);

      // Assert
      expect(exception.message, equals(errorMessage));
      expect(exception.cause, equals(cause));
    });
  });

  group('documentRepositoryProvider', () {
    test('should provide DocumentRepository with dependencies', () {
      // Arrange
      final container = ProviderContainer();

      // Act
      final repository = container.read(documentRepositoryProvider);

      // Assert
      expect(repository, isA<DocumentRepository>());

      container.dispose();
    });
  });

  group('Document Model serialization', () {
    test('should correctly serialize document to map', () {
      // Arrange
      final document = Document(
        id: 'doc-id-123',
        title: 'Test Title',
        description: 'Test Description',
        pagesPaths: [
          '/path/to/file-page1.enc',
          '/path/to/file-page2.enc',
          '/path/to/file-page3.enc',
          '/path/to/file-page4.enc',
          '/path/to/file-page5.enc',
        ],
        thumbnailPath: '/path/to/thumb.enc',
        originalFileName: 'original.pdf',
        fileSize: 2048,
        mimeType: 'application/pdf',
        ocrText: 'Extracted text content',
        ocrStatus: OcrStatus.completed,
        createdAt: DateTime.parse('2026-01-11T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-01-11T11:00:00.000Z'),
        folderId: 'folder-123',
        isFavorite: true,
        tags: ['tag-1', 'tag-2'],
      );

      // Act
      final map = document.toMap();

      // Assert
      expect(map['id'], equals('doc-id-123'));
      expect(map['title'], equals('Test Title'));
      expect(map['description'], equals('Test Description'));
      expect(map['thumbnail_path'], equals('/path/to/thumb.enc'));
      expect(map['original_file_name'], equals('original.pdf'));
      expect(map['file_size'], equals(2048));
      expect(map['mime_type'], equals('application/pdf'));
      expect(map['ocr_text'], equals('Extracted text content'));
      expect(map['ocr_status'], equals('completed'));
      expect(map['folder_id'], equals('folder-123'));
      expect(map['is_favorite'], equals(1));
      // Note: pagesPaths and tags are not included in toMap() as they're stored in separate tables
      expect(map.containsKey('file_path'), isFalse);
      expect(map.containsKey('page_count'), isFalse);
    });

    test('should correctly deserialize document from map', () {
      // Arrange
      final map = {
        'id': 'doc-id-456',
        'title': 'Restored Document',
        'description': null,
        'thumbnail_path': null,
        'original_file_name': 'scan.jpg',
        'file_size': 1024,
        'mime_type': 'image/jpeg',
        'ocr_text': null,
        'ocr_status': 'pending',
        'created_at': '2026-01-11T10:00:00.000Z',
        'updated_at': '2026-01-11T10:00:00.000Z',
        'folder_id': null,
        'is_favorite': 0,
      };
      final pagesPaths = ['/encrypted/doc.enc'];

      // Act
      final document = Document.fromMap(map, pagesPaths: pagesPaths);

      // Assert
      expect(document.id, equals('doc-id-456'));
      expect(document.title, equals('Restored Document'));
      expect(document.description, isNull);
      expect(document.filePath, equals('/encrypted/doc.enc'));
      expect(document.pageCount, equals(1));
      expect(document.thumbnailPath, isNull);
      expect(document.ocrStatus, equals(OcrStatus.pending));
      expect(document.isFavorite, isFalse);
    });

    test('should deserialize document with tags', () {
      // Arrange
      final map = {
        'id': 'doc-with-tags',
        'title': 'Tagged Document',
        'created_at': '2026-01-11T10:00:00.000Z',
        'updated_at': '2026-01-11T10:00:00.000Z',
      };
      final pagesPaths = ['/path/file.enc'];
      final tags = ['tag-a', 'tag-b', 'tag-c'];

      // Act
      final document =
          Document.fromMap(map, pagesPaths: pagesPaths, tags: tags);

      // Assert
      expect(document.tags, equals(tags));
      expect(document.hasTags, isTrue);
    });

    test('copyWith should preserve values when not specified', () {
      // Arrange
      final original = Document.fromMap(
        testDocumentMap,
        pagesPaths: ['/encrypted/documents/test-uuid-123.jpg.enc'],
      );

      // Act
      final copy = original.copyWith();

      // Assert
      expect(copy.id, equals(original.id));
      expect(copy.title, equals(original.title));
      expect(copy.description, equals(original.description));
      expect(copy.filePath, equals(original.filePath));
      expect(copy.thumbnailPath, equals(original.thumbnailPath));
      expect(copy.originalFileName, equals(original.originalFileName));
      expect(copy.pageCount, equals(original.pageCount));
      expect(copy.fileSize, equals(original.fileSize));
      expect(copy.mimeType, equals(original.mimeType));
    });

    test('copyWith should update specified values', () {
      // Arrange
      final original = Document.fromMap(
        testDocumentMap,
        pagesPaths: ['/encrypted/documents/test-uuid-123.jpg.enc'],
      );

      // Act
      final copy = original.copyWith(
        title: 'New Title',
        description: 'New Description',
        isFavorite: true,
      );

      // Assert
      expect(copy.title, equals('New Title'));
      expect(copy.description, equals('New Description'));
      expect(copy.isFavorite, isTrue);
      // Unchanged values
      expect(copy.id, equals(original.id));
      expect(copy.filePath, equals(original.filePath));
    });

    test('copyWith with clear flags should set nullable fields to null', () {
      // Arrange
      final original = Document(
        id: 'test-id',
        title: 'Test',
        pagesPaths: ['/path/file.enc'],
        description: 'Has description',
        folderId: 'folder-123',
        ocrText: 'Has OCR text',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act
      final copy = original.copyWith(
        clearDescription: true,
        clearFolderId: true,
        clearOcrText: true,
      );

      // Assert
      expect(copy.description, isNull);
      expect(copy.folderId, isNull);
      expect(copy.ocrText, isNull);
      // Other values unchanged
      expect(copy.title, equals('Test'));
      expect(copy.filePath, equals('/path/file.enc'));
    });
  });

  group('Document convenience getters', () {
    test('hasOcrText should return true when OCR completed with text', () {
      // Arrange
      final document = Document(
        id: 'test-id',
        title: 'Test',
        pagesPaths: ['/path/file.enc'],
        ocrText: 'Extracted text',
        ocrStatus: OcrStatus.completed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Assert
      expect(document.hasOcrText, isTrue);
    });

    test('hasOcrText should return false when OCR pending', () {
      // Arrange
      final document = Document(
        id: 'test-id',
        title: 'Test',
        pagesPaths: ['/path/file.enc'],
        ocrText: null,
        ocrStatus: OcrStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Assert
      expect(document.hasOcrText, isFalse);
    });

    test('isInFolder should return true when folder assigned', () {
      // Arrange
      final document = Document(
        id: 'test-id',
        title: 'Test',
        pagesPaths: ['/path/file.enc'],
        folderId: 'folder-123',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Assert
      expect(document.isInFolder, isTrue);
    });

    test('isMultiPage should return true when pageCount > 1', () {
      // Arrange
      final document = Document(
        id: 'test-id',
        title: 'Test',
        pagesPaths: [
          '/path/file-page1.enc',
          '/path/file-page2.enc',
          '/path/file-page3.enc',
          '/path/file-page4.enc',
          '/path/file-page5.enc',
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Assert
      expect(document.isMultiPage, isTrue);
      expect(document.pageCount, equals(5));
    });

    test('fileSizeFormatted should display appropriate units', () {
      // Bytes
      final bytesDoc = Document(
        id: 'test-id',
        title: 'Test',
        pagesPaths: ['/path/file.enc'],
        fileSize: 512,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(bytesDoc.fileSizeFormatted, equals('512 B'));

      // KB
      final kbDoc = Document(
        id: 'test-id',
        title: 'Test',
        pagesPaths: ['/path/file.enc'],
        fileSize: 2048,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(kbDoc.fileSizeFormatted, equals('2.0 KB'));

      // MB
      final mbDoc = Document(
        id: 'test-id',
        title: 'Test',
        pagesPaths: ['/path/file.enc'],
        fileSize: 5 * 1024 * 1024,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(mbDoc.fileSizeFormatted, equals('5.0 MB'));
    });
  });

  group('DocumentListExtensions', () {
    final documents = [
      Document(
        id: 'doc-1',
        title: 'Zebra Document',
        pagesPaths: ['/path/1.enc'],
        isFavorite: true,
        ocrStatus: OcrStatus.completed,
        ocrText: 'Text 1',
        folderId: 'folder-a',
        fileSize: 1000,
        tags: ['tag-x'],
        createdAt: DateTime.parse('2026-01-10T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-01-11T10:00:00.000Z'),
      ),
      Document(
        id: 'doc-2',
        title: 'Alpha Document',
        pagesPaths: ['/path/2.enc'],
        isFavorite: false,
        ocrStatus: OcrStatus.pending,
        folderId: 'folder-b',
        fileSize: 2000,
        tags: ['tag-y'],
        createdAt: DateTime.parse('2026-01-11T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-01-10T10:00:00.000Z'),
      ),
      Document(
        id: 'doc-3',
        title: 'Beta Document',
        pagesPaths: ['/path/3.enc'],
        isFavorite: true,
        ocrStatus: OcrStatus.completed,
        ocrText: 'Text 3',
        folderId: 'folder-a',
        fileSize: 500,
        tags: ['tag-x', 'tag-y'],
        createdAt: DateTime.parse('2026-01-09T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-01-12T10:00:00.000Z'),
      ),
    ];

    test('favorites should return only favorite documents', () {
      final favorites = documents.favorites;
      expect(favorites, hasLength(2));
      expect(favorites.every((doc) => doc.isFavorite), isTrue);
    });

    test('withOcr should return documents with completed OCR', () {
      final withOcr = documents.withOcr;
      expect(withOcr, hasLength(2));
      expect(withOcr.every((doc) => doc.hasOcrText), isTrue);
    });

    test('inFolder should return documents in specified folder', () {
      final inFolderA = documents.inFolder('folder-a');
      expect(inFolderA, hasLength(2));
      expect(inFolderA.every((doc) => doc.folderId == 'folder-a'), isTrue);
    });

    test('withTag should return documents with specified tag', () {
      final withTagX = documents.withTag('tag-x');
      expect(withTagX, hasLength(2));

      final withTagY = documents.withTag('tag-y');
      expect(withTagY, hasLength(2));
    });

    test('sortedByTitle should sort alphabetically', () {
      final sorted = documents.sortedByTitle();
      expect(sorted[0].title, equals('Alpha Document'));
      expect(sorted[1].title, equals('Beta Document'));
      expect(sorted[2].title, equals('Zebra Document'));
    });

    test('sortedByCreatedDesc should sort newest first', () {
      final sorted = documents.sortedByCreatedDesc();
      expect(sorted[0].id, equals('doc-2'));
      expect(sorted[1].id, equals('doc-1'));
      expect(sorted[2].id, equals('doc-3'));
    });

    test('sortedByCreatedAsc should sort oldest first', () {
      final sorted = documents.sortedByCreatedAsc();
      expect(sorted[0].id, equals('doc-3'));
      expect(sorted[1].id, equals('doc-1'));
      expect(sorted[2].id, equals('doc-2'));
    });

    test('sortedByUpdatedDesc should sort by update date', () {
      final sorted = documents.sortedByUpdatedDesc();
      expect(sorted[0].id, equals('doc-3'));
      expect(sorted[1].id, equals('doc-1'));
      expect(sorted[2].id, equals('doc-2'));
    });

    test('sortedBySize should sort largest first', () {
      final sorted = documents.sortedBySize();
      expect(sorted[0].fileSize, equals(2000));
      expect(sorted[1].fileSize, equals(1000));
      expect(sorted[2].fileSize, equals(500));
    });
  });

  group('OcrStatus enum', () {
    test('should convert to and from string correctly', () {
      expect(OcrStatus.pending.value, equals('pending'));
      expect(OcrStatus.processing.value, equals('processing'));
      expect(OcrStatus.completed.value, equals('completed'));
      expect(OcrStatus.failed.value, equals('failed'));
    });

    test('fromString should parse valid values', () {
      expect(OcrStatus.fromString('pending'), equals(OcrStatus.pending));
      expect(OcrStatus.fromString('processing'), equals(OcrStatus.processing));
      expect(OcrStatus.fromString('completed'), equals(OcrStatus.completed));
      expect(OcrStatus.fromString('failed'), equals(OcrStatus.failed));
    });

    test('fromString should default to pending for invalid values', () {
      expect(OcrStatus.fromString(null), equals(OcrStatus.pending));
      expect(OcrStatus.fromString('unknown'), equals(OcrStatus.pending));
      expect(OcrStatus.fromString(''), equals(OcrStatus.pending));
    });
  });

  group('Multiple document scenarios', () {
    test('should handle batch retrieval of multiple documents', () async {
      // Arrange
      final doc1 = Map<String, dynamic>.from(testDocumentMap);
      doc1['id'] = 'doc-1';
      doc1['title'] = 'Document 1';

      final doc2 = Map<String, dynamic>.from(testDocumentMap);
      doc2['id'] = 'doc-2';
      doc2['title'] = 'Document 2';

      final doc3 = Map<String, dynamic>.from(testDocumentMap);
      doc3['id'] = 'doc-3';
      doc3['title'] = 'Document 3';

      when(mockDatabase.query(
        DatabaseHelper.tableDocuments,
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => [doc1, doc2, doc3]);

      // Act
      final result = await repository.getAllDocuments();

      // Assert
      expect(result, hasLength(3));
      expect(result[0].id, equals('doc-1'));
      expect(result[1].id, equals('doc-2'));
      expect(result[2].id, equals('doc-3'));
    });

    test('should handle custom orderBy parameter', () async {
      // Arrange
      when(mockDatabase.query(
        DatabaseHelper.tableDocuments,
        orderBy: '${DatabaseHelper.columnTitle} ASC',
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => [testDocumentMap]);

      // Act
      await repository.getAllDocuments(
        orderBy: '${DatabaseHelper.columnTitle} ASC',
      );

      // Assert
      verify(mockDatabase.query(
        DatabaseHelper.tableDocuments,
        orderBy: '${DatabaseHelper.columnTitle} ASC',
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).called(1);
    });
  });

  group('Error handling edge cases', () {
    test(
        'should throw DocumentRepositoryException on toggle favorite for non-existent document',
        () async {
      // Arrange
      when(mockDatabase.getById(DatabaseHelper.tableDocuments, 'non-existent'))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => repository.toggleFavorite('non-existent'),
        throwsA(isA<DocumentRepositoryException>()),
      );
    });

    test(
        'should throw DocumentRepositoryException on move to folder for non-existent document',
        () async {
      // Arrange
      when(mockDatabase.getById(DatabaseHelper.tableDocuments, 'non-existent'))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => repository.moveToFolder('non-existent', 'folder-123'),
        throwsA(isA<DocumentRepositoryException>()),
      );
    });

    test(
        'should throw DocumentRepositoryException on update OCR for non-existent document',
        () async {
      // Arrange
      when(mockDatabase.getById(DatabaseHelper.tableDocuments, 'non-existent'))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => repository.updateDocumentOcr('non-existent', 'OCR text'),
        throwsA(isA<DocumentRepositoryException>()),
      );
    });

    test('should handle tag operation errors gracefully', () async {
      // Arrange
      when(mockDatabase.query(
        DatabaseHelper.tableDocumentTags,
        columns: anyNamed('columns'),
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
      )).thenThrow(Exception('Tag query failed'));

      // Act & Assert
      expect(
        () => repository.getDocumentTags('test-uuid-123'),
        throwsA(isA<DocumentRepositoryException>()),
      );
    });

    test('should throw on addTagToDocument failure', () async {
      // Arrange
      when(mockDatabase.insert(DatabaseHelper.tableDocumentTags, any))
          .thenThrow(Exception('Insert failed'));

      // Act & Assert
      expect(
        () => repository.addTagToDocument('doc-id', 'tag-id'),
        throwsA(isA<DocumentRepositoryException>()),
      );
    });

    test('should throw on removeTagFromDocument failure', () async {
      // Arrange
      when(mockDatabase.delete(
        DatabaseHelper.tableDocumentTags,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
      )).thenThrow(Exception('Delete failed'));

      // Act & Assert
      expect(
        () => repository.removeTagFromDocument('doc-id', 'tag-id'),
        throwsA(isA<DocumentRepositoryException>()),
      );
    });

    test('should throw on getDocumentsByTag failure', () async {
      // Arrange
      when(mockDatabase.rawQuery(any, any))
          .thenThrow(Exception('Raw query failed'));

      // Act & Assert
      expect(
        () => repository.getDocumentsByTag('tag-id'),
        throwsA(isA<DocumentRepositoryException>()),
      );
    });

    test('should throw on searchDocuments failure', () async {
      // Arrange
      when(mockDatabase.searchDocuments(any))
          .thenThrow(Exception('Search failed'));

      // Act & Assert
      expect(
        () => repository.searchDocuments('test query'),
        throwsA(isA<DocumentRepositoryException>()),
      );
    });

    test('should throw on getAllDocuments failure', () async {
      // Arrange
      when(mockDatabase.query(
        DatabaseHelper.tableDocuments,
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenThrow(Exception('Query failed'));

      // Act & Assert
      expect(
        () => repository.getAllDocuments(),
        throwsA(isA<DocumentRepositoryException>()),
      );
    });

    test('should throw on getDocumentsInFolder failure', () async {
      // Arrange
      when(mockDatabase.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        orderBy: anyNamed('orderBy'),
      )).thenThrow(Exception('Query failed'));

      // Act & Assert
      expect(
        () => repository.getDocumentsInFolder('folder-123'),
        throwsA(isA<DocumentRepositoryException>()),
      );
    });

    test('should throw on getFavoriteDocuments failure', () async {
      // Arrange
      when(mockDatabase.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        orderBy: anyNamed('orderBy'),
      )).thenThrow(Exception('Query failed'));

      // Act & Assert
      expect(
        () => repository.getFavoriteDocuments(),
        throwsA(isA<DocumentRepositoryException>()),
      );
    });

    test('should throw on getDocumentCount failure', () async {
      // Arrange
      when(mockDatabase.count(DatabaseHelper.tableDocuments))
          .thenThrow(Exception('Count failed'));

      // Act & Assert
      expect(
        () => repository.getDocumentCount(),
        throwsA(isA<DocumentRepositoryException>()),
      );
    });
  });

  group('Document equality and hashCode', () {
    test('should consider equal documents with same properties', () {
      // Arrange
      final doc1 = Document.fromMap(
        testDocumentMap,
        pagesPaths: ['/encrypted/documents/test-uuid-123.jpg.enc'],
      );
      final doc2 = Document.fromMap(
        testDocumentMap,
        pagesPaths: ['/encrypted/documents/test-uuid-123.jpg.enc'],
      );

      // Assert
      expect(doc1, equals(doc2));
      expect(doc1.hashCode, equals(doc2.hashCode));
    });

    test('should consider unequal documents with different properties', () {
      // Arrange
      final doc1 = Document.fromMap(
        testDocumentMap,
        pagesPaths: ['/encrypted/documents/test-uuid-123.jpg.enc'],
      );
      final doc2 = Document.fromMap(
        testDocumentMap,
        pagesPaths: ['/encrypted/documents/test-uuid-123.jpg.enc'],
      ).copyWith(title: 'Different');

      // Assert
      expect(doc1, isNot(equals(doc2)));
    });

    test('toString should include key properties', () {
      // Arrange
      final document = Document.fromMap(
        testDocumentMap,
        pagesPaths: ['/encrypted/documents/test-uuid-123.jpg.enc'],
      );

      // Act
      final str = document.toString();

      // Assert
      expect(str, contains('id: test-uuid-123'));
      expect(str, contains('title: Test Document'));
      expect(str, contains('pageCount: 1'));
    });
  });
}
