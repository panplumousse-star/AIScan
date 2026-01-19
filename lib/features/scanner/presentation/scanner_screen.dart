import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
import '../../../core/widgets/bento_background.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../core/widgets/bento_mascot.dart';
import '../../../core/widgets/bento_rename_document_dialog.dart';
import '../../../core/widgets/bento_share_format_dialog.dart';
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
        clearResult: true,
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
          // Custom Header
          _buildCustomHeader(context, state, notifier, theme),
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
                Expanded(
                  child: Center(
                    child: Text(
                      state.hasSavedDocument
                          ? 'Enregistré'
                          : (state.hasResult ? 'Aperçu' : 'Numérisation'),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                // "Add more pages" button removed per user request
                const SizedBox(width: 48), // Spacer for centering
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
    if (state.isScanning) {
      return const _LoadingView(message: 'Opening scanner...');
    }

    if (state.isSaving) {
      return const _LoadingView(message: 'Saving document...');
    }

    if (state.hasResult) {
      return _PreviewView(
        result: state.scanResult!,
        selectedIndex: state.selectedPageIndex,
        onPageSelected: notifier.selectPage,
      );
    }

    // After save: show saved confirmation
    if (state.hasSavedDocument) {
      return _SavedView(documentTitle: state.savedDocument!.title);
    }

    // Fallback: show loading while auto-scan starts
    return const _LoadingView(message: 'Starting scanner...');
  }

  Widget? _buildFab(
    BuildContext context,
    ScannerScreenState state,
    ScannerScreenNotifier notifier,
  ) {
    if (state.isLoading) return null;

    final theme = Theme.of(context);

    // After save: show Share, Export, OCR, and Done buttons
    if (state.hasSavedDocument) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BentoActionButton(
                onPressed: () => _handleShare(context, state),
                icon: Icons.share_rounded,
                label: 'Share',
                color: const Color(0xFF6366F1),
              ),
              const SizedBox(width: 8),
              _BentoActionButton(
                onPressed: () => _handleExport(context, state),
                icon: Icons.save_alt_rounded,
                label: 'Exporter',
                color: const Color(0xFF0D9488),
              ),
              const SizedBox(width: 8),
              _BentoActionButton(
                onPressed: () => _handleOcr(context, state),
                icon: Icons.contact_page_rounded,
                label: 'OCR',
                color: const Color(0xFF7C3AED),
              ),
              const SizedBox(width: 8),
              _BentoActionButton(
                onPressed: () => _navigateToDocuments(context),
                icon: Icons.check_circle_rounded,
                label: 'Fermer',
                isPrimary: true,
              ),
            ],
          ),
        ),
      );
    }

    // Before save: show Discard and Save buttons (only if we have a scan result)
    if (state.hasResult) {
      final isDark = theme.brightness == Brightness.dark;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final shouldDiscard = await _showDiscardDialog(context);
                  if (shouldDiscard == true) {
                    await notifier.discardScan();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                },
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.red.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Supprimer',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            color: Colors.redAccent,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark 
                        ? [
                            const Color(0xFF312E81),
                            const Color(0xFF3730A3),
                            const Color(0xFF1E1B4B),
                          ]
                        : [
                            const Color(0xFF6366F1),
                            const Color(0xFF4F46E5),
                            const Color(0xFF3730A3),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? Colors.black : const Color(0xFF4F46E5)).withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleSave(context, state, notifier),
                    borderRadius: BorderRadius.circular(20),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Enregistrer',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return null;
  }

  Future<void> _handleShare(BuildContext context, ScannerScreenState state) async {
    if (state.savedDocument == null) return;

    // Show format selection dialog
    final format = await showBentoShareFormatDialog(context);
    if (format == null) return; // User cancelled

    final shareService = ref.read(documentShareServiceProvider);

    try {
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

  Future<void> _handleSave(
    BuildContext context,
    ScannerScreenState state,
    ScannerScreenNotifier notifier,
  ) async {
    if (state.scanResult == null) return;

    // Show rename dialog before saving
    final documentTitle = await _showSaveRenameDialog(
      context,
      widget.documentTitle ?? 'Scan ${DateTime.now().toString().substring(0, 16)}',
    );

    // User cancelled the dialog
    if (documentTitle == null) return;

    // Show folder selection dialog
    if (!context.mounted) return;
    final selectedFolderId = await _showFolderSelectionDialog(context);

    // User cancelled the folder selection
    if (selectedFolderId == '_cancelled_') return;

    try {
      // Save to encrypted storage with selected folder
      final savedDocument = await notifier.saveToStorage(
        title: documentTitle,
        folderId: selectedFolderId ?? widget.folderId,
      );

      if (savedDocument != null) {
        // Call the new onDocumentSaved callback
        widget.onDocumentSaved?.call(savedDocument);

        // Also call legacy callback for backward compatibility
        // ignore: deprecated_member_use_from_same_package
        widget.onScanComplete?.call(state.scanResult!);

        if (context.mounted) {
          // Set just scanned state for celebration message
          ref.read(hasJustScannedProvider.notifier).state = true;
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Document saved: ${savedDocument.title}'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 2),
            ),
          );
          // Stay on screen to allow sharing - don't pop
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<String?> _showSaveRenameDialog(
    BuildContext context,
    String defaultTitle,
  ) async {
    return showBentoRenameDocumentDialog(
      context,
      currentTitle: defaultTitle,
      dialogTitle: 'Enregistrer le document',
      hintText: 'Nom du document...',
      confirmButtonText: 'Enregistrer',
    );
  }

  /// Shows a dialog to select a folder for saving the document.
  ///
  /// Returns the selected folder ID, or null for root.
  /// Returns a special value '_cancelled_' if the user cancelled.
  Future<String?> _showFolderSelectionDialog(BuildContext context) async {
    final folderService = ref.read(folderServiceProvider);
    final folders = await folderService.getAllFolders();

    if (!context.mounted) return '_cancelled_';

    return showDialog<String>(
      context: context,
      builder: (context) => _FolderSelectionDialog(
        folders: folders,
        onCreateFolder: () async {
          final result = await _showCreateFolderDialog(context);
          if (result != null && result.name.isNotEmpty) {
            try {
              final newFolder = await folderService.createFolder(
                name: result.name,
                color: result.color,
              );
              if (context.mounted) {
                Navigator.of(context).pop(newFolder.id);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to create folder: $e')),
                );
              }
            }
          }
        },
      ),
    );
  }

  /// Shows a dialog to create a new folder with name and color.
  Future<BentoFolderDialogResult?> _showCreateFolderDialog(BuildContext context) async {
    return showDialog<BentoFolderDialogResult>(
      context: context,
      builder: (context) => const BentoFolderDialog(),
    );
  }

  Future<bool?> _showDiscardDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard scan?'),
        content: const Text(
          'Are you sure you want to discard this scan? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}

/// View shown after document is saved.
class _SavedView extends StatelessWidget {
  const _SavedView({required this.documentTitle});

  final String documentTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BentoLevitationWidget(
              child: BentoMascot(
                height: 120,
                variant: BentoMascotVariant.photo,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Document Enregistré !',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              documentTitle,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            BentoCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              backgroundColor: isDark 
                  ? Colors.white.withValues(alpha: 0.05) 
                  : Colors.black.withValues(alpha: 0.03),
              child: Text(
                'Utilisez les boutons ci-dessous pour partager ou terminer.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 60), // Room for FABs
          ],
        ),
      ),
    );
  }
}

/// Loading state view.
class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const BentoBackground(),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const ScanaiLoader(size: 60),
              const SizedBox(height: 24),
              Text(
                message,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Preview view for scanned pages.
class _PreviewView extends StatelessWidget {
  const _PreviewView({
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
    final isDark = theme.brightness == Brightness.dark;
    final selectedPage = result.pages[selectedIndex];

    return Column(
      children: [
        SizedBox(height: MediaQuery.of(context).padding.top + 60),
        // Main preview area
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: BentoCard(
              padding: EdgeInsets.zero,
              borderRadius: 32,
              backgroundColor: isDark 
                  ? Colors.white.withValues(alpha: 0.05) 
                  : Colors.white.withValues(alpha: 0.8),
              blur: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: _PagePreview(imagePath: selectedPage.imagePath),
              ),
            ),
          ),
        ),

        // Mascot and Speech Bubble
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BentoLevitationWidget(
                child: BentoMascot(
                  height: 90,
                  variant: BentoMascotVariant.photo,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF000000).withValues(alpha: 0.6) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark 
                              ? const Color(0xFFFFFFFF).withValues(alpha: 0.1) 
                              : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'Hop, c\'est dans la boîte !',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                          letterSpacing: 0.2,
                        ),
                      ),
                    Positioned(
                      bottom: -10,
                      left: 8,
                      child: CustomPaint(
                        size: const Size(14, 14),
                        painter: _BubbleTailPainter(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                          borderColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Page info
        Text(
          'Page ${selectedIndex + 1} sur ${result.pageCount}',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),

        // Page thumbnails (if multi-page)
        if (result.pageCount > 1) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: _PageThumbnailStrip(
              result: result,
              selectedIndex: selectedIndex,
              onPageSelected: onPageSelected,
            ),
          ),
        ],

        // Bottom padding for redesigned FAB
        const SizedBox(height: 110),
      ],
    );
  }
}

/// Single page preview image.
///
/// Uses cacheWidth to limit memory usage while still allowing zoom.
class _PagePreview extends StatelessWidget {
  const _PagePreview({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);
    // Cache at 2x screen width for good quality when zooming
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

  Widget _buildLoadingPlaceholder(BuildContext context) {
    return const Center(
      child: ScanaiLoader(size: 40),
    );
  }

  Widget _buildErrorPlaceholder(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load image',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.error,
            ),
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
          padding: EdgeInsets.only(
            right: index < result.pageCount - 1 ? 8 : 0,
          ),
          child: GestureDetector(
            onTap: () => onPageSelected(index),
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withOpacity(0.3),
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
                      // Thumbnails are 56px wide, cache at 2x for retina displays
                      cacheWidth: 112,
                      cacheHeight: 160,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 24,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
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
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          size: 12,
                          color: theme.colorScheme.onPrimary,
                        ),
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

/// Dialog for selecting a folder when saving a document.
class _FolderSelectionDialog extends StatelessWidget {
  const _FolderSelectionDialog({
    required this.folders,
    required this.onCreateFolder,
  });

  final List<Folder> folders;
  final VoidCallback onCreateFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Save to folder'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Root folder option (no folder)
            ListTile(
              leading: Icon(
                Icons.home_outlined,
                color: theme.colorScheme.primary,
              ),
              title: const Text('My Documents'),
              subtitle: const Text('Save without folder'),
              onTap: () => Navigator.of(context).pop(null),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            if (folders.isNotEmpty) ...[
              const Divider(),
              // Existing folders list
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return ListTile(
                      leading: Icon(
                        Icons.folder_outlined,
                        color: folder.color != null
                            ? _parseColor(folder.color!)
                            : theme.colorScheme.secondary,
                      ),
                      title: Text(folder.name),
                      onTap: () => Navigator.of(context).pop(folder.id),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Create new folder button
            OutlinedButton.icon(
              onPressed: onCreateFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Create new folder'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop('_cancelled_'),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  /// Parses a hex color string to a Color.
  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

/// Painter for speech bubble tail pointing down-left toward mascot.
class _BubbleTailPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _BubbleTailPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Triangular path with rounded tip using a quadratic bezier (Bento Style)
    final path = Path();
    path.moveTo(0, 0);                 
    path.quadraticBezierTo(size.width * 1.2, size.height / 2, 0, size.height); 
    path.close();

    // 1. Shadow for the tail to match the card
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.03)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path.shift(const Offset(2, 4)), shadowPaint);

    // 2. Main fill
    canvas.drawPath(path, paint);

    // 3. Border stroke if needed
    if (borderColor != Colors.transparent) {
      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      
      final borderPath = Path();
      borderPath.moveTo(0, 0);
      borderPath.quadraticBezierTo(size.width * 1.2, size.height / 2, 0, size.height);
      canvas.drawPath(borderPath, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BentoActionButton extends StatelessWidget {
  const _BentoActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.color,
    this.isPrimary = false,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color? color;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveColor = color ?? const Color(0xFF4F46E5);

    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: isPrimary 
            ? LinearGradient(
                colors: isDark 
                    ? [const Color(0xFF312E81), const Color(0xFF1E1B4B)]
                    : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isPrimary ? null : effectiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: isPrimary 
            ? Border.all(color: Colors.white.withValues(alpha: 0.1))
            : Border.all(color: effectiveColor.withValues(alpha: 0.2), width: 1.5),
        boxShadow: isPrimary ? [
          BoxShadow(
            color: effectiveColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon, 
                  color: isPrimary ? Colors.white : effectiveColor, 
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    color: isPrimary ? Colors.white : effectiveColor,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
