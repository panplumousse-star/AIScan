import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/database_helper.dart';
import '../../../core/storage/document_repository.dart';
import '../../documents/domain/document_model.dart';

/// Riverpod provider for [SearchService].
///
/// Provides a singleton instance of the search service for
/// dependency injection throughout the application.
final searchServiceProvider = Provider<SearchService>((ref) {
  final databaseHelper = ref.read(databaseHelperProvider);
  final documentRepository = ref.read(documentRepositoryProvider);
  return SearchService(
    databaseHelper: databaseHelper,
    documentRepository: documentRepository,
  );
});

/// Exception thrown when search operations fail.
///
/// Contains the original error message and optional underlying exception.
class SearchException implements Exception {
  /// Creates a [SearchException] with the given [message].
  const SearchException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'SearchException: $message (caused by: $cause)';
    }
    return 'SearchException: $message';
  }
}

/// A single search result with relevance information.
///
/// Contains the matching document along with search-specific metadata
/// like relevance score and highlighted snippets.
@immutable
class SearchResult {
  /// Creates a [SearchResult] with the required data.
  const SearchResult({
    required this.document,
    required this.score,
    this.snippets = const [],
    this.matchedFields = const [],
  });

  /// The matching document.
  final Document document;

  /// Relevance score (higher is more relevant).
  ///
  /// Typically based on BM25 ranking from FTS5.
  /// Score is typically negative (closer to 0 is better match).
  final double score;

  /// Text snippets showing matching portions with context.
  ///
  /// Each snippet may contain highlighted matching terms.
  final List<SearchSnippet> snippets;

  /// List of fields that matched the query.
  ///
  /// Possible values: 'title', 'description', 'ocr_text'.
  final List<String> matchedFields;

  /// Whether the search matched in the document title.
  bool get matchedTitle => matchedFields.contains('title');

  /// Whether the search matched in the document description.
  bool get matchedDescription => matchedFields.contains('description');

  /// Whether the search matched in the OCR text.
  bool get matchedOcrText => matchedFields.contains('ocr_text');

  /// Gets a brief preview of the best matching content.
  String get preview {
    if (snippets.isNotEmpty) {
      return snippets.first.text;
    }
    if (document.description != null && document.description!.isNotEmpty) {
      return document.description!;
    }
    if (document.hasOcrText) {
      final ocrPreview = document.ocrText!;
      return ocrPreview.length > 200
          ? '${ocrPreview.substring(0, 200)}...'
          : ocrPreview;
    }
    return document.title;
  }

  /// Creates a copy with updated values.
  SearchResult copyWith({
    Document? document,
    double? score,
    List<SearchSnippet>? snippets,
    List<String>? matchedFields,
  }) {
    return SearchResult(
      document: document ?? this.document,
      score: score ?? this.score,
      snippets: snippets ?? this.snippets,
      matchedFields: matchedFields ?? this.matchedFields,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchResult &&
        other.document == document &&
        other.score == score &&
        listEquals(other.snippets, snippets) &&
        listEquals(other.matchedFields, matchedFields);
  }

  @override
  int get hashCode => Object.hash(
        document,
        score,
        Object.hashAll(snippets),
        Object.hashAll(matchedFields),
      );

  @override
  String toString() => 'SearchResult('
      'document: ${document.id}, '
      'score: ${score.toStringAsFixed(3)}, '
      'matchedFields: $matchedFields)';
}

/// A text snippet from a search result with optional highlighting.
///
/// Contains a portion of text from the matched document with
/// markers indicating where the search terms appear.
@immutable
class SearchSnippet {
  /// Creates a [SearchSnippet] with the text and highlighting info.
  const SearchSnippet({
    required this.text,
    required this.field,
    this.highlights = const [],
  });

  /// The snippet text, potentially with highlight markers.
  final String text;

  /// The field this snippet came from ('title', 'description', 'ocr_text').
  final String field;

  /// Character ranges of highlighted terms in the text.
  ///
  /// Each entry is a [start, end] pair indicating a range to highlight.
  final List<List<int>> highlights;

  /// Whether the snippet has any highlights.
  bool get hasHighlights => highlights.isNotEmpty;

  /// Gets the display name for the source field.
  String get fieldDisplayName {
    switch (field) {
      case 'title':
        return 'Title';
      case 'description':
        return 'Description';
      case 'ocr_text':
        return 'Document Text';
      default:
        return field;
    }
  }

