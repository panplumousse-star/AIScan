import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../device_performance.dart';

// ============================================================================
// Image Cache Manager Provider
// ============================================================================

/// Riverpod provider for the image cache manager.
///
/// Provides memory-efficient image caching with automatic eviction.
final imageCacheManagerProvider = Provider<ImageCacheManager>((ref) {
  final devicePerformance = ref.watch(devicePerformanceProvider);
  return ImageCacheManager(
    maxSizeBytes: devicePerformance.recommendedImageCacheSize,
    maxItems: devicePerformance.isLowEndDevice ? 50 : 100,
  );
});

/// Riverpod provider for the thumbnail cache service.
///
/// Provides memory-efficient thumbnail caching with automatic eviction.
final thumbnailCacheProvider = Provider<ThumbnailCacheService>((ref) {
  final devicePerformance = ref.watch(devicePerformanceProvider);
  return ThumbnailCacheService(devicePerformance: devicePerformance);
});

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
/// final cache = ref.read(imageCacheManagerProvider);
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

// ============================================================================
// Thumbnail Cache Service
// ============================================================================

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

// ============================================================================
// Image Optimization
// ============================================================================

/// Utility class for optimizing images for display.
///
/// Provides methods to calculate optimal image sizes based on
/// device capabilities and display requirements.
abstract final class ImageOptimization {
  /// Calculates optimal image dimensions for display.
  ///
  /// Takes into account device pixel ratio and target container size.
  static Size calculateOptimalSize({
    required int originalWidth,
    required int originalHeight,
    required double containerWidth,
    required double containerHeight,
    required double devicePixelRatio,
    DevicePerformance? devicePerformance,
  }) {
    // Adjust pixel ratio for low-end devices
    double effectiveRatio = devicePixelRatio;
    if (devicePerformance?.isLowEndDevice ?? false) {
      effectiveRatio = devicePixelRatio.clamp(1.0, 2.0);
    }

    // Calculate target dimensions
    final targetWidth = (containerWidth * effectiveRatio).round();
    final targetHeight = (containerHeight * effectiveRatio).round();

    // Maintain aspect ratio
    final aspectRatio = originalWidth / originalHeight;
    final containerAspectRatio = targetWidth / targetHeight;

    int finalWidth, finalHeight;

    if (aspectRatio > containerAspectRatio) {
      // Image is wider, fit to width
      finalWidth = targetWidth;
      finalHeight = (targetWidth / aspectRatio).round();
    } else {
      // Image is taller, fit to height
      finalHeight = targetHeight;
      finalWidth = (targetHeight * aspectRatio).round();
    }

    // Apply maximum dimension limit
    final maxDim = devicePerformance?.maxImageDimension ?? 4000;
    if (finalWidth > maxDim || finalHeight > maxDim) {
      if (finalWidth > finalHeight) {
        finalHeight = (finalHeight * maxDim / finalWidth).round();
        finalWidth = maxDim;
      } else {
        finalWidth = (finalWidth * maxDim / finalHeight).round();
        finalHeight = maxDim;
      }
    }

    return Size(finalWidth.toDouble(), finalHeight.toDouble());
  }

  /// Calculates the optimal thumbnail size for a document grid.
  static int calculateThumbnailSize({
    required double gridWidth,
    required int crossAxisCount,
    required double spacing,
    required double devicePixelRatio,
    DevicePerformance? devicePerformance,
  }) {
    // Calculate item width
    final totalSpacing = spacing * (crossAxisCount - 1);
    final itemWidth = (gridWidth - totalSpacing) / crossAxisCount;

    // Apply device pixel ratio
    double effectiveRatio = devicePixelRatio;
    if (devicePerformance?.isLowEndDevice ?? false) {
      effectiveRatio = effectiveRatio.clamp(1.0, 1.5);
    }

    final targetSize = (itemWidth * effectiveRatio).round();

    // Apply max limit
    final maxSize = devicePerformance?.recommendedThumbnailSize ?? 300;
    return targetSize.clamp(100, maxSize);
  }
}

// ============================================================================
// Optimized Widgets
// ============================================================================

/// An optimized image widget that adapts quality based on device.
///
/// Automatically adjusts caching, decode size, and quality based
/// on device capabilities detected by [DevicePerformance].
class OptimizedImage extends ConsumerWidget {
  /// Creates an [OptimizedImage] from a file path.
  const OptimizedImage.file({
    required this.filePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    super.key,
  }) : imageBytes = null;

  /// Creates an [OptimizedImage] from bytes.
  const OptimizedImage.memory({
    required this.imageBytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    super.key,
  }) : filePath = null;

  /// Path to the image file.
  final String? filePath;

  /// Image bytes.
  final Uint8List? imageBytes;

  /// Target width.
  final double? width;

  /// Target height.
  final double? height;

  /// How to inscribe the image.
  final BoxFit fit;

  /// Widget to show while loading.
  final Widget? placeholder;

  /// Widget to show on error.
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicePerformance = ref.watch(devicePerformanceProvider);
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Calculate decode size based on device capabilities
    int? cacheWidth, cacheHeight;
    if (width != null && height != null) {
      final optimalSize = ImageOptimization.calculateOptimalSize(
        originalWidth: 4000, // Assume large original
        originalHeight: 4000,
        containerWidth: width!,
        containerHeight: height!,
        devicePixelRatio: pixelRatio,
        devicePerformance: devicePerformance,
      );
      cacheWidth = optimalSize.width.round();
      cacheHeight = optimalSize.height.round();
    }

    // Build image widget
    Widget image;

    if (filePath != null) {
      image = Image.file(
        File(filePath!),
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ??
              Container(
                width: width,
                height: height,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              );
        },
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: frame == null
                ? (placeholder ??
                    Container(
                      width: width,
                      height: height,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ))
                : child,
          );
        },
      );
    } else if (imageBytes != null) {
      image = Image.memory(
        imageBytes!,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ??
              Container(
                width: width,
                height: height,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              );
        },
      );
    } else {
      // Fallback
      image = Container(
        width: width,
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      );
    }

    // Add repaint boundary for performance
    return RepaintBoundary(child: image);
  }
}
