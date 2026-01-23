/// Preview widget for displaying saved encrypted documents.
///
/// This widget fetches and displays decrypted thumbnails from encrypted
/// document storage. It handles the asynchronous loading of decrypted
/// images and provides loading feedback.
///
/// Features:
/// - Decrypted thumbnail loading from secure storage
/// - Loading state with progress indicator
/// - Image display with proper sizing
/// - Error handling for missing or corrupted images
///
/// Usage:
/// ```dart
/// SavedPreview(
///   document: savedDocument,
/// )
/// ```
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../documents/domain/document_model.dart';
import '../../../../core/storage/document_repository.dart';

/// Saved document preview widget.
///
/// Displays a preview of a saved document by fetching and displaying
/// its decrypted thumbnail. Shows a loading indicator while the thumbnail
/// is being retrieved.
class SavedPreview extends ConsumerWidget {
  const SavedPreview({
    super.key,
    required this.document,
  });

  final Document document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(documentRepositoryProvider);
    return FutureBuilder<String?>(
      future: repository.getDecryptedThumbnailPath(document),
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Image.file(File(path), fit: BoxFit.contain);
      },
    );
  }
}
