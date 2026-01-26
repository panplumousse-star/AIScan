import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/document_repository.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/export/document_export_service.dart';
import '../../../scanner/presentation/scanner_screen.dart';
import '../../../ocr/presentation/ocr_results_screen.dart';
import '../../../enhancement/presentation/enhancement_screen.dart';
import '../../domain/document_model.dart';
import '../document_detail_screen.dart';
import '../documents_screen.dart' show documentsScreenProvider;

/// Navigation controller for documents screen.
///
/// Provides static methods for navigating to different screens from the documents screen.
/// Extracted to reduce the size of the main documents_screen.dart file.
class DocumentsNavigationController {
  /// Navigates to the scanner screen with a fade transition.
  ///
  /// Plays haptic feedback and audio cue before navigation.
  static void navigateToScanner(BuildContext context, WidgetRef ref) {
    unawaited(HapticFeedback.lightImpact());
    unawaited(ref.read(audioServiceProvider).playScanLaunch());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        opaque: true,
        barrierColor: isDark ? Colors.black : Colors.white,
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ScannerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return ColoredBox(
            color: isDark ? Colors.black : Colors.white,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
      ),
    );
  }

  /// Navigates to the document detail screen.
  ///
  /// Shows the full document with actions for delete, export, OCR, and enhancement.
  /// Refreshes the documents list when returning from the detail screen.
  static void navigateToDocumentDetail(
    BuildContext context,
    Document document,
    WidgetRef ref,
  ) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (navContext) => DocumentDetailScreen(
          document: document,
          onDelete: () {
            Navigator.of(navContext).pop();
            // Refresh the documents list
            ref.read(documentsScreenProvider.notifier).loadDocuments();
          },
          onExport: (doc, imageBytes) async {
            final exportService = ref.read(documentExportServiceProvider);
            try {
              final result = await exportService.exportDocument(doc);
              if (!navContext.mounted) return;
              if (result.isSuccess) {
                ScaffoldMessenger.of(navContext).showSnackBar(
                  const SnackBar(content: Text('Document exporté')),
                );
              } else if (result.isFailed) {
                ScaffoldMessenger.of(navContext).showSnackBar(
                  SnackBar(
                      content: Text(
                          result.errorMessage ?? 'Échec de l\'exportation')),
                );
              }
            } on DocumentExportException catch (e) {
              if (navContext.mounted) {
                ScaffoldMessenger.of(navContext).showSnackBar(
                  SnackBar(content: Text(e.message)),
                );
              }
            }
          },
          onOcr: (doc, imageBytes) =>
              navigateToOcr(navContext, doc, imageBytes, ref),
          onEnhance: (doc, imageBytes) =>
              navigateToEnhancement(navContext, doc, imageBytes),
        ),
      ),
    )
        .then((_) {
      // Refresh documents when returning from detail screen
      ref.read(documentsScreenProvider.notifier).loadDocuments();
    });
  }

  /// Navigates to the OCR results screen.
  ///
  /// Automatically runs OCR on the document image and saves the results.
  static void navigateToOcr(
    BuildContext context,
    Document document,
    Uint8List imageBytes,
    WidgetRef ref,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OcrResultsScreen(
          document: document,
          imageBytes: imageBytes,
          autoRunOcr: true,
          onOcrComplete: (result) async {
            // Save OCR text to the document
            if (result.hasText) {
              try {
                final repository = ref.read(documentRepositoryProvider);
                await repository.updateDocumentOcr(
                  document.id,
                  result.text,
                );
                // Refresh the documents list
                unawaited(ref.read(documentsScreenProvider.notifier).loadDocuments());
              } on Object catch (_) {
                // Error saving OCR text - silently fail
              }
            }
          },
        ),
      ),
    );
  }

  /// Navigates to the image enhancement screen.
  ///
  /// Allows the user to enhance/edit the document image.
  static void navigateToEnhancement(
    BuildContext context,
    Document document,
    Uint8List imageBytes,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EnhancementScreen(
          imageBytes: imageBytes,
          title: document.title,
        ),
      ),
    );
  }
}
