import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A full-screen immersive view for document images.
///
/// Displays a document image in full-screen mode with interactive zoom/pan
/// capabilities and a close button. The background is black to provide
/// maximum contrast and focus on the document content.
///
/// ## Usage
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => DocumentFullScreenView(
///       imageBytes: documentImageBytes,
///       transformationController: transformationController,
///     ),
///   ),
/// );
/// ```
///
/// ## Features
/// - Interactive zoom and pan with [InteractiveViewer]
/// - Scale range: 0.5x to 6.0x
/// - Black background for immersive viewing
/// - Close button with semi-transparent background for visibility
class DocumentFullScreenView extends StatelessWidget {
  /// Creates a [DocumentFullScreenView].
  const DocumentFullScreenView({
    super.key,
    required this.imageBytes,
    required this.transformationController,
    this.onClose,
  });

  /// The image data to display in full-screen mode.
  ///
  /// Should contain the decoded image bytes of the document page.
  final Uint8List imageBytes;

  /// Controller for managing zoom and pan transformations.
  ///
  /// Allows external control of the image transformation state
  /// and preserves zoom/pan state across view transitions.
  final TransformationController transformationController;

  /// Callback invoked when the close button is pressed.
  ///
  /// If not provided, defaults to [Navigator.pop].
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image with interactive zoom/pan
          InteractiveViewer(
            transformationController: transformationController,
            minScale: 0.5,
            maxScale: 6.0,
            child: Center(
              child: Image.memory(
                imageBytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),

          // Close button overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: Semantics(
              button: true,
              label: 'Close full screen view',
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onClose ?? () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
