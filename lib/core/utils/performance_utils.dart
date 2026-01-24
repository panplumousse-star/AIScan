import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// Device Performance Provider
// ============================================================================

/// Riverpod provider for device performance detection.
///
/// Provides a singleton instance that detects device capabilities
/// and returns appropriate performance settings.
final devicePerformanceProvider = Provider<DevicePerformance>((ref) {
  return DevicePerformance();
});

/// Riverpod provider for the performance monitor.
///
/// Provides frame rate monitoring and jank detection.
final performanceMonitorProvider = Provider<PerformanceMonitor>((ref) {
  return PerformanceMonitor();
});

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

// ============================================================================
// Device Performance Detection
// ============================================================================

/// Performance tier classification for devices.
///
/// Used to adapt UI complexity, image quality, and animations
/// based on device capabilities.
enum DeviceTier {
  /// Low-end device: <3GB RAM, single/dual core
  ///
  /// Requires aggressive optimizations:
  /// - Reduced animations
  /// - Lower image quality
  /// - Smaller caches
  low,

  /// Mid-range device: 3-6GB RAM, quad core
  ///
  /// Standard optimizations:
  /// - Normal animations
  /// - Standard image quality
  /// - Normal cache sizes
  medium,

  /// High-end device: >6GB RAM, octa core
  ///
  /// Full features enabled:
  /// - Rich animations
  /// - High image quality
  /// - Large caches
  high,
}

/// Detects device performance capabilities and provides appropriate settings.
///
/// This class analyzes device characteristics to determine optimal settings
/// for animations, image processing, and caching. Used throughout the app
/// to ensure smooth performance on low-end devices.
///
/// ## Usage
/// ```dart
/// final devicePerformance = ref.read(devicePerformanceProvider);
/// if (devicePerformance.isLowEndDevice) {
///   // Use simplified UI
/// }
/// ```
class DevicePerformance {
  /// Creates a [DevicePerformance] instance.
  DevicePerformance() {
    _detectCapabilities();
  }

  late DeviceTier _tier;
  late int _processorCount;
  late int _estimatedRamMB;
  bool _capabilitiesDetected = false;

  /// The detected device tier.
  DeviceTier get tier => _tier;

  /// Number of processor cores.
  int get processorCount => _processorCount;

  /// Estimated RAM in megabytes.
  int get estimatedRamMB => _estimatedRamMB;

  /// Whether the device is classified as low-end.
  bool get isLowEndDevice => _tier == DeviceTier.low;

  /// Whether the device is classified as mid-range.
  bool get isMidRangeDevice => _tier == DeviceTier.medium;

  /// Whether the device is classified as high-end.
  bool get isHighEndDevice => _tier == DeviceTier.high;

  /// Recommended animation duration multiplier.
  ///
  /// Low-end devices get shorter animations to prevent jank.
  double get animationDurationMultiplier {
    switch (_tier) {
      case DeviceTier.low:
        return 0.5;
      case DeviceTier.medium:
        return 0.8;
      case DeviceTier.high:
        return 1.0;
    }
  }

  /// Whether complex animations should be enabled.
  ///
  /// Disables animations like parallax, physics-based springs,
  /// and particle effects on low-end devices.
  bool get enableComplexAnimations => _tier != DeviceTier.low;

  /// Whether page transitions should be animated.
  bool get enablePageTransitions => _tier != DeviceTier.low;

  /// Recommended thumbnail size in pixels.
  ///
  /// Lower resolution thumbnails for low-end devices to reduce
  /// memory usage and improve scrolling performance.
  int get recommendedThumbnailSize {
    switch (_tier) {
      case DeviceTier.low:
        return 150;
      case DeviceTier.medium:
        return 200;
      case DeviceTier.high:
        return 200;
    }
  }

  /// Recommended JPEG quality for thumbnails (0-100).
  int get recommendedThumbnailQuality {
    switch (_tier) {
      case DeviceTier.low:
        return 60;
      case DeviceTier.medium:
        return 75;
      case DeviceTier.high:
        return 85;
    }
  }

  /// Maximum image dimension before auto-downscaling.
  ///
  /// Images larger than this will be downscaled during processing
  /// to prevent out-of-memory errors.
  int get maxImageDimension {
    switch (_tier) {
      case DeviceTier.low:
        return 2000;
      case DeviceTier.medium:
        return 3000;
      case DeviceTier.high:
        return 4000;
    }
  }

  /// Recommended image cache size in bytes.
  int get recommendedImageCacheSize {
    switch (_tier) {
      case DeviceTier.low:
        return 20 * 1024 * 1024; // 20 MB
      case DeviceTier.medium:
        return 50 * 1024 * 1024; // 50 MB
      case DeviceTier.high:
        return 100 * 1024 * 1024; // 100 MB
    }
  }

