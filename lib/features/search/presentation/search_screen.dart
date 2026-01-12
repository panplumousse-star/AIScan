import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../documents/domain/document_model.dart';
import '../domain/search_service.dart';

/// State for the search screen.
///
/// Tracks the current search query, results, and UI state.
@immutable
class SearchScreenState {
  /// Creates a [SearchScreenState] with default values.
  const SearchScreenState({
    this.query = '',
    this.results,
    this.suggestions = const [],
    this.recentSearches = const [],
    this.isSearching = false,
    this.isLoadingMore = false,
    this.isInitialized = false,
    this.error,
    this.showFilters = false,
    this.options = const SearchOptions.defaults(),
  });

  /// The current search query.
  final String query;

  /// Search results, or null if no search has been performed.
  final SearchResults? results;

  /// Search suggestions based on partial query.
  final List<String> suggestions;

  /// Recent search history.
  final List<RecentSearch> recentSearches;

  /// Whether a search is currently in progress.
  final bool isSearching;

  /// Whether more results are being loaded (pagination).
  final bool isLoadingMore;

  /// Whether the search service has been initialized.
  final bool isInitialized;

  /// Error message, if any.
  final String? error;

  /// Whether the filter options are visible.
  final bool showFilters;

  /// Current search options/filters.
  final SearchOptions options;

  /// Whether we have search results.
  bool get hasResults => results != null && results!.hasResults;

  /// Whether the search returned empty results.
  bool get isEmpty =>
      results != null && results!.results.isEmpty && query.isNotEmpty;

  /// Whether we have suggestions to show.
  bool get hasSuggestions => suggestions.isNotEmpty;

  /// Whether we have recent searches to show.
  bool get hasRecentSearches => recentSearches.isNotEmpty;

  /// Whether we're in any loading state.
  bool get isLoading => isSearching || isLoadingMore;

  /// Whether more results are available for pagination.
  bool get hasMore => results?.hasMore ?? false;

  /// Whether we should show the initial state (no query).
  bool get showInitialState => query.isEmpty && results == null;

  /// Creates a copy with updated values.
  SearchScreenState copyWith({
    String? query,
    SearchResults? results,
    List<String>? suggestions,
    List<RecentSearch>? recentSearches,
    bool? isSearching,
    bool? isLoadingMore,
    bool? isInitialized,
    String? error,
    bool? showFilters,
    SearchOptions? options,
    bool clearResults = false,
    bool clearError = false,
    bool clearSuggestions = false,
  }) {
    return SearchScreenState(
      query: query ?? this.query,
      results: clearResults ? null : (results ?? this.results),
      suggestions:
          clearSuggestions ? const [] : (suggestions ?? this.suggestions),
      recentSearches: recentSearches ?? this.recentSearches,
      isSearching: isSearching ?? this.isSearching,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isInitialized: isInitialized ?? this.isInitialized,
      error: clearError ? null : (error ?? this.error),
      showFilters: showFilters ?? this.showFilters,
      options: options ?? this.options,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchScreenState &&
        other.query == query &&
        other.results == results &&
        other.isSearching == isSearching &&
        other.isLoadingMore == isLoadingMore &&
        other.isInitialized == isInitialized &&
        other.error == error &&
        other.showFilters == showFilters &&
        other.options == options;
  }

  @override
  int get hashCode => Object.hash(
        query,
        results,
        isSearching,
        isLoadingMore,
        isInitialized,
        error,
        showFilters,
        options,
      );
}

/// State notifier for the search screen.
///
/// Manages search operations, suggestions, and history.
class SearchScreenNotifier extends StateNotifier<SearchScreenState> {
  /// Creates a [SearchScreenNotifier] with the given search service.
  SearchScreenNotifier(this._searchService)
      : super(const SearchScreenState());

  final SearchService _searchService;
  Timer? _debounceTimer;

  /// Duration to wait before performing search after typing.
  static const _searchDebounce = Duration(milliseconds: 400);

  /// Duration to wait before fetching suggestions.
  static const _suggestionsDebounce = Duration(milliseconds: 200);

  /// Initializes the search service and loads recent searches.
  Future<void> initialize() async {
    if (state.isInitialized) return;

    try {
      await _searchService.initialize();

      final recent = await _searchService.getRecentSearches(limit: 10);

      state = state.copyWith(
        isInitialized: true,
        recentSearches: recent,
      );
    } on SearchException catch (e) {
      state = state.copyWith(
        isInitialized: false,
        error: 'Failed to initialize search: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        isInitialized: false,
        error: 'Failed to initialize search: $e',
      );
    }
  }