  /// Creates a copy with updated values.
  SearchSnippet copyWith({
    String? text,
    String? field,
    List<List<int>>? highlights,
  }) {
    return SearchSnippet(
      text: text ?? this.text,
      field: field ?? this.field,
      highlights: highlights ?? this.highlights,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SearchSnippet) return false;
    if (other.text != text || other.field != field) return false;
    if (other.highlights.length != highlights.length) return false;
    for (var i = 0; i < highlights.length; i++) {
      if (!listEquals(other.highlights[i], highlights[i])) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        text,
        field,
        Object.hashAll(highlights.map((h) => Object.hashAll(h))),
      );

  @override
  String toString() => 'SearchSnippet('
      'field: $field, '
      'text: ${text.length} chars, '
      'highlights: ${highlights.length})';
}

/// The field to search in.
enum SearchField {
  /// Search in all fields.
  all,

  /// Search only in document titles.
  title,

  /// Search only in document descriptions.
  description,

  /// Search only in OCR text.
  ocrText,
}

/// Configuration options for search operations.
@immutable
class SearchOptions {
  /// Creates [SearchOptions] with the specified parameters.
  const SearchOptions({
    this.field = SearchField.all,
    this.matchMode = SearchMatchMode.prefix,
    this.limit = 50,
    this.offset = 0,
    this.includeSnippets = true,
    this.snippetLength = 150,
    this.includeTags = false,
    this.folderId,
    this.favoritesOnly = false,
    this.hasOcrOnly = false,
    this.sortBy = SearchSortBy.relevance,
    this.sortDescending = true,
  });

  /// Creates default search options.
  const SearchOptions.defaults() : this();

  /// Creates options optimized for quick search suggestions.
  ///
  /// Returns minimal data without snippets, limited results.
  const SearchOptions.suggestions()
      : field = SearchField.all,
        matchMode = SearchMatchMode.prefix,
        limit = 5,
        offset = 0,
        includeSnippets = false,
        snippetLength = 0,
        includeTags = false,
        folderId = null,
        favoritesOnly = false,
        hasOcrOnly = false,
        sortBy = SearchSortBy.relevance,
        sortDescending = true;

  /// Creates options for searching document titles only.
  const SearchOptions.titlesOnly({
    int limit = 50,
    bool includeSnippets = false,
  })  : field = SearchField.title,
        matchMode = SearchMatchMode.prefix,
        limit = limit,
        offset = 0,
        includeSnippets = includeSnippets,
        snippetLength = 100,
        includeTags = false,
        folderId = null,
        favoritesOnly = false,
        hasOcrOnly = false,
        sortBy = SearchSortBy.relevance,
        sortDescending = true;

  /// Creates options for searching OCR text only.
  const SearchOptions.ocrTextOnly({
    int limit = 50,
    int snippetLength = 200,
  })  : field = SearchField.ocrText,
        matchMode = SearchMatchMode.phrase,
        limit = limit,
        offset = 0,
        includeSnippets = true,
        snippetLength = snippetLength,
        includeTags = false,
        folderId = null,
        favoritesOnly = false,
        hasOcrOnly = true,
        sortBy = SearchSortBy.relevance,
        sortDescending = true;

  /// Which field(s) to search in.
  final SearchField field;

  /// How to match the search query.
  final SearchMatchMode matchMode;

  /// Maximum number of results to return.
  final int limit;

  /// Number of results to skip (for pagination).
  final int offset;

  /// Whether to generate text snippets with highlights.
  final bool includeSnippets;

  /// Approximate length of generated snippets in characters.
  final int snippetLength;

  /// Whether to include document tags in results.
  final bool includeTags;

  /// Limit results to documents in this folder.
  ///
  /// Use null for all folders.
  final String? folderId;

  /// Only return favorite documents.
  final bool favoritesOnly;

  /// Only return documents that have OCR text.
  final bool hasOcrOnly;

  /// How to sort the results.
  final SearchSortBy sortBy;

  /// Whether to sort in descending order.
  final bool sortDescending;

