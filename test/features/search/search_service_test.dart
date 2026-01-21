import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  group('SearchException', () {
    test('creates with message only', () {
      const exception = SearchException('Test error');
      expect(exception.message, 'Test error');
      expect(exception.cause, isNull);
    });

    test('creates with message and cause', () {
      final cause = Exception('Original error');
      final exception = SearchException('Test error', cause: cause);
      expect(exception.message, 'Test error');
      expect(exception.cause, cause);
    });

    test('toString without cause', () {
      const exception = SearchException('Test error');
      expect(exception.toString(), 'SearchException: Test error');
    });

    test('toString with cause', () {
      final exception = SearchException(
        'Test error',
        cause: Exception('Original'),
      );
      expect(
        exception.toString(),
        contains('SearchException: Test error'),
      );
      expect(exception.toString(), contains('caused by:'));
    });
  });

  group('SearchSnippet', () {
    test('creates with required fields', () {
      const snippet = SearchSnippet(
        text: 'This is a test snippet',
        field: 'title',
      );
      expect(snippet.text, 'This is a test snippet');
      expect(snippet.field, 'title');
      expect(snippet.highlights, isEmpty);
      expect(snippet.hasHighlights, isFalse);
    });

    test('creates with highlights', () {
      const snippet = SearchSnippet(
        text: 'This is a test',
        field: 'ocr_text',
        highlights: [
          [0, 4],
          [10, 14]
        ],
      );
      expect(snippet.hasHighlights, isTrue);
      expect(snippet.highlights.length, 2);
    });

    test('fieldDisplayName returns correct names', () {
      expect(
        const SearchSnippet(text: '', field: 'title').fieldDisplayName,
        'Title',
      );
      expect(
        const SearchSnippet(text: '', field: 'description').fieldDisplayName,
        'Description',
      );
      expect(
        const SearchSnippet(text: '', field: 'ocr_text').fieldDisplayName,
        'Document Text',
      );
      expect(
        const SearchSnippet(text: '', field: 'unknown').fieldDisplayName,
        'unknown',
      );
    });

    test('copyWith creates new instance with updated values', () {
      const original = SearchSnippet(
        text: 'Original text',
        field: 'title',
        highlights: [
          [0, 5]
        ],
      );

      final updated = original.copyWith(
        text: 'Updated text',
        field: 'description',
      );

      expect(updated.text, 'Updated text');
      expect(updated.field, 'description');
      expect(updated.highlights, original.highlights);
    });

    test('equality works correctly', () {
      const snippet1 = SearchSnippet(
        text: 'Test',
        field: 'title',
        highlights: [
          [0, 4]
        ],
      );
      const snippet2 = SearchSnippet(
        text: 'Test',
        field: 'title',
        highlights: [
          [0, 4]
        ],
      );
      const snippet3 = SearchSnippet(
        text: 'Different',
        field: 'title',
      );

      expect(snippet1, equals(snippet2));
      expect(snippet1, isNot(equals(snippet3)));
    });

    test('hashCode is consistent', () {
      const snippet1 = SearchSnippet(text: 'Test', field: 'title');
      const snippet2 = SearchSnippet(text: 'Test', field: 'title');
      expect(snippet1.hashCode, equals(snippet2.hashCode));
    });

    test('toString returns expected format', () {
      const snippet = SearchSnippet(
        text: 'This is a test',
        field: 'title',
        highlights: [
          [0, 4]
        ],
      );
      final str = snippet.toString();
      expect(str, contains('field: title'));
      expect(str, contains('14 chars'));
      expect(str, contains('highlights: 1'));
    });
  });

  group('SearchResult', () {
    test('creates with required fields', () {
      final document = createTestDocument();
      final result = SearchResult(
        document: document,
        score: -1.5,
      );

      expect(result.document, document);
      expect(result.score, -1.5);
      expect(result.snippets, isEmpty);
      expect(result.matchedFields, isEmpty);
    });

    test('creates with all fields', () {
      final document = createTestDocument();
      const snippet = SearchSnippet(text: 'test', field: 'title');
      final result = SearchResult(
        document: document,
        score: -2.0,
        snippets: [snippet],
        matchedFields: ['title', 'ocr_text'],
      );

      expect(result.snippets.length, 1);
      expect(result.matchedFields.length, 2);
    });

    test('matchedTitle returns true when title matched', () {
      final result = SearchResult(
        document: createTestDocument(),
        score: 0,
        matchedFields: ['title'],
      );
      expect(result.matchedTitle, isTrue);
      expect(result.matchedDescription, isFalse);
      expect(result.matchedOcrText, isFalse);
    });

    test('matchedDescription returns true when description matched', () {
      final result = SearchResult(
        document: createTestDocument(),
        score: 0,
        matchedFields: ['description'],
      );
      expect(result.matchedTitle, isFalse);
      expect(result.matchedDescription, isTrue);
    });

    test('matchedOcrText returns true when ocr_text matched', () {
      final result = SearchResult(
        document: createTestDocument(),
        score: 0,
        matchedFields: ['ocr_text'],
      );
      expect(result.matchedOcrText, isTrue);
    });

    test('preview returns snippet text when available', () {
      const snippet = SearchSnippet(text: 'Snippet content', field: 'title');
      final result = SearchResult(
        document: createTestDocument(),
        score: 0,
        snippets: [snippet],
      );
      expect(result.preview, 'Snippet content');
    });

    test('preview returns description when no snippets', () {
      final result = SearchResult(
        document: createTestDocument(description: 'Document description'),
        score: 0,
      );
      expect(result.preview, 'Document description');
    });

    test('preview returns OCR text when no snippets or description', () {
      final result = SearchResult(
        document: createTestDocument(ocrText: 'OCR extracted text'),
        score: 0,
      );
      expect(result.preview, 'OCR extracted text');
    });

    test('preview truncates long OCR text', () {
      final longText = 'A' * 300;
      final result = SearchResult(
        document: createTestDocument(ocrText: longText),
        score: 0,
      );
      expect(result.preview.length, 203); // 200 chars + '...'
      expect(result.preview.endsWith('...'), isTrue);
    });

    test('preview returns title as fallback', () {
      final result = SearchResult(
        document: createTestDocument(title: 'My Document'),
        score: 0,
      );
      expect(result.preview, 'My Document');
    });

    test('copyWith creates new instance with updated values', () {
      final original = SearchResult(
        document: createTestDocument(id: 'original'),
        score: -1.0,
        matchedFields: ['title'],
      );

      final newDocument = createTestDocument(id: 'updated');
      final updated = original.copyWith(
        document: newDocument,
        score: -2.0,
      );

      expect(updated.document.id, 'updated');
      expect(updated.score, -2.0);
      expect(updated.matchedFields, ['title']);
    });

    test('equality works correctly', () {
      final document = createTestDocument();
      final result1 = SearchResult(document: document, score: -1.0);
      final result2 = SearchResult(document: document, score: -1.0);
      final result3 = SearchResult(document: document, score: -2.0);

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });

    test('hashCode is consistent', () {
      final document = createTestDocument();
      final result1 = SearchResult(document: document, score: -1.0);
      final result2 = SearchResult(document: document, score: -1.0);
      expect(result1.hashCode, equals(result2.hashCode));
    });

    test('toString returns expected format', () {
      final result = SearchResult(
        document: createTestDocument(id: 'test-doc'),
        score: -1.5,
        matchedFields: ['title'],
      );
      final str = result.toString();
      expect(str, contains('document: test-doc'));
      expect(str, contains('-1.500'));
      expect(str, contains('matchedFields: [title]'));
    });
  });

  group('SearchOptions', () {
    test('defaults are correct', () {
      const options = SearchOptions();
      expect(options.field, SearchField.all);
      expect(options.matchMode, SearchMatchMode.prefix);
      expect(options.limit, 50);
      expect(options.offset, 0);
      expect(options.includeSnippets, isTrue);
      expect(options.snippetLength, 150);
      expect(options.includeTags, isFalse);
      expect(options.folderId, isNull);
      expect(options.favoritesOnly, isFalse);
      expect(options.hasOcrOnly, isFalse);
      expect(options.sortBy, SearchSortBy.relevance);
      expect(options.sortDescending, isTrue);
    });

    test('SearchOptions.defaults() creates default options', () {
      const options = SearchOptions.defaults();
      expect(options.field, SearchField.all);
      expect(options.limit, 50);
    });

    test('SearchOptions.suggestions() creates suggestion options', () {
      const options = SearchOptions.suggestions();
      expect(options.limit, 5);
      expect(options.includeSnippets, isFalse);
      expect(options.matchMode, SearchMatchMode.prefix);
    });

    test('SearchOptions.titlesOnly() creates title-only options', () {
      const options = SearchOptions.titlesOnly();
      expect(options.field, SearchField.title);
      expect(options.includeSnippets, isFalse);
    });

    test('SearchOptions.titlesOnly() accepts custom parameters', () {
      const options = SearchOptions.titlesOnly(
        limit: 20,
        includeSnippets: true,
      );
      expect(options.limit, 20);
      expect(options.includeSnippets, isTrue);
    });

    test('SearchOptions.ocrTextOnly() creates OCR options', () {
      const options = SearchOptions.ocrTextOnly();
      expect(options.field, SearchField.ocrText);
      expect(options.matchMode, SearchMatchMode.phrase);
      expect(options.hasOcrOnly, isTrue);
      expect(options.snippetLength, 200);
    });

    test('copyWith creates new instance with updated values', () {
      const original = SearchOptions(
        limit: 50,
        field: SearchField.all,
      );

      final updated = original.copyWith(
        limit: 100,
        field: SearchField.title,
        favoritesOnly: true,
      );

      expect(updated.limit, 100);
      expect(updated.field, SearchField.title);
      expect(updated.favoritesOnly, isTrue);
      expect(updated.matchMode, SearchMatchMode.prefix);
    });

    test('copyWith with clearFolderId clears folder', () {
      const original = SearchOptions(folderId: 'folder-1');
      final updated = original.copyWith(clearFolderId: true);
      expect(updated.folderId, isNull);
    });

    test('equality works correctly', () {
      const options1 = SearchOptions(limit: 20, field: SearchField.title);
      const options2 = SearchOptions(limit: 20, field: SearchField.title);
      const options3 = SearchOptions(limit: 30, field: SearchField.title);

      expect(options1, equals(options2));
      expect(options1, isNot(equals(options3)));
    });

    test('hashCode is consistent', () {
      const options1 = SearchOptions(limit: 20);
      const options2 = SearchOptions(limit: 20);
      expect(options1.hashCode, equals(options2.hashCode));
    });

    test('toString returns expected format', () {
      const options = SearchOptions(
        field: SearchField.ocrText,
        matchMode: SearchMatchMode.phrase,
        limit: 25,
      );
      final str = options.toString();
      expect(str, contains('field: SearchField.ocrText'));
      expect(str, contains('matchMode: SearchMatchMode.phrase'));
      expect(str, contains('limit: 25'));
    });
  });

  group('SearchField enum', () {
    test('has all expected values', () {
      expect(SearchField.values, contains(SearchField.all));
      expect(SearchField.values, contains(SearchField.title));
      expect(SearchField.values, contains(SearchField.description));
      expect(SearchField.values, contains(SearchField.ocrText));
      expect(SearchField.values.length, 4);
    });
  });

  group('SearchMatchMode enum', () {
    test('has all expected values', () {
      expect(SearchMatchMode.values, contains(SearchMatchMode.prefix));
      expect(SearchMatchMode.values, contains(SearchMatchMode.phrase));
      expect(SearchMatchMode.values, contains(SearchMatchMode.allWords));
      expect(SearchMatchMode.values, contains(SearchMatchMode.anyWord));
      expect(SearchMatchMode.values.length, 4);
    });
  });

  group('SearchSortBy enum', () {
    test('has all expected values', () {
      expect(SearchSortBy.values, contains(SearchSortBy.relevance));
      expect(SearchSortBy.values, contains(SearchSortBy.title));
      expect(SearchSortBy.values, contains(SearchSortBy.createdAt));
      expect(SearchSortBy.values, contains(SearchSortBy.updatedAt));
      expect(SearchSortBy.values, contains(SearchSortBy.fileSize));
      expect(SearchSortBy.values.length, 5);
    });
  });

  group('SearchResults', () {
    test('creates with required fields', () {
      final results = SearchResults(
        query: 'test',
        results: [],
        totalCount: 0,
        searchTimeMs: 10,
        options: const SearchOptions(),
      );

      expect(results.query, 'test');
      expect(results.results, isEmpty);
      expect(results.totalCount, 0);
      expect(results.searchTimeMs, 10);
    });

    test('SearchResults.empty() creates empty results', () {
      const results = SearchResults.empty(query: 'test');
      expect(results.query, 'test');
      expect(results.results, isEmpty);
      expect(results.totalCount, 0);
      expect(results.searchTimeMs, 0);
    });

    test('hasResults returns true when results exist', () {
      final document = createTestDocument();
      final results = SearchResults(
        query: 'test',
        results: [SearchResult(document: document, score: -1.0)],
        totalCount: 1,
        searchTimeMs: 10,
        options: const SearchOptions(),
      );
      expect(results.hasResults, isTrue);
    });

    test('hasResults returns false when no results', () {
      const results = SearchResults.empty();
      expect(results.hasResults, isFalse);
    });

    test('hasMore returns true when more results available', () {
      final results = SearchResults(
        query: 'test',
        results: [],
        totalCount: 100,
        searchTimeMs: 10,
        options: const SearchOptions(limit: 50, offset: 0),
      );
      expect(results.hasMore, isTrue);
    });

    test('hasMore returns false when all results returned', () {
      final document = createTestDocument();
      final results = SearchResults(
        query: 'test',
        results: [SearchResult(document: document, score: -1.0)],
        totalCount: 1,
        searchTimeMs: 10,
        options: const SearchOptions(limit: 50, offset: 0),
      );
      expect(results.hasMore, isFalse);
    });

    test('count returns number of results', () {
      final document = createTestDocument();
      final results = SearchResults(
        query: 'test',
        results: [
          SearchResult(document: document, score: -1.0),
          SearchResult(document: document, score: -0.5),
        ],
        totalCount: 2,
        searchTimeMs: 10,
        options: const SearchOptions(),
      );
      expect(results.count, 2);
    });

    test('documents returns list of documents', () {
      final doc1 = createTestDocument(id: 'doc-1');
      final doc2 = createTestDocument(id: 'doc-2');
      final results = SearchResults(
        query: 'test',
        results: [
          SearchResult(document: doc1, score: -1.0),
          SearchResult(document: doc2, score: -0.5),
        ],
        totalCount: 2,
        searchTimeMs: 10,
        options: const SearchOptions(),
      );
      expect(results.documents.length, 2);
      expect(results.documents[0].id, 'doc-1');
      expect(results.documents[1].id, 'doc-2');
    });

    test('copyWith creates new instance with updated values', () {
      const original = SearchResults.empty(query: 'original');
      final updated = original.copyWith(
        query: 'updated',
        totalCount: 10,
      );

      expect(updated.query, 'updated');
      expect(updated.totalCount, 10);
      expect(updated.results, isEmpty);
    });

    test('equality works correctly', () {
      final results1 = SearchResults(
        query: 'test',
        results: [],
        totalCount: 0,
        searchTimeMs: 10,
        options: const SearchOptions(),
      );
      final results2 = SearchResults(
        query: 'test',
        results: [],
        totalCount: 0,
        searchTimeMs: 10,
        options: const SearchOptions(),
      );
      final results3 = SearchResults(
        query: 'different',
        results: [],
        totalCount: 0,
        searchTimeMs: 10,
        options: const SearchOptions(),
      );

      expect(results1, equals(results2));
      expect(results1, isNot(equals(results3)));
    });

    test('hashCode is consistent', () {
      final results1 = SearchResults(
        query: 'test',
        results: [],
        totalCount: 0,
        searchTimeMs: 10,
        options: const SearchOptions(),
      );
      final results2 = SearchResults(
        query: 'test',
        results: [],
        totalCount: 0,
        searchTimeMs: 10,
        options: const SearchOptions(),
      );
      expect(results1.hashCode, equals(results2.hashCode));
    });

    test('toString returns expected format', () {
      final results = SearchResults(
        query: 'test query',
        results: [],
        totalCount: 5,
        searchTimeMs: 25,
        options: const SearchOptions(),
      );
      final str = results.toString();
      expect(str, contains('query: "test query"'));
      expect(str, contains('count: 0'));
      expect(str, contains('total: 5'));
      expect(str, contains('time: 25ms'));
    });
  });

  group('RecentSearch', () {
    test('creates with required fields', () {
      final timestamp = DateTime(2024, 1, 15, 10, 30);
      final recent = RecentSearch(
        query: 'test search',
        timestamp: timestamp,
      );

      expect(recent.query, 'test search');
      expect(recent.timestamp, timestamp);
      expect(recent.resultCount, isNull);
    });

    test('creates with resultCount', () {
      final recent = RecentSearch(
        query: 'test',
        timestamp: DateTime.now(),
        resultCount: 42,
      );
      expect(recent.resultCount, 42);
    });

    test('copyWith creates new instance with updated values', () {
      final original = RecentSearch(
        query: 'original',
        timestamp: DateTime(2024, 1, 1),
      );

      final updated = original.copyWith(
        query: 'updated',
        resultCount: 10,
      );

      expect(updated.query, 'updated');
      expect(updated.resultCount, 10);
      expect(updated.timestamp, original.timestamp);
    });

    test('toMap serializes correctly', () {
      final timestamp = DateTime(2024, 1, 15, 10, 30);
      final recent = RecentSearch(
        query: 'test',
        timestamp: timestamp,
        resultCount: 5,
      );

      final map = recent.toMap();
      expect(map['query'], 'test');
      expect(map['timestamp'], timestamp.toIso8601String());
      expect(map['resultCount'], 5);
    });

    test('toMap omits null resultCount', () {
      final recent = RecentSearch(
        query: 'test',
        timestamp: DateTime.now(),
      );

      final map = recent.toMap();
      expect(map.containsKey('resultCount'), isFalse);
    });

    test('fromMap deserializes correctly', () {
      final map = {
        'query': 'test query',
        'timestamp': '2024-01-15T10:30:00.000',
        'resultCount': 10,
      };

      final recent = RecentSearch.fromMap(map);
      expect(recent.query, 'test query');
      expect(recent.timestamp.year, 2024);
      expect(recent.timestamp.month, 1);
      expect(recent.timestamp.day, 15);
      expect(recent.resultCount, 10);
    });

    test('fromMap handles null resultCount', () {
      final map = {
        'query': 'test',
        'timestamp': '2024-01-15T10:30:00.000',
      };

      final recent = RecentSearch.fromMap(map);
      expect(recent.resultCount, isNull);
    });

    test('equality works correctly', () {
      final timestamp = DateTime(2024, 1, 15);
      final recent1 = RecentSearch(query: 'test', timestamp: timestamp);
      final recent2 = RecentSearch(query: 'test', timestamp: timestamp);
      final recent3 = RecentSearch(query: 'different', timestamp: timestamp);

      expect(recent1, equals(recent2));
      expect(recent1, isNot(equals(recent3)));
    });

    test('hashCode is consistent', () {
      final timestamp = DateTime(2024, 1, 15);
      final recent1 = RecentSearch(query: 'test', timestamp: timestamp);
      final recent2 = RecentSearch(query: 'test', timestamp: timestamp);
      expect(recent1.hashCode, equals(recent2.hashCode));
    });

    test('toString returns expected format', () {
      final recent = RecentSearch(
        query: 'test query',
        timestamp: DateTime(2024, 1, 15),
        resultCount: 5,
      );
      final str = recent.toString();
      expect(str, contains('query: "test query"'));
      expect(str, contains('resultCount: 5'));
    });
  });

  group('SearchService', () {
    test('isReady returns false before initialization', () {
      expect(searchService.isReady, isFalse);
    });

    test('recentSearches is empty initially', () {
      expect(searchService.recentSearches, isEmpty);
    });

    test('initialize returns true on success', () async {
      final result = await searchService.initialize();
      expect(result, isTrue);
      expect(searchService.isReady, isTrue);
    });

    test('initialize is idempotent', () async {
      await searchService.initialize();
      final result = await searchService.initialize();
      expect(result, isTrue);
      verify(mockDatabaseHelper.initialize()).called(1);
    });

    test('initialize throws SearchException on failure', () async {
      when(mockDatabaseHelper.initialize())
          .thenThrow(Exception('Database error'));

      expect(
        () => searchService.initialize(),
        throwsA(isA<SearchException>()),
      );
    });

    test('loads recent searches during initialization', () async {
      // Mock search history data
      when(mockDatabaseHelper.getSearchHistory(limit: anyNamed('limit')))
          .thenAnswer((_) async => [
                {
                  'query': 'invoice 2024',
                  'timestamp': '2024-01-15T10:30:00.000',
                  'resultCount': 5,
                },
                {
                  'query': 'contract',
                  'timestamp': '2024-01-14T14:20:00.000',
                  'resultCount': 3,
                },
              ]);

      await searchService.initialize();

      // Verify recent searches were loaded
      expect(searchService.recentSearches.length, 2);
      expect(searchService.recentSearches[0].query, 'invoice 2024');
      expect(searchService.recentSearches[0].resultCount, 5);
      expect(searchService.recentSearches[1].query, 'contract');
      expect(searchService.recentSearches[1].resultCount, 3);

      // Verify getSearchHistory was called with correct limit
      verify(
        mockDatabaseHelper.getSearchHistory(limit: SearchService.maxRecentSearches),
      ).called(1);
    });

    test('search throws if not initialized', () async {
      expect(
        () => searchService.search('test'),
        throwsA(isA<SearchException>()),
      );
    });

    test('search returns empty results for empty query', () async {
      await searchService.initialize();

      final results = await searchService.search('');
      expect(results.results, isEmpty);
      expect(results.totalCount, 0);
    });

    test('search returns empty results for whitespace query', () async {
      await searchService.initialize();

      final results = await searchService.search('   ');
      expect(results.results, isEmpty);
    });

    test('search executes FTS query', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => [
            {
              'id': 'doc-1',
              'title': 'Test Document',
              'description': 'Description',
              'ocr_text': 'OCR text',
              'score': -1.5,
            },
          ]);

      when(mockDocumentRepository.getDocument('doc-1', includeTags: false))
          .thenAnswer((_) async => createTestDocument(
                id: 'doc-1',
                title: 'Test Document',
              ));

      final results = await searchService.search('test');

      expect(results.hasResults, isTrue);
      expect(results.results.length, 1);
      expect(results.results.first.document.id, 'doc-1');
    });

    test('search adds to recent searches', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => []);

      await searchService.search('my query');

      expect(searchService.recentSearches.length, 1);
      expect(searchService.recentSearches.first.query, 'my query');
    });

    test('persistRecentSearches to database after search', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => []);
      when(mockDatabaseHelper.clearSearchHistory()).thenAnswer((_) async => 0);
      when(mockDatabaseHelper.insertSearchHistory(
        query: anyNamed('query'),
        timestamp: anyNamed('timestamp'),
        resultCount: anyNamed('resultCount'),
      )).thenAnswer((_) async => 1);

      await searchService.search('test query');

      // Wait a bit for async persistence to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify database methods were called
      verify(mockDatabaseHelper.clearSearchHistory()).called(1);
      verify(mockDatabaseHelper.insertSearchHistory(
        query: 'test query',
        timestamp: anyNamed('timestamp'),
        resultCount: 0,
      )).called(1);
    });

    test('search deduplicates recent searches', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => []);

      await searchService.search('query1');
      await searchService.search('query2');
      await searchService.search('query1'); // Duplicate

      expect(searchService.recentSearches.length, 2);
      expect(searchService.recentSearches.first.query, 'query1');
    });

    test('search trims recent searches to max', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => []);

      // Add more than maxRecentSearches
      for (var i = 0; i < 25; i++) {
        await searchService.search('query$i');
      }

      expect(
        searchService.recentSearches.length,
        SearchService.maxRecentSearches,
      );
    });

    test('search with phrase mode wraps query in quotes', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => []);

      await searchService.search(
        'important document',
        options: const SearchOptions(matchMode: SearchMatchMode.phrase),
      );

      verify(
        mockDatabaseHelper.rawQuery(
          any,
          argThat(contains('"important document"')),
        ),
      ).called(1);
    });

    test('search with prefix mode adds asterisks', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => []);

      await searchService.search(
        'test query',
        options: const SearchOptions(matchMode: SearchMatchMode.prefix),
      );

      verify(
        mockDatabaseHelper.rawQuery(
          any,
          argThat(contains('test* query*')),
        ),
      ).called(1);
    });

    test('search with anyWord mode uses OR', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => []);

      await searchService.search(
        'word1 word2',
        options: const SearchOptions(matchMode: SearchMatchMode.anyWord),
      );

      verify(
        mockDatabaseHelper.rawQuery(
          any,
          argThat(contains('word1 OR word2')),
        ),
      ).called(1);
    });

    test('search with title field adds column prefix', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => []);

      await searchService.search(
        'test',
        options: const SearchOptions(field: SearchField.title),
      );

      verify(
        mockDatabaseHelper.rawQuery(
          any,
          argThat(contains('title:')),
        ),
      ).called(1);
    });

    test('search falls back to LIKE on FTS failure', () async {
      await searchService.initialize();

      // First call fails (FTS)
      var callCount = 0;
      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw Exception('FTS error');
        }
        return [];
      });

      final results = await searchService.search('test');

      expect(results.results, isEmpty);
      verify(mockDatabaseHelper.rawQuery(any, any)).called(2);
    });

    test('search filters by favorites', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => [
            {
              'id': 'doc-1',
              'title': 'Test',
              'description': null,
              'ocr_text': null,
              'score': -1.0,
            },
          ]);

      when(mockDocumentRepository.getDocument('doc-1'))
          .thenAnswer((_) async => createTestDocument(
                id: 'doc-1',
                isFavorite: false,
              ));

      final results = await searchService.search(
        'test',
        options: const SearchOptions(favoritesOnly: true),
      );

      expect(results.results, isEmpty);
    });

    test('search filters by hasOcrOnly', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => [
            {
              'id': 'doc-1',
              'title': 'Test',
              'description': null,
              'ocr_text': null,
              'score': -1.0,
            },
          ]);

      when(mockDocumentRepository.getDocument('doc-1'))
          .thenAnswer((_) async => createTestDocument(
                id: 'doc-1',
                ocrText: null,
              ));

      final results = await searchService.search(
        'test',
        options: const SearchOptions(hasOcrOnly: true),
      );

      expect(results.results, isEmpty);
    });

    test('search filters by folderId', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => [
            {
              'id': 'doc-1',
              'title': 'Test',
              'description': null,
              'ocr_text': null,
              'score': -1.0,
            },
          ]);

      when(mockDocumentRepository.getDocument('doc-1'))
          .thenAnswer((_) async => createTestDocument(
                id: 'doc-1',
                folderId: 'folder-1',
              ));

      final results = await searchService.search(
        'test',
        options: const SearchOptions(folderId: 'folder-2'),
      );

      expect(results.results, isEmpty);
    });

    test('getSuggestions throws if not initialized', () async {
      expect(
        () => searchService.getSuggestions('test'),
        throwsA(isA<SearchException>()),
      );
    });

    test('getSuggestions returns recent searches for empty query', () async {
      await searchService.initialize();
      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => []);

      await searchService.search('query1');
      await searchService.search('query2');

      final suggestions = await searchService.getSuggestions('');

      expect(suggestions.isNotEmpty, isTrue);
      expect(suggestions, contains('query2'));
    });

    test('getSuggestions returns matching recent searches', () async {
      await searchService.initialize();
      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => []);

      await searchService.search('invoice 2024');
      await searchService.search('contract agreement');
      await searchService.search('invoice summary');

      final suggestions = await searchService.getSuggestions('inv');

      expect(suggestions.contains('invoice 2024'), isTrue);
      expect(suggestions.contains('invoice summary'), isTrue);
      expect(suggestions.contains('contract agreement'), isFalse);
    });

    test('getRecentSearches returns empty list initially', () async {
      final recent = await searchService.getRecentSearches();
      expect(recent, isEmpty);
    });

    test('getRecentSearches respects limit', () async {
      await searchService.initialize();
      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => []);

      for (var i = 0; i < 10; i++) {
        await searchService.search('query$i');
      }

      final recent = await searchService.getRecentSearches(limit: 3);
      expect(recent.length, 3);
    });

    test('clearRecentSearches removes all entries', () async {
      await searchService.initialize();
      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => []);
      when(mockDatabaseHelper.clearSearchHistory()).thenAnswer((_) async => 0);
      when(mockDatabaseHelper.insertSearchHistory(
        query: anyNamed('query'),
        timestamp: anyNamed('timestamp'),
        resultCount: anyNamed('resultCount'),
      )).thenAnswer((_) async => 1);

      await searchService.search('query1');
      await searchService.search('query2');

      await searchService.clearRecentSearches();

      expect(searchService.recentSearches, isEmpty);
    });

    test('clearRecentSearches persists to database', () async {
      await searchService.initialize();
      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => []);
      when(mockDatabaseHelper.clearSearchHistory()).thenAnswer((_) async => 0);
      when(mockDatabaseHelper.insertSearchHistory(
        query: anyNamed('query'),
        timestamp: anyNamed('timestamp'),
        resultCount: anyNamed('resultCount'),
      )).thenAnswer((_) async => 1);

      await searchService.search('query1');
      await searchService.search('query2');

      await searchService.clearRecentSearches();

      // Verify database method was called at least 3 times
      // (once per search for persistence, once for clearRecentSearches)
      verify(mockDatabaseHelper.clearSearchHistory()).called(3);
      expect(searchService.recentSearches, isEmpty);
    });

    test('removeRecentSearch removes specific entry', () async {
      await searchService.initialize();
      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => []);

      await searchService.search('query1');
      await searchService.search('query2');
      await searchService.search('query3');

      await searchService.removeRecentSearch('query2');

      expect(searchService.recentSearches.length, 2);
      expect(
        searchService.recentSearches.any((s) => s.query == 'query2'),
        isFalse,
      );
    });

    test('removeRecentSearch is case insensitive', () async {
      await searchService.initialize();
      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => []);

      await searchService.search('MyQuery');

      await searchService.removeRecentSearch('MYQUERY');

      expect(searchService.recentSearches, isEmpty);
    });

    test('rebuildIndex throws if not initialized', () async {
      expect(
        () => searchService.rebuildIndex(),
        throwsA(isA<SearchException>()),
      );
    });

    test('rebuildIndex calls database rebuild', () async {
      await searchService.initialize();
      when(mockDatabaseHelper.rebuildFtsIndex()).thenAnswer((_) async {});

      await searchService.rebuildIndex();

      verify(mockDatabaseHelper.rebuildFtsIndex()).called(1);
    });

    test('rebuildIndex throws SearchException on failure', () async {
      await searchService.initialize();
      when(mockDatabaseHelper.rebuildFtsIndex())
          .thenThrow(Exception('Rebuild failed'));

      expect(
        () => searchService.rebuildIndex(),
        throwsA(isA<SearchException>()),
      );
    });

    test('getIndexSize returns 0', () async {
      final size = await searchService.getIndexSize();
      expect(size, 0);
    });
  });

  group('SearchService sorting', () {
    test('sorts by relevance by default', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => [
            {
              'id': 'doc-1',
              'title': 'Test 1',
              'description': null,
              'ocr_text': null,
              'score': -2.0,
            },
            {
              'id': 'doc-2',
              'title': 'Test 2',
              'description': null,
              'ocr_text': null,
              'score': -1.0,
            },
          ]);

      when(mockDocumentRepository.getDocument('doc-1', includeTags: false))
          .thenAnswer((_) async => createTestDocument(id: 'doc-1'));
      when(mockDocumentRepository.getDocument('doc-2', includeTags: false))
          .thenAnswer((_) async => createTestDocument(id: 'doc-2'));

      final results = await searchService.search('test');

      // More negative score = better match, should be first
      expect(results.results[0].score, lessThan(results.results[1].score));
    });

    test('sorts by title when specified', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => [
            {
              'id': 'doc-1',
              'title': 'Zebra',
              'description': null,
              'ocr_text': null,
              'score': -1.0,
            },
            {
              'id': 'doc-2',
              'title': 'Apple',
              'description': null,
              'ocr_text': null,
              'score': -2.0,
            },
          ]);

      when(mockDocumentRepository.getDocument('doc-1', includeTags: false))
          .thenAnswer(
              (_) async => createTestDocument(id: 'doc-1', title: 'Zebra'));
      when(mockDocumentRepository.getDocument('doc-2', includeTags: false))
          .thenAnswer(
              (_) async => createTestDocument(id: 'doc-2', title: 'Apple'));

      final results = await searchService.search(
        'test',
        options: const SearchOptions(
          sortBy: SearchSortBy.title,
          sortDescending: false,
        ),
      );

      expect(results.results[0].document.title, 'Apple');
      expect(results.results[1].document.title, 'Zebra');
    });

    test('sorts descending when specified', () async {
      await searchService.initialize();

      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => [
            {
              'id': 'doc-1',
              'title': 'Small',
              'description': null,
              'ocr_text': null,
              'score': -1.0,
            },
            {
              'id': 'doc-2',
              'title': 'Large',
              'description': null,
              'ocr_text': null,
              'score': -1.0,
            },
          ]);

      when(mockDocumentRepository.getDocument('doc-1', includeTags: false))
          .thenAnswer(
              (_) async => createTestDocument(id: 'doc-1', fileSize: 100));
      when(mockDocumentRepository.getDocument('doc-2', includeTags: false))
          .thenAnswer(
              (_) async => createTestDocument(id: 'doc-2', fileSize: 1000));

      final results = await searchService.search(
        'test',
        options: const SearchOptions(
          sortBy: SearchSortBy.fileSize,
          sortDescending: true,
        ),
      );

      expect(results.results[0].document.fileSize, 1000);
      expect(results.results[1].document.fileSize, 100);
    });
  });

  group('Riverpod provider', () {
    test('searchServiceProvider creates SearchService', () {
      final container = ProviderContainer(
        overrides: [
          databaseHelperProvider.overrideWithValue(mockDatabaseHelper),
          documentRepositoryProvider.overrideWithValue(mockDocumentRepository),
        ],
      );

      addTearDown(container.dispose);

      final service = container.read(searchServiceProvider);
      expect(service, isA<SearchService>());
    });
  });

  group('Integration tests', () {
    test('full search workflow', () async {
      await searchService.initialize();

      // Setup mock responses
      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => [
            {
              'id': 'doc-1',
              'title': 'Invoice 2024',
              'description': 'Annual invoice',
              'ocr_text': 'Total: \$500',
              'score': -2.5,
            },
          ]);

      when(mockDocumentRepository.getDocument('doc-1', includeTags: false))
          .thenAnswer((_) async => createTestDocument(
                id: 'doc-1',
                title: 'Invoice 2024',
                description: 'Annual invoice',
                ocrText: 'Total: \$500',
              ));

      // Perform search
      final results = await searchService.search(
        'invoice',
        options: const SearchOptions(
          includeSnippets: true,
          snippetLength: 100,
        ),
      );

      // Verify results
      expect(results.hasResults, isTrue);
      expect(results.query, 'invoice');
      expect(results.results.first.document.title, 'Invoice 2024');
      expect(results.results.first.matchedTitle, isTrue);

      // Verify snippets generated
      expect(results.results.first.snippets.isNotEmpty, isTrue);

      // Verify recent search added
      expect(searchService.recentSearches.length, 1);
      expect(searchService.recentSearches.first.query, 'invoice');
    });

    test('pagination works correctly', () async {
      await searchService.initialize();

      // Create 5 mock results
      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => [
            for (var i = 1; i <= 5; i++)
              {
                'id': 'doc-$i',
                'title': 'Document $i',
                'description': null,
                'ocr_text': null,
                'score': -1.0 * i,
              },
          ]);

      for (var i = 1; i <= 5; i++) {
        when(mockDocumentRepository.getDocument('doc-$i', includeTags: false))
            .thenAnswer((_) async => createTestDocument(id: 'doc-$i'));
      }

      // Get first page
      final page1 = await searchService.search(
        'test',
        options: const SearchOptions(limit: 2, offset: 0),
      );

      expect(page1.results.length, 2);
      expect(page1.totalCount, 5);
      expect(page1.hasMore, isTrue);

      // Get second page
      final page2 = await searchService.search(
        'test',
        options: const SearchOptions(limit: 2, offset: 2),
      );

      expect(page2.results.length, 2);
      expect(page2.hasMore, isTrue);

      // Get last page
      final page3 = await searchService.search(
        'test',
        options: const SearchOptions(limit: 2, offset: 4),
      );

      expect(page3.results.length, 1);
      expect(page3.hasMore, isFalse);
    });

    test('empty results handling', () async {
      await searchService.initialize();
      when(mockDatabaseHelper.rawQuery(any, any)).thenAnswer((_) async => []);

      final results = await searchService.search('nonexistent');

      expect(results.hasResults, isFalse);
      expect(results.totalCount, 0);
      expect(results.searchTimeMs, greaterThanOrEqualTo(0));
    });
  });
}
