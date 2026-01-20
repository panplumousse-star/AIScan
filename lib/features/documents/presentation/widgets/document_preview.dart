import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interactive document preview with zoom.
///
/// Displays a document image with zoom and pan capabilities using
/// [InteractiveViewer]. Supports gesture controls for zooming in/out
/// and panning around the document.
///
/// ## Usage
/// ```dart
/// DocumentPreview(
///   imageBytes: documentBytes,
///   transformationController: _transformationController,
/// )
/// ```
class DocumentPreview extends StatelessWidget {
  /// Creates a [DocumentPreview].
  const DocumentPreview({
    super.key,
    required this.imageBytes,
    required this.transformationController,
  });

  /// The document image bytes to display.
  final Uint8List imageBytes;

  /// Controller for managing zoom and pan transformations.
  ///
  /// Allows external control and synchronization of the transformation state.
  final TransformationController transformationController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerLowest,
      child: InteractiveViewer(
        transformationController: transformationController,
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.memory(
            imageBytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load image',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