  /// Creates a copy with updated values.
  SearchOptions copyWith({
    SearchField? field,
    SearchMatchMode? matchMode,
    int? limit,
    int? offset,
    bool? includeSnippets,
    int? snippetLength,
    bool? includeTags,
    String? folderId,
    bool? clearFolderId,
    bool? favoritesOnly,
    bool? hasOcrOnly,
    SearchSortBy? sortBy,
    bool? sortDescending,
  }) {
    return SearchOptions(
      field: field ?? this.field,
      matchMode: matchMode ?? this.matchMode,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      includeSnippets: includeSnippets ?? this.includeSnippets,
      snippetLength: snippetLength ?? this.snippetLength,
      includeTags: includeTags ?? this.includeTags,
      folderId: (clearFolderId ?? false) ? null : (folderId ?? this.folderId),
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      hasOcrOnly: hasOcrOnly ?? this.hasOcrOnly,
      sortBy: sortBy ?? this.sortBy,
      sortDescending: sortDescending ?? this.sortDescending,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchOptions &&
        other.field == field &&
        other.matchMode == matchMode &&
        other.limit == limit &&
        other.offset == offset &&
        other.includeSnippets == includeSnippets &&
        other.snippetLength == snippetLength &&
        other.includeTags == includeTags &&
        other.folderId == folderId &&
        other.favoritesOnly == favoritesOnly &&
        other.hasOcrOnly == hasOcrOnly &&
        other.sortBy == sortBy &&
        other.sortDescending == sortDescending;
  }

  @override
  int get hashCode => Object.hash(
        field,
        matchMode,
        limit,
        offset,
        includeSnippets,
        snippetLength,
        includeTags,
        folderId,
        favoritesOnly,
        hasOcrOnly,
        sortBy,
        sortDescending,
      );

  @override
  String toString() => 'SearchOptions('
      'field: $field, '
      'matchMode: $matchMode, '
      'limit: $limit)';
}

/// How the search query should be matched against documents.
enum SearchMatchMode {
  /// Prefix matching - finds words starting with the query.
  ///
  /// Example: "doc" matches "document", "documentation".
  prefix,

  /// Exact phrase matching - finds the exact phrase.
  ///
  /// Example: "important document" matches only that exact phrase.
  phrase,

  /// Match all words in any order.
  ///
  /// Example: "document important" matches documents containing both words.
  allWords,

  /// Match any of the words.
  ///
  /// Example: "document important" matches documents with either word.
  anyWord,
}

/// How to sort search results.
enum SearchSortBy {
  /// Sort by relevance score (default for search).
  relevance,

  /// Sort by document title alphabetically.
  title,

  /// Sort by creation date.
  createdAt,

  /// Sort by last updated date.
  updatedAt,

  /// Sort by file size.
  fileSize,
}

/// Aggregated results from a search operation.
@immutable
class SearchResults {
  /// Creates [SearchResults] with the search data.
  const SearchResults({
    required this.query,
    required this.results,
    required this.totalCount,
    required this.searchTimeMs,
    required this.options,
  });

  /// Creates empty search results.
  const SearchResults.empty({
    String query = '',
    SearchOptions options = const SearchOptions.defaults(),
  })  : query = query,
        results = const [],
        totalCount = 0,
        searchTimeMs = 0,
        options = options;

  /// The original search query.
  final String query;

  /// The list of matching search results.
  final List<SearchResult> results;

  /// Total number of matching documents (before pagination).
  final int totalCount;

  /// Time taken to perform the search in milliseconds.
  final int searchTimeMs;

  /// Options used for this search.
  final SearchOptions options;

  /// Whether any results were found.
  bool get hasResults => results.isNotEmpty;

  /// Whether more results are available (for pagination).
  bool get hasMore => (options.offset + results.length) < totalCount;

  /// Number of results returned.
  int get count => results.length;

  /// The documents from the search results.
  List<Document> get documents => results.map((r) => r.document).toList();

  /// Creates a copy with updated values.
  SearchResults copyWith({
    String? query,
    List<SearchResult>? results,
    int? totalCount,
    int? searchTimeMs,
    SearchOptions? options,
  }) {
    return SearchResults(
      query: query ?? this.query,
      results: results ?? this.results,
      totalCount: totalCount ?? this.totalCount,
      searchTimeMs: searchTimeMs ?? this.searchTimeMs,
      options: options ?? this.options,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchResults &&
        other.query == query &&
        listEquals(other.results, results) &&
        other.totalCount == totalCount &&
        other.searchTimeMs == searchTimeMs &&
        other.options == options;
  }

  @override
  int get hashCode => Object.hash(
        query,
        Object.hashAll(results),
        totalCount,
        searchTimeMs,
        options,
      );

  @override
  String toString() => 'SearchResults('
      'query: "$query", '
      'count: $count, '
      'total: $totalCount, '
      'time: ${searchTimeMs}ms)';
}

/// A recent search entry for search history.
@immutable
class RecentSearch {
  /// Creates a [RecentSearch] with the query and timestamp.
  const RecentSearch({
    required this.query,
    required this.timestamp,
    this.resultCount,
  });

  /// The search query string.
  final String query;

  /// When the search was performed.
  final DateTime timestamp;

  /// Number of results found (optional).
  final int? resultCount;

  /// Creates a copy with updated values.
  RecentSearch copyWith({
    String? query,
    DateTime? timestamp,
    int? resultCount,
  }) {
    return RecentSearch(
      query: query ?? this.query,
      timestamp: timestamp ?? this.timestamp,
      resultCount: resultCount ?? this.resultCount,
    );
  }

