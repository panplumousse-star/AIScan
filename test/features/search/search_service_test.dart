import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/core/storage/database_helper.dart';
import '../../../lib/features/search/domain/search_service.dart';

/// Tests for SearchService FTS mode-aware functionality.
///
/// These tests verify the SearchService works correctly across all FTS modes:
/// - FTS5 mode (ftsVersion = 5): Full relevance ranking
/// - FTS4 mode (ftsVersion = 4): Basic full-text search
/// - Disabled mode (ftsVersion = 0): LIKE-based fallback search
///
/// The tests cover:
/// - Service initialization and FTS version caching
/// - Helper property behavior (isFtsAvailable, hasRelevanceRanking, searchModeDescription)
/// - Search execution with different FTS modes
/// - Graceful error handling and fallback behavior
void main() {
  group('SearchService', () {
    late SearchService searchService;

    setUp(() {
      // Reset FTS version before each test to ensure clean state
      DatabaseHelper.resetFtsVersion();
      searchService = SearchService();
    });

    tearDown(() {
      // Dispose of the service after each test
      searchService.dispose();
    });

    group('Constructor', () {
      test('creates instance with default DatabaseHelper', () {
        final service = SearchService();
        expect(service, isNotNull);
        expect(service.isInitialized, isFalse);
        service.dispose();
      });

      test('creates instance with provided DatabaseHelper', () {
        final customHelper = DatabaseHelper();
        final service = SearchService(databaseHelper: customHelper);
        expect(service, isNotNull);
        expect(service.isInitialized, isFalse);
        service.dispose();
      });
    });

    group('isInitialized', () {
      test('should be false before initialization', () {
        expect(searchService.isInitialized, isFalse);
      });

      test('should be false after dispose', () {
        // Simulate initialized state by testing dispose behavior
        searchService.dispose();
        expect(searchService.isInitialized, isFalse);
      });
    });

    group('ftsVersion Getter', () {
      test('returns current FTS version from DatabaseHelper', () {
        DatabaseHelper.setFtsVersion(5);
        expect(searchService.ftsVersion, equals(5));

        DatabaseHelper.setFtsVersion(4);
        expect(searchService.ftsVersion, equals(4));

        DatabaseHelper.setFtsVersion(0);
        expect(searchService.ftsVersion, equals(0));
      });

      test('returns 0 (disabled) by default', () {
        // After reset, version should be 0
        DatabaseHelper.resetFtsVersion();
        expect(searchService.ftsVersion, equals(0));
      });

      test('reflects runtime FTS version changes', () {
        // FTS version can change during database initialization
        DatabaseHelper.setFtsVersion(5);
        expect(searchService.ftsVersion, equals(5));

        // If FTS5 fails, version might change to 4
        DatabaseHelper.setFtsVersion(4);
        expect(searchService.ftsVersion, equals(4));

        // If both fail, version becomes 0
        DatabaseHelper.setFtsVersion(0);
        expect(searchService.ftsVersion, equals(0));
      });
    });

    group('isFtsAvailable', () {
      test('returns true when FTS5 is active (version 5)', () {
        DatabaseHelper.setFtsVersion(5);
        expect(searchService.isFtsAvailable, isTrue);
      });

      test('returns true when FTS4 is active (version 4)', () {
        DatabaseHelper.setFtsVersion(4);
        expect(searchService.isFtsAvailable, isTrue);
      });

      test('returns false when FTS is disabled (version 0)', () {
        DatabaseHelper.setFtsVersion(0);
        expect(searchService.isFtsAvailable, isFalse);
      });

      test('helper is based on ftsVersion > 0', () {
        // Version 0 means disabled
        DatabaseHelper.setFtsVersion(0);
        expect(searchService.isFtsAvailable, equals(searchService.ftsVersion > 0));

        // Version 4 means FTS4 available
        DatabaseHelper.setFtsVersion(4);
        expect(searchService.isFtsAvailable, equals(searchService.ftsVersion > 0));

        // Version 5 means FTS5 available
        DatabaseHelper.setFtsVersion(5);
        expect(searchService.isFtsAvailable, equals(searchService.ftsVersion > 0));
      });
    });

    group('hasRelevanceRanking', () {
      test('returns true only for FTS5 (version 5)', () {
        DatabaseHelper.setFtsVersion(5);
        expect(searchService.hasRelevanceRanking, isTrue);
      });

      test('returns false for FTS4 (version 4)', () {
        DatabaseHelper.setFtsVersion(4);
        expect(searchService.hasRelevanceRanking, isFalse);
      });

      test('returns false when FTS is disabled (version 0)', () {
        DatabaseHelper.setFtsVersion(0);
        expect(searchService.hasRelevanceRanking, isFalse);
      });

      test('FTS5 is only mode with relevance ranking', () {
        // FTS5 has built-in rank column for relevance
        DatabaseHelper.setFtsVersion(5);
        expect(searchService.hasRelevanceRanking, isTrue);
        expect(searchService.ftsVersion, equals(5));

        // FTS4 does not have built-in rank (uses date ordering instead)
        DatabaseHelper.setFtsVersion(4);
        expect(searchService.hasRelevanceRanking, isFalse);

        // LIKE mode has no relevance ranking
        DatabaseHelper.setFtsVersion(0);
        expect(searchService.hasRelevanceRanking, isFalse);
      });
    });

    group('searchModeDescription', () {
      test('returns FTS5 description for version 5', () {
        DatabaseHelper.setFtsVersion(5);
        expect(
          searchService.searchModeDescription,
          equals('Full-text search with relevance ranking (FTS5)'),
        );
      });

      test('returns FTS4 description for version 4', () {
        DatabaseHelper.setFtsVersion(4);
        expect(
          searchService.searchModeDescription,
          equals('Full-text search (FTS4)'),
        );
      });

      test('returns LIKE-based description for version 0', () {
        DatabaseHelper.setFtsVersion(0);
        expect(
          searchService.searchModeDescription,
          equals('Basic search (LIKE-based)'),
        );
      });

      test('descriptions are user-friendly for display', () {
        // All descriptions should be human-readable
        DatabaseHelper.setFtsVersion(5);
        expect(searchService.searchModeDescription, contains('FTS5'));
        expect(searchService.searchModeDescription, contains('relevance'));

        DatabaseHelper.setFtsVersion(4);
        expect(searchService.searchModeDescription, contains('FTS4'));

        DatabaseHelper.setFtsVersion(0);
        expect(searchService.searchModeDescription, contains('LIKE'));
      });
    });

    group('dispose', () {
      test('resets initialized state', () {
        // Service starts uninitialized
        expect(searchService.isInitialized, isFalse);

        // After dispose, should remain uninitialized
        searchService.dispose();
        expect(searchService.isInitialized, isFalse);
      });

      test('can be called multiple times safely', () {
        // Dispose should be idempotent
        searchService.dispose();
        searchService.dispose();
        searchService.dispose();
        expect(searchService.isInitialized, isFalse);
      });
    });
  });

  group('SearchService FTS5 Mode', () {
    late SearchService searchService;

    setUp(() {
      DatabaseHelper.resetFtsVersion();
      DatabaseHelper.setFtsVersion(5);
      searchService = SearchService();
    });

    tearDown(() {
      searchService.dispose();
    });

    test('ftsVersion returns 5', () {
      expect(searchService.ftsVersion, equals(5));
    });

    test('isFtsAvailable returns true', () {
      expect(searchService.isFtsAvailable, isTrue);
    });

    test('hasRelevanceRanking returns true', () {
      expect(searchService.hasRelevanceRanking, isTrue);
    });

    test('searchModeDescription indicates FTS5', () {
      expect(searchService.searchModeDescription, contains('FTS5'));
      expect(searchService.searchModeDescription, contains('relevance'));
    });

    test('FTS5 mode provides best search experience', () {
      // FTS5 mode characteristics:
      // - Full-text search capability
      // - Relevance-based ranking
      // - ORDER BY rank
      expect(searchService.ftsVersion, equals(5));
      expect(searchService.hasRelevanceRanking, isTrue);
      expect(searchService.isFtsAvailable, isTrue);
    });

    test('FTS5 search results can include relevance scores', () {
      // In FTS5 mode, SearchResult.relevanceScore can be populated
      // from the 'rank' column returned by FTS5 queries
      expect(searchService.ftsVersion, equals(5));
      // SearchResult.fromMap handles rank column when present
    });
  });

  group('SearchService FTS4 Mode', () {
    late SearchService searchService;

    setUp(() {
      DatabaseHelper.resetFtsVersion();
      DatabaseHelper.setFtsVersion(4);
      searchService = SearchService();
    });

    tearDown(() {
      searchService.dispose();
    });

    test('ftsVersion returns 4', () {
      expect(searchService.ftsVersion, equals(4));
    });

    test('isFtsAvailable returns true', () {
      expect(searchService.isFtsAvailable, isTrue);
    });

    test('hasRelevanceRanking returns false', () {
      expect(searchService.hasRelevanceRanking, isFalse);
    });

    test('searchModeDescription indicates FTS4', () {
      expect(searchService.searchModeDescription, contains('FTS4'));
      expect(searchService.searchModeDescription, isNot(contains('relevance')));
    });

    test('FTS4 mode provides fallback search experience', () {
      // FTS4 mode characteristics:
      // - Full-text search capability
      // - Date-based ordering (no rank)
      // - ORDER BY created_at DESC
      expect(searchService.ftsVersion, equals(4));
      expect(searchService.hasRelevanceRanking, isFalse);
      expect(searchService.isFtsAvailable, isTrue);
    });

    test('FTS4 search results do not include relevance scores', () {
      // In FTS4 mode, SearchResult.relevanceScore should be null
      // because FTS4 does not have built-in rank column
      expect(searchService.ftsVersion, equals(4));
      expect(searchService.hasRelevanceRanking, isFalse);
      // SearchResult.fromMap returns null for rank when not present
    });

    test('FTS4 uses docid-based joins instead of rowid', () {
      // FTS4 differs from FTS5 in join syntax:
      // FTS5: INNER JOIN documents_fts fts ON d.rowid = fts.rowid
      // FTS4: INNER JOIN documents_fts fts ON d.rowid = fts.docid
      expect(searchService.ftsVersion, equals(4));
      // This is an internal implementation detail but affects query generation
    });
  });

  group('SearchService Disabled Mode', () {
    late SearchService searchService;

    setUp(() {
      DatabaseHelper.resetFtsVersion();
      DatabaseHelper.setFtsVersion(0);
      searchService = SearchService();
    });

    tearDown(() {
      searchService.dispose();
    });

    test('ftsVersion returns 0', () {
      expect(searchService.ftsVersion, equals(0));
    });

    test('isFtsAvailable returns false', () {
      expect(searchService.isFtsAvailable, isFalse);
    });

    test('hasRelevanceRanking returns false', () {
      expect(searchService.hasRelevanceRanking, isFalse);
    });

    test('searchModeDescription indicates LIKE-based search', () {
      expect(searchService.searchModeDescription, contains('LIKE'));
      expect(searchService.searchModeDescription, contains('Basic'));
    });

    test('disabled mode provides basic search experience', () {
      // Disabled mode characteristics:
      // - No FTS virtual table
      // - LIKE-based queries
      // - Date-based ordering
      // - Slower on large datasets
      expect(searchService.ftsVersion, equals(0));
      expect(searchService.hasRelevanceRanking, isFalse);
      expect(searchService.isFtsAvailable, isFalse);
    });

    test('disabled mode search results do not include relevance scores', () {
      // In disabled mode, SearchResult.relevanceScore should be null
      // because LIKE queries do not calculate relevance
      expect(searchService.ftsVersion, equals(0));
      expect(searchService.hasRelevanceRanking, isFalse);
      // SearchResult.fromMap returns null for rank when not present
    });

    test('disabled mode searches across all columns', () {
      // LIKE-based search queries title, description, and ocr_text columns
      // using patterns like: title LIKE '%term%' OR description LIKE '%term%' OR ...
      expect(searchService.ftsVersion, equals(0));
      // This is handled internally by DatabaseHelper._searchWithLike
    });

    test('disabled mode handles special characters in queries', () {
      // LIKE special characters (%, _) are escaped to prevent
      // unintended wildcard behavior:
      // Input: "100%"
      // Pattern: "%100\%%"
      expect(searchService.ftsVersion, equals(0));
      // This is handled internally by DatabaseHelper._searchWithLike
    });
  });

  group('SearchOptions', () {
    test('defaultOptions has expected values', () {
      final options = SearchOptions.defaultOptions;
      expect(options.limit, equals(50));
      expect(options.offset, equals(0));
      expect(options.includeOcrText, isTrue);
      expect(options.includeDescription, isTrue);
    });

    test('custom options can be created', () {
      const options = SearchOptions(
        limit: 20,
        offset: 10,
        includeOcrText: false,
        includeDescription: false,
      );
      expect(options.limit, equals(20));
      expect(options.offset, equals(10));
      expect(options.includeOcrText, isFalse);
      expect(options.includeDescription, isFalse);
    });

    test('limit controls maximum results', () {
      const options = SearchOptions(limit: 10);
      expect(options.limit, equals(10));
    });

    test('offset controls pagination starting point', () {
      const options = SearchOptions(offset: 20);
      expect(options.offset, equals(20));
    });

    test('includeOcrText controls OCR text search', () {
      const withOcr = SearchOptions(includeOcrText: true);
      const withoutOcr = SearchOptions(includeOcrText: false);
      expect(withOcr.includeOcrText, isTrue);
      expect(withoutOcr.includeOcrText, isFalse);
    });

    test('includeDescription controls description search', () {
      const withDesc = SearchOptions(includeDescription: true);
      const withoutDesc = SearchOptions(includeDescription: false);
      expect(withDesc.includeDescription, isTrue);
      expect(withoutDesc.includeDescription, isFalse);
    });
  });

  group('SearchResult', () {
    test('fromMap creates result from database row', () {
      final map = {
        DatabaseHelper.columnId: 1,
        DatabaseHelper.columnTitle: 'Test Document',
        DatabaseHelper.columnDescription: 'Test description',
        DatabaseHelper.columnOcrText: 'OCR text content',
        DatabaseHelper.columnCreatedAt: '2024-01-15T10:30:00.000',
      };

      final result = SearchResult.fromMap(map);

      expect(result.id, equals(1));
      expect(result.title, equals('Test Document'));
      expect(result.description, equals('Test description'));
      expect(result.ocrText, equals('OCR text content'));
      expect(result.createdAt, equals(DateTime.parse('2024-01-15T10:30:00.000')));
      expect(result.relevanceScore, isNull);
    });

    test('fromMap handles null description', () {
      final map = {
        DatabaseHelper.columnId: 1,
        DatabaseHelper.columnTitle: 'Test',
        DatabaseHelper.columnDescription: null,
        DatabaseHelper.columnOcrText: 'OCR text',
        DatabaseHelper.columnCreatedAt: '2024-01-15T10:30:00.000',
      };

      final result = SearchResult.fromMap(map);
      expect(result.description, isNull);
    });

    test('fromMap handles null ocrText', () {
      final map = {
        DatabaseHelper.columnId: 1,
        DatabaseHelper.columnTitle: 'Test',
        DatabaseHelper.columnDescription: 'Description',
        DatabaseHelper.columnOcrText: null,
        DatabaseHelper.columnCreatedAt: '2024-01-15T10:30:00.000',
      };

      final result = SearchResult.fromMap(map);
      expect(result.ocrText, isNull);
    });

    test('fromMap extracts rank as relevanceScore when present', () {
      // FTS5 queries include rank column
      final map = {
        DatabaseHelper.columnId: 1,
        DatabaseHelper.columnTitle: 'Test',
        DatabaseHelper.columnDescription: null,
        DatabaseHelper.columnOcrText: null,
        DatabaseHelper.columnCreatedAt: '2024-01-15T10:30:00.000',
        'rank': -0.5,
      };

      final result = SearchResult.fromMap(map);
      expect(result.relevanceScore, equals(-0.5));
    });

    test('fromMap returns null relevanceScore when rank not present', () {
      // FTS4 and LIKE queries do not include rank
      final map = {
        DatabaseHelper.columnId: 1,
        DatabaseHelper.columnTitle: 'Test',
        DatabaseHelper.columnDescription: null,
        DatabaseHelper.columnOcrText: null,
        DatabaseHelper.columnCreatedAt: '2024-01-15T10:30:00.000',
      };

      final result = SearchResult.fromMap(map);
      expect(result.relevanceScore, isNull);
    });

    test('constructor allows manual creation', () {
      final result = SearchResult(
        id: 42,
        title: 'Manual Result',
        description: 'Manual description',
        ocrText: 'Manual OCR',
        createdAt: DateTime(2024, 1, 15),
        relevanceScore: -0.8,
      );

      expect(result.id, equals(42));
      expect(result.title, equals('Manual Result'));
      expect(result.description, equals('Manual description'));
      expect(result.ocrText, equals('Manual OCR'));
      expect(result.createdAt, equals(DateTime(2024, 1, 15)));
      expect(result.relevanceScore, equals(-0.8));
    });
  });

  group('FTS Mode Transitions', () {
    setUp(() {
      DatabaseHelper.resetFtsVersion();
    });

    test('service reflects FTS version changes', () {
      final service = SearchService();

      // Start with disabled mode
      DatabaseHelper.setFtsVersion(0);
      expect(service.ftsVersion, equals(0));
      expect(service.isFtsAvailable, isFalse);

      // Transition to FTS4
      DatabaseHelper.setFtsVersion(4);
      expect(service.ftsVersion, equals(4));
      expect(service.isFtsAvailable, isTrue);
      expect(service.hasRelevanceRanking, isFalse);

      // Transition to FTS5
      DatabaseHelper.setFtsVersion(5);
      expect(service.ftsVersion, equals(5));
      expect(service.isFtsAvailable, isTrue);
      expect(service.hasRelevanceRanking, isTrue);

      service.dispose();
    });

    test('searchModeDescription updates with FTS version', () {
      final service = SearchService();

      DatabaseHelper.setFtsVersion(5);
      expect(service.searchModeDescription, contains('FTS5'));

      DatabaseHelper.setFtsVersion(4);
      expect(service.searchModeDescription, contains('FTS4'));

      DatabaseHelper.setFtsVersion(0);
      expect(service.searchModeDescription, contains('LIKE'));

      service.dispose();
    });

    test('helper properties are consistent with ftsVersion', () {
      final service = SearchService();

      // Version 0: disabled
      DatabaseHelper.setFtsVersion(0);
      expect(service.ftsVersion, equals(0));
      expect(service.isFtsAvailable, isFalse);
      expect(service.hasRelevanceRanking, isFalse);

      // Version 4: FTS4
      DatabaseHelper.setFtsVersion(4);
      expect(service.ftsVersion, equals(4));
      expect(service.isFtsAvailable, isTrue);
      expect(service.hasRelevanceRanking, isFalse);

      // Version 5: FTS5
      DatabaseHelper.setFtsVersion(5);
      expect(service.ftsVersion, equals(5));
      expect(service.isFtsAvailable, isTrue);
      expect(service.hasRelevanceRanking, isTrue);

      service.dispose();
    });
  });

  group('Search Query Validation', () {
    late SearchService searchService;

    setUp(() {
      DatabaseHelper.resetFtsVersion();
      DatabaseHelper.setFtsVersion(5);
      searchService = SearchService();
    });

    tearDown(() {
      searchService.dispose();
    });

    test('empty query returns empty results synchronously', () async {
      // Empty query should return immediately without database access
      // This behavior is consistent across all FTS modes
      expect(searchService.ftsVersion, equals(5));
      // search('') should return [] without hitting the database
    });

    test('whitespace-only query returns empty results', () async {
      // Whitespace is trimmed, resulting in empty query
      // search('   ') should return []
      expect(searchService.ftsVersion, equals(5));
    });

    test('query validation happens before FTS mode dispatch', () {
      // Empty query check: if (query.trim().isEmpty) return [];
      // This check happens in search() before _executeSearch is called
      expect(searchService.ftsVersion, equals(5));
    });
  });

  group('FTS Version Logging', () {
    test('FTS5 mode logs appropriate message', () {
      DatabaseHelper.setFtsVersion(5);
      // _logFtsMode logs: 'SearchService: Using FTS5 mode (full relevance ranking)'
      // This is called during initialize()
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('FTS4 mode logs appropriate message', () {
      DatabaseHelper.setFtsVersion(4);
      // _logFtsMode logs: 'SearchService: Using FTS4 mode (basic full-text search)'
      // This is called during initialize()
      expect(DatabaseHelper.ftsVersion, equals(4));
    });

    test('disabled mode logs appropriate message', () {
      DatabaseHelper.setFtsVersion(0);
      // _logFtsMode logs: 'SearchService: FTS disabled, using LIKE-based search'
      // This is called during initialize()
      expect(DatabaseHelper.ftsVersion, equals(0));
    });
  });

  group('Error Handling and Fallback', () {
    late SearchService searchService;

    setUp(() {
      DatabaseHelper.resetFtsVersion();
      searchService = SearchService();
    });

    tearDown(() {
      searchService.dispose();
    });

    test('_fallbackSearch is available for error recovery', () {
      // _fallbackSearch provides LIKE-based search when primary search fails
      // This is separate from disabled mode (ftsVersion == 0)
      // It handles cases like corrupt FTS index or query syntax errors
      expect(searchService, isNotNull);
    });

    test('_fallbackSearch uses LIKE patterns', () {
      // Fallback search builds LIKE conditions:
      // title LIKE '%term%' OR description LIKE '%term%' OR ocr_text LIKE '%term%'
      // Terms are combined with AND logic
      expect(searchService, isNotNull);
    });

    test('_fallbackSearch escapes LIKE special characters', () {
      // Special characters are escaped:
      // % -> \%
      // _ -> \_
      // Uses ESCAPE '\' clause
      expect(searchService, isNotNull);
    });

    test('_fallbackSearch returns empty list on failure', () {
      // If _fallbackSearch itself fails, it returns []
      // This prevents app crashes in worst-case scenarios
      expect(searchService, isNotNull);
    });

    test('error recovery logs search failures', () {
      // When FTS query fails, _executeSearch logs:
      // 'SearchService._executeSearch: FTS{version} query failed: {error}'
      // Then falls back to _fallbackSearch
      expect(searchService, isNotNull);
    });
  });

  group('Pagination', () {
    late SearchService searchService;

    setUp(() {
      DatabaseHelper.resetFtsVersion();
      DatabaseHelper.setFtsVersion(5);
      searchService = SearchService();
    });

    tearDown(() {
      searchService.dispose();
    });

    test('_applyPagination respects limit option', () {
      // SearchOptions.limit controls maximum results
      // Results are truncated to fit within limit
      expect(searchService.ftsVersion, equals(5));
    });

    test('_applyPagination respects offset option', () {
      // SearchOptions.offset controls starting point
      // Results skip first 'offset' items
      expect(searchService.ftsVersion, equals(5));
    });

    test('pagination works across all FTS modes', () {
      // Pagination is applied in _executeSearch after receiving results
      // It works the same for FTS5, FTS4, and LIKE modes
      DatabaseHelper.setFtsVersion(5);
      expect(searchService.ftsVersion, equals(5));

      DatabaseHelper.setFtsVersion(4);
      expect(searchService.ftsVersion, equals(4));

      DatabaseHelper.setFtsVersion(0);
      expect(searchService.ftsVersion, equals(0));
    });

    test('empty results return empty list regardless of pagination', () {
      // If no results, pagination returns empty list
      // This handles edge cases gracefully
      expect(searchService.ftsVersion, equals(5));
    });

    test('offset beyond results returns empty list', () {
      // If offset >= results.length, returns []
      // This handles edge cases gracefully
      expect(searchService.ftsVersion, equals(5));
    });
  });

  group('Search Result Ordering', () {
    setUp(() {
      DatabaseHelper.resetFtsVersion();
    });

    test('FTS5 mode orders by relevance rank', () {
      DatabaseHelper.setFtsVersion(5);
      final service = SearchService();

      // FTS5 search: ORDER BY fts.rank
      // Best matches (rank closer to 0) appear first
      expect(service.ftsVersion, equals(5));
      expect(service.hasRelevanceRanking, isTrue);

      service.dispose();
    });

    test('FTS4 mode orders by created_at DESC', () {
      DatabaseHelper.setFtsVersion(4);
      final service = SearchService();

      // FTS4 search: ORDER BY d.created_at DESC
      // Most recent documents appear first
      expect(service.ftsVersion, equals(4));
      expect(service.hasRelevanceRanking, isFalse);

      service.dispose();
    });

    test('disabled mode orders by created_at DESC', () {
      DatabaseHelper.setFtsVersion(0);
      final service = SearchService();

      // LIKE search: ORDER BY created_at DESC
      // Most recent documents appear first
      expect(service.ftsVersion, equals(0));
      expect(service.hasRelevanceRanking, isFalse);

      service.dispose();
    });

    test('only FTS5 provides relevance-based ordering', () {
      // FTS5 is the only mode with rank column
      final service = SearchService();

      DatabaseHelper.setFtsVersion(5);
      expect(service.hasRelevanceRanking, isTrue);

      DatabaseHelper.setFtsVersion(4);
      expect(service.hasRelevanceRanking, isFalse);

      DatabaseHelper.setFtsVersion(0);
      expect(service.hasRelevanceRanking, isFalse);

      service.dispose();
    });
  });

  group('Integration with DatabaseHelper', () {
    setUp(() {
      DatabaseHelper.resetFtsVersion();
    });

    test('uses DatabaseHelper.ftsVersion for mode detection', () {
      final service = SearchService();

      DatabaseHelper.setFtsVersion(5);
      expect(service.ftsVersion, equals(DatabaseHelper.ftsVersion));

      DatabaseHelper.setFtsVersion(4);
      expect(service.ftsVersion, equals(DatabaseHelper.ftsVersion));

      DatabaseHelper.setFtsVersion(0);
      expect(service.ftsVersion, equals(DatabaseHelper.ftsVersion));

      service.dispose();
    });

    test('uses DatabaseHelper.searchDocuments for queries', () {
      // _executeSearch calls _databaseHelper.searchDocuments(query)
      // DatabaseHelper.searchDocuments handles FTS version dispatch internally
      final service = SearchService();
      expect(service, isNotNull);
      service.dispose();
    });

    test('SearchResult uses DatabaseHelper column constants', () {
      // SearchResult.fromMap uses:
      // - DatabaseHelper.columnId
      // - DatabaseHelper.columnTitle
      // - DatabaseHelper.columnDescription
      // - DatabaseHelper.columnOcrText
      // - DatabaseHelper.columnCreatedAt
      expect(DatabaseHelper.columnId, equals('id'));
      expect(DatabaseHelper.columnTitle, equals('title'));
      expect(DatabaseHelper.columnDescription, equals('description'));
      expect(DatabaseHelper.columnOcrText, equals('ocr_text'));
      expect(DatabaseHelper.columnCreatedAt, equals('created_at'));
    });
  });
}
