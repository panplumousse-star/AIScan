import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../device_performance.dart';
import '../optimization/image_optimization.dart';

// ============================================================================
// Optimized Image Widget
// ============================================================================

/// An optimized image widget that adapts quality based on device.
///
/// Automatically adjusts caching, decode size, and quality based
/// on device capabilities detected by [DevicePerformance].
///
/// ## Usage
/// ```dart
/// // From file path
/// OptimizedImage.file(
///   filePath: '/path/to/image.jpg',
///   width: 200,
///   height: 200,
///   fit: BoxFit.cover,
/// )
///
/// // From bytes
/// OptimizedImage.memory(
///   imageBytes: bytes,
///   width: 200,
///   height: 200,
/// )
/// ```
///
/// ## Features
/// - Automatic decode size optimization based on device tier
/// - Memory-efficient caching
/// - Smooth loading transitions
/// - Error handling with fallback UI
/// - RepaintBoundary for improved performance
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