  /// Serializes to a map for storage.
  Map<String, dynamic> toMap() {
    return {
      'query': query,
      'timestamp': timestamp.toIso8601String(),
      if (resultCount != null) 'resultCount': resultCount,
    };
  }

  /// Creates from a serialized map.
  factory RecentSearch.fromMap(Map<String, dynamic> map) {
    return RecentSearch(
      query: map['query'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      resultCount: map['resultCount'] as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecentSearch &&
        other.query == query &&
        other.timestamp == timestamp &&
        other.resultCount == resultCount;
  }

  @override
  int get hashCode => Object.hash(query, timestamp, resultCount);

  @override
  String toString() => 'RecentSearch('
      'query: "$query", '
      'timestamp: $timestamp, '
      'resultCount: $resultCount)';
}

/// Service for full-text search across documents.
///
/// Provides powerful search functionality using SQLite FTS5 (Full-Text Search),
/// enabling fast and relevant searches across document titles, descriptions,
/// and OCR-extracted text.
///
/// ## Key Features
/// - **Full-Text Search**: Uses SQLite FTS5 for efficient text matching
/// - **Relevance Ranking**: Results sorted by BM25 relevance scoring
/// - **Snippet Generation**: Creates context snippets with matching terms
/// - **Search History**: Tracks recent searches for quick access
/// - **Flexible Options**: Configurable search field, match mode, and filters
/// - **Offline-First**: All search operations work completely offline
///
/// ## Search Modes
/// The service supports different matching modes:
/// - **Prefix**: "doc" matches "document", "documentation" (default)
/// - **Phrase**: "important document" matches exact phrase
/// - **All Words**: Matches documents containing all query words
/// - **Any Word**: Matches documents containing any query word
///
/// ## Usage
/// ```dart
/// final searchService = ref.read(searchServiceProvider);
///
/// // Simple search
/// final results = await searchService.search('invoice');
///
/// // Search with options
/// final results = await searchService.search(
///   'contract',
///   options: const SearchOptions(
///     field: SearchField.ocrText,
///     matchMode: SearchMatchMode.phrase,
///     limit: 20,
///   ),
/// );
///
/// // Get search suggestions
/// final suggestions = await searchService.getSuggestions('inv');
///
/// // Recent searches
/// final recent = await searchService.getRecentSearches();
/// ```
///
/// ## FTS5 Query Syntax
/// The service translates user queries to FTS5 syntax:
/// - Prefix: `word*` for prefix matching
/// - Phrase: `"word1 word2"` for exact phrase
/// - AND: `word1 word2` for all words
/// - OR: `word1 OR word2` for any word
/// - Field: `title:word` for specific field
class SearchService {
  /// Creates a [SearchService] with the required dependencies.
  SearchService({
    required DatabaseHelper databaseHelper,
    required DocumentRepository documentRepository,
  })  : _database = databaseHelper,
        _documentRepository = documentRepository;

  /// The database helper for FTS queries.
  final DatabaseHelper _database;

  /// The document repository for retrieving full documents.
  final DocumentRepository _documentRepository;

  /// Maximum number of recent searches to store.
  static const int maxRecentSearches = 20;

  /// In-memory cache of recent searches.
  /// In a production app, this would be persisted.
  final List<RecentSearch> _recentSearches = [];

  /// Whether the service has been initialized.
  bool _isInitialized = false;

  /// Whether the service is ready for use.
  bool get isReady => _isInitialized;

  /// Gets the list of recent searches.
  List<RecentSearch> get recentSearches => List.unmodifiable(_recentSearches);

  /// Initializes the search service.
  ///
  /// This must be called before performing searches. It verifies
  /// that the database FTS index is available.
  ///
  /// Returns true if initialization was successful.
  ///
  /// Throws [SearchException] if initialization fails.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Verify the database is available
      await _database.initialize();

      // Load recent searches from database
      await _loadRecentSearches();

      _isInitialized = true;
      return true;
    } on Object catch (e) {
      throw SearchException(
        'Failed to initialize search service',
        cause: e,
      );
    }
  }

