import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/permissions/camera_permission_service.dart';
import '../../../core/permissions/contact_permission_dialog.dart';
import '../../../core/permissions/permission_dialog.dart';
import '../../../core/permissions/storage_permission_service.dart';
import '../../contacts/domain/contact_data_extractor.dart';
import '../../contacts/presentation/contact_creation_sheet.dart';
import '../../documents/domain/document_model.dart';
import '../../documents/presentation/documents_screen.dart';
import '../../folders/domain/folder_model.dart';
import '../../folders/domain/folder_service.dart';
import '../../folders/presentation/widgets/bento_folder_dialog.dart';
import '../../ocr/domain/ocr_service.dart';
import '../../sharing/domain/document_share_service.dart';
import '../../../core/export/document_export_service.dart';
import '../domain/scanner_service.dart';
import '../../../core/storage/document_repository.dart';
import '../../../core/widgets/bento_background.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../core/widgets/bento_mascot.dart';
import '../../../core/widgets/bento_speech_bubble.dart';
import '../../../core/widgets/bento_rename_document_dialog.dart';
import '../../../core/widgets/bento_share_format_dialog.dart';
import '../../../core/widgets/bento_state_views.dart';
import '../../home/presentation/bento_home_screen.dart';

/// Scanner screen state notifier for managing scan workflow.
///
/// Handles the scanning process, preview, and saving workflow.
/// Uses Riverpod for state management and dependency injection.
class ScannerScreenState {
  const ScannerScreenState({
    this.scanResult,
    this.savedDocument,
    this.isScanning = false,
    this.isSaving = false,
    this.error,
    this.selectedPageIndex = 0,
  });

  /// The current scan result, if any.
  final ScanResult? scanResult;

  /// The document created after saving to encrypted storage.
  final Document? savedDocument;

  /// Whether a scan is currently in progress.
  final bool isScanning;

  /// Whether the scan is being saved.
  final bool isSaving;

  /// Error message, if any.
  final String? error;

  /// Currently selected page index for preview.
  final int selectedPageIndex;

  /// Whether we have a scan result to preview.
  bool get hasResult => scanResult != null && scanResult!.isNotEmpty;

  /// Whether a document was saved to storage.
  bool get hasSavedDocument => savedDocument != null;

  /// Whether we're in a loading state.
  bool get isLoading => isScanning || isSaving;

  /// Creates a copy with updated fields.
  ScannerScreenState copyWith({
    ScanResult? scanResult,
    Document? savedDocument,
    bool? isScanning,
    bool? isSaving,
    String? error,
    int? selectedPageIndex,
    bool clearResult = false,
    bool clearError = false,
    bool clearSavedDocument = false,
  }) {
    return ScannerScreenState(
      scanResult: clearResult ? null : (scanResult ?? this.scanResult),
      savedDocument: clearSavedDocument ? null : (savedDocument ?? this.savedDocument),
      isScanning: isScanning ?? this.isScanning,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      selectedPageIndex: selectedPageIndex ?? this.selectedPageIndex,
    );
  }
}

/// State notifier for the scanner screen.
class ScannerScreenNotifier extends StateNotifier<ScannerScreenState> {
  ScannerScreenNotifier(
    this._scannerService,
    this._storageService,
  ) : super(const ScannerScreenState());

  final ScannerService _scannerService;
  final ScannerStorageService _storageService;

