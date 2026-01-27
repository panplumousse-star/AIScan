import 'package:flutter/material.dart';

import '../device_performance.dart';

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
