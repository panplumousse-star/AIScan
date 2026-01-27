/// Action handlers for scanner screen (share, export).
///
/// This file provides reusable action handlers for scanner screen
/// operations including document sharing and export.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/bento_share_format_dialog.dart';
import '../../../../core/export/document_export_service.dart';
import '../../../../core/storage/document_repository.dart';
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
    if (state.savedDocument == null) return;

    // Show format selection dialog with OCR text if available
    final format = await showBentoShareFormatDialog(
      context,
      ocrText:
          state.savedDocument!.hasOcrText ? state.savedDocument!.ocrText : null,
    );
    if (format == null) return; // User cancelled

    final shareService = ref.read(documentShareServiceProvider);

    try {
      // Handle text format separately (no file sharing needed)
      if (format == ShareFormat.text) {
        String textToShare = state.savedDocument!.ocrText ?? '';

        // If no OCR text, extract it on-the-fly
        if (textToShare.isEmpty) {
          // Show loading indicator
          if (context.mounted) {
            final l10n = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 16),
                    Text(l10n?.extractingText ?? 'Extracting text...'),
                  ],
                ),
                duration: const Duration(seconds: 30),
              ),
            );
          }

          try {
            // Get decrypted page paths
            final documentRepo = ref.read(documentRepositoryProvider);
            final pagePaths =
                await documentRepo.getDecryptedAllPages(state.savedDocument!);

            // Run OCR on pages
            final ocrService = ref.read(ocrServiceProvider);
            final ocrResult =
                await ocrService.extractTextFromMultipleFiles(pagePaths);

            // Cleanup temp files
            await documentRepo.cleanupTempFiles();

            if (context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            }

            if (ocrResult.hasText) {
              textToShare = ocrResult.text;
            } else {
              // No text found
              if (context.mounted) {
                final l10n = AppLocalizations.of(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(l10n?.noTextFound ?? 'No text found in document'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
              return;
            }
          } on Object catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('OCR failed: $e'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
            return;
          }
        }

        await shareService.shareText(
          textToShare,
          subject: state.savedDocument!.title,
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
        [state.savedDocument!],
        format: format,
      );
      await shareService.cleanupTempFiles(result.tempFilePaths);
      // Navigate to documents after sharing
      if (context.mounted) {
        // Set just scanned state for celebration message
        ref.read(hasJustScannedProvider.notifier).state = true;
        _navigateToDocuments(context);
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec du partage: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Handles exporting the scanned document to external storage.
  Future<void> handleExport(ScannerScreenState state) async {
    if (state.savedDocument == null) return;

    // Show loading indicator
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Exportation en cours...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    final exportService = ref.read(documentExportServiceProvider);

    try {
      final result = await exportService.exportDocument(state.savedDocument!);

      // Hide loading snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (!context.mounted) return;

      if (result.isSuccess) {
        // Show success message with folder name
        final l10n = AppLocalizations.of(context);
        final folderName = result.folderDisplayName ?? 'external storage';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.documentExportedTo(folderName) ??
                'Document exported to $folderName'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
        // Set just scanned state for celebration message
        ref.read(hasJustScannedProvider.notifier).state = true;
        _navigateToDocuments(context);
      } else if (result.isFailed) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                result.errorMessage ?? (l10n?.exportFailed ?? 'Export failed')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      // If cancelled, do nothing (user cancelled the picker)
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec de l\'exportation: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
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
