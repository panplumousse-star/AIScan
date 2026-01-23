import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/bento_background.dart';
import '../../../core/widgets/bento_state_views.dart';
import '../../documents/domain/document_model.dart';
import '../../documents/presentation/documents_screen.dart';
import '../domain/scanner_service.dart';
import 'state/scanner_screen_state.dart';
import 'state/scanner_screen_notifier.dart';
import 'widgets/result_view.dart';
import 'helpers/scanner_action_handler.dart';
import 'helpers/scanner_permission_handler.dart';

/// The main scanner screen UI.
///
/// Provides a streamlined interface for document scanning with:
/// - Quick scan and multi-page scan options
/// - Preview of scanned pages with page navigation
/// - Save and discard actions with encrypted storage
/// - Error handling with retry capability
///
/// ## Encrypted Storage
/// Scanned documents are automatically saved to encrypted storage using
/// AES-256 encryption. The source scan files are cleaned up after saving.
///
/// ## Usage
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => const ScannerScreen()),
/// );
/// ```
///
/// ## Custom Title and Folder
/// ```dart
/// ScannerScreen(
///   documentTitle: 'Invoice 2024',
///   folderId: 'folder-invoices',
///   onDocumentSaved: (doc) => print('Saved: ${doc.id}'),
/// )
/// ```
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({
    super.key,
    this.documentTitle,
    this.folderId,
    this.onDocumentSaved,
    @Deprecated('Use onDocumentSaved instead') this.onScanComplete,
  });

  /// Optional title for the saved document.
  ///
  /// If not provided, a title is auto-generated based on the current date/time.
  final String? documentTitle;

  /// Optional folder ID to save the document in.
  ///
  /// If not provided, the document is saved in the root folder.
  final String? folderId;

  /// Callback invoked when a document is saved to encrypted storage.
  ///
  /// Receives the [Document] that was created.
  final void Function(Document document)? onDocumentSaved;

  /// Legacy callback for scan completion.
  @Deprecated('Use onDocumentSaved instead')
  final void Function(ScanResult result)? onScanComplete;

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  bool _autoScanStarted = false;
  bool _scanWasActive = false;

  late final ScannerPermissionHandler _permissionHandler;
  late final ScannerActionHandler _actionHandler;

  @override
  void initState() {
    super.initState();
    // Launch scanner automatically when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _permissionHandler = ScannerPermissionHandler(ref, context);
      _actionHandler = ScannerActionHandler(ref, context);
      _autoScanStarted = true;
      _permissionHandler.autoStartScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scannerScreenProvider);
    final notifier = ref.read(scannerScreenProvider.notifier);

    // Listen for state changes
    ref.listen<ScannerScreenState>(scannerScreenProvider, (previous, next) {
      // Track when scan is active
      if (next.isScanning) {
        _scanWasActive = true;
      }

      // If scan was cancelled (was active, now not active, no result) and
      // was auto-started, go back to previous screen
      if (_autoScanStarted &&
          _scanWasActive &&
          !next.isScanning &&
          !next.hasResult &&
          previous?.isScanning == true) {
        Navigator.of(context).pop();
        return;
      }

      // Show error snackbar
      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                notifier.clearError();
                notifier.multiPageScan();
              },
            ),
          ),
        );
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const BentoBackground(),
          _buildBody(context, state, notifier),
        ],
      ),
      floatingActionButton: _buildFab(context, state, notifier),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBody(
    BuildContext context,
    ScannerScreenState state,
    ScannerScreenNotifier notifier,
  ) {
    final l10n = AppLocalizations.of(context);
    if (state.isScanning) {
      return BentoLoadingView(
          message: l10n?.openingScanner ?? 'Opening scanner...');
    }

    if (state.isSaving && !state.hasResult && !state.hasSavedDocument) {
      return BentoLoadingView(
          message: l10n?.savingDocument ?? 'Saving document...');
    }

    if (state.hasResult || state.hasSavedDocument) {
      return ResultView(
        scanResult: state.scanResult,
        savedDocument: state.savedDocument,
        selectedIndex: state.selectedPageIndex,
        onPageSelected: notifier.selectPage,
        onSave: (title, folderId) => notifier.saveToStorage(
          title: title,
          folderId: folderId,
        ),
        onDelete: () async {
          final shouldDiscard = await _showDiscardDialog(context);
          if (shouldDiscard == true) {
            await notifier.discardScan();
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          }
        },
        onShare: () => _actionHandler.handleShare(state),
        onExport: () => _actionHandler.handleExport(state),
        onOcr: () => _actionHandler.handleOcr(state),
        onDone: () => _navigateToDocuments(context),
      );
    }

    // Fallback: show loading while auto-scan starts
    return BentoLoadingView(
        message: l10n?.launchingScanner ?? 'Launching scanner...');
  }

  Widget? _buildFab(
    BuildContext context,
    ScannerScreenState state,
    ScannerScreenNotifier notifier,
  ) {
    if (state.isLoading) return null;

    // After save or in result view: no FAB (buttons are integrated)
    if (state.hasSavedDocument || state.hasResult) {
      return null;
    }

    return null;
  }

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

  Future<bool?> _showDiscardDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.abandonScanTitle ?? 'Abandon scan?'),
        content: Text(
          l10n?.abandonScanMessage ??
              'Are you sure you want to abandon this scan? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n?.abandon ?? 'Abandon'),
          ),
        ],
      ),
    );
  }
}
