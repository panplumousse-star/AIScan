import 'dart:async';

// ============================================================================
// Lazy Loading Utilities
// ============================================================================

/// A lazy-loading helper for list items.
///
/// Provides pagination support and preloading for smooth scrolling.
///
/// ## Usage
/// ```dart
/// final lazyLoader = LazyLoader<Document>(
///   pageSize: 20,
///   loadPage: (offset, limit) async {
///     return await repository.getDocuments(offset: offset, limit: limit);
///   },
/// );
///
/// // Load initial data
/// await lazyLoader.loadMore();
///
/// // In scroll listener
/// if (lazyLoader.shouldLoadMore(scrollPosition)) {
///   await lazyLoader.loadMore();
/// }
/// ```
class LazyLoader<T> {
  /// Creates a [LazyLoader] with the given configuration.
  LazyLoader({
    required this.pageSize,
    required this.loadPage,
    this.preloadThreshold = 0.8,
  });

  /// Number of items per page.
  final int pageSize;

  /// Callback to load a page of items.
  final Future<List<T>> Function(int offset, int limit) loadPage;

  /// Scroll threshold (0-1) at which to trigger preloading.
  final double preloadThreshold;

  final List<T> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentOffset = 0;

  /// All loaded items.
  List<T> get items => List.unmodifiable(_items);

  /// Whether a load operation is in progress.
  bool get isLoading => _isLoading;

  /// Whether there are more items to load.
  bool get hasMore => _hasMore;

  /// Total number of loaded items.
  int get itemCount => _items.length;

  /// Loads the next page of items.
  ///
  /// Returns the newly loaded items.
  Future<List<T>> loadMore() async {
    if (_isLoading || !_hasMore) return [];

    _isLoading = true;

    try {
      final newItems = await loadPage(_currentOffset, pageSize);

      _items.addAll(newItems);
      _currentOffset += newItems.length;

      if (newItems.length < pageSize) {
        _hasMore = false;
      }

      return newItems;
    } finally {
      _isLoading = false;
    }
  }

  /// Reloads all data from the beginning.
  Future<List<T>> refresh() async {
    _items.clear();
    _currentOffset = 0;
    _hasMore = true;
    return loadMore();
  }

  /// Whether loading should be triggered based on scroll position.
  ///
  /// [currentIndex] is the index of the currently visible item.
  bool shouldLoadMore(int currentIndex) {
    if (!_hasMore || _isLoading) return false;
    return currentIndex >= _items.length * preloadThreshold;
  }

  /// Removes an item from the loaded list.
  void removeItem(T item) {
    _items.remove(item);
  }

  /// Removes an item at the given index.
  void removeAt(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
    }
  }

  /// Inserts an item at the given index.
  void insertAt(int index, T item) {
    if (index >= 0 && index <= _items.length) {
      _items.insert(index, item);
    }
  }

  /// Updates an item at the given index.
  void updateAt(int index, T item) {
    if (index >= 0 && index < _items.length) {
      _items[index] = item;
    }
  }

  /// Clears all loaded items.
  void clear() {
    _items.clear();
    _currentOffset = 0;
    _hasMore = true;
  }
}
