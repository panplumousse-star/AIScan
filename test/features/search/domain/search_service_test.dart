import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:aiscan/core/storage/database_helper.dart';
import 'package:aiscan/core/storage/document_repository.dart';
import 'package:aiscan/features/documents/domain/document_model.dart';
import 'package:aiscan/features/search/domain/search_service.dart';

@GenerateMocks([DatabaseHelper, DocumentRepository])
import 'search_service_test.mocks.dart';

void main() {
  late MockDatabaseHelper mockDatabaseHelper;
  late MockDocumentRepository mockDocumentRepository;
  late SearchService searchService;

  /// Creates a test document with specified properties.
  Document createTestDocument({
    String id = 'doc-1',
    String title = 'Test Document',
    String? description,
    String? ocrText,
    String? folderId,
    bool isFavorite = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    int fileSize = 1024,
  }) {
    final now = DateTime.now();
    return Document(
      id: id,
      title: title,
      description: description,
      pagesPaths: ['/path/to/$id-page-1.enc'],
      thumbnailPath: '/path/to/$id-thumb.enc',
      originalFileName: '$id.jpg',
      fileSize: fileSize,
      mimeType: 'image/jpeg',
      ocrText: ocrText,
      ocrStatus: ocrText != null ? OcrStatus.completed : OcrStatus.pending,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      folderId: folderId,
      isFavorite: isFavorite,
    );
  }

  setUp(() {
    mockDatabaseHelper = MockDatabaseHelper();
    mockDocumentRepository = MockDocumentRepository();

    when(mockDatabaseHelper.initialize()).thenAnswer((_) async => true);
    when(mockDatabaseHelper.getSearchHistory(limit: anyNamed('limit')))
        .thenAnswer((_) async => []);

    // Default stubs for batch loading methods
    when(mockDatabaseHelper.query(
      any,
      distinct: anyNamed('distinct'),
      columns: anyNamed('columns'),
      where: anyNamed('where'),
      whereArgs: anyNamed('whereArgs'),
      groupBy: anyNamed('groupBy'),
      having: anyNamed('having'),
      orderBy: anyNamed('orderBy'),
      limit: anyNamed('limit'),
      offset: anyNamed('offset'),
    )).thenAnswer((_) async => []);

    when(mockDatabaseHelper.getBatchDocumentPagePaths(any))
        .thenAnswer((_) async => {});

    when(mockDatabaseHelper.getBatchDocumentTags(any))
        .thenAnswer((_) async => {});

    searchService = SearchService(
      databaseHelper: mockDatabaseHelper,
      documentRepository: mockDocumentRepository,
    );
  });

  group('Filter combinations with SQL WHERE clauses', () {
    test('favoritesOnly filter applies SQL WHERE clause', () async {
      await searchService.initialize();

      // Setup mock to return favorite documents
      when(mockDatabaseHelper.rawQuery(any, any))
          .thenAnswer((invocation) async {
        final sql = invocation.positionalArguments[0] as String;

        // Verify SQL contains the favorites filter
        expect(
          sql,
          contains('${DatabaseHelper.columnIsFavorite} = 1'),
          reason: 'SQL should include favorites filter in WHERE clause',
        );

        return [
          {
            'id': 'doc-fav-1',
            'title': 'Favorite Document',
            'description': 'A favorite',
            'ocr_text': null,
            'score': -1.0,
          },
        ];
      });

      // Mock batch document loading
      when(mockDatabaseHelper.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        distinct: anyNamed('distinct'),
        columns: anyNamed('columns'),
        groupBy: anyNamed('groupBy'),
        having: anyNamed('having'),
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => [
        {
          'id': 'doc-fav-1',
          'title': 'Favorite Document',
          'description': 'A favorite',
          'thumbnail_path': '/path/to/doc-fav-1-thumb.enc',
          'original_file_name': 'doc-fav-1.jpg',
          'file_size': 1024,
          'mime_type': 'image/jpeg',
          'ocr_text': null,
          'ocr_status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'folder_id': null,
          'is_favorite': 1,
        },
      ]);

      when(mockDatabaseHelper.getBatchDocumentPagePaths(['doc-fav-1']))
          .thenAnswer((_) async => {
        'doc-fav-1': ['/path/to/doc-fav-1-page-1.enc'],
      });

      final results = await searchService.search(
        'test',
        options: const SearchOptions(favoritesOnly: true),
      );

      expect(results.hasResults, isTrue);
      expect(results.results.length, 1);
      expect(results.results.first.document.isFavorite, isTrue);

      // Verify batch loading was used (query called once for all documents)
      verify(mockDatabaseHelper.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        distinct: anyNamed('distinct'),
        columns: anyNamed('columns'),
        groupBy: anyNamed('groupBy'),
        having: anyNamed('having'),
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).called(1);
    });

    test('hasOcrOnly filter applies SQL WHERE clause', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any))
          .thenAnswer((invocation) async {
        final sql = invocation.positionalArguments[0] as String;

        // Verify SQL contains the OCR filter
        expect(
          sql,
          contains('${DatabaseHelper.columnOcrText} IS NOT NULL'),
          reason: 'SQL should include OCR filter in WHERE clause',
        );

        return [
          {
            'id': 'doc-ocr-1',
            'title': 'Document with OCR',
            'description': null,
            'ocr_text': 'Extracted text content',
            'score': -1.5,
          },
        ];
      });

      // Mock batch document loading
      when(mockDatabaseHelper.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        distinct: anyNamed('distinct'),
        columns: anyNamed('columns'),
        groupBy: anyNamed('groupBy'),
        having: anyNamed('having'),
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => [
        {
          'id': 'doc-ocr-1',
          'title': 'Document with OCR',
          'description': null,
          'thumbnail_path': '/path/to/doc-ocr-1-thumb.enc',
          'original_file_name': 'doc-ocr-1.jpg',
          'file_size': 1024,
          'mime_type': 'image/jpeg',
          'ocr_text': 'Extracted text content',
          'ocr_status': 'completed',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'folder_id': null,
          'is_favorite': 0,
        },
      ]);

      when(mockDatabaseHelper.getBatchDocumentPagePaths(['doc-ocr-1']))
          .thenAnswer((_) async => {
        'doc-ocr-1': ['/path/to/doc-ocr-1-page-1.enc'],
      });

      final results = await searchService.search(
        'test',
        options: const SearchOptions(hasOcrOnly: true),
      );

      expect(results.hasResults, isTrue);
      expect(results.results.first.document.hasOcrText, isTrue);

      // Verify batch loading was used (query called once for all documents)
      verify(mockDatabaseHelper.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        distinct: anyNamed('distinct'),
        columns: anyNamed('columns'),
        groupBy: anyNamed('groupBy'),
        having: anyNamed('having'),
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).called(1);
    });

    test('folderId filter applies SQL WHERE clause with parameter', () async {
      await searchService.initialize();

      const testFolderId = 'folder-123';

      when(mockDatabaseHelper.rawQuery(any, any))
          .thenAnswer((invocation) async {
        final sql = invocation.positionalArguments[0] as String;
        final args = invocation.positionalArguments[1] as List<Object>;

        // Verify SQL contains the folder filter
        expect(
          sql,
          contains('${DatabaseHelper.columnFolderId} = ?'),
          reason: 'SQL should include folder filter in WHERE clause',
        );

        // Verify folder ID is passed as parameter
        expect(
          args,
          contains(testFolderId),
          reason: 'Folder ID should be passed as query parameter',
        );

        return [
          {
            'id': 'doc-folder-1',
            'title': 'Document in folder',
            'description': null,
            'ocr_text': null,
            'score': -1.0,
          },
        ];
      });

      // Mock batch document loading
      when(mockDatabaseHelper.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        distinct: anyNamed('distinct'),
        columns: anyNamed('columns'),
        groupBy: anyNamed('groupBy'),
        having: anyNamed('having'),
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => [
        {
          'id': 'doc-folder-1',
          'title': 'Document in folder',
          'description': null,
          'thumbnail_path': '/path/to/doc-folder-1-thumb.enc',
          'original_file_name': 'doc-folder-1.jpg',
          'file_size': 1024,
          'mime_type': 'image/jpeg',
          'ocr_text': null,
          'ocr_status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'folder_id': testFolderId,
          'is_favorite': 0,
        },
      ]);

      when(mockDatabaseHelper.getBatchDocumentPagePaths(['doc-folder-1']))
          .thenAnswer((_) async => {
        'doc-folder-1': ['/path/to/doc-folder-1-page-1.enc'],
      });

      final results = await searchService.search(
        'test',
        options: const SearchOptions(folderId: testFolderId),
      );

      expect(results.hasResults, isTrue);
      expect(results.results.first.document.folderId, testFolderId);

      // Verify batch loading was used (query called once for all documents)
      verify(mockDatabaseHelper.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        distinct: anyNamed('distinct'),
        columns: anyNamed('columns'),
        groupBy: anyNamed('groupBy'),
        having: anyNamed('having'),
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).called(1);
    });

    test('combination of favoritesOnly and hasOcrOnly filters', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any))
          .thenAnswer((invocation) async {
        final sql = invocation.positionalArguments[0] as String;

        // Verify SQL contains both filters combined with AND
        expect(
          sql,
          contains('${DatabaseHelper.columnIsFavorite} = 1'),
          reason: 'SQL should include favorites filter',
        );
        expect(
          sql,
          contains('${DatabaseHelper.columnOcrText} IS NOT NULL'),
          reason: 'SQL should include OCR filter',
        );

        return [
          {
            'id': 'doc-both-1',
            'title': 'Favorite with OCR',
            'description': null,
            'ocr_text': 'OCR content',
            'score': -2.0,
          },
        ];
      });

      // Mock batch document loading
      when(mockDatabaseHelper.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        distinct: anyNamed('distinct'),
        columns: anyNamed('columns'),
        groupBy: anyNamed('groupBy'),
        having: anyNamed('having'),
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => [
        {
          'id': 'doc-both-1',
          'title': 'Favorite with OCR',
          'description': null,
          'thumbnail_path': '/path/to/doc-both-1-thumb.enc',
          'original_file_name': 'doc-both-1.jpg',
          'file_size': 1024,
          'mime_type': 'image/jpeg',
          'ocr_text': 'OCR content',
          'ocr_status': 'completed',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'folder_id': null,
          'is_favorite': 1,
        },
      ]);

      when(mockDatabaseHelper.getBatchDocumentPagePaths(['doc-both-1']))
          .thenAnswer((_) async => {
        'doc-both-1': ['/path/to/doc-both-1-page-1.enc'],
      });

      final results = await searchService.search(
        'test',
        options: const SearchOptions(
          favoritesOnly: true,
          hasOcrOnly: true,
        ),
      );

      expect(results.hasResults, isTrue);
      expect(results.results.first.document.isFavorite, isTrue);
      expect(results.results.first.document.hasOcrText, isTrue);

      // Verify batch loading was used (query called once for all documents)
      verify(mockDatabaseHelper.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        distinct: anyNamed('distinct'),
        columns: anyNamed('columns'),
        groupBy: anyNamed('groupBy'),
        having: anyNamed('having'),
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).called(1);
    });

    test('combination of favoritesOnly and folderId filters', () async {
      await searchService.initialize();

      const testFolderId = 'folder-456';

      when(mockDatabaseHelper.rawQuery(any, any))
          .thenAnswer((invocation) async {
        final sql = invocation.positionalArguments[0] as String;
        final args = invocation.positionalArguments[1] as List<Object>;

        // Verify both filters in SQL
        expect(
          sql,
          contains('${DatabaseHelper.columnIsFavorite} = 1'),
          reason: 'SQL should include favorites filter',
        );
        expect(
          sql,
          contains('${DatabaseHelper.columnFolderId} = ?'),
          reason: 'SQL should include folder filter',
        );
        expect(
          args,
          contains(testFolderId),
          reason: 'Folder ID should be in parameters',
        );

        return [
          {
            'id': 'doc-combo-1',
            'title': 'Favorite in folder',
            'description': null,
            'ocr_text': null,
            'score': -1.5,
          },
        ];
      });

      // Mock batch document loading
      when(mockDatabaseHelper.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        distinct: anyNamed('distinct'),
        columns: anyNamed('columns'),
        groupBy: anyNamed('groupBy'),
        having: anyNamed('having'),
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => [
        {
          'id': 'doc-combo-1',
          'title': 'Favorite in folder',
          'description': null,
          'thumbnail_path': '/path/to/doc-combo-1-thumb.enc',
          'original_file_name': 'doc-combo-1.jpg',
          'file_size': 1024,
          'mime_type': 'image/jpeg',
          'ocr_text': null,
          'ocr_status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'folder_id': testFolderId,
          'is_favorite': 1,
        },
      ]);

      when(mockDatabaseHelper.getBatchDocumentPagePaths(['doc-combo-1']))
          .thenAnswer((_) async => {
        'doc-combo-1': ['/path/to/doc-combo-1-page-1.enc'],
      });

      final results = await searchService.search(
        'test',
        options: const SearchOptions(
          favoritesOnly: true,
          folderId: testFolderId,
        ),
      );

      expect(results.hasResults, isTrue);
      expect(results.results.first.document.isFavorite, isTrue);
      expect(results.results.first.document.folderId, testFolderId);

      // Verify batch loading was used (query called once for all documents)
      verify(mockDatabaseHelper.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        distinct: anyNamed('distinct'),
        columns: anyNamed('columns'),
        groupBy: anyNamed('groupBy'),
        having: anyNamed('having'),
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).called(1);
    });

    test('all three filters combined (favoritesOnly, hasOcrOnly, folderId)',
        () async {
      await searchService.initialize();

      const testFolderId = 'folder-789';

      when(mockDatabaseHelper.rawQuery(any, any))
          .thenAnswer((invocation) async {
        final sql = invocation.positionalArguments[0] as String;
        final args = invocation.positionalArguments[1] as List<Object>;

        // Verify all three filters in SQL
        expect(
          sql,
          contains('${DatabaseHelper.columnIsFavorite} = 1'),
          reason: 'SQL should include favorites filter',
        );
        expect(
          sql,
          contains('${DatabaseHelper.columnOcrText} IS NOT NULL'),
          reason: 'SQL should include OCR filter',
        );
        expect(
          sql,
          contains('${DatabaseHelper.columnFolderId} = ?'),
          reason: 'SQL should include folder filter',
        );
        expect(
          args,
          contains(testFolderId),
          reason: 'Folder ID should be in parameters',
        );

        return [
          {
            'id': 'doc-all-1',
            'title': 'All filters match',
            'description': 'Test',
            'ocr_text': 'Complete OCR text',
            'score': -2.5,
          },
        ];
      });

      // Mock batch document loading
      when(mockDatabaseHelper.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        distinct: anyNamed('distinct'),
        columns: anyNamed('columns'),
        groupBy: anyNamed('groupBy'),
        having: anyNamed('having'),
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => [
        {
          'id': 'doc-all-1',
          'title': 'All filters match',
          'description': 'Test',
          'thumbnail_path': '/path/to/doc-all-1-thumb.enc',
          'original_file_name': 'doc-all-1.jpg',
          'file_size': 1024,
          'mime_type': 'image/jpeg',
          'ocr_text': 'Complete OCR text',
          'ocr_status': 'completed',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'folder_id': testFolderId,
          'is_favorite': 1,
        },
      ]);

      when(mockDatabaseHelper.getBatchDocumentPagePaths(['doc-all-1']))
          .thenAnswer((_) async => {
        'doc-all-1': ['/path/to/doc-all-1-page-1.enc'],
      });

      final results = await searchService.search(
        'test',
        options: const SearchOptions(
          favoritesOnly: true,
          hasOcrOnly: true,
          folderId: testFolderId,
        ),
      );

      expect(results.hasResults, isTrue);
      expect(results.results.first.document.isFavorite, isTrue);
      expect(results.results.first.document.hasOcrText, isTrue);
      expect(results.results.first.document.folderId, testFolderId);

      // Verify batch loading was used (query called once for all documents)
      verify(mockDatabaseHelper.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        distinct: anyNamed('distinct'),
        columns: anyNamed('columns'),
        groupBy: anyNamed('groupBy'),
        having: anyNamed('having'),
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).called(1);
    });

    test('no filters applied when all are false/null', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any))
          .thenAnswer((invocation) async {
        final sql = invocation.positionalArguments[0] as String;

        // When no filters, SQL should only have MATCH condition
        // Should NOT contain filter WHERE clauses
        expect(
          sql,
          isNot(contains('${DatabaseHelper.columnIsFavorite} = 1')),
          reason: 'SQL should not include favorites filter when not requested',
        );
        expect(
          sql,
          isNot(contains('${DatabaseHelper.columnOcrText} IS NOT NULL')),
          reason: 'SQL should not include OCR filter when not requested',
        );
        expect(
          sql,
          isNot(contains('${DatabaseHelper.columnFolderId} = ?')),
          reason: 'SQL should not include folder filter when not requested',
        );

        return [
          {
            'id': 'doc-no-filter-1',
            'title': 'Any document',
            'description': null,
            'ocr_text': null,
            'score': -1.0,
          },
        ];
      });

      // Mock batch document loading
      when(mockDatabaseHelper.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        distinct: anyNamed('distinct'),
        columns: anyNamed('columns'),
        groupBy: anyNamed('groupBy'),
        having: anyNamed('having'),
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => [
        {
          'id': 'doc-no-filter-1',
          'title': 'Any document',
          'description': null,
          'thumbnail_path': '/path/to/doc-no-filter-1-thumb.enc',
          'original_file_name': 'doc-no-filter-1.jpg',
          'file_size': 1024,
          'mime_type': 'image/jpeg',
          'ocr_text': null,
          'ocr_status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'folder_id': null,
          'is_favorite': 0,
        },
      ]);

      when(mockDatabaseHelper.getBatchDocumentPagePaths(['doc-no-filter-1']))
          .thenAnswer((_) async => {
        'doc-no-filter-1': ['/path/to/doc-no-filter-1-page-1.enc'],
      });

      final results = await searchService.search(
        'test',
      );

      expect(results.hasResults, isTrue);

      // Verify batch loading was used (query called once for all documents)
      verify(mockDatabaseHelper.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        distinct: anyNamed('distinct'),
        columns: anyNamed('columns'),
        groupBy: anyNamed('groupBy'),
        having: anyNamed('having'),
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).called(1);
    });

    test('verifies no N+1 query issue with multiple results', () async {
      await searchService.initialize();

      // Return multiple results to verify no N+1 pattern
      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => [
            {
              'id': 'doc-1',
              'title': 'Document 1',
              'description': null,
              'ocr_text': 'OCR 1',
              'score': -1.0,
            },
            {
              'id': 'doc-2',
              'title': 'Document 2',
              'description': null,
              'ocr_text': 'OCR 2',
              'score': -1.5,
            },
            {
              'id': 'doc-3',
              'title': 'Document 3',
              'description': null,
              'ocr_text': 'OCR 3',
              'score': -2.0,
            },
          ]);

      // Mock batch document loading for all three documents
      when(mockDatabaseHelper.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        distinct: anyNamed('distinct'),
        columns: anyNamed('columns'),
        groupBy: anyNamed('groupBy'),
        having: anyNamed('having'),
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => [
        {
          'id': 'doc-1',
          'title': 'Document 1',
          'description': null,
          'thumbnail_path': '/path/to/doc-1-thumb.enc',
          'original_file_name': 'doc-1.jpg',
          'file_size': 1024,
          'mime_type': 'image/jpeg',
          'ocr_text': 'OCR 1',
          'ocr_status': 'completed',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'folder_id': null,
          'is_favorite': 1,
        },
        {
          'id': 'doc-2',
          'title': 'Document 2',
          'description': null,
          'thumbnail_path': '/path/to/doc-2-thumb.enc',
          'original_file_name': 'doc-2.jpg',
          'file_size': 1024,
          'mime_type': 'image/jpeg',
          'ocr_text': 'OCR 2',
          'ocr_status': 'completed',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'folder_id': null,
          'is_favorite': 1,
        },
        {
          'id': 'doc-3',
          'title': 'Document 3',
          'description': null,
          'thumbnail_path': '/path/to/doc-3-thumb.enc',
          'original_file_name': 'doc-3.jpg',
          'file_size': 1024,
          'mime_type': 'image/jpeg',
          'ocr_text': 'OCR 3',
          'ocr_status': 'completed',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'folder_id': null,
          'is_favorite': 1,
        },
      ]);

      when(mockDatabaseHelper.getBatchDocumentPagePaths(['doc-1', 'doc-2', 'doc-3']))
          .thenAnswer((_) async => {
        'doc-1': ['/path/to/doc-1-page-1.enc'],
        'doc-2': ['/path/to/doc-2-page-1.enc'],
        'doc-3': ['/path/to/doc-3-page-1.enc'],
      });

      final results = await searchService.search(
        'test',
        options: const SearchOptions(
          favoritesOnly: true,
          hasOcrOnly: true,
        ),
      );

      expect(results.results.length, 3);

      // Verify exactly 1 database query was made (not N queries for filtering)
      verify(mockDatabaseHelper.rawQuery(any, any)).called(1);

      // Verify batch loading was called once for all documents (not N times)
      verify(mockDatabaseHelper.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        distinct: anyNamed('distinct'),
        columns: anyNamed('columns'),
        groupBy: anyNamed('groupBy'),
        having: anyNamed('having'),
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).called(1);

      // Verify page paths batch loading was called once
      verify(mockDatabaseHelper.getBatchDocumentPagePaths(any)).called(1);
    });

    test('filters work correctly in fallback LIKE search', () async {
      await searchService.initialize();

      // First call fails (FTS), second succeeds (fallback)
      var callCount = 0;
      when(mockDatabaseHelper.rawQuery(any, any))
          .thenAnswer((invocation) async {
        callCount++;
        final sql = invocation.positionalArguments[0] as String;

        if (callCount == 1) {
          // FTS query fails
          throw Exception('FTS error');
        }

        // Fallback LIKE query should also include filters
        expect(
          sql,
          contains('${DatabaseHelper.columnIsFavorite} = 1'),
          reason: 'Fallback SQL should include favorites filter',
        );
        expect(
          sql,
          contains('${DatabaseHelper.columnOcrText} IS NOT NULL'),
          reason: 'Fallback SQL should include OCR filter',
        );

        return [
          {
            'id': 'doc-fallback-1',
            'title': 'Fallback result',
            'description': null,
            'ocr_text': 'Fallback OCR',
            'score': 0.0,
          },
        ];
      });

      // Mock batch document loading
      when(mockDatabaseHelper.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        distinct: anyNamed('distinct'),
        columns: anyNamed('columns'),
        groupBy: anyNamed('groupBy'),
        having: anyNamed('having'),
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => [
        {
          'id': 'doc-fallback-1',
          'title': 'Fallback result',
          'description': null,
          'thumbnail_path': '/path/to/doc-fallback-1-thumb.enc',
          'original_file_name': 'doc-fallback-1.jpg',
          'file_size': 1024,
          'mime_type': 'image/jpeg',
          'ocr_text': 'Fallback OCR',
          'ocr_status': 'completed',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'folder_id': null,
          'is_favorite': 1,
        },
      ]);

      when(mockDatabaseHelper.getBatchDocumentPagePaths(['doc-fallback-1']))
          .thenAnswer((_) async => {
        'doc-fallback-1': ['/path/to/doc-fallback-1-page-1.enc'],
      });

      final results = await searchService.search(
        'test',
        options: const SearchOptions(
          favoritesOnly: true,
          hasOcrOnly: true,
        ),
      );

      expect(results.hasResults, isTrue);
      expect(results.results.first.document.isFavorite, isTrue);
      expect(results.results.first.document.hasOcrText, isTrue);

      // Verify fallback was called
      verify(mockDatabaseHelper.rawQuery(any, any)).called(2);

      // Verify batch loading was used (query called once for all documents)
      verify(mockDatabaseHelper.query(
        DatabaseHelper.tableDocuments,
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
        distinct: anyNamed('distinct'),
        columns: anyNamed('columns'),
        groupBy: anyNamed('groupBy'),
        having: anyNamed('having'),
        orderBy: anyNamed('orderBy'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).called(1);
    });
  });
}
