import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/camera_permission_service.dart';
import '../../../core/permissions/permission_dialog.dart';
import '../../../core/permissions/storage_permission_service.dart';
import '../../documents/domain/document_model.dart';
import '../../documents/presentation/documents_screen.dart';
import '../../folders/domain/folder_model.dart';
import '../../folders/domain/folder_service.dart';
import '../../sharing/domain/document_share_service.dart';
import '../domain/scanner_service.dart';

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
      appBar: AppBar(
        title: Text(state.hasSavedDocument
            ? 'Saved'
            : (state.hasResult ? 'Preview' : 'Scan Document')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            if (state.hasSavedDocument) {
              // Already saved, just go to documents
              _navigateToDocuments(context);
            } else if (state.hasResult) {
              // Not saved, ask to discard
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
        actions: [
          // Only show "add more pages" if not yet saved
          if (state.hasResult && !state.hasSavedDocument) ...[
            IconButton(
              icon: const Icon(Icons.add_a_photo_outlined),
              tooltip: 'Add more pages',
              onPressed: state.isLoading
                  ? null
                  : _startMultiPageScanWithPermissionCheck,
            ),
          ],
        ],
      ),
      body: _buildBody(context, state, notifier, theme),
      floatingActionButton: _buildFab(context, state, notifier),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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

    // After save: show Share and Done buttons
    if (state.hasSavedDocument) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton.extended(
            heroTag: 'share',
            onPressed: () => _handleShare(context, state),
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share'),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            heroTag: 'done',
            onPressed: () => _navigateToDocuments(context),
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            icon: const Icon(Icons.check),
            label: const Text('Done'),
          ),
        ],
      );
    }

    // Before save: show Discard and Save buttons (only if we have a scan result)
    if (state.hasResult) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton.extended(
            heroTag: 'discard',
            onPressed: () async {
              final shouldDiscard = await _showDiscardDialog(context);
              if (shouldDiscard == true) {
                await notifier.discardScan();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            backgroundColor: theme.colorScheme.errorContainer,
            foregroundColor: theme.colorScheme.onErrorContainer,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Discard'),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            heroTag: 'save',
            onPressed: () => _handleSave(context, state, notifier),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ],
      );
    }

    return null;
  }

  Future<void> _handleShare(BuildContext context, ScannerScreenState state) async {
    if (state.savedDocument == null) return;

    final shareService = ref.read(documentShareServiceProvider);

    try {
      final result = await shareService.shareDocuments([state.savedDocument!]);
      await shareService.cleanupTempFiles(result.tempFilePaths);
      // Navigate to documents after sharing
      if (context.mounted) {
        _navigateToDocuments(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
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
    final controller = TextEditingController(text: defaultTitle);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Document name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.of(context).pop(value);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                Navigator.of(context).pop(title);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
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
  Future<_CreateFolderResult?> _showCreateFolderDialog(BuildContext context) async {
    return showDialog<_CreateFolderResult>(
      context: context,
      builder: (context) => const _CreateFolderWithColorDialog(),
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Document Saved',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              documentTitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Use the buttons below to share or finish',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
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
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
    final selectedPage = result.pages[selectedIndex];

    return Column(
      children: [
        // Main preview area
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _PagePreview(imagePath: selectedPage.imagePath),
          ),
        ),

        // Page info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Page ${selectedIndex + 1} of ${result.pageCount}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        // Page thumbnails (if multi-page)
        if (result.pageCount > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: _PageThumbnailStrip(
              result: result,
              selectedIndex: selectedIndex,
              onPageSelected: onPageSelected,
            ),
          ),
        ],

        // Bottom padding for FAB
        const SizedBox(height: 88),
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

/// Result from folder creation dialog.
class _CreateFolderResult {
  const _CreateFolderResult({
    required this.name,
    this.color,
  });

  final String name;
  final String? color;
}

/// Dialog for creating a new folder with name and color.
class _CreateFolderWithColorDialog extends StatefulWidget {
  const _CreateFolderWithColorDialog();

  @override
  State<_CreateFolderWithColorDialog> createState() => _CreateFolderWithColorDialogState();
}

class _CreateFolderWithColorDialogState extends State<_CreateFolderWithColorDialog> {
  late final TextEditingController _nameController;
  String? _selectedColor;
  String? _error;

  static const List<String> _folderColors = [
    '#F44336', // Red
    '#E91E63', // Pink
    '#9C27B0', // Purple
    '#673AB7', // Deep Purple
    '#3F51B5', // Indigo
    '#2196F3', // Blue
    '#03A9F4', // Light Blue
    '#00BCD4', // Cyan
    '#009688', // Teal
    '#4CAF50', // Green
    '#8BC34A', // Light Green
    '#CDDC39', // Lime
    '#FFEB3B', // Yellow
    '#FFC107', // Amber
    '#FF9800', // Orange
    '#FF5722', // Deep Orange
    '#795548', // Brown
    '#607D8B', // Blue Grey
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Folder name cannot be empty');
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(_CreateFolderResult(
      name: name,
      color: _selectedColor,
    ));
  }

  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('New Folder'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name field
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Folder name',
                errorText: _error,
                border: const OutlineInputBorder(),
                hintText: 'Enter folder name',
              ),
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            // Color picker
            Text(
              'Color (optional)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // No color option
                GestureDetector(
                  onTap: () => setState(() => _selectedColor = null),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                      border: _selectedColor == null
                          ? Border.all(color: theme.colorScheme.primary, width: 2)
                          : null,
                    ),
                    child: Icon(
                      Icons.folder_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // Color options
                for (final color in _folderColors)
                  GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _parseColor(color),
                        shape: BoxShape.circle,
                        border: _selectedColor == color
                            ? Border.all(color: theme.colorScheme.primary, width: 2)
                            : null,
                      ),
                      child: _selectedColor == color
                          ? const Icon(
                              Icons.check,
                              size: 20,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
