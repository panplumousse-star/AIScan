import 'dart:collection';

import 'package:flutter/foundation.dart';

// ============================================================================
// Image Cache Manager
// ============================================================================

/// LRU cache entry with metadata.
class _CacheEntry {
  _CacheEntry({
    required this.key,
    required this.bytes,
    required this.accessTime,
  });

  final String key;
  final Uint8List bytes;
  DateTime accessTime;

  int get sizeBytes => bytes.length;
}

/// Memory-efficient image cache with LRU eviction.
///
/// Automatically evicts least recently used images when cache limits
/// are exceeded. Designed for document thumbnail caching.
///
/// ## Usage
/// ```dart
/// final cache = ImageCacheManager(
///   maxSizeBytes: 50 * 1024 * 1024, // 50 MB
///   maxItems: 100,
/// );
///
/// // Store thumbnail
/// cache.put('doc-123-thumb', thumbnailBytes);
///
/// // Retrieve thumbnail
/// final cached = cache.get('doc-123-thumb');
/// ```
class ImageCacheManager {
  /// Creates an [ImageCacheManager] with the given limits.
  ImageCacheManager({required this.maxSizeBytes, required this.maxItems});

  /// Maximum cache size in bytes.
  final int maxSizeBytes;

  /// Maximum number of cached items.
  final int maxItems;

  final LinkedHashMap<String, _CacheEntry> _cache =
      LinkedHashMap<String, _CacheEntry>();

  int _currentSizeBytes = 0;

  /// Current cache size in bytes.
  int get currentSizeBytes => _currentSizeBytes;

  /// Current number of cached items.
  int get itemCount => _cache.length;

  /// Whether the cache is empty.
  bool get isEmpty => _cache.isEmpty;

  /// Whether the cache is at capacity.
  bool get isFull =>
      _currentSizeBytes >= maxSizeBytes || _cache.length >= maxItems;

  /// Cache utilization as a percentage.
  double get utilizationPercent => (currentSizeBytes / maxSizeBytes) * 100;

  /// Gets an image from the cache.
  ///
  /// Returns null if not found. Updates access time for LRU tracking.
  Uint8List? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    // Update access time for LRU
    entry.accessTime = DateTime.now();

    // Move to end to mark as recently used
    _cache.remove(key);
    _cache[key] = entry;

    return entry.bytes;
  }

  /// Checks if a key exists in the cache.
  bool containsKey(String key) => _cache.containsKey(key);

  /// Stores an image in the cache.
  ///
  /// Automatically evicts old entries if limits are exceeded.
  void put(String key, Uint8List bytes) {
    // Remove existing entry if present
    if (_cache.containsKey(key)) {
      _evict(key);
    }

    // Evict until we have space
    while (_currentSizeBytes + bytes.length > maxSizeBytes ||
        _cache.length >= maxItems) {
      if (_cache.isEmpty) break;
      _evictOldest();
    }

    // Add new entry
    final entry = _CacheEntry(
      key: key,
      bytes: bytes,
      accessTime: DateTime.now(),
    );

    _cache[key] = entry;
    _currentSizeBytes += bytes.length;
  }

  /// Removes an image from the cache.
  void remove(String key) {
    _evict(key);
  }

  /// Clears all cached images.
  void clear() {
    _cache.clear();
    _currentSizeBytes = 0;
  }

  /// Trims the cache to the given size limit.
  void trimToSize(int targetSizeBytes) {
    while (_currentSizeBytes > targetSizeBytes && _cache.isNotEmpty) {
      _evictOldest();
    }
  }

  void _evict(String key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _currentSizeBytes -= entry.sizeBytes;
    }
  }

  void _evictOldest() {
    if (_cache.isEmpty) return;

    // LinkedHashMap maintains insertion order, so first entry is oldest
    final oldestKey = _cache.keys.first;
    _evict(oldestKey);
  }

  @override
  String toString() => 'ImageCacheManager(items: $itemCount, '
      'size: ${(_currentSizeBytes / 1024 / 1024).toStringAsFixed(1)}MB/'
      '${(maxSizeBytes / 1024 / 1024).toStringAsFixed(1)}MB)';
}
