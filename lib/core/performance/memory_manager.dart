import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'device_performance.dart';

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