  /// Updates the search query and triggers search.
  void setQuery(String query) {
    final trimmedQuery = query.trim();
    state = state.copyWith(query: query);

    _debounceTimer?.cancel();

    if (trimmedQuery.isEmpty) {
      state = state.copyWith(
        clearResults: true,
        clearSuggestions: true,
      );
      return;
    }

    // Fetch suggestions quickly
    _debounceTimer = Timer(_suggestionsDebounce, () {
      _fetchSuggestions(trimmedQuery);
    });

    // Perform full search with longer debounce
    _debounceTimer = Timer(_searchDebounce, () {
      performSearch();
    });
  }

  /// Performs a search with the current query.
  Future<void> performSearch({bool loadMore = false}) async {
    if (!state.isInitialized) return;

    final query = state.query.trim();
    if (query.isEmpty) return;

    if (loadMore) {
      state = state.copyWith(isLoadingMore: true, clearError: true);
    } else {
      state = state.copyWith(
        isSearching: true,
        clearError: true,
        clearSuggestions: true,
      );
    }

    try {
      final options = loadMore
          ? state.options.copyWith(
              offset: state.results?.count ?? 0,
            )
          : state.options.copyWith(offset: 0);

      final results = await _searchService.search(query, options: options);

      if (loadMore && state.results != null) {
        // Append to existing results
        final combinedResults = SearchResults(
          query: results.query,
          results: [...state.results!.results, ...results.results],
          totalCount: results.totalCount,
          searchTimeMs: results.searchTimeMs,
          options: results.options,
        );
        state = state.copyWith(
          results: combinedResults,
          isLoadingMore: false,
        );
      } else {
        state = state.copyWith(
          results: results,
          isSearching: false,
        );
      }

      // Update recent searches
      final recent = await _searchService.getRecentSearches(limit: 10);
      state = state.copyWith(recentSearches: recent);
    } on SearchException catch (e) {
      state = state.copyWith(
        isSearching: false,
        isLoadingMore: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isSearching: false,
        isLoadingMore: false,
        error: 'Search failed: $e',
      );
    }
  }

  /// Fetches search suggestions for the current query.
  Future<void> _fetchSuggestions(String query) async {
    if (!state.isInitialized || query.isEmpty) return;

    try {
      final suggestions = await _searchService.getSuggestions(query);
      state = state.copyWith(suggestions: suggestions);
    } catch (_) {
      // Silently ignore suggestion errors
    }
  }

  /// Selects a suggestion and performs search.
  void selectSuggestion(String suggestion) {
    state = state.copyWith(
      query: suggestion,
      clearSuggestions: true,
    );
    performSearch();
  }

  /// Selects a recent search and performs search.
  void selectRecentSearch(RecentSearch recent) {
    state = state.copyWith(
      query: recent.query,
      clearSuggestions: true,
    );
    performSearch();
  }

  /// Clears a recent search from history.
  Future<void> clearRecentSearch(String query) async {
    await _searchService.removeRecentSearch(query);
    final recent = await _searchService.getRecentSearches(limit: 10);
    state = state.copyWith(recentSearches: recent);
  }

  /// Clears all recent searches.
  Future<void> clearAllRecentSearches() async {
    await _searchService.clearRecentSearches();
    state = state.copyWith(recentSearches: []);
  }

  /// Toggles filter visibility.
  void toggleFilters() {
    state = state.copyWith(showFilters: !state.showFilters);
  }

  /// Updates search options and re-runs search.
  void setOptions(SearchOptions options) {
    state = state.copyWith(options: options);
    if (state.query.isNotEmpty) {
      performSearch();
    }
  }

  /// Updates a specific filter option.
  void setFavoritesOnly(bool value) {
    setOptions(state.options.copyWith(favoritesOnly: value));
  }

  /// Updates the match mode option.
  void setMatchMode(SearchMatchMode mode) {
    setOptions(state.options.copyWith(matchMode: mode));
  }

  /// Updates the sort option.
  void setSortBy(SearchSortBy sortBy) {
    setOptions(state.options.copyWith(sortBy: sortBy));
  }

  /// Clears the current search.
  void clearSearch() {
    _debounceTimer?.cancel();
    state = state.copyWith(
      query: '',
      clearResults: true,
      clearSuggestions: true,
      clearError: true,
    );
  }

