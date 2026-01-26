import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../l10n/app_localizations.dart';
import '../../documents/domain/document_model.dart';
import '../domain/ocr_service.dart';
import 'widgets/empty_result_view.dart';
import 'widgets/ocr_options_sheet.dart';
import 'widgets/processing_view.dart';
import 'widgets/prompt_view.dart';
import 'widgets/results_view.dart';

part 'ocr_results_screen.freezed.dart';

/// State for the OCR results screen.
///
/// Tracks the current OCR result, processing state, and user actions.
@freezed
class OcrResultsScreenState with _$OcrResultsScreenState {
  const OcrResultsScreenState._();

  /// Creates an [OcrResultsScreenState] with default values.
  factory OcrResultsScreenState({
    /// Whether OCR processing is currently in progress.
    @Default(false) bool isProcessing,

    /// Whether the screen is initializing (loading image, etc.).
    @Default(false) bool isInitializing,

    /// The OCR result after text extraction.
    OcrResult? ocrResult,

    /// Error message if OCR failed.
    String? error,

    /// Title of the document being processed.
    String? documentTitle,

    /// ID of the document being processed (for saving results).
    String? documentId,

    /// Path to the source image file.
    String? sourceImagePath,

    /// Source image bytes (alternative to file path).
    Uint8List? sourceImageBytes,

    /// OCR options being used.
    @Default(OcrOptions.defaultDocument) OcrOptions options,

    /// Currently selected text (for partial copy).
    String? selectedText,

    /// Processing progress (0.0 - 1.0) for multi-page documents.
    @Default(0.0) double progress,

    /// Current page being processed (for multi-page).
    @Default(0) int currentPage,

    /// Total pages to process (for multi-page).
    @Default(1) int totalPages,
    // ignore: redirect_to_invalid_return_type
  }) = _OcrResultsScreenState;

  /// Whether OCR has been completed successfully.
  bool get hasResult => ocrResult != null && ocrResult!.hasText;

  /// Whether there was an error.
  bool get hasError => error != null;

  /// Whether OCR completed but found no text.
  bool get isEmpty => ocrResult != null && ocrResult!.isEmpty;

  /// Whether in any loading state.
  bool get isLoading => isProcessing || isInitializing;

  /// Whether we can run OCR.
  bool get canRunOcr =>
      !isLoading && (sourceImagePath != null || sourceImageBytes != null);

  /// Whether we can copy text.
  bool get canCopy => hasResult && !isLoading;
}

/// State notifier for the OCR results screen.
///
/// Manages OCR processing, text extraction, and user actions.
class OcrResultsScreenNotifier extends StateNotifier<OcrResultsScreenState> {
  /// Creates an [OcrResultsScreenNotifier] with the given OCR service.
  OcrResultsScreenNotifier(this._ocrService)
      : super(OcrResultsScreenState());

  final OcrService _ocrService;

  /// Sets up the screen with initial data.
  ///
  /// Either [imagePath] or [imageBytes] must be provided.
  /// If [existingOcrText] is provided, it will be displayed without
  /// running OCR (useful for viewing previously extracted text).
  Future<void> initialize({
    String? imagePath,
    Uint8List? imageBytes,
    List<String>? imagePathsList,
    String? documentTitle,
    String? documentId,
    String? existingOcrText,
    OcrOptions options = OcrOptions.defaultDocument,
  }) async {
    state = state.copyWith(
      isInitializing: true,
      sourceImagePath: imagePath,
      sourceImageBytes: imageBytes,
      documentTitle: documentTitle,
      documentId: documentId,
      options: options,
      totalPages: imagePathsList?.length ?? 1,
      error: null,
    );

    try {
      // Initialize OCR service
      if (!_ocrService.isReady) {
        await _ocrService.initialize(languages: [options.language]);
      }

      // If we have existing OCR text, display it
      if (existingOcrText != null && existingOcrText.isNotEmpty) {
        final result = OcrResult(
          text: existingOcrText,
          language: options.language.code,
          wordCount: _countWords(existingOcrText),
          lineCount: _countLines(existingOcrText),
        );
        state = state.copyWith(
          isInitializing: false,
          ocrResult: result,
        );
      } else {
        state = state.copyWith(isInitializing: false);
      }
    } on OcrException catch (e) {
      state = state.copyWith(
        isInitializing: false,
        error: 'Failed to initialize OCR: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        isInitializing: false,
        error: 'Failed to initialize: $e',
      );
    }
  }

