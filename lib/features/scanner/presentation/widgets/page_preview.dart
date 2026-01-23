/// Interactive page preview widget with zoom and pan capabilities.
///
/// This widget displays scanned document pages with full gesture support
/// for zooming and panning, optimized for examining document details.
///
/// Features:
/// - InteractiveViewer for zoom and pan
/// - Gesture controls (pinch to zoom, drag to pan)
/// - Optimized image loading with caching
/// - Error handling and placeholder display
/// - Responsive to screen size for cache optimization
///
/// The preview supports zoom levels from 0.5x to 4x for detailed inspection.
library;

import 'dart:io';

import 'package:flutter/material.dart';

/// Interactive page preview with zoom for scanned documents.
///
/// Displays a scanned page image with zoom and pan capabilities using
/// [InteractiveViewer]. Supports gesture controls for zooming in/out
/// and panning around the page. Handles image loading states and errors.
///
/// ## Usage
/// ```dart
/// PagePreview(
///   imagePath: '/path/to/scanned/page.jpg',
/// )
/// ```
class PagePreview extends StatelessWidget {
  /// Creates a [PagePreview].
  const PagePreview({
    super.key,
    required this.imagePath,
  });

  /// The file path to the scanned page image.
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);
    final screenWidth = MediaQuery.of(context).size.width;
    final cacheWidth = (screenWidth * 2).toInt();

    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data != true) {
          return _buildErrorPlaceholder(context);
        }

        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(
            file,
            fit: BoxFit.contain,
            cacheWidth: cacheWidth,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorPlaceholder(context);
            },
          ),
        );
      },
    );
  }

  Widget _buildErrorPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined,
              size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Échec du chargement de l\'image',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ),
    );
  }
}
