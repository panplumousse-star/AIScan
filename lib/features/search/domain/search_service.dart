import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/storage/database_helper.dart';

/// Search options for configuring search behavior.
class SearchOptions {
  /// Maximum number of results to return.
  final int limit;

  /// Offset for pagination.
  final int offset;

  /// Whether to include OCR text in search.
  final bool includeOcrText;

  /// Whether to include description in search.
  final bool includeDescription;

  const SearchOptions({
    this.limit = 50,
    this.offset = 0,
    this.includeOcrText = true,
    this.includeDescription = true,
  });

  /// Default search options.
  static const SearchOptions defaultOptions = SearchOptions();
}

/// Result from a search operation.
class SearchResult {
  /// The document ID.
  final int id;

  /// The document title.
  final String title;

  /// The document description.
  final String? description;

  /// The OCR text content.
  final String? ocrText;

  /// When the document was created.
  final DateTime createdAt;

  /// Relevance score (available in FTS5 mode, otherwise null).
  final double? relevanceScore;

  SearchResult({
    required this.id,
    required this.title,
    this.description,
    this.ocrText,
    required this.createdAt,
    this.relevanceScore,
  });

  /// Creates a SearchResult from a database row map.
  factory SearchResult.fromMap(Map<String, dynamic> map) {
    return SearchResult(
      id: map[DatabaseHelper.columnId] as int,
      title: map[DatabaseHelper.columnTitle] as String,
      description: map[DatabaseHelper.columnDescription] as String?,
      ocrText: map[DatabaseHelper.columnOcrText] as String?,
      createdAt: DateTime.parse(map[DatabaseHelper.columnCreatedAt] as String),
      relevanceScore: map['rank'] != null
          ? (map['rank'] as num).toDouble()
          : null,
    );
  }
}

/// Service for searching documents with FTS version-aware capabilities.
///
/// SearchService provides a high-level interface for searching documents,
/// automatically handling the underlying FTS implementation (FTS5, FTS4, or LIKE).
///
/// The service integrates with [DatabaseHelper] to:
/// - Detect the active FTS version
/// - Execute version-appropriate search queries
/// - Provide graceful fallback when FTS is unavailable
///
/// Example:
/// ```dart
/// final searchService = SearchService();
/// await searchService.initialize();
///
/// final results = await searchService.search('flutter tutorial');
/// for (final result in results) {
///   print('Found: ${result.title}');
/// }
/// ```
class SearchService {
  final DatabaseHelper _databaseHelper;

  /// Whether the service has been initialized.
  bool _initialized = false;

  /// Cached FTS version for logging and decision making.
  int _cachedFtsVersion = 0;

