/// Action handlers for scanner screen (share, export).
///
/// This file provides reusable action handlers for scanner screen
/// operations including document sharing and export.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/bento_share_format_dialog.dart';
import '../../../../core/export/document_export_service.dart';
import '../../../../core/storage/document_repository.dart';
import '../../../premium/domain/premium_service.dart';
import '../../../premium/presentation/widgets/premium_upgrade_dialog.dart';
import '../../../sharing/domain/document_share_service.dart';
import '../../../home/presentation/bento_home_screen.dart';
import '../../../documents/presentation/documents_screen.dart';
import '../../../ocr/domain/ocr_service.dart';
import '../scanner_screen.dart';
import '../state/scanner_screen_state.dart';

/// Handles scanner screen actions (share, export).
class ScannerActionHandler {
  final WidgetRef ref;
  final BuildContext context;

  const ScannerActionHandler(this.ref, this.context);

  /// Handles sharing the scanned document.
  Future<void> handleShare(ScannerScreenState state) async {
    // QC-01: Capture in local variable for null safety
    final savedDocument = state.savedDocument;
    if (savedDocument == null) return;

    // Show format selection dialog with OCR text if available
    final format = await showBentoShareFormatDialog(
      context,
      ocrText: savedDocument.hasOcrText ? savedDocument.ocrText : null,
    );
    if (format == null) return; // User cancelled

    final shareService = ref.read(documentShareServiceProvider);

    try {
      // Handle text format separately (no file sharing needed)
      // OCR/text sharing requires premium
      if (format == ShareFormat.text) {
        final isPremium = ref.read(isPremiumProvider);
        if (!isPremium) {
          await PremiumUpgradeDialog.show(context, feature: PremiumFeature.ocr);
          return;
        }
        String textToShare = savedDocument.ocrText ?? '';

        // If no OCR text, extract it on-the-fly
        if (textToShare.isEmpty) {
          try {
            // Get decrypted page paths
            final documentRepo = ref.read(documentRepositoryProvider);
            final pagePaths =
                await documentRepo.getDecryptedAllPages(savedDocument);

            // Run OCR on pages
            final ocrService = ref.read(ocrServiceProvider);
            final ocrResult =
                await ocrService.extractTextFromMultipleFiles(pagePaths);

            // Cleanup temp files
            await documentRepo.cleanupTempFiles();

            if (ocrResult.hasText) {
              textToShare = ocrResult.text;
            } else {
              return;
            }
          } on Object catch (_) {
            return;
          }
        }

        await shareService.shareText(
          textToShare,
          subject: savedDocument.title,
        );
        // Navigate to documents after sharing
        if (context.mounted) {
          ref.read(hasJustScannedProvider.notifier).state = true;
          _navigateToDocuments(context);
        }
        return;
      }

      // Handle PDF and images formats
      final result = await shareService.shareDocuments(
        [savedDocument],
        format: format,
      );
      await shareService.cleanupTempFiles(result.tempFilePaths);
      // Navigate to documents after sharing
      if (context.mounted) {
        // Set just scanned state for celebration message
        ref.read(hasJustScannedProvider.notifier).state = true;
        _navigateToDocuments(context);
      }
    } on Object catch (_) {
      // Error handled silently
    }
  }

  /// Handles exporting the scanned document to external storage.
  Future<void> handleExport(ScannerScreenState state) async {
    // QC-01: Capture in local variable for null safety
    final savedDocument = state.savedDocument;
    if (savedDocument == null) return;

    // Check premium access for PDF export
    final isPremium = ref.read(isPremiumProvider);
    if (!isPremium) {
      await PremiumUpgradeDialog.show(context, feature: PremiumFeature.pdfExport);
      return;
    }

    final exportService = ref.read(documentExportServiceProvider);

    try {
      final result = await exportService.exportDocument(savedDocument);

      if (!context.mounted) return;

      if (result.isSuccess) {
        // Set just scanned state for celebration message
        ref.read(hasJustScannedProvider.notifier).state = true;
        _navigateToDocuments(context);
      }
      // If cancelled or failed, do nothing
    } on Object catch (_) {
      // Error handled silently
    }
  }

  /// Navigate to documents screen (helper method).
  void _navigateToDocuments(BuildContext context) {
    // Replace scanner screen with documents screen
    unawaited(Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (navContext) => DocumentsScreen(
          onScanPressed: () {
            // Navigate to scanner when scan button is pressed
            unawaited(Navigator.of(navContext).push(
              MaterialPageRoute(
                builder: (_) => const ScannerScreen(),
              ),
            ));
          },
        ),
      ),
    ));
  }
}