  /// Starts a document scan with the given options.
  Future<void> startScan({ScannerOptions options = const ScannerOptions()}) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isScanning: true,
      clearError: true,
      clearResult: true,
      clearSavedDocument: true,
    );

    try {
      final result = await _scannerService.scanDocument(options: options);

      if (result != null && result.isNotEmpty) {
        state = state.copyWith(
          scanResult: result,
          isScanning: false,
          selectedPageIndex: 0,
        );
      } else {
        // User cancelled
        state = state.copyWith(isScanning: false);
      }
    } on ScannerException catch (e) {
      state = state.copyWith(
        isScanning: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  /// Performs a quick single-page scan.
  Future<void> quickScan() async {
    await startScan(options: const ScannerOptions.quickScan());
  }

  /// Performs a multi-page scan.
  ///
  /// [allowGalleryImport] controls whether the gallery import button is shown.
  /// Set to false if storage permission is not granted.
  Future<void> multiPageScan({
    int maxPages = 100,
    bool allowGalleryImport = true,
  }) async {
    await startScan(
      options: ScannerOptions(
        documentFormat: ScanDocumentFormat.jpeg,
        scannerMode: ScanMode.full,
        pageLimit: maxPages,
        allowGalleryImport: allowGalleryImport,
      ),
    );
  }

  /// Selects a page for preview.
  void selectPage(int index) {
    if (state.scanResult == null) return;
    if (index < 0 || index >= state.scanResult!.pageCount) return;
    state = state.copyWith(selectedPageIndex: index);
  }

  /// Discards the current scan result.
  Future<void> discardScan() async {
    if (state.scanResult != null) {
      await _scannerService.cleanupScanResult(state.scanResult!);
    }
    state = state.copyWith(
      clearResult: true,
      clearSavedDocument: true,
      selectedPageIndex: 0,
    );
  }

  /// Saves the current scan result to encrypted document storage.
  ///
  /// Parameters:
  /// - [title]: Optional title for the document (auto-generated if not provided)
  /// - [description]: Optional description
  /// - [folderId]: Optional folder to save the document in
  /// - [isFavorite]: Whether to mark the document as favorite
  ///
  /// Returns the saved [Document] if successful.
  ///
  /// Throws [ScannerException] if saving fails.
  Future<Document?> saveToStorage({
    String? title,
    String? description,
    String? folderId,
    bool isFavorite = false,
  }) async {
    if (state.scanResult == null || state.isLoading) return null;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final savedResult = await _storageService.saveScanResult(
        state.scanResult!,
        title: title,
        description: description,
        folderId: folderId,
        isFavorite: isFavorite,
      );

      state = state.copyWith(
        isSaving: false,
        savedDocument: savedResult.document,
      );

      return savedResult.document;
    } on ScannerException catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: e.message,
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to save document: $e',
      );
      return null;
    }
  }

  /// Saves the current scan as a quick scan with auto-generated title.
  ///
  /// This is optimized for the one-click scan workflow.
  Future<Document?> quickSave() async {
    return saveToStorage();
  }

  /// Clears the error state.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Sets the saving state.
  void setSaving(bool saving) {
    state = state.copyWith(isSaving: saving);
  }

  /// Gets the saved document, if any.
  Document? get savedDocument => state.savedDocument;

  @override
  void dispose() {
    if (state.scanResult != null) {
      _scannerService.cleanupScanResult(state.scanResult!);
    }
    super.dispose();
  }
}