  /// Clears the current error.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Riverpod provider for the search screen state.
final searchScreenProvider =
    StateNotifierProvider.autoDispose<SearchScreenNotifier, SearchScreenState>(
  (ref) {
    final searchService = ref.watch(searchServiceProvider);
    return SearchScreenNotifier(searchService);
  },
);

/// Search screen with query input and results list.
///
/// Provides a comprehensive search interface with:
/// - Real-time search with debouncing
/// - Search suggestions and history
/// - Filter options (favorites only, match mode, sort)
/// - Results list with document previews and snippets
/// - Pagination for large result sets
///
/// ## Usage
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => SearchScreen(
///       onDocumentSelected: (document) {
///         // Navigate to document detail
///       },
///     ),
///   ),
/// );
/// ```
class SearchScreen extends ConsumerStatefulWidget {
  /// Creates a [SearchScreen].
  const SearchScreen({
    super.key,
    this.onDocumentSelected,
    this.initialQuery,
    this.autoFocus = true,
  });

  /// Callback invoked when a document is selected from results.
  final void Function(Document document)? onDocumentSelected;

  /// Initial search query to populate.
  final String? initialQuery;

  /// Whether to auto-focus the search field.
  final bool autoFocus;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Set up scroll listener for pagination
    _scrollController.addListener(_onScroll);

    // Initialize after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    final notifier = ref.read(searchScreenProvider.notifier);
    await notifier.initialize();

    // Set initial query if provided
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      notifier.setQuery(widget.initialQuery!);
    }

    // Auto-focus if requested
    if (widget.autoFocus && mounted) {
      _searchFocusNode.requestFocus();
    }
  }

  void _onScroll() {
    final state = ref.read(searchScreenProvider);
    if (state.hasMore && !state.isLoadingMore) {
      // Check if we're near the bottom
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(searchScreenProvider.notifier).performSearch(loadMore: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchScreenProvider);
    final notifier = ref.read(searchScreenProvider.notifier);
    final theme = Theme.of(context);

    // Listen for errors and show snackbar
    ref.listen<SearchScreenState>(searchScreenProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: notifier.clearError,
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: _SearchBar(
          controller: _searchController,
          focusNode: _searchFocusNode,
          isSearching: state.isSearching,
          onChanged: notifier.setQuery,
          onClear: () {
            _searchController.clear();
            notifier.clearSearch();
          },
          onBack: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: state.options.favoritesOnly ||
                  state.options.matchMode != SearchMatchMode.prefix,
              smallSize: 8,
              child: const Icon(Icons.tune),
            ),
            onPressed: () => _showFiltersSheet(context, state, notifier),
            tooltip: 'Search filters',
          ),
        ],
      ),
      body: _buildBody(context, state, notifier, theme),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SearchScreenState state,
    SearchScreenNotifier notifier,
    ThemeData theme,
  ) {
    if (!state.isInitialized && !state.isSearching) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Show suggestions if we have them
    if (state.hasSuggestions && state.query.isNotEmpty) {
      return _SuggestionsList(
        suggestions: state.suggestions,
        onSelect: notifier.selectSuggestion,
        theme: theme,
      );
    }

    // Show initial state with recent searches
    if (state.showInitialState) {
      return _InitialView(
        recentSearches: state.recentSearches,
        onSelectRecent: notifier.selectRecentSearch,
        onClearRecent: notifier.clearRecentSearch,
        onClearAll: notifier.clearAllRecentSearches,
        theme: theme,
      );
    }

    // Show loading state
    if (state.isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching...'),
          ],
        ),
      );
    }

    // Show empty state
    if (state.isEmpty) {
      return _EmptyResultsView(
        query: state.query,
        theme: theme,
      );
    }

    // Show results
    if (state.hasResults) {
      return _ResultsList(
        results: state.results!,
        isLoadingMore: state.isLoadingMore,
        scrollController: _scrollController,
        onDocumentTap: (result) {
          widget.onDocumentSelected?.call(result.document);
        },
        theme: theme,
      );
    }

    return const SizedBox.shrink();
  }

  void _showFiltersSheet(
    BuildContext context,
    SearchScreenState state,
    SearchScreenNotifier notifier,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FiltersSheet(
        options: state.options,
        onOptionsChanged: notifier.setOptions,
      ),
    );
  }
}

/// Search bar widget with text field and actions.
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.onChanged,
    required this.onClear,
    required this.onBack,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 48,
      margin: const EdgeInsets.only(left: 8),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack,
            tooltip: 'Back',
          ),

          // Search field
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search documents...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: onClear,
                        tooltip: 'Clear search',
                      )
                    : null,
              ),
              style: theme.textTheme.bodyLarge,
              onChanged: onChanged,
              onSubmitted: (_) {}, // Handled by onChanged with debounce
            ),
          ),

          // Loading indicator
          if (isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}