  /// Runs OCR on the source image(s).
  Future<OcrResult?> runOcr() async {
    if (!state.canRunOcr) return null;

    state = state.copyWith(
      isProcessing: true,
      progress: 0.0,
      error: null,
      ocrResult: null,
    );

    try {
      OcrResult result;

      // Prefer bytes over file path since documents are encrypted at rest
      // and bytes are already decrypted
      if (state.sourceImageBytes != null) {
        // Process from bytes (preferred for encrypted documents)
        result = await _ocrService.extractTextFromBytes(
          state.sourceImageBytes!,
          options: state.options,
        );
      } else if (state.sourceImagePath != null) {
        // Process from file path (for unencrypted images)
        result = await _ocrService.extractTextFromFile(
          state.sourceImagePath!,
          options: state.options,
        );
      } else {
        throw const OcrException('No image source available');
      }

      state = state.copyWith(
        isProcessing: false,
        ocrResult: result,
        progress: 1.0,
      );

      return result;
    } on OcrException catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'OCR failed: ${e.message}',
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'OCR failed: $e',
      );
      return null;
    }
  }

  /// Runs OCR on multiple image files with progress updates.
  Future<OcrResult?> runOcrMultiPage(List<String> imagePaths) async {
    if (imagePaths.isEmpty) return null;

    state = state.copyWith(
      isProcessing: true,
      progress: 0.0,
      totalPages: imagePaths.length,
      currentPage: 0,
      error: null,
      ocrResult: null,
    );

    try {
      final result = await _ocrService.extractTextWithProgress(
        imagePaths,
        options: state.options,
        onProgress: (currentPage, totalPages, _) {
          state = state.copyWith(
            currentPage: currentPage + 1,
            progress: (currentPage + 1) / totalPages,
          );
        },
      );

      state = state.copyWith(
        isProcessing: false,
        ocrResult: result,
        progress: 1.0,
      );

      return result;
    } on OcrException catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'OCR failed: ${e.message}',
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'OCR failed: $e',
      );
      return null;
    }
  }

  /// Changes the OCR options and optionally re-runs OCR.
  void setOptions(OcrOptions options, {bool rerunOcr = false}) {
    state = state.copyWith(options: options);
    if (rerunOcr) {
      runOcr();
    }
  }

  /// Clears the current error.
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Sets the selected text (for partial copying).
  void setSelectedText(String? text) {
    state = state.copyWith(
      selectedText: text,
    );
  }

  /// Clears the selected text.
  void clearSelectedText() {
    state = state.copyWith(selectedText: null);
  }

  /// Gets the text to copy (selected text or full text).
  String? getTextToCopy() {
    if (state.selectedText != null && state.selectedText!.isNotEmpty) {
      return state.selectedText;
    }
    return state.ocrResult?.trimmedText;
  }

  /// Counts words in text.
  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  /// Counts lines in text.
  int _countLines(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split('\n').length;
  }
}

/// Riverpod provider for the OCR results screen state.
final ocrResultsScreenProvider = StateNotifierProvider.autoDispose<
    OcrResultsScreenNotifier, OcrResultsScreenState>(
  (ref) {
    final ocrService = ref.watch(ocrServiceProvider);
    return OcrResultsScreenNotifier(ocrService);
  },
);