  /// Performs a full-text search across documents.
  ///
  /// The [query] string is searched against document fields based
  /// on the [options] configuration.
  ///
  /// Returns a [SearchResults] object containing matching documents
  /// with relevance scores and optional snippets.
  ///
  /// Throws [SearchException] if:
  /// - The service is not initialized
  /// - The query is empty
  /// - The search operation fails
  ///
  /// Example:
  /// ```dart
  /// final results = await searchService.search(
  ///   'contract agreement',
  ///   options: const SearchOptions(
  ///     matchMode: SearchMatchMode.allWords,
  ///     limit: 20,
  ///     includeSnippets: true,
  ///   ),
  /// );
  ///
  /// for (final result in results.results) {
  ///   print('${result.document.title}: ${result.score}');
  /// }
  /// ```
  Future<SearchResults> search(
    String query, {
    SearchOptions options = const SearchOptions.defaults(),
  }) async {
    if (!_isInitialized) {
      throw const SearchException(
        'Search service not initialized. Call initialize() first.',
      );
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return SearchResults.empty(query: query, options: options);
    }

    try {
      final stopwatch = Stopwatch()..start();

      // Build FTS query based on options
      final ftsQuery = _buildFtsQuery(trimmedQuery, options);

      // Execute search
      final searchResultsRaw = await _executeSearch(ftsQuery, options);

      // Apply additional filters not supported by FTS
      final filteredResults = await _applyFilters(searchResultsRaw, options);

      // Calculate total count before pagination
      final totalCount = filteredResults.length;

      // Apply pagination
      final paginatedResults =
          filteredResults.skip(options.offset).take(options.limit).toList();

      // Build full search results with snippets if requested
      final results = await _buildSearchResults(
        paginatedResults,
        trimmedQuery,
        options,
      );

      // Sort results
      _sortResults(results, options);

      stopwatch.stop();

      // Add to recent searches
      _addToRecentSearches(trimmedQuery, totalCount);

      return SearchResults(
        query: trimmedQuery,
        results: results,
        totalCount: totalCount,
        searchTimeMs: stopwatch.elapsedMilliseconds,
        options: options,
      );
    } on Object catch (e) {
      if (e is SearchException) rethrow;
      throw SearchException(
        'Search failed for query: $query',
        cause: e,
      );
    }
  }

  /// Builds an FTS5 query string based on search options.
  String _buildFtsQuery(String query, SearchOptions options) {
    // Escape special FTS5 characters
    var escapedQuery = _escapeFtsSpecialChars(query);

    // Apply match mode
    switch (options.matchMode) {
      case SearchMatchMode.prefix:
        // Add prefix operator to each word
        final words = escapedQuery.split(RegExp(r'\s+'));
        escapedQuery = words.map((w) => w.isEmpty ? w : '$w*').join(' ');

      case SearchMatchMode.phrase:
        // Wrap in quotes for phrase matching
        escapedQuery = '"$escapedQuery"';

      case SearchMatchMode.allWords:
        // Default FTS5 behavior is AND
        break; // Keep break for empty case

      case SearchMatchMode.anyWord:
        // Join words with OR
        final words = escapedQuery.split(RegExp(r'\s+'));
        escapedQuery = words.where((w) => w.isNotEmpty).join(' OR ');
    }

    // Apply field filter if not searching all fields
    if (options.field != SearchField.all) {
      final column = _getColumnName(options.field);
      escapedQuery = '$column:$escapedQuery';
    }

    return escapedQuery;
  }

  /// Escapes special FTS5 characters in a query.
  String _escapeFtsSpecialChars(String query) {
    // FTS5 special characters: " * - ^ OR AND NOT NEAR
    // We want to treat them as literals, so escape with quotes where needed
    return query
        .replaceAll('"', ' ')
        .replaceAll('*', ' ')
        .replaceAll('^', ' ')
        .trim();
  }

  /// Gets the FTS column name for a search field.
  String _getColumnName(SearchField field) {
    switch (field) {
      case SearchField.all:
        return '*';
      case SearchField.title:
        return 'title';
      case SearchField.description:
        return 'description';
      case SearchField.ocrText:
        return 'ocr_text';
    }
  }