  /// Maximum number of cached images.
  int get maxCachedImages {
    switch (_tier) {
      case DeviceTier.low:
        return 30;
      case DeviceTier.medium:
        return 50;
      case DeviceTier.high:
        return 100;
    }
  }

  /// Recommended number of items to preload in lists.
  int get listPreloadCount {
    switch (_tier) {
      case DeviceTier.low:
        return 2;
      case DeviceTier.medium:
        return 3;
      case DeviceTier.high:
        return 5;
    }
  }

  /// Whether to use isolates for heavy computations.
  ///
  /// On very low-end devices, isolate overhead may be too costly.
  bool get useIsolates => _processorCount >= 4;

  /// Recommended debounce duration for search/filter operations.
  Duration get searchDebounce {
    switch (_tier) {
      case DeviceTier.low:
        return const Duration(milliseconds: 500);
      case DeviceTier.medium:
        return const Duration(milliseconds: 400);
      case DeviceTier.high:
        return const Duration(milliseconds: 300);
    }
  }

  /// Recommended scroll physics for lists.
  ScrollPhysics get recommendedScrollPhysics {
    if (_tier == DeviceTier.low) {
      // Clamp to prevent overscroll which requires extra rendering
      return const ClampingScrollPhysics();
    }
    return const BouncingScrollPhysics();
  }

  void _detectCapabilities() {
    if (_capabilitiesDetected) return;

    // Detect processor count
    _processorCount = Platform.numberOfProcessors;

    // Estimate RAM based on platform heuristics
    // Note: Direct RAM query not available in Flutter
    // Using processor count as a proxy
    if (_processorCount <= 2) {
      _estimatedRamMB = 2048; // 2GB assumption for low-core devices
    } else if (_processorCount <= 4) {
      _estimatedRamMB = 4096; // 4GB assumption for quad-core
    } else {
      _estimatedRamMB = 8192; // 8GB assumption for high-core devices
    }

    // Classify device tier
    if (_processorCount <= 2 || _estimatedRamMB <= 2048) {
      _tier = DeviceTier.low;
    } else if (_processorCount <= 4 || _estimatedRamMB <= 4096) {
      _tier = DeviceTier.medium;
    } else {
      _tier = DeviceTier.high;
    }

    _capabilitiesDetected = true;
  }

  @override
  String toString() => 'DevicePerformance(tier: $_tier, '
      'cores: $_processorCount, estimatedRAM: ${_estimatedRamMB}MB)';
}

// ============================================================================
// Performance Monitor
// ============================================================================

/// Monitors frame rate and detects jank during rendering.
///
/// Use this to identify performance issues and adapt UI complexity.
///
/// ## Usage
/// ```dart
/// final monitor = ref.read(performanceMonitorProvider);
/// monitor.start();
/// // ... do work ...
/// monitor.stop();
/// print('Average FPS: ${monitor.averageFps}');
/// ```
class PerformanceMonitor {
  final List<double> _frameTimings = [];
  bool _isMonitoring = false;
  int _droppedFrameCount = 0;
  DateTime? _startTime;

  /// Whether monitoring is currently active.
  bool get isMonitoring => _isMonitoring;

  /// Number of frames that exceeded 16ms (dropped frames).
  int get droppedFrameCount => _droppedFrameCount;

  /// Total frames recorded.
  int get totalFrames => _frameTimings.length;

  /// Average frame time in milliseconds.
  double get averageFrameTimeMs {
    if (_frameTimings.isEmpty) return 0;
    return _frameTimings.reduce((a, b) => a + b) / _frameTimings.length;
  }

  /// Average frames per second.
  double get averageFps {
    final avgMs = averageFrameTimeMs;
    if (avgMs <= 0) return 0;
    return 1000 / avgMs;
  }

  /// Percentage of frames that were dropped (>16ms).
  double get droppedFramePercentage {
    if (_frameTimings.isEmpty) return 0;
    return (_droppedFrameCount / _frameTimings.length) * 100;
  }

  /// Whether performance is considered smooth (>50 FPS, <10% dropped).
  bool get isPerformanceSmooth =>
      averageFps >= 50 && droppedFramePercentage < 10;

  /// Starts monitoring frame timings.
  void start() {
    if (_isMonitoring) return;

    _frameTimings.clear();
    _droppedFrameCount = 0;
    _startTime = DateTime.now();
    _isMonitoring = true;

    SchedulerBinding.instance.addTimingsCallback(_handleTimings);
  }

