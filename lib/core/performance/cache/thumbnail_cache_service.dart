import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../device_performance.dart';
import 'image_cache_manager.dart';

// ============================================================================
// Thumbnail Cache Service
// ============================================================================

/// Riverpod provider for the thumbnail cache service.
///
/// Provides memory-efficient thumbnail caching with automatic eviction.
final thumbnailCacheProvider = Provider<ThumbnailCacheService>((ref) {
  final devicePerformance = ref.watch(devicePerformanceProvider);
  return ThumbnailCacheService(devicePerformance: devicePerformance);
});

/// Dedicated cache service for decrypted document thumbnails.
///
/// This service wraps [ImageCacheManager] to provide specialized caching
/// for decrypted thumbnail bytes. By caching decrypted thumbnails in memory,
/// we eliminate repeated decryption operations when navigating between screens.
///
/// The cache uses LRU (Least Recently Used) eviction and respects device-specific
/// memory limits to ensure smooth performance on low-end devices.
///
/// ## Usage
/// ```dart
/// final thumbnailCache = ref.read(thumbnailCacheProvider);
///
/// // Check if thumbnail is cached
/// final cached = thumbnailCache.getCachedThumbnail(document.id);
///
/// // Cache a decrypted thumbnail
/// thumbnailCache.cacheThumbnail(document.id, decryptedBytes);
///
/// // Remove specific thumbnail
/// thumbnailCache.removeThumbnail(document.id);
///
/// // Clear all cached thumbnails
/// thumbnailCache.clearCache();
/// ```
///
/// ## Cache Key Format
/// Thumbnails are stored with keys in the format: `thumb_{documentId}`
///
/// ## Memory Management
/// Cache size is automatically adjusted based on device tier:
/// - Low-end devices: 20 MB, 30 items
/// - Mid-range devices: 50 MB, 50 items
/// - High-end devices: 100 MB, 100 items
class ThumbnailCacheService {
  /// Creates a [ThumbnailCacheService] configured for the given device.
  ThumbnailCacheService({required DevicePerformance devicePerformance}) {
    final maxSize = devicePerformance.recommendedImageCacheSize;
    final maxItems = devicePerformance.maxCachedImages;

    _cache = ImageCacheManager(
      maxSizeBytes: maxSize,
      maxItems: maxItems,
    );
  }

  late final ImageCacheManager _cache;

  int _cacheHits = 0;
  int _cacheMisses = 0;

  /// Current cache size in bytes.
  int get currentSizeBytes => _cache.currentSizeBytes;

  /// Current number of cached thumbnails.
  int get itemCount => _cache.itemCount;

  /// Cache hit rate as a percentage (0-100).
  ///
  /// Returns 0 if no cache lookups have been performed.
  double get hitRate {
    final total = _cacheHits + _cacheMisses;
    if (total == 0) return 0;
    return (_cacheHits / total) * 100;
  }

  /// Total number of cache hits.
  int get cacheHits => _cacheHits;

  /// Total number of cache misses.
  int get cacheMisses => _cacheMisses;

  /// Whether the cache is empty.
  bool get isEmpty => _cache.isEmpty;

  /// Cache utilization as a percentage (0-100).
  double get utilizationPercent => _cache.utilizationPercent;

  /// Gets a cached thumbnail by document ID.
  ///
  /// Returns the decrypted thumbnail bytes if found in cache, or null
  /// if not cached. Updates access time for LRU tracking on cache hit.
  ///
  /// [docId] The document ID to look up.
  ///
  /// Returns the cached thumbnail bytes or null if not found.
  Uint8List? getCachedThumbnail(String docId) {
    final cacheKey = _buildCacheKey(docId);
    final bytes = _cache.get(cacheKey);

    if (bytes != null) {
      _cacheHits++;
    } else {
      _cacheMisses++;
    }

    return bytes;
  }

  /// Caches a decrypted thumbnail for a document.
  ///
  /// Stores the provided thumbnail bytes in the cache with the document ID
  /// as the key. Automatically evicts old entries if cache limits are exceeded.
  ///
  /// [docId] The document ID to associate with this thumbnail.
  /// [bytes] The decrypted thumbnail bytes to cache.
  void cacheThumbnail(String docId, Uint8List bytes) {
    final cacheKey = _buildCacheKey(docId);
    _cache.put(cacheKey, bytes);
  }

  /// Removes a thumbnail from the cache.
  ///
  /// Use this when a document is deleted or its thumbnail is updated.
  ///
  /// [docId] The document ID whose thumbnail should be removed.
  void removeThumbnail(String docId) {
    final cacheKey = _buildCacheKey(docId);
    _cache.remove(cacheKey);
  }

  /// Checks if a thumbnail is cached for the given document ID.
  ///
  /// [docId] The document ID to check.
  ///
  /// Returns true if the thumbnail is in the cache.
  bool hasCachedThumbnail(String docId) {
    final cacheKey = _buildCacheKey(docId);
    return _cache.containsKey(cacheKey);
  }

  /// Clears all cached thumbnails and resets statistics.
  ///
  /// Use this when:
  /// - User logs out
  /// - Memory warning is received
  /// - App goes to background (optional)
  void clearCache() {
    _cache.clear();
    _cacheHits = 0;
    _cacheMisses = 0;
  }

  /// Trims the cache to a specific size limit.
  ///
  /// Useful for responding to memory pressure warnings.
  ///
  /// [targetSizeBytes] The target cache size in bytes.
  void trimToSize(int targetSizeBytes) {
    _cache.trimToSize(targetSizeBytes);
  }

  /// Resets cache statistics without clearing cached items.
  void resetStatistics() {
    _cacheHits = 0;
    _cacheMisses = 0;
  }

  /// Builds the cache key for a document thumbnail.
  ///
  /// Format: `thumb_{documentId}`
  String _buildCacheKey(String docId) {
    return 'thumb_$docId';
  }

  @override
  String toString() => 'ThumbnailCacheService(items: $itemCount, '
      'size: ${(currentSizeBytes / 1024 / 1024).toStringAsFixed(1)}MB, '
      'hitRate: ${hitRate.toStringAsFixed(1)}%)';
}