/// Screen for displaying and interacting with OCR results.
///
/// Shows extracted text from a document with options to:
/// - Copy text to clipboard
/// - Share text via system share sheet
/// - Re-run OCR with different settings
/// - View OCR metadata (word count, processing time, etc.)
///
/// ## Usage
/// ```dart
/// // View existing OCR text
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => OcrResultsScreen(
///       existingOcrText: document.ocrText,
///       documentTitle: document.title,
///     ),
///   ),
/// );
///
/// // Run OCR on an image
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => OcrResultsScreen(
///       imagePath: '/path/to/image.jpg',
///       autoRunOcr: true,
///     ),
///   ),
/// );
/// ```
class OcrResultsScreen extends ConsumerStatefulWidget {
  /// Creates an [OcrResultsScreen].
  const OcrResultsScreen({
    super.key,
    this.imagePath,
    this.imageBytes,
    this.imagePathsList,
    this.existingOcrText,
    this.documentTitle,
    this.documentId,
    this.document,
    this.autoRunOcr = false,
    this.onOcrComplete,
    this.onSaveRequested,
  });

  /// Path to the image file for OCR.
  final String? imagePath;

  /// Image bytes for OCR (alternative to file path).
  final Uint8List? imageBytes;

  /// List of image paths for multi-page OCR.
  final List<String>? imagePathsList;

  /// Existing OCR text to display (if OCR was already run).
  final String? existingOcrText;

  /// Title of the document being processed.
  final String? documentTitle;

  /// ID of the document (for saving OCR results).
  final String? documentId;

  /// Full document object (provides all metadata).
  final Document? document;

  /// Whether to automatically run OCR when the screen opens.
  final bool autoRunOcr;

  /// Callback invoked when OCR is complete.
  final void Function(OcrResult result)? onOcrComplete;

  /// Callback invoked when user wants to save OCR results.
  final void Function(String text)? onSaveRequested;

  @override
  ConsumerState<OcrResultsScreen> createState() => _OcrResultsScreenState();
}

class _OcrResultsScreenState extends ConsumerState<OcrResultsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    // Initialize after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    final notifier = ref.read(ocrResultsScreenProvider.notifier);

    // Use document object if provided
    final doc = widget.document;

    await notifier.initialize(
      imagePath: widget.imagePath ?? doc?.filePath,
      imageBytes: widget.imageBytes,
      documentTitle: widget.documentTitle ?? doc?.title,
      documentId: widget.documentId ?? doc?.id,
      existingOcrText: widget.existingOcrText ?? doc?.ocrText,
    );

    // Auto-run OCR if requested and no existing text
    if (widget.autoRunOcr &&
        widget.existingOcrText == null &&
        doc?.ocrText == null) {
      final result = widget.imagePathsList != null
          ? await notifier.runOcrMultiPage(widget.imagePathsList!)
          : await notifier.runOcr();

      if (result != null) {
        widget.onOcrComplete?.call(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ocrResultsScreenProvider);
    final notifier = ref.read(ocrResultsScreenProvider.notifier);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // Listen for errors and show snackbar
    ref.listen<OcrResultsScreenState>(ocrResultsScreenProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            action: SnackBarAction(
              label: l10n?.dismiss ?? 'Dismiss',
              onPressed: notifier.clearError,
            ),
          ),
        );
      }
    });

    // Determine if we should show the Copy Selection FAB
    final hasSelection =
        state.selectedText != null && state.selectedText!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(state.documentTitle ?? (l10n?.ocrResults ?? 'OCR Results')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: l10n?.close ?? 'Close',
        ),
        actions: [
          if (state.hasResult) ...[
            // Search button
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _showSearchSheet(context, state, theme),
              tooltip: l10n?.searchInTextTooltip ?? 'Search in text',
            ),
            // Copy all button
            IconButton(
              icon: const Icon(Icons.copy_all),
              onPressed:
                  state.canCopy ? () => _copyAllText(context, state) : null,
              tooltip: l10n?.copyAllTextTooltip ?? 'Copy all text',
            ),
            // Share button
            IconButton(
              icon: const Icon(Icons.share),
              onPressed:
                  state.canCopy ? () => _shareText(context, state) : null,
              tooltip: l10n?.shareTextTooltip ?? 'Share text',
            ),
          ],
          // More options menu
          PopupMenuButton<String>(
            onSelected: (value) =>
                _handleMenuAction(value, state, notifier, l10n),
            itemBuilder: (context) => [
              if (state.canRunOcr)
                PopupMenuItem(
                  value: 'rerun',
                  child: ListTile(
                    leading: const Icon(Icons.refresh),
                    title: Text(l10n?.rerunOcr ?? 'Re-run OCR'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              PopupMenuItem(
                value: 'options',
                child: ListTile(
                  leading: const Icon(Icons.tune),
                  title: Text(l10n?.ocrOptions ?? 'OCR Options'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (state.hasResult && widget.onSaveRequested != null)
                PopupMenuItem(
                  value: 'save',
                  child: ListTile(
                    leading: const Icon(Icons.save),
                    title: Text(l10n?.saveToDocument ?? 'Save to Document'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _buildBody(context, state, notifier, theme),
      // Conditional Copy Selection FAB - appears only when text is selected
      floatingActionButton: hasSelection
          ? FloatingActionButton.extended(
              onPressed: () => _copySelectedText(context, state, notifier),
              icon: const Icon(Icons.copy),
              label: Text(l10n?.copySelection ?? 'Copy Selection'),
              tooltip: l10n?.copySelectionTooltip ??
                  'Copy selected text to clipboard',
            )
          : null,
    );
  }

  Widget _buildBody(
    BuildContext context,
    OcrResultsScreenState state,
    OcrResultsScreenNotifier notifier,
    ThemeData theme,
  ) {
    final l10n = AppLocalizations.of(context);
    if (state.isInitializing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n?.initializingOcr ?? 'Initializing OCR...'),
          ],
        ),
      );
    }

    if (state.isProcessing) {
      return OcrProcessingView(
        progress: state.progress,
        currentPage: state.currentPage,
        totalPages: state.totalPages,
        theme: theme,
      );
    }

    if (state.hasResult) {
      return OcrResultsView(
        result: state.ocrResult!,
        searchQuery: _searchQuery,
        theme: theme,
        onTextSelected: notifier.setSelectedText,
        selectedText: state.selectedText,
      );
    }

    if (state.isEmpty) {
      return EmptyResultView(
        onRetry: state.canRunOcr ? () => notifier.runOcr() : null,
        theme: theme,
      );
    }

    // No OCR run yet - show prompt
    return OcrPromptView(
      canRunOcr: state.canRunOcr,
      onRunOcr: () => notifier.runOcr(),
      theme: theme,
    );
  }

  void _handleMenuAction(
    String action,
    OcrResultsScreenState state,
    OcrResultsScreenNotifier notifier,
    AppLocalizations? l10n,
  ) {
    switch (action) {
      case 'rerun':
        notifier.runOcr();
        break;
      case 'options':
        _showOptionsSheet(context, state, notifier);
        break;
      case 'save':
        if (state.ocrResult != null) {
          widget.onSaveRequested?.call(state.ocrResult!.trimmedText);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(l10n?.ocrSaved ?? 'OCR text saved to document')),
          );
        }
        break;
    }
  }

  Future<void> _copyAllText(
    BuildContext context,
    OcrResultsScreenState state,
  ) async {
    if (state.ocrResult == null) return;
    final l10n = AppLocalizations.of(context);

    await Clipboard.setData(
      ClipboardData(text: state.ocrResult!.trimmedText),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.copiedWords(state.ocrResult!.wordCount ?? 0) ??
                'Copied ${state.ocrResult!.wordCount} words to clipboard',
          ),
          action: SnackBarAction(
            label: l10n?.dismiss ?? 'Dismiss',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  /// Copies the selected text to clipboard.
  Future<void> _copySelectedText(
    BuildContext context,
    OcrResultsScreenState state,
    OcrResultsScreenNotifier notifier,
  ) async {
    if (state.selectedText == null || state.selectedText!.isEmpty) return;
    final l10n = AppLocalizations.of(context);

    try {
      await Clipboard.setData(
        ClipboardData(text: state.selectedText!),
      );

      // Haptic feedback on successful copy
      await HapticFeedback.mediumImpact();

      // Count words in selected text
      final wordCount = _countWords(state.selectedText!);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.copiedWords(wordCount) ??
                  'Copied $wordCount ${wordCount == 1 ? 'word' : 'words'} to clipboard',
            ),
            action: SnackBarAction(
              label: l10n?.dismiss ?? 'Dismiss',
              onPressed: () {},
            ),
          ),
        );
      }

      // Clear selection after copying
      notifier.clearSelectedText();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                l10n?.failedToCopyText ?? 'Failed to copy text to clipboard'),
            action: SnackBarAction(
              label: l10n?.dismiss ?? 'Dismiss',
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  /// Counts words in text.
  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  Future<void> _shareText(
    BuildContext context,
    OcrResultsScreenState state,
  ) async {
    if (state.ocrResult == null) return;

    final text = state.ocrResult!.trimmedText;
    final title = state.documentTitle ?? 'OCR Text';

    // Create a temporary file for sharing
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName =
        '${title.replaceAll(RegExp(r'[^\w\s]'), '_')}_$timestamp.txt';
    final filePath = p.join(tempDir.path, fileName);
    final file = File(filePath);
    await file.writeAsString(text);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: 'text/plain')],
        subject: title,
      ),
    );
  }

  void _showSearchSheet(
    BuildContext context,
    OcrResultsScreenState state,
    ThemeData theme,
  ) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n?.searchInText ?? 'Search in text...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              autofocus: true,
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
            const SizedBox(height: 16),
            if (_searchQuery.isNotEmpty && state.ocrResult != null)
              Text(
                l10n?.matchesFound(_countOccurrences(
                        state.ocrResult!.text, _searchQuery)) ??
                    '${_countOccurrences(state.ocrResult!.text, _searchQuery)} matches found',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n?.done ?? 'Done'),
            ),
          ],
        ),
      ),
    );
  }

  int _countOccurrences(String text, String pattern) {
    if (pattern.isEmpty) return 0;
    return pattern.allMatches(text.toLowerCase()).length;
  }

  void _showOptionsSheet(
    BuildContext context,
    OcrResultsScreenState state,
    OcrResultsScreenNotifier notifier,
  ) {
    showOcrOptionsSheet(
      context,
      currentOptions: state.options,
      onOptionsChanged: (options) {
        notifier.setOptions(options);
        Navigator.pop(context);
      },
      onRunOcr: () {
        Navigator.pop(context);
        notifier.runOcr();
      },
    );
  }
}