  /// Stops monitoring and returns summary.
  PerformanceSummary stop() {
    if (!_isMonitoring) {
      return PerformanceSummary.empty();
    }

    _isMonitoring = false;
    SchedulerBinding.instance.removeTimingsCallback(_handleTimings);

    final duration = DateTime.now().difference(_startTime!);

    return PerformanceSummary(
      averageFps: averageFps,
      droppedFrames: _droppedFrameCount,
      totalFrames: totalFrames,
      monitoringDuration: duration,
      averageFrameTimeMs: averageFrameTimeMs,
    );
  }

  void _handleTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      // Calculate total frame time (build + raster)
      final buildMs = timing.buildDuration.inMicroseconds / 1000;
      final rasterMs = timing.rasterDuration.inMicroseconds / 1000;
      final totalMs = buildMs + rasterMs;

      _frameTimings.add(totalMs);

      // 16.67ms = 60 FPS target
      if (totalMs > 16.67) {
        _droppedFrameCount++;
      }
    }
  }

  /// Resets all recorded data.
  void reset() {
    _frameTimings.clear();
    _droppedFrameCount = 0;
    _startTime = null;
  }
}

/// Summary of performance monitoring results.
@immutable
class PerformanceSummary {
  /// Creates a [PerformanceSummary] with the given values.
  const PerformanceSummary({
    required this.averageFps,
    required this.droppedFrames,
    required this.totalFrames,
    required this.monitoringDuration,
    required this.averageFrameTimeMs,
  });

  /// Creates an empty summary.
  factory PerformanceSummary.empty() {
    return const PerformanceSummary(
      averageFps: 0,
      droppedFrames: 0,
      totalFrames: 0,
      monitoringDuration: Duration.zero,
      averageFrameTimeMs: 0,
    );
  }

  /// Average frames per second.
  final double averageFps;

  /// Number of dropped frames.
  final int droppedFrames;

  /// Total frames recorded.
  final int totalFrames;

  /// Duration of monitoring.
  final Duration monitoringDuration;

  /// Average frame time in milliseconds.
  final double averageFrameTimeMs;

  /// Whether performance met the 60fps target.
  bool get isSmooth => averageFps >= 55 && droppedFrames < totalFrames * 0.05;

  @override
  String toString() =>
      'PerformanceSummary(fps: ${averageFps.toStringAsFixed(1)}, '
      'dropped: $droppedFrames/$totalFrames, '
      'duration: ${monitoringDuration.inSeconds}s)';
}

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

// ============================================================================
// Debouncing & Throttling
// ============================================================================

/// A debouncer that delays execution until input stops.
///
/// Useful for search fields, filter inputs, and other cases where
/// you want to wait for the user to stop typing before executing.
///
/// ## Usage
/// ```dart
/// final debouncer = Debouncer(duration: Duration(milliseconds: 300));
///
/// // In onChanged callback
/// debouncer.run(() {
///   // This runs 300ms after the last call
///   performSearch(query);
/// });
/// ```
class Debouncer {
  /// Creates a [Debouncer] with the given [duration].
  Debouncer({required this.duration});

  /// The debounce duration.
  final Duration duration;

  Timer? _timer;

  /// Whether a debounced call is pending.
  bool get isPending => _timer?.isActive ?? false;

  /// Runs the given [action] after the debounce duration.
  ///
  /// Cancels any previously scheduled action.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Runs the given [action] immediately and prevents further calls
  /// during the debounce period.
  void runImmediate(VoidCallback action) {
    if (!isPending) {
      action();
      _timer = Timer(duration, () {});
    }
  }

  /// Cancels any pending debounced action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Disposes the debouncer.
  void dispose() {
    cancel();
  }
}

/// A throttler that limits execution rate.
///
/// Ensures the action is only executed at most once per interval,
/// regardless of how many times it's called.
///
/// ## Usage
/// ```dart
/// final throttler = Throttler(duration: Duration(milliseconds: 100));
///
/// // In scroll listener
/// throttler.run(() {
///   // This runs at most every 100ms
///   updateScrollPosition();
/// });
/// ```
class Throttler {
  /// Creates a [Throttler] with the given [duration].
  Throttler({required this.duration});

  /// The throttle duration.
  final Duration duration;

  DateTime? _lastRunTime;
  Timer? _timer;
  VoidCallback? _pendingAction;

  /// Whether the throttler is currently in a throttle period.
  bool get isThrottled {
    if (_lastRunTime == null) return false;
    return DateTime.now().difference(_lastRunTime!) < duration;
  }