/// Suggestions list widget.
class _SuggestionsList extends StatelessWidget {
  const _SuggestionsList({
    required this.suggestions,
    required this.onSelect,
    required this.theme,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSelect;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return ListTile(
          leading: Icon(
            Icons.search,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          title: Text(suggestion),
          onTap: () => onSelect(suggestion),
          trailing: IconButton(
            icon: const Icon(Icons.north_west, size: 18),
            onPressed: () => onSelect(suggestion),
            tooltip: 'Use suggestion',
          ),
        );
      },
    );
  }
}

/// Initial view showing recent searches.
class _InitialView extends StatelessWidget {
  const _InitialView({
    required this.recentSearches,
    required this.onSelectRecent,
    required this.onClearRecent,
    required this.onClearAll,
    required this.theme,
  });

  final List<RecentSearch> recentSearches;
  final void Function(RecentSearch) onSelectRecent;
  final void Function(String) onClearRecent;
  final VoidCallback onClearAll;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (recentSearches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Search your documents',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Find documents by title, description,\nor extracted text content.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent searches',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              TextButton(
                onPressed: onClearAll,
                child: const Text('Clear all'),
              ),
            ],
          ),
        ),

        // Recent searches list
        Expanded(
          child: ListView.builder(
            itemCount: recentSearches.length,
            itemBuilder: (context, index) {
              final recent = recentSearches[index];
              return ListTile(
                leading: Icon(
                  Icons.history,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(recent.query),
                subtitle: recent.resultCount != null
                    ? Text(
                        '${recent.resultCount} results',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onClearRecent(recent.query),
                  tooltip: 'Remove from history',
                ),
                onTap: () => onSelectRecent(recent),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Empty results view.
class _EmptyResultsView extends StatelessWidget {
  const _EmptyResultsView({
    required this.query,
    required this.theme,
  });

  final String query;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No documents match "$query".\nTry different keywords or check your filters.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Results list widget.
class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.results,
    required this.isLoadingMore,
    required this.scrollController,
    required this.onDocumentTap,
    required this.theme,
  });

  final SearchResults results;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final void Function(SearchResult) onDocumentTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results header
        _ResultsHeader(
          count: results.count,
          totalCount: results.totalCount,
          searchTimeMs: results.searchTimeMs,
          theme: theme,
        ),

        // Results list
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: results.results.length + (isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= results.results.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final result = results.results[index];
              return _SearchResultCard(
                result: result,
                onTap: () => onDocumentTap(result),
                theme: theme,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Results header showing count and search time.
class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.count,
    required this.totalCount,
    required this.searchTimeMs,
    required this.theme,
  });

  final int count;
  final int totalCount;
  final int searchTimeMs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            totalCount == count
                ? '$totalCount results'
                : 'Showing $count of $totalCount results',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            '${searchTimeMs}ms',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual search result card.
class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.result,
    required this.onTap,
    required this.theme,
  });

  final SearchResult result;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final document = result.document;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail or placeholder
              _DocumentThumbnail(
                thumbnailPath: document.thumbnailPath,
                theme: theme,
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            document.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (document.isFavorite)
                          Icon(
                            Icons.star,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Matched fields badges
                    if (result.matchedFields.isNotEmpty)
                      _MatchedFieldsBadges(
                        fields: result.matchedFields,
                        theme: theme,
                      ),

                    // Preview/snippet
                    if (result.snippets.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _SnippetText(
                          snippet: result.snippets.first,
                          theme: theme,
                        ),
                      )
                    else if (result.preview.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          result.preview,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    // Metadata row
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Text(
                            document.fileSizeFormatted,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (document.pageCount > 1) ...[
                            Icon(
                              Icons.layers_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${document.pageCount} pages',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (document.hasOcrText)
                            Icon(
                              Icons.text_snippet_outlined,
                              size: 14,
                              color: theme.colorScheme.primary.withOpacity(0.7),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Document thumbnail widget.
class _DocumentThumbnail extends StatelessWidget {
  const _DocumentThumbnail({
    required this.thumbnailPath,
    required this.theme,
  });

  final String? thumbnailPath;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 72,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: thumbnailPath != null && File(thumbnailPath!).existsSync()
          ? Image.file(
              File(thumbnailPath!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholder();
              },
            )
          : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.description_outlined,
        size: 28,
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
      ),
    );
  }
}

/// Matched fields badges widget.
class _MatchedFieldsBadges extends StatelessWidget {
  const _MatchedFieldsBadges({
    required this.fields,
    required this.theme,
  });

  final List<String> fields;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: fields.map((field) {
        final label = _getFieldLabel(field);
        final icon = _getFieldIcon(field);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _getFieldLabel(String field) {
    switch (field) {
      case 'title':
        return 'Title';
      case 'description':
        return 'Description';
      case 'ocr_text':
        return 'Text';
      default:
        return field;
    }
  }

  IconData _getFieldIcon(String field) {
    switch (field) {
      case 'title':
        return Icons.title;
      case 'description':
        return Icons.notes;
      case 'ocr_text':
        return Icons.text_snippet_outlined;
      default:
        return Icons.label;
    }
  }
}

/// Snippet text with optional highlighting.
class _SnippetText extends StatelessWidget {
  const _SnippetText({
    required this.snippet,
    required this.theme,
  });

  final SearchSnippet snippet;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (snippet.highlights.isEmpty) {
      return Text(
        snippet.text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Build highlighted text
    final spans = <TextSpan>[];
    var currentIndex = 0;
    final text = snippet.text;

    for (final highlight in snippet.highlights) {
      if (highlight.length != 2) continue;
      final start = highlight[0].clamp(0, text.length);
      final end = highlight[1].clamp(0, text.length);

      // Add text before highlight
      if (start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, start),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ));
      }

      // Add highlighted text
      if (end > start) {
        spans.add(TextSpan(
          text: text.substring(start, end),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface,
            backgroundColor:
                theme.colorScheme.primaryContainer.withOpacity(0.5),
            fontWeight: FontWeight.w600,
          ),
        ));
      }

      currentIndex = end;
    }

    // Add remaining text
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Filters bottom sheet.
class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({
    required this.options,
    required this.onOptionsChanged,
  });

  final SearchOptions options;
  final void Function(SearchOptions) onOptionsChanged;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late SearchMatchMode _matchMode;
  late SearchSortBy _sortBy;
  late bool _favoritesOnly;
  late bool _hasOcrOnly;
  late bool _sortDescending;

  @override
  void initState() {
    super.initState();
    _matchMode = widget.options.matchMode;
    _sortBy = widget.options.sortBy;
    _favoritesOnly = widget.options.favoritesOnly;
    _hasOcrOnly = widget.options.hasOcrOnly;
    _sortDescending = widget.options.sortDescending;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Search Filters',
                  style: theme.textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Match mode
            Text(
              'Match Mode',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SearchMatchMode.values.map((mode) {
                return FilterChip(
                  label: Text(_getMatchModeLabel(mode)),
                  selected: _matchMode == mode,
                  onSelected: (_) {
                    setState(() => _matchMode = mode);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Sort by
            Text(
              'Sort By',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SearchSortBy.values.map((sort) {
                return FilterChip(
                  label: Text(_getSortByLabel(sort)),
                  selected: _sortBy == sort,
                  onSelected: (_) {
                    setState(() => _sortBy = sort);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Toggles
            SwitchListTile(
              title: const Text('Favorites only'),
              value: _favoritesOnly,
              onChanged: (value) {
                setState(() => _favoritesOnly = value);
              },
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Documents with OCR text only'),
              value: _hasOcrOnly,
              onChanged: (value) {
                setState(() => _hasOcrOnly = value);
              },
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Sort descending'),
              value: _sortDescending,
              onChanged: (value) {
                setState(() => _sortDescending = value);
              },
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _matchMode = SearchMatchMode.prefix;
                        _sortBy = SearchSortBy.relevance;
                        _favoritesOnly = false;
                        _hasOcrOnly = false;
                        _sortDescending = true;
                      });
                    },
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final options = widget.options.copyWith(
                        matchMode: _matchMode,
                        sortBy: _sortBy,
                        favoritesOnly: _favoritesOnly,
                        hasOcrOnly: _hasOcrOnly,
                        sortDescending: _sortDescending,
                      );
                      widget.onOptionsChanged(options);
                      Navigator.pop(context);
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getMatchModeLabel(SearchMatchMode mode) {
    switch (mode) {
      case SearchMatchMode.prefix:
        return 'Prefix';
      case SearchMatchMode.phrase:
        return 'Phrase';
      case SearchMatchMode.allWords:
        return 'All Words';
      case SearchMatchMode.anyWord:
        return 'Any Word';
    }
  }

  String _getSortByLabel(SearchSortBy sortBy) {
    switch (sortBy) {
      case SearchSortBy.relevance:
        return 'Relevance';
      case SearchSortBy.title:
        return 'Title';
      case SearchSortBy.createdAt:
        return 'Created';
      case SearchSortBy.updatedAt:
        return 'Updated';
      case SearchSortBy.fileSize:
        return 'Size';
    }
  }
}
