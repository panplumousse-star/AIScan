import 'dart:io';

import 'package:flutter/material.dart';
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