  /// Runs the given [action], respecting the throttle duration.
  ///
  /// If within throttle period, schedules the action to run after.
  void run(VoidCallback action) {
    final now = DateTime.now();

    if (_lastRunTime == null || now.difference(_lastRunTime!) >= duration) {
      // Not throttled, run immediately
      _lastRunTime = now;
      action();
    } else {
      // Throttled, schedule for later
      _pendingAction = action;
      _timer?.cancel();
      _timer = Timer(duration - now.difference(_lastRunTime!), () {
        _lastRunTime = DateTime.now();
        _pendingAction?.call();
        _pendingAction = null;
      });
    }
  }

  /// Cancels any pending throttled action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pendingAction = null;
  }

  /// Disposes the throttler.
  void dispose() {
    cancel();
  }
}

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

// ============================================================================
// Memory Management
// ============================================================================

/// Utility class for memory management and optimization.
///
/// Provides methods to clear caches, monitor memory usage,
/// and suggest optimizations when memory is low.
abstract final class MemoryManager {
  /// Clears Flutter's image cache.
  static void clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// Sets the maximum number of images in Flutter's cache.
  static void setImageCacheSize(int maxImages, int maxSizeBytes) {
    PaintingBinding.instance.imageCache.maximumSize = maxImages;
    PaintingBinding.instance.imageCache.maximumSizeBytes = maxSizeBytes;
  }

  /// Configures cache sizes based on device performance.
  static void configureForDevice(DevicePerformance devicePerformance) {
    switch (devicePerformance.tier) {
      case DeviceTier.low:
        setImageCacheSize(30, 20 * 1024 * 1024); // 30 images, 20 MB
      case DeviceTier.medium:
        setImageCacheSize(50, 50 * 1024 * 1024); // 50 images, 50 MB
      case DeviceTier.high:
        setImageCacheSize(100, 100 * 1024 * 1024); // 100 images, 100 MB
    }
  }

  /// Suggests garbage collection.
  ///
  /// Note: This is a hint to the Dart VM, not a guaranteed collection.
  static void suggestGarbageCollection() {
    // This is a no-op in release mode
    if (kDebugMode) {
      // In debug mode, we can't force GC but we can clear caches
      clearImageCache();
    }
  }
}

// ============================================================================
// Scroll Optimization
// ============================================================================

/// Configuration for optimized scrolling on low-end devices.
///
/// Use with [ListView.builder] and [GridView.builder] for smooth scrolling.
///
/// ## Usage
/// ```dart
/// final config = ScrollOptimizationConfig.forDevice(devicePerformance);
///
/// ListView.builder(
///   cacheExtent: config.cacheExtent,
///   physics: config.physics,
///   addAutomaticKeepAlives: config.addAutomaticKeepAlives,
///   addRepaintBoundaries: config.addRepaintBoundaries,
///   itemBuilder: (context, index) => ...,
/// )
/// ```
@immutable
class ScrollOptimizationConfig {
  /// Creates a [ScrollOptimizationConfig] with the given values.
  const ScrollOptimizationConfig({
    required this.cacheExtent,
    required this.physics,
    required this.addAutomaticKeepAlives,
    required this.addRepaintBoundaries,
    required this.itemExtent,
  });

  /// Creates a configuration optimized for the given device.
  factory ScrollOptimizationConfig.forDevice(DevicePerformance device) {
    switch (device.tier) {
      case DeviceTier.low:
        return const ScrollOptimizationConfig(
          cacheExtent: 100, // Minimal cache
          physics: ClampingScrollPhysics(),
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          itemExtent: null,
        );
      case DeviceTier.medium:
        return const ScrollOptimizationConfig(
          cacheExtent: 250,
          physics: BouncingScrollPhysics(),
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
          itemExtent: null,
        );
      case DeviceTier.high:
        return const ScrollOptimizationConfig(
          cacheExtent: 500,
          physics: BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
          itemExtent: null,
        );
    }
  }

  /// How many pixels to cache ahead/behind visible area.
  final double cacheExtent;

  /// Scroll physics to use.
  final ScrollPhysics physics;

  /// Whether to add automatic keep-alives.
  final bool addAutomaticKeepAlives;

  /// Whether to add repaint boundaries.
  final bool addRepaintBoundaries;