  /// Creates a new SearchService instance.
  ///
  /// If [databaseHelper] is not provided, uses the singleton instance.
  SearchService({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper();

  /// Whether the service has been initialized.
  bool get isInitialized => _initialized;

  /// Gets the active FTS version from DatabaseHelper.
  ///
  /// Returns:
  /// - 5: FTS5 is active (best performance with relevance ranking)
  /// - 4: FTS4 is active (universal compatibility)
  /// - 0: FTS is disabled (LIKE-based search)
  int get ftsVersion => DatabaseHelper.ftsVersion;

  /// Initializes the search service.
  ///
  /// This method:
  /// 1. Ensures the database is initialized
  /// 2. Caches the detected FTS version
  /// 3. Logs the FTS mode for debugging
  ///
  /// Must be called before performing searches.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    // Access the database to ensure it's initialized
    // This triggers FTS detection in DatabaseHelper._onCreate()
    await _databaseHelper.database;

    // Cache the FTS version for logging
    _cachedFtsVersion = DatabaseHelper.ftsVersion;

    // Log the active FTS mode for debugging
    _logFtsMode();

    _initialized = true;
  }

  /// Logs the active FTS mode for debugging purposes.
  void _logFtsMode() {
    switch (_cachedFtsVersion) {
      case 5:
        debugPrint('SearchService: Using FTS5 mode (full relevance ranking)');
        break;
      case 4:
        debugPrint('SearchService: Using FTS4 mode (basic full-text search)');
        break;
      default:
        debugPrint('SearchService: FTS disabled, using LIKE-based search');
    }
  }

  /// Searches documents with the given query.
  ///
  /// This is the main search entry point. It:
  /// 1. Validates the query
  /// 2. Executes the search using [_executeSearch]
  /// 3. Transforms results into [SearchResult] objects
  ///
  /// Parameters:
  /// - [query]: The search query string
  /// - [options]: Optional search configuration
  ///
  /// Returns a list of [SearchResult] objects matching the query.
  ///
  /// Example:
  /// ```dart
  /// final results = await searchService.search('invoice 2024');
  /// ```
  Future<List<SearchResult>> search(
    String query, {
    SearchOptions options = SearchOptions.defaultOptions,
  }) async {
    // Ensure service is initialized
    if (!_initialized) {
      await initialize();
    }

    // Validate query
    if (query.trim().isEmpty) {
      return [];
    }

    // Execute the search with graceful FTS mode handling
    final rawResults = await _executeSearch(query, options);

    // Transform raw results to SearchResult objects
    return rawResults.map((row) => SearchResult.fromMap(row)).toList();
  }

  /// Executes the search using the appropriate method based on FTS version.
  ///
  /// This method handles all FTS modes gracefully:
  /// - FTS5 (version 5): Uses DatabaseHelper.searchDocuments() with rank ordering
  /// - FTS4 (version 4): Uses DatabaseHelper.searchDocuments() with date ordering
  /// - Disabled (version 0): Uses DatabaseHelper.searchDocuments() with LIKE queries
  ///
  /// The method provides graceful error handling:
  /// - If FTS query fails (e.g., corrupt index), falls back to [_fallbackSearch]
  /// - All errors are logged for debugging
  ///
  /// Parameters:
  /// - [query]: The search query string
  /// - [options]: Search configuration options
  ///
  /// Returns raw database result maps.
  Future<List<Map<String, dynamic>>> _executeSearch(
    String query,
    SearchOptions options,
  ) async {
    final ftsVersion = DatabaseHelper.ftsVersion;

    try {
      // DatabaseHelper.searchDocuments() already dispatches based on _ftsVersion
      // It handles FTS5, FTS4, and LIKE modes internally
      final results = await _databaseHelper.searchDocuments(query);

      // Apply pagination
      final paginatedResults = _applyPagination(results, options);

      // Log search mode and results for debugging
      if (kDebugMode) {
        final modeLabel = ftsVersion == 5
            ? 'FTS5'
            : ftsVersion == 4
                ? 'FTS4'
                : 'LIKE';
        debugPrint(
          'SearchService._executeSearch: $modeLabel query="$query" '
          'found ${results.length} results (returning ${paginatedResults.length})',
        );
      }

      return paginatedResults;
    } catch (e) {
      // FTS query may fail due to:
      // - Corrupt FTS index
      // - Invalid query syntax that escaped sanitization
      // - Database connection issues
      debugPrint(
        'SearchService._executeSearch: FTS$ftsVersion query failed: $e',
      );
      debugPrint('SearchService._executeSearch: Falling back to LIKE search');

      // Attempt fallback search as last resort
      return await _fallbackSearch(query, options);
    }
  }

  /// Performs a LIKE-based fallback search when primary search fails.
  ///
  /// This method is called when:
  /// - The primary search method throws an exception
  /// - FTS index is corrupted or unavailable
  ///
  /// It provides a safety net to ensure search functionality remains available
  /// even when FTS encounters unexpected errors.
  ///
  /// Note: This is different from the disabled mode (ftsVersion == 0) which
  /// uses _searchWithLike in DatabaseHelper. This fallback is for error recovery.
  ///
  /// Parameters:
  /// - [query]: The search query string
  /// - [options]: Search configuration options
  ///
  /// Returns raw database result maps using LIKE-based queries.
  Future<List<Map<String, dynamic>>> _fallbackSearch(
    String query,
    SearchOptions options,
  ) async {
    try {
      // Split query into terms
      final terms = query.trim().split(RegExp(r'\s+'))
          .where((term) => term.isNotEmpty)
          .toList();

      if (terms.isEmpty) {
        return [];
      }

      // Build LIKE conditions for each term
      final conditions = <String>[];
      final args = <dynamic>[];

      for (final term in terms) {
        // Escape LIKE special characters
        final escapedTerm = term
            .replaceAll('%', r'\%')
            .replaceAll('_', r'\_');
        final likePattern = '%$escapedTerm%';

        // Each term must match at least one searchable column
        final termConditions = <String>[];

        // Always include title
        termConditions.add("${DatabaseHelper.columnTitle} LIKE ? ESCAPE '\\'");
        args.add(likePattern);

        // Optionally include description
        if (options.includeDescription) {
          termConditions.add(
            "${DatabaseHelper.columnDescription} LIKE ? ESCAPE '\\'",
          );
          args.add(likePattern);
        }

        // Optionally include OCR text
        if (options.includeOcrText) {
          termConditions.add(
            "${DatabaseHelper.columnOcrText} LIKE ? ESCAPE '\\'",
          );
          args.add(likePattern);
        }

        conditions.add('(${termConditions.join(' OR ')})');
      }

      // Combine all term conditions with AND
      final whereClause = conditions.join(' AND ');

      // Query documents
      final db = await _databaseHelper.database;
      final results = await db.rawQuery('''
        SELECT *
        FROM ${DatabaseHelper.tableDocuments}
        WHERE $whereClause
        ORDER BY ${DatabaseHelper.columnCreatedAt} DESC
        LIMIT ? OFFSET ?
      ''', [...args, options.limit, options.offset]);

      debugPrint(
        'SearchService._fallbackSearch: LIKE query found ${results.length} results',
      );

      return results;
    } catch (e) {
      debugPrint('SearchService._fallbackSearch: Failed with error: $e');
      // Return empty results rather than propagating the error
      // This ensures the app doesn't crash even in worst-case scenarios
      return [];
    }
  }

  /// Applies pagination to search results.
  ///
  /// Parameters:
  /// - [results]: The full list of search results
  /// - [options]: Search options containing limit and offset
  ///
  /// Returns the paginated subset of results.
  List<Map<String, dynamic>> _applyPagination(
    List<Map<String, dynamic>> results,
    SearchOptions options,
  ) {
    if (results.isEmpty) {
      return results;
    }

    final startIndex = options.offset;
    if (startIndex >= results.length) {
      return [];
    }

    final endIndex = (startIndex + options.limit).clamp(0, results.length);
    return results.sublist(startIndex, endIndex);
  }

  /// Checks if FTS is available (either FTS5 or FTS4).
  ///
  /// Returns true if FTS is available, false if using LIKE-based search.
  bool get isFtsAvailable => ftsVersion > 0;

  /// Checks if full relevance ranking is available (FTS5 only).
  ///
  /// Returns true if FTS5 is active and relevance scores are available.
  bool get hasRelevanceRanking => ftsVersion == 5;

  /// Gets a human-readable description of the current search mode.
  ///
  /// Useful for displaying search capabilities to users or in logs.
  String get searchModeDescription {
    switch (ftsVersion) {
      case 5:
        return 'Full-text search with relevance ranking (FTS5)';
      case 4:
        return 'Full-text search (FTS4)';
      default:
        return 'Basic search (LIKE-based)';
    }
  }

  /// Disposes of resources used by the search service.
  void dispose() {
    _initialized = false;
    _cachedFtsVersion = 0;
  }
}