/// Riverpod provider for the scanner screen state.
final scannerScreenProvider =
    StateNotifierProvider.autoDispose<ScannerScreenNotifier, ScannerScreenState>(
  (ref) {
    final scannerService = ref.watch(scannerServiceProvider);
    final storageService = ref.watch(scannerStorageServiceProvider);
    return ScannerScreenNotifier(scannerService, storageService);
  },
);

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
    @Deprecated('Use onDocumentSaved instead')
    this.onScanComplete,
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

  @override
  void initState() {
    super.initState();
    // Launch scanner automatically when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoStartScan();
    });
  }

  Future<void> _autoStartScan() async {
    _autoScanStarted = true;
    final hasPermission = await _checkAndRequestPermission();
    if (!hasPermission && mounted) {
      // Permission denied, go back
      Navigator.of(context).pop();
      return;
    }
    if (hasPermission && mounted) {
      // Check storage permission to determine if gallery import should be enabled
      final storageService = ref.read(storagePermissionServiceProvider);
      final storageState = await storageService.checkPermission();
      final hasStoragePermission =
          storageState == StoragePermissionState.granted ||
          storageState == StoragePermissionState.sessionOnly;

      // Only enable gallery import if storage permission is granted
      ref.read(scannerScreenProvider.notifier).multiPageScan(
        allowGalleryImport: hasStoragePermission,
      );
    }
  }

  /// Checks camera permission and shows dialog if needed.
  ///
  /// Returns `true` if permission is granted (permanent or session),
  /// `false` if denied or cancelled.
  Future<bool> _checkAndRequestPermission() async {
    final permissionService = ref.read(cameraPermissionServiceProvider);
    final state = await permissionService.checkPermission();

    // If already granted, proceed
    if (state == CameraPermissionState.granted ||
        state == CameraPermissionState.sessionOnly) {
      return true;
    }

    // Check if this is a first-time request or if permission is blocked
    if (await permissionService.isFirstTimeRequest()) {
      // Show native Android permission dialog
      final result = await permissionService.requestSystemPermission();

      if (result == CameraPermissionState.granted ||
          result == CameraPermissionState.sessionOnly) {
        return true;
      }

      // Permission denied, show snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Camera permission is required to scan documents'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => permissionService.openSettings(),
            ),
          ),
        );
      }
      return false;
    }

    // Permission is blocked, show settings dialog
    if (await permissionService.isPermissionBlocked()) {
      if (!mounted) return false;

      final shouldOpenSettings = await showCameraSettingsDialog(context);
      if (shouldOpenSettings == true) {
        await permissionService.openSettings();
      }
      return false;
    }

    return false;
  }

  /// Starts a multi-page scan with permission check.
  Future<void> _startMultiPageScanWithPermissionCheck() async {
    final hasPermission = await _checkAndRequestPermission();
    if (hasPermission && mounted) {
      ref.read(scannerScreenProvider.notifier).multiPageScan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scannerScreenProvider);
    final notifier = ref.read(scannerScreenProvider.notifier);
    final theme = Theme.of(context);

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
          _buildBody(context, state, notifier, theme),
        ],
      ),
      floatingActionButton: _buildFab(context, state, notifier),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCustomHeader(
    BuildContext context,
    ScannerScreenState state,
    ScannerScreenNotifier notifier,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 12,
              left: 12,
              right: 12,
            ),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.black.withValues(alpha: 0.3) 
                  : Colors.white.withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.05) 
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () async {
                    if (state.hasSavedDocument) {
                      _navigateToDocuments(context);
                    } else if (state.hasResult) {
                      final shouldDiscard = await _showDiscardDialog(context);
                      if (shouldDiscard == true) {
                        await notifier.discardScan();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      }
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ScannerScreenState state,
    ScannerScreenNotifier notifier,
    ThemeData theme,
  ) {
    final l10n = AppLocalizations.of(context);
    if (state.isScanning) {
      return BentoLoadingView(message: l10n?.openingScanner ?? 'Opening scanner...');
    }

    if (state.isSaving && !state.hasResult && !state.hasSavedDocument) {
      return BentoLoadingView(message: l10n?.savingDocument ?? 'Saving document...');
    }

    if (state.hasResult || state.hasSavedDocument) {
      return _ResultView(
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
        onShare: () => _handleShare(context, state),
        onExport: () => _handleExport(context, state),
        onOcr: () => _handleOcr(context, state),
        onDone: () => _navigateToDocuments(context),
      );
    }

    // Fallback: show loading while auto-scan starts
    return BentoLoadingView(message: l10n?.launchingScanner ?? 'Launching scanner...');
  }

  Widget? _buildFab(
    BuildContext context,
    ScannerScreenState state,
    ScannerScreenNotifier notifier,
  ) {
    if (state.isLoading) return null;

    final theme = Theme.of(context);

    // After save or in result view: no FAB (buttons are integrated)
    if (state.hasSavedDocument || state.hasResult) {
      return null;
    }

    return null;
  }

  Future<void> _handleShare(BuildContext context, ScannerScreenState state) async {
    if (state.savedDocument == null) return;

    // Show format selection dialog with OCR text if available
    final format = await showBentoShareFormatDialog(
      context,
      ocrText: state.savedDocument!.hasOcrText ? state.savedDocument!.ocrText : null,
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

  /// Handles exporting the saved document to external storage via SAF.
  Future<void> _handleExport(BuildContext context, ScannerScreenState state) async {
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
        final folderName = result.folderDisplayName ?? 'stockage externe';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document exporté vers $folderName'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
        // Set just scanned state for celebration message
        ref.read(hasJustScannedProvider.notifier).state = true;
        _navigateToDocuments(context);
      } else if (result.isFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Échec de l\'exportation'),
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

  /// Handles OCR extraction and contact creation from scanned document.
  Future<void> _handleOcr(BuildContext context, ScannerScreenState state) async {
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
          l10n?.abandonScanMessage ?? 'Are you sure you want to abandon this scan? This action cannot be undone.',
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

/// View shown after document is saved.
/// Unified view for scan result (preview + post-save actions).
class _ResultView extends ConsumerWidget {
  const _ResultView({
    required this.scanResult,
    required this.savedDocument,
    required this.selectedIndex,
    required this.onPageSelected,
    required this.onSave,
    required this.onDelete,
    required this.onShare,
    required this.onExport,
    required this.onOcr,
    required this.onDone,
  });

  final ScanResult? scanResult;
  final Document? savedDocument;
  final int selectedIndex;
  final void Function(int) onPageSelected;
  final Function(String, String?) onSave;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onExport;
  final VoidCallback onOcr;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSaved = savedDocument != null;
    final l10n = AppLocalizations.of(context);
    
    final now = DateTime.now();
    final timestamp = 'scanai_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
                      '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    // We prefer the saved document for title, but fallback to a default if not yet saved
    final title = savedDocument?.title ?? timestamp;
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Spacing to clear the floating header
          // Spacing to clear the system status bar
          const SizedBox(height: 60),
          
          // 1. Top Section: Mascot & Bubble (Simplified)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mascot Card
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF000000).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark 
                            ? const Color(0xFFFFFFFF).withValues(alpha: 0.1) 
                            : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: BentoMascot(
                        height: 90,
                        variant: BentoMascotVariant.photo,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Message Bubble using BentoSpeechBubble widget
                Expanded(
                  flex: 6,
                  child: BentoSpeechBubble(
                    tailDirection: BubbleTailDirection.left,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Center(
                      child: Text(
                        isSaved ? 'Hop, c\'est dans la boîte !' : 'On l\'enregistre ?',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 2. Center Section: Document Preview
          Container(
            height: 310, // Reduced from 380 to save vertical space
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: BentoCard(
                padding: EdgeInsets.zero,
                borderRadius: 28,
                backgroundColor: isDark 
                    ? Colors.white.withValues(alpha: 0.05) 
                    : Colors.white,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: savedDocument != null 
                    ? _SavedPreview(document: savedDocument!)
                    : (scanResult != null ? _PagePreview(imagePath: scanResult!.pages[selectedIndex].imagePath) : const SizedBox()),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Page Info Text
          if (!isSaved && scanResult != null)
            Text(
              'Page ${selectedIndex + 1} sur ${scanResult!.pageCount}',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            
          const SizedBox(height: 16),
          
          // 3. Footer Section: Action Wizard (Multi-step)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: _ActionWizard(
              initialTitle: title,
              isSaved: isSaved,
              onSave: onSave,
              onDelete: onDelete,
              onShare: onShare,
              onExport: onExport,
              onOcr: onOcr,
              onDone: onDone,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedPreview extends ConsumerWidget {
  const _SavedPreview({required this.document});
  final Document document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(documentRepositoryProvider);
    return FutureBuilder<String?>(
      future: repository.getDecryptedThumbnailPath(document),
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path == null) return const Center(child: CircularProgressIndicator());
        return Image.file(File(path), fit: BoxFit.contain);
      },
    );
  }
}

class _ActionWizard extends StatefulWidget {
  const _ActionWizard({
    required this.initialTitle,
    required this.isSaved,
    required this.onSave,
    required this.onDelete,
    required this.onShare,
    required this.onExport,
    required this.onOcr,
    required this.onDone,
  });

  final String initialTitle;
  final bool isSaved;
  final Function(String, String?) onSave;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onExport;
  final VoidCallback onOcr;
  final VoidCallback onDone;

  @override
  State<_ActionWizard> createState() => _ActionWizardState();
}

class _ActionWizardState extends State<_ActionWizard> with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _pulseController;
  late Animation<double> _flipAnimation;
  late Animation<double> _pulseAnimation;
  late TextEditingController _titleController;
  late TextEditingController _folderSearchController;
  
  int _step = 0; // 0: Rename, 1: Folder selection, 2: Final Actions
  String? _selectedFolderId;
  String _folderSearchQuery = '';
  bool _isSavingLocal = false;

  @override
  void initState() {
    super.initState();
    // Initialize empty if unsaved to show the "temporary" timestamp hint
    _titleController = TextEditingController(text: widget.isSaved ? widget.initialTitle : '');
    _folderSearchController = TextEditingController();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    if (widget.isSaved) {
      _step = 2;
      _flipController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_ActionWizard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSaved && !oldWidget.isSaved) {
      // Artificially wait a bit for the pulse to feel intentional and complete
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        
        setState(() {
          _isSavingLocal = false;
          _step = 2;
        });
        _pulseController.stop();
        _flipController.forward();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _folderSearchController.dispose();
    _flipController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleNextWithFlip() async {
    // Phase 1: Flip to halfway (90 degrees)
    await _flipController.animateTo(0.5, duration: const Duration(milliseconds: 300));
    
    // Switch to step 1
    setState(() => _step = 1);
    
    // Phase 2: Complete the flip
    await _flipController.animateTo(1.0, duration: const Duration(milliseconds: 300));
    
    // Reset controller for next potential flip (step 1 -> step 2)
    _flipController.value = 0.0;
  }

  Future<void> _handleBackWithFlip() async {
    await _flipController.animateTo(0.5, duration: const Duration(milliseconds: 300));
    setState(() => _step = 0);
    await _flipController.reverse();
    _flipController.value = 0.0;
  }

  Future<void> _handleSaveWithFlip() async {
    // Use the controller text if provided, otherwise fallback to the temporary timestamp title
    final finalTitle = _titleController.text.trim().isEmpty ? widget.initialTitle : _titleController.text.trim();
    
    setState(() => _isSavingLocal = true);
    _pulseController.repeat(reverse: true);

    // The actual save happens via widget.onSave. 
    widget.onSave(finalTitle, _selectedFolderId);
    
    // Note: didUpdateWidget will detect isSaved change and trigger the final flip.
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320, // Consistent fixed height for all steps
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final isFlipping = _flipController.value > 0 && _flipController.value < 1;
          final angle = _flipAnimation.value * pi;
          final isBack = angle > pi / 2;

          return Stack(
            children: [
              Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                alignment: Alignment.center,
                child: isBack
                    ? Transform(
                        transform: Matrix4.identity()..rotateY(pi),
                        alignment: Alignment.center,
                        child: _step == 1 ? _buildFolderStep() : _buildFinalActions(),
                      )
                    : (_step == 0 ? _buildRenameStep() : _buildFolderStep()),
              ),
              // Full-screen loading removed in favor of button-specific pulse animation
            ],
          );
        },
      ),
    );
  }

  Widget _buildRenameStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              labelText: l10n?.documentName ?? 'Document name',
              labelStyle: GoogleFonts.outfit(
                color: isDark ? Colors.white60 : Colors.black45,
                fontWeight: FontWeight.w600,
              ),
              hintText: 'ex: ${widget.initialTitle}',
              hintStyle: GoogleFonts.outfit(
                color: isDark ? Colors.white30 : Colors.black26,
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: isDark 
                  ? const Color(0xFFFFFFFF).withValues(alpha: 0.05) 
                  : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF4F46E5),
                  width: 2,
                ),
              ),
              prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF4F46E5)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSimpleButton(
                  label: l10n?.delete ?? 'Delete',
                  icon: Icons.delete_outline_rounded,
                  onTap: widget.onDelete,
                  color: Colors.redAccent,
                  isSecondary: true,
                ),
              ),
              const SizedBox(width: 12),
                  Expanded(
                    child: _buildSimpleButton(
                      label: l10n?.save ?? 'Save',
                      icon: Icons.arrow_forward_rounded,
                      onTap: _handleNextWithFlip,
                      color: const Color(0xFF4F46E5),
                      isSecondary: false,
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFolderStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    return Consumer(
      builder: (context, ref, _) {
        final folderService = ref.read(folderServiceProvider);
        return FutureBuilder<List<Folder>>(
          future: folderService.getAllFolders(),
          builder: (context, snapshot) {
            final folders = snapshot.data ?? [];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Back and Search integrated
                  Row(
                    children: [
                      IconButton(
                        onPressed: _handleBackWithFlip,
                        icon: const Icon(Icons.arrow_back_rounded, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextField(
                            controller: _folderSearchController,
                            onChanged: (value) => setState(() => _folderSearchQuery = value),
                            style: GoogleFonts.outfit(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: l10n?.searchFolder ?? 'Search folder...',
                              hintStyle: GoogleFonts.outfit(color: isDark ? Colors.white30 : Colors.black38, fontSize: 13),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 9),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 85, // Reduced height for more compact cards
                    child: Builder(
                      builder: (context) {
                        // Sort folders by creation date descent (newest first)
                        final sortedFolders = List<Folder>.from(folders)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                        
                        final filteredFolders = _folderSearchQuery.isEmpty 
                            ? sortedFolders 
                            : sortedFolders.where((f) => f.name.toLowerCase().contains(_folderSearchQuery.toLowerCase())).toList();
                        
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredFolders.length + (_folderSearchQuery.isEmpty ? 2 : 0),
                          itemBuilder: (context, index) {
                            if (_folderSearchQuery.isEmpty) {
                              if (index == 0 && filteredFolders.isNotEmpty) {
                                // NEWEST FOLDER (takes index 0)
                                final folder = filteredFolders[0];
                                final isSelected = _selectedFolderId == folder.id;
                                return _buildFolderOption(
                                  icon: Icons.folder_rounded,
                                  label: folder.name,
                                  isSelected: isSelected,
                                  onTap: () => setState(() => _selectedFolderId = folder.id),
                                  color: folder.color != null ? _parseColor(folder.color!) : null,
                                );
                              }
                              
                              // Adjust index for subsequent items
                              final realIndex = filteredFolders.isEmpty ? index : index - (index > 0 ? 1 : 0);
                              
                              if (index == (filteredFolders.isEmpty ? 0 : 1)) {
                                // Create New Folder
                                return _buildFolderOption(
                                  icon: Icons.create_new_folder_outlined,
                                  label: l10n?.newFolder ?? 'New',
                                  isSelected: false,
                                  onTap: () async {
                                    final result = await showDialog<BentoFolderDialogResult>(
                                      context: context,
                                      builder: (context) => const BentoFolderDialog(),
                                    );
                                    if (result != null && result.name.isNotEmpty) {
                                      try {
                                        final newFolder = await folderService.createFolder(
                                          name: result.name,
                                          color: result.color,
                                        );
                                        setState(() {
                                          _selectedFolderId = newFolder.id;
                                          _folderSearchQuery = '';
                                          _folderSearchController.clear();
                                        });
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Échec création dossier: $e')),
                                          );
                                        }
                                      }
                                    }
                                  },
                                );
                              }
                              if (index == (filteredFolders.isEmpty ? 1 : 2)) {
                                // Root folder (no folder)
                                final isSelected = _selectedFolderId == null;
                                return _buildFolderOption(
                                  icon: Icons.home_outlined,
                                  label: l10n?.myDocs ?? 'My Docs',
                                  isSelected: isSelected,
                                  onTap: () => setState(() => _selectedFolderId = null),
                                );
                              }
                              
                              // Other folders
                              final folder = filteredFolders[index - (filteredFolders.isEmpty ? 2 : 2)];
                              // We already showed folders[0] at index 0, so we skip it here if it exists
                              final folderToShow = filteredFolders[index - 2]; 
                              if (folderToShow.id == filteredFolders[0].id) {
                                // This is a bit tricky, let's just use a clear logic:
                                // [Newest] [Create] [Root] [Rest...]
                              }
                              
                              // Simplified logic for order: [Newest] [Create] [Root] [Others...]
                              // Wait, if filteredFolders is empty: [Create] [Root]
                              // If not empty: [F[0]] [Create] [Root] [F[1]...]
                              
                              if (index >= 3) {
                                final folder = filteredFolders[index - 2];
                                final isSelected = _selectedFolderId == folder.id;
                                return _buildFolderOption(
                                  icon: Icons.folder_rounded,
                                  label: folder.name,
                                  isSelected: isSelected,
                                  onTap: () => setState(() => _selectedFolderId = folder.id),
                                  color: folder.color != null ? _parseColor(folder.color!) : null,
                                );
                              }
                              return const SizedBox();
                            } else {
                              // Search results: alphabetical or recent
                              final folder = filteredFolders[index];
                              final isSelected = _selectedFolderId == folder.id;
                              return _buildFolderOption(
                                icon: Icons.folder_rounded,
                                label: folder.name,
                                isSelected: isSelected,
                                onTap: () => setState(() => _selectedFolderId = folder.id),
                                color: folder.color != null ? _parseColor(folder.color!) : null,
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Builder(
                    builder: (context) {
                      Color btnColor = const Color(0xFF4F46E5); // Default Indigo
                      if (_selectedFolderId != null) {
                        final folder = folders.firstWhere((f) => f.id == _selectedFolderId, orElse: () => folders.first);
                        if (folder.color != null) {
                          btnColor = _parseColor(folder.color!);
                        }
                      }
                      
                      return _buildSimpleButton(
                        label: l10n?.saveHere ?? 'Save here',
                        icon: Icons.check_circle_rounded,
                        onTap: _handleSaveWithFlip,
                        color: btnColor,
                        isSecondary: false,
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFolderOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? (color?.withValues(alpha: 0.1) ?? const Color(0xFF4F46E5).withValues(alpha: 0.1))
              : (isDark ? Colors.black.withValues(alpha: 0.1) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? (color ?? const Color(0xFF4F46E5))
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              color: color ?? (isSelected ? const Color(0xFF4F46E5) : (isDark ? Colors.white60 : Colors.black38)),
              size: 20, // Slightly smaller as requested
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isSelected 
                    ? (isDark ? Colors.white : Colors.black87) 
                    : (isDark ? Colors.white54 : Colors.black54),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalActions() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.zero,
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: [
          _buildActionTile(
            icon: Icons.share_rounded,
            label: l10n?.share ?? 'Share',
            onTap: widget.onShare,
            color: const Color(0xFF6366F1),
          ),
          _buildActionTile(
            icon: Icons.save_alt_rounded,
            label: l10n?.export ?? 'Export',
            onTap: widget.onExport,
            color: const Color(0xFF10B981),
          ),
          _buildActionTile(
            icon: Icons.auto_fix_high_rounded,
            label: l10n?.ocr ?? 'OCR',
            onTap: widget.onOcr,
            color: const Color(0xFFF59E0B),
          ),
          _buildActionTile(
            icon: Icons.check_circle_rounded,
            label: l10n?.finish ?? 'Finish',
            onTap: widget.onDone,
            color: const Color(0xFF4F46E5),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required bool isSecondary,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: isSecondary
              ? (isDark ? Colors.redAccent.withValues(alpha: 0.1) : const Color(0xFFFEF2F2))
              : color,
          borderRadius: BorderRadius.circular(20),
          border: isSecondary
              ? Border.all(color: color.withValues(alpha: 0.3), width: 1.5)
              : null,
          boxShadow: isSecondary ? null : [
            BoxShadow(
              color: color.withValues(alpha: _isSavingLocal ? 0.6 : 0.3),
              blurRadius: _isSavingLocal ? 20 : 12,
              spreadRadius: _isSavingLocal ? 4 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: _isSavingLocal ? _pulseAnimation.value : 1.0,
              child: child,
            );
          },
          child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSecondary ? color : Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isSecondary ? color : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon, 
    required String label, 
    required VoidCallback onTap, 
    required Color color,
    double? height,
    bool isWide = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF000000).withValues(alpha: 0.6) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isWide 
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

/// Single page preview image.
class _PagePreview extends StatelessWidget {
  const _PagePreview({required this.imagePath});

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
          Icon(Icons.broken_image_outlined, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Échec du chargement de l\'image',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ),
    );
  }
}

/// Horizontal thumbnail strip for multi-page navigation.
class _PageThumbnailStrip extends StatelessWidget {
  const _PageThumbnailStrip({
    required this.result,
    required this.selectedIndex,
    required this.onPageSelected,
  });

  final ScanResult result;
  final int selectedIndex;
  final void Function(int) onPageSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: result.pageCount,
      itemBuilder: (context, index) {
        final page = result.pages[index];
        final isSelected = index == selectedIndex;

        return Padding(
          padding: EdgeInsets.only(right: index < result.pageCount - 1 ? 8 : 0),
          child: GestureDetector(
            onTap: () => onPageSelected(index),
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.file(
                      File(page.imagePath),
                      fit: BoxFit.cover,
                      cacheWidth: 112,
                      cacheHeight: 160,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.image_not_supported_outlined, size: 24),
                        );
                      },
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                        child: Icon(Icons.check, size: 12, color: theme.colorScheme.onPrimary),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