  /// Fixed item extent for optimization (null for variable).
  final double? itemExtent;
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
    if (devicePerformance?.isLowEndDevice == true) {
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
    if (devicePerformance?.isLowEndDevice == true) {
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

/// An optimized list view that adapts to device capabilities.
///
/// Automatically configures caching, physics, and item rendering
/// based on device tier.
class OptimizedListView extends ConsumerWidget {
  /// Creates an [OptimizedListView].
  const OptimizedListView({
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.itemExtent,
    this.padding,
    this.scrollController,
    this.onScrollEnd,
    super.key,
  });

  /// Number of items.
  final int itemCount;

  /// Builder for list items.
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Builder for separators (optional).
  final Widget Function(BuildContext context, int index)? separatorBuilder;

  /// Fixed item extent for optimization.
  final double? itemExtent;

  /// List padding.
  final EdgeInsetsGeometry? padding;

  /// Scroll controller.
  final ScrollController? scrollController;

  /// Called when scrolled to end (for pagination).
  final VoidCallback? onScrollEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicePerformance = ref.watch(devicePerformanceProvider);
    final config = ScrollOptimizationConfig.forDevice(devicePerformance);

    // Add scroll listener for pagination
    final controller = scrollController ?? ScrollController();

    if (onScrollEnd != null) {
      controller.addListener(() {
        if (controller.position.pixels >=
            controller.position.maxScrollExtent * 0.9) {
          onScrollEnd!();
        }
      });
    }

    if (separatorBuilder != null) {
      return ListView.separated(
        controller: controller,
        padding: padding,
        physics: config.physics,
        cacheExtent: config.cacheExtent,
        addAutomaticKeepAlives: config.addAutomaticKeepAlives,
        addRepaintBoundaries: config.addRepaintBoundaries,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return RepaintBoundary(child: itemBuilder(context, index));
        },
        separatorBuilder: separatorBuilder!,
      );
    }

    return ListView.builder(
      controller: controller,
      padding: padding,
      physics: config.physics,
      cacheExtent: config.cacheExtent,
      addAutomaticKeepAlives: config.addAutomaticKeepAlives,
      addRepaintBoundaries: config.addRepaintBoundaries,
      itemExtent: itemExtent ?? config.itemExtent,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return RepaintBoundary(child: itemBuilder(context, index));
      },
    );
  }
}

// ============================================================================
// Startup Optimization
// ============================================================================

/// Utility for optimizing app startup time.
///
/// Provides methods to defer non-critical initialization and
/// track startup performance.
abstract final class StartupOptimization {
  static DateTime? _startTime;
  static bool _isInitialized = false;

  /// Marks the start of app initialization.
  ///
  /// Call this at the very beginning of main().
  static void markStart() {
    _startTime = DateTime.now();
  }

  /// Marks the end of initialization.
  ///
  /// Returns the startup duration.
  static Duration markInitialized() {
    _isInitialized = true;
    if (_startTime == null) return Duration.zero;
    return DateTime.now().difference(_startTime!);
  }

  /// Whether initialization is complete.
  static bool get isInitialized => _isInitialized;

  /// Time since app started.
  static Duration get timeSinceStart {
    if (_startTime == null) return Duration.zero;
    return DateTime.now().difference(_startTime!);
  }

  /// Defers a task to run after the first frame is rendered.
  ///
  /// Use this for non-critical initialization to improve startup time.
  static void deferAfterFirstFrame(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      callback();
    });
  }

  /// Defers a task to run after a specified delay.
  ///
  /// Use this for very low-priority initialization.
  static void deferWithDelay(Duration delay, VoidCallback callback) {
    Future.delayed(delay, callback);
  }

  /// Runs initialization tasks in priority order.
  ///
  /// Critical tasks run immediately, normal tasks after first frame,
  /// low priority tasks after delay.
  static Future<void> runInitSequence({
    required List<Future<void> Function()> criticalTasks,
    List<Future<void> Function()>? normalTasks,
    List<Future<void> Function()>? lowPriorityTasks,
    Duration lowPriorityDelay = const Duration(seconds: 2),
  }) async {
    // Run critical tasks synchronously
    for (final task in criticalTasks) {
      await task();
    }

    // Schedule normal tasks after first frame
    if (normalTasks != null && normalTasks.isNotEmpty) {
      deferAfterFirstFrame(() async {
        for (final task in normalTasks) {
          await task();
        }
      });
    }

    // Schedule low priority tasks after delay
    if (lowPriorityTasks != null && lowPriorityTasks.isNotEmpty) {
      deferWithDelay(lowPriorityDelay, () async {
        for (final task in lowPriorityTasks) {
          await task();
        }
      });
    }
  }
}

// ============================================================================
// Performance Context Extension
// ============================================================================

/// Extension on [BuildContext] for easy access to performance utilities.
extension PerformanceContextExtension on BuildContext {
  /// Gets the animation duration adjusted for device performance.
  Duration adjustedDuration(Duration baseDuration) {
    // This requires a ProviderScope in the widget tree
    // For now, return base duration
    return baseDuration;
  }
}
