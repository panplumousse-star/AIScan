/// Action handlers for scanner screen (share, export, OCR).
///
/// This file provides reusable action handlers for scanner screen
/// operations including document sharing, export, and OCR processing.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/bento_share_format_dialog.dart';
import '../../../../core/permissions/contact_permission_dialog.dart';
import '../../../../core/export/document_export_service.dart';
import '../../../contacts/presentation/contact_creation_sheet.dart';
import '../../../contacts/domain/contact_data_extractor.dart';
import '../../../ocr/domain/ocr_service.dart';
import '../../../sharing/domain/document_share_service.dart';
import '../../../home/presentation/bento_home_screen.dart';
import '../../../documents/presentation/documents_screen.dart';
import '../scanner_screen.dart';
import '../state/scanner_screen_state.dart';

/// Handles scanner screen actions (share, export, OCR).
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
        await shareService.shareText(
          state.savedDocument!.ocrText!,
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
    } catch (e) {
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
    } catch (e) {
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

  /// Handles OCR processing on the scanned document.
  Future<void> handleOcr(ScannerScreenState state) async {
    if (state.scanResult == null || state.scanResult!.pages.isEmpty) {
      if (context.mounted) {
        showNoContactDataFoundSnackbar(context);
      }
      return;
    }

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
              Text('Extracting text...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      final ocrService = ref.read(ocrServiceProvider);
      const extractor = ContactDataExtractor();

      // Run OCR on all scanned pages
      final textParts = <String>[];
      for (final page in state.scanResult!.pages) {
        // Read image file and run OCR
        final imageFile = File(page.imagePath);
        if (await imageFile.exists()) {
          final imageBytes = await imageFile.readAsBytes();
          final result = await ocrService.extractTextFromBytes(imageBytes);
          if (result.text.isNotEmpty) {
            textParts.add(result.text);
          }
        }
      }

      // Hide loading snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (!context.mounted) return;

      if (textParts.isEmpty) {
        showNoContactDataFoundSnackbar(context);
        return;
      }

      // Combine all text and extract contact data
      final combinedText = textParts.join('\n\n');
      final extractedData = extractor.extractFromText(combinedText);

      if (extractedData.isEmpty) {
        showNoContactDataFoundSnackbar(context);
        return;
      }

      // Show contact creation sheet
      await showContactCreationSheet(
        context,
        extractedData: extractedData,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Navigate to documents screen (helper method).
  void _navigateToDocuments(BuildContext context) {
    // Replace scanner screen with documents screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (navContext) => DocumentsScreen(
          onScanPressed: () {
            // Navigate to scanner when scan button is pressed
            Navigator.of(navContext).push(
              MaterialPageRoute(
                builder: (_) => const ScannerScreen(),
              ),
            );
          },
        ),
      ),
    );
  }
}
