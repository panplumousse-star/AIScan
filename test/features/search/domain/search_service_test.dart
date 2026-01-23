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

    searchService = SearchService(
      databaseHelper: mockDatabaseHelper,
      documentRepository: mockDocumentRepository,
    );
  });

  group('Filter combinations with SQL WHERE clauses', () {
    test('favoritesOnly filter applies SQL WHERE clause', () async {
      await searchService.initialize();

      // Setup mock to return favorite documents
      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((invocation) async {
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

      when(mockDocumentRepository.getDocument('doc-fav-1', includeTags: false))
          .thenAnswer((_) async => createTestDocument(
                id: 'doc-fav-1',
                title: 'Favorite Document',
                isFavorite: true,
              ));

      final results = await searchService.search(
        'test',
        options: const SearchOptions(favoritesOnly: true),
      );

      expect(results.hasResults, isTrue);
      expect(results.results.length, 1);
      expect(results.results.first.document.isFavorite, isTrue);

      // Verify that getDocument was only called once to build the result,
      // not for filtering (which would indicate N+1 queries)
      verify(mockDocumentRepository.getDocument('doc-fav-1', includeTags: false))
          .called(1);
    });

    test('hasOcrOnly filter applies SQL WHERE clause', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((invocation) async {
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

      when(mockDocumentRepository.getDocument('doc-ocr-1', includeTags: false))
          .thenAnswer((_) async => createTestDocument(
                id: 'doc-ocr-1',
                title: 'Document with OCR',
                ocrText: 'Extracted text content',
              ));

      final results = await searchService.search(
        'test',
        options: const SearchOptions(hasOcrOnly: true),
      );

      expect(results.hasResults, isTrue);
      expect(results.results.first.document.hasOcrText, isTrue);

      // Verify no N+1 query pattern
      verify(mockDocumentRepository.getDocument('doc-ocr-1', includeTags: false))
          .called(1);
    });

    test('folderId filter applies SQL WHERE clause with parameter', () async {
      await searchService.initialize();

      const testFolderId = 'folder-123';

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((invocation) async {
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

      when(mockDocumentRepository.getDocument('doc-folder-1', includeTags: false))
          .thenAnswer((_) async => createTestDocument(
                id: 'doc-folder-1',
                title: 'Document in folder',
                folderId: testFolderId,
              ));

      final results = await searchService.search(
        'test',
        options: const SearchOptions(folderId: testFolderId),
      );

      expect(results.hasResults, isTrue);
      expect(results.results.first.document.folderId, testFolderId);

      // Verify no N+1 query pattern
      verify(mockDocumentRepository.getDocument('doc-folder-1', includeTags: false))
          .called(1);
    });

    test('combination of favoritesOnly and hasOcrOnly filters', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((invocation) async {
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

      when(mockDocumentRepository.getDocument('doc-both-1', includeTags: false))
          .thenAnswer((_) async => createTestDocument(
                id: 'doc-both-1',
                title: 'Favorite with OCR',
                ocrText: 'OCR content',
                isFavorite: true,
              ));

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

      // Verify single getDocument call per result
      verify(mockDocumentRepository.getDocument('doc-both-1', includeTags: false))
          .called(1);
    });

    test('combination of favoritesOnly and folderId filters', () async {
      await searchService.initialize();

      const testFolderId = 'folder-456';

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((invocation) async {
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

      when(mockDocumentRepository.getDocument('doc-combo-1', includeTags: false))
          .thenAnswer((_) async => createTestDocument(
                id: 'doc-combo-1',
                title: 'Favorite in folder',
                folderId: testFolderId,
                isFavorite: true,
              ));

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

      // Verify no N+1 queries
      verify(mockDocumentRepository.getDocument('doc-combo-1', includeTags: false))
          .called(1);
    });

    test('all three filters combined (favoritesOnly, hasOcrOnly, folderId)', () async {
      await searchService.initialize();

      const testFolderId = 'folder-789';

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((invocation) async {
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

      when(mockDocumentRepository.getDocument('doc-all-1', includeTags: false))
          .thenAnswer((_) async => createTestDocument(
                id: 'doc-all-1',
                title: 'All filters match',
                description: 'Test',
                ocrText: 'Complete OCR text',
                folderId: testFolderId,
                isFavorite: true,
              ));

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

      // Verify only one getDocument call per result (no N+1 pattern)
      verify(mockDocumentRepository.getDocument('doc-all-1', includeTags: false))
          .called(1);
    });

    test('no filters applied when all are false/null', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((invocation) async {
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

      when(mockDocumentRepository.getDocument('doc-no-filter-1', includeTags: false))
          .thenAnswer((_) async => createTestDocument(
                id: 'doc-no-filter-1',
                title: 'Any document',
              ));

      final results = await searchService.search(
        'test',
        options: const SearchOptions(
          favoritesOnly: false,
          hasOcrOnly: false,
          folderId: null,
        ),
      );

      expect(results.hasResults, isTrue);

      // Verify single getDocument call
      verify(mockDocumentRepository.getDocument('doc-no-filter-1', includeTags: false))
          .called(1);
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

      // Mock document repository for building full results
      when(mockDocumentRepository.getDocument('doc-1', includeTags: false))
          .thenAnswer((_) async => createTestDocument(id: 'doc-1', ocrText: 'OCR 1'));
      when(mockDocumentRepository.getDocument('doc-2', includeTags: false))
          .thenAnswer((_) async => createTestDocument(id: 'doc-2', ocrText: 'OCR 2'));
      when(mockDocumentRepository.getDocument('doc-3', includeTags: false))
          .thenAnswer((_) async => createTestDocument(id: 'doc-3', ocrText: 'OCR 3'));

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

      // Verify getDocument was called exactly 3 times (once per result to build full data)
      // NOT called for filtering - that's done in SQL
      verify(mockDocumentRepository.getDocument('doc-1', includeTags: false)).called(1);
      verify(mockDocumentRepository.getDocument('doc-2', includeTags: false)).called(1);
      verify(mockDocumentRepository.getDocument('doc-3', includeTags: false)).called(1);

      // Verify no additional calls were made beyond building the results
      verifyNever(mockDocumentRepository.getDocument(any));
    });

    test('filters work correctly in fallback LIKE search', () async {
      await searchService.initialize();

      // First call fails (FTS), second succeeds (fallback)
      var callCount = 0;
      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((invocation) async {
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

      when(mockDocumentRepository.getDocument('doc-fallback-1', includeTags: false))
          .thenAnswer((_) async => createTestDocument(
                id: 'doc-fallback-1',
                title: 'Fallback result',
                ocrText: 'Fallback OCR',
                isFavorite: true,
              ));

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

      // Verify no N+1 pattern in fallback
      verify(mockDocumentRepository.getDocument('doc-fallback-1', includeTags: false))
          .called(1);
    });
  });
}