  /// Executes the FTS search and returns raw results.
  Future<List<_RawSearchResult>> _executeSearch(
    String ftsQuery,
    SearchOptions options,
  ) async {
    try {
      // Build dynamic WHERE clause for filters
      final whereConditions = <String>[
        '${DatabaseHelper.tableDocumentsFts} MATCH ?'
      ];
      final queryArgs = <Object>[ftsQuery];

      // Add filter conditions based on SearchOptions
      if (options.favoritesOnly) {
        whereConditions.add('d.${DatabaseHelper.columnIsFavorite} = 1');
      }

      if (options.hasOcrOnly) {
        whereConditions.add('d.${DatabaseHelper.columnOcrText} IS NOT NULL');
      }

      if (options.folderId != null) {
        whereConditions.add('d.${DatabaseHelper.columnFolderId} = ?');
        queryArgs.add(options.folderId!);
      }

      // Combine WHERE conditions with AND
      final whereClause = whereConditions.join(' AND ');

      // Query FTS table with ranking and filters
      final sql = '''
        SELECT
          d.${DatabaseHelper.columnId} as id,
          d.${DatabaseHelper.columnTitle} as title,
          d.${DatabaseHelper.columnDescription} as description,
          d.${DatabaseHelper.columnOcrText} as ocr_text,
          fts.rank as score
        FROM ${DatabaseHelper.tableDocuments} d
        INNER JOIN ${DatabaseHelper.tableDocumentsFts} fts ON d.rowid = fts.rowid
        WHERE $whereClause
        ORDER BY fts.rank
      ''';

      final results = await _database.rawQuery(sql, queryArgs);

      return results.map((row) {
        return _RawSearchResult(
          documentId: row['id'] as String,
          title: row['title'] as String?,
          description: row['description'] as String?,
          ocrText: row['ocr_text'] as String?,
          score: (row['score'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    } on Object catch (_) {
      // If FTS query fails, try fallback LIKE search
      return _fallbackSearch(ftsQuery, options);
    }
  }

  /// Fallback LIKE-based search when FTS fails.
  Future<List<_RawSearchResult>> _fallbackSearch(
    String query,
    SearchOptions options,
  ) async {
    // Extract simple terms from query
    final terms = query
        .replaceAll(RegExp(r'[*":]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .toList();

    if (terms.isEmpty) {
      return [];
    }

    // Build LIKE conditions for search terms
    final conditions = <String>[];
    final args = <Object>[];

    for (final term in terms) {
      final likePattern = '%$term%';
      if (options.field == SearchField.all) {
        conditions.add(
          '(${DatabaseHelper.columnTitle} LIKE ? OR '
          '${DatabaseHelper.columnDescription} LIKE ? OR '
          '${DatabaseHelper.columnOcrText} LIKE ?)',
        );
        args.addAll([likePattern, likePattern, likePattern]);
      } else {
        final column = _getColumnName(options.field);
        conditions.add('$column LIKE ?');
        args.add(likePattern);
      }
    }

    final searchCondition = conditions.join(
      options.matchMode == SearchMatchMode.anyWord ? ' OR ' : ' AND ',
    );

    // Build WHERE clause with search and filter conditions
    final whereConditions = <String>['($searchCondition)'];

    // Add filter conditions based on SearchOptions
    if (options.favoritesOnly) {
      whereConditions.add('${DatabaseHelper.columnIsFavorite} = 1');
    }

    if (options.hasOcrOnly) {
      whereConditions.add('${DatabaseHelper.columnOcrText} IS NOT NULL');
    }

    if (options.folderId != null) {
      whereConditions.add('${DatabaseHelper.columnFolderId} = ?');
      args.add(options.folderId!);
    }

    // Combine all WHERE conditions with AND
    final whereClause = whereConditions.join(' AND ');

    final sql = '''
      SELECT
        ${DatabaseHelper.columnId} as id,
        ${DatabaseHelper.columnTitle} as title,
        ${DatabaseHelper.columnDescription} as description,
        ${DatabaseHelper.columnOcrText} as ocr_text,
        0.0 as score
      FROM ${DatabaseHelper.tableDocuments}
      WHERE $whereClause
    ''';

    final results = await _database.rawQuery(sql, args);

    return results.map((row) {
      return _RawSearchResult(
        documentId: row['id'] as String,
        title: row['title'] as String?,
        description: row['description'] as String?,
        ocrText: row['ocr_text'] as String?,
        score: 0.0,
      );
    }).toList();
  }

  /// Applies additional filters to raw search results.
  ///
  /// This method is kept for API compatibility and future extensibility,
  /// but currently returns results unchanged since all filters
  /// (favoritesOnly, hasOcrOnly, folderId) are now applied in the SQL query.
  Future<List<_RawSearchResult>> _applyFilters(
    List<_RawSearchResult> results,
    SearchOptions options,
  ) async {
    // All filters are now applied in the SQL query in _executeSearch(),
    // so we just return the results unchanged to avoid O(n) database lookups.
    return results;
  }

  /// Builds full search results with documents and snippets.
  Future<List<SearchResult>> _buildSearchResults(
    List<_RawSearchResult> rawResults,
    String query,
    SearchOptions options,
  ) async {
    final results = <SearchResult>[];

    for (final raw in rawResults) {
      // Get full document
      final document = await _documentRepository.getDocument(
        raw.documentId,
        includeTags: options.includeTags,
      );

      if (document == null) continue;

      // Determine matched fields
      final matchedFields = _determineMatchedFields(raw, query);

      // Generate snippets if requested
      List<SearchSnippet> snippets = [];
      if (options.includeSnippets) {
        snippets = _generateSnippets(raw, query, options.snippetLength);
      }

      results.add(SearchResult(
        document: document,
        score: raw.score,
        snippets: snippets,
        matchedFields: matchedFields,
      ));
    }

    return results;
  }

  /// Determines which fields matched the search query.
  List<String> _determineMatchedFields(_RawSearchResult result, String query) {
    final queryLower = query.toLowerCase();
    final terms = queryLower
        .replaceAll(RegExp(r'[*":]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .toList();

    final matchedFields = <String>[];

    bool containsAnyTerm(String? text) {
      if (text == null || text.isEmpty) return false;
      final textLower = text.toLowerCase();
      return terms.any((term) => textLower.contains(term));
    }

    if (containsAnyTerm(result.title)) {
      matchedFields.add('title');
    }
    if (containsAnyTerm(result.description)) {
      matchedFields.add('description');
    }
    if (containsAnyTerm(result.ocrText)) {
      matchedFields.add('ocr_text');
    }

    return matchedFields;
  }

  /// Generates snippets from search results.
  List<SearchSnippet> _generateSnippets(
    _RawSearchResult result,
    String query,
    int snippetLength,
  ) {
    final snippets = <SearchSnippet>[];
    final queryTerms = query
        .toLowerCase()
        .replaceAll(RegExp(r'[*":]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .toSet();

    // Helper to create snippet from text
    SearchSnippet? createSnippet(String? text, String field) {
      if (text == null || text.isEmpty) return null;

      final textLower = text.toLowerCase();

      // Find the first matching term
      int? matchStart;
      for (final term in queryTerms) {
        final index = textLower.indexOf(term);
        if (index != -1 && (matchStart == null || index < matchStart)) {
          matchStart = index;
        }
      }

      if (matchStart == null) return null;

      // Calculate snippet window
      final halfLength = snippetLength ~/ 2;
      var start = matchStart - halfLength;
      var end = matchStart + halfLength;

      if (start < 0) {
        end = end - start;
        start = 0;
      }
      if (end > text.length) {
        start = start - (end - text.length);
        end = text.length;
      }
      start = start.clamp(0, text.length);
      end = end.clamp(0, text.length);

      var snippetText = text.substring(start, end);

      // Add ellipsis if truncated
      if (start > 0) {
        snippetText = '...$snippetText';
      }
      if (end < text.length) {
        snippetText = '$snippetText...';
      }

      // Find highlights in snippet
      final highlights = _findHighlights(snippetText, queryTerms);

      return SearchSnippet(
        text: snippetText,
        field: field,
        highlights: highlights,
      );
    }

    // Create snippets from each field
    final titleSnippet = createSnippet(result.title, 'title');
    if (titleSnippet != null) snippets.add(titleSnippet);

    final descSnippet = createSnippet(result.description, 'description');
    if (descSnippet != null) snippets.add(descSnippet);

    final ocrSnippet = createSnippet(result.ocrText, 'ocr_text');
    if (ocrSnippet != null) snippets.add(ocrSnippet);

    return snippets;
  }

  /// Finds highlight ranges for query terms in text.
  List<List<int>> _findHighlights(String text, Set<String> terms) {
    final highlights = <List<int>>[];
    final textLower = text.toLowerCase();

    for (final term in terms) {
      var searchStart = 0;
      while (true) {
        final index = textLower.indexOf(term, searchStart);
        if (index == -1) break;
        highlights.add([index, index + term.length]);
        searchStart = index + 1;
      }
    }

    // Sort by start position
    highlights.sort((a, b) => a[0].compareTo(b[0]));

    return highlights;
  }

  /// Sorts search results based on options.
  void _sortResults(List<SearchResult> results, SearchOptions options) {
    results.sort((a, b) {
      int comparison;
      switch (options.sortBy) {
        case SearchSortBy.relevance:
          // Lower score is better in FTS5 (more negative = better match)
          comparison = a.score.compareTo(b.score);
        case SearchSortBy.title:
          comparison = a.document.title.compareTo(b.document.title);
        case SearchSortBy.createdAt:
          comparison = a.document.createdAt.compareTo(b.document.createdAt);
        case SearchSortBy.updatedAt:
          comparison = a.document.updatedAt.compareTo(b.document.updatedAt);
        case SearchSortBy.fileSize:
          comparison = a.document.fileSize.compareTo(b.document.fileSize);
      }
      return options.sortDescending ? -comparison : comparison;
    });
  }

  /// Loads recent searches from database.
  Future<void> _loadRecentSearches() async {
    try {
      final searchHistory = await _database.getSearchHistory(
        limit: maxRecentSearches,
      );

      _recentSearches.clear();
      for (final map in searchHistory) {
        _recentSearches.add(RecentSearch.fromMap(map));
      }
    } on Object catch (_) {
      // Log error but don't throw - search history is not critical
    }
  }

  /// Adds a query to recent searches.
  void _addToRecentSearches(String query, int resultCount) {
    // Remove existing entry with same query
    _recentSearches.removeWhere(
      (s) => s.query.toLowerCase() == query.toLowerCase(),
    );

    // Add new entry at the beginning
    _recentSearches.insert(
      0,
      RecentSearch(
        query: query,
        timestamp: DateTime.now(),
        resultCount: resultCount,
      ),
    );

    // Trim to max size
    while (_recentSearches.length > maxRecentSearches) {
      _recentSearches.removeLast();
    }

    // Persist to database (fire and forget)
    unawaited(_persistRecentSearchesToDatabase());
  }

  /// Persists the current in-memory recent searches list to the database.
  Future<void> _persistRecentSearchesToDatabase() async {
    try {
      // Clear existing entries and re-insert all current searches
      // This ensures database stays synchronized with in-memory list
      await _database.clearSearchHistory();

      for (final search in _recentSearches) {
        await _database.insertSearchHistory(
          query: search.query,
          timestamp: search.timestamp.toIso8601String(),
          resultCount: search.resultCount ?? 0,
        );
      }
    } on Object catch (_) {
      // Log error but don't throw - search history persistence is not critical
    }
  }

  /// Gets search suggestions based on a partial query.
  ///
  /// Returns suggestions from:
  /// 1. Recent searches matching the prefix
  /// 2. Document titles matching the prefix
  ///
  /// Example:
  /// ```dart
  /// final suggestions = await searchService.getSuggestions('inv');
  /// // Returns: ['invoice', 'investment report', ...]
  /// ```
  Future<List<String>> getSuggestions(
    String partialQuery, {
    int limit = 5,
  }) async {
    if (!_isInitialized) {
      throw const SearchException(
        'Search service not initialized. Call initialize() first.',
      );
    }

    final query = partialQuery.trim().toLowerCase();
    if (query.isEmpty) {
      // Return recent searches if no query
      return _recentSearches.take(limit).map((s) => s.query).toList();
    }

    final suggestions = <String>[];

    // Add matching recent searches
    for (final recent in _recentSearches) {
      if (recent.query.toLowerCase().startsWith(query)) {
        suggestions.add(recent.query);
        if (suggestions.length >= limit) break;
      }
    }

    // Add matching document titles
    if (suggestions.length < limit) {
      try {
        final results = await search(
          partialQuery,
          options: const SearchOptions.titlesOnly(limit: 10),
        );
        for (final result in results.results) {
          if (suggestions.length >= limit) break;
          final title = result.document.title;
          if (!suggestions.contains(title)) {
            suggestions.add(title);
          }
        }
      } on Object catch (_) {
        // Ignore errors in suggestions
      }
    }

    return suggestions.take(limit).toList();
  }

  /// Gets recent searches.
  ///
  /// Returns the list of recent searches, most recent first.
  ///
  /// Example:
  /// ```dart
  /// final recent = await searchService.getRecentSearches(limit: 10);
  /// for (final search in recent) {
  ///   print('${search.query} - ${search.resultCount} results');
  /// }
  /// ```
  Future<List<RecentSearch>> getRecentSearches({int limit = 10}) async {
    return _recentSearches.take(limit).toList();
  }

  /// Clears recent search history.
  Future<void> clearRecentSearches() async {
    _recentSearches.clear();

    // Delete from database
    try {
      await _database.clearSearchHistory();
    } on Object catch (_) {
      // Log error but don't throw - search history persistence is not critical
    }
  }

  /// Removes a specific search from history.
  Future<void> removeRecentSearch(String query) async {
    _recentSearches.removeWhere(
      (s) => s.query.toLowerCase() == query.toLowerCase(),
    );

    // Update database to reflect the removal
    await _persistRecentSearchesToDatabase();
  }

  /// Rebuilds the search index.
  ///
  /// Call this if search results seem inconsistent or after
  /// bulk document operations.
  ///
  /// Throws [SearchException] if rebuild fails.
  Future<void> rebuildIndex() async {
    if (!_isInitialized) {
      throw const SearchException(
        'Search service not initialized. Call initialize() first.',
      );
    }

    try {
      await _database.rebuildFtsIndex();
    } on Object catch (e) {
      throw SearchException(
        'Failed to rebuild search index',
        cause: e,
      );
    }
  }

  /// Gets the approximate size of the search index.
  ///
  /// Returns the size in bytes, or 0 if unable to determine.
  Future<int> getIndexSize() async {
    try {
      // FTS5 doesn't have a direct size query, return 0
      return 0;
    } on Object catch (_) {
      return 0;
    }
  }
}

/// Internal class for raw search results before document loading.
class _RawSearchResult {
  const _RawSearchResult({
    required this.documentId,
    this.title,
    this.description,
    this.ocrText,
    required this.score,
  });

  final String documentId;
  final String? title;
  final String? description;
  final String? ocrText;
  final double score;
}
