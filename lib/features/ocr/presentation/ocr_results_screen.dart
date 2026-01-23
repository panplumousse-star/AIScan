import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../documents/domain/document_model.dart';
import '../domain/ocr_service.dart';

/// State for the OCR results screen.
///
/// Tracks the current OCR result, processing state, and user actions.
@immutable
class OcrResultsScreenState {
  /// Creates an [OcrResultsScreenState] with default values.
  const OcrResultsScreenState({
    this.isProcessing = false,
    this.isInitializing = false,
    this.ocrResult,
    this.error,
    this.documentTitle,
    this.documentId,
    this.sourceImagePath,
    this.sourceImageBytes,
    this.options = OcrOptions.defaultDocument,
    this.selectedText,
    this.progress = 0.0,
    this.currentPage = 0,
    this.totalPages = 1,
  });

  /// Whether OCR processing is currently in progress.
  final bool isProcessing;

  /// Whether the screen is initializing (loading image, etc.).
  final bool isInitializing;

  /// The OCR result after text extraction.
  final OcrResult? ocrResult;

  /// Error message if OCR failed.
  final String? error;

  /// Title of the document being processed.
  final String? documentTitle;

  /// ID of the document being processed (for saving results).
  final String? documentId;

  /// Path to the source image file.
  final String? sourceImagePath;

  /// Source image bytes (alternative to file path).
  final Uint8List? sourceImageBytes;

  /// OCR options being used.
  final OcrOptions options;

  /// Currently selected text (for partial copy).
  final String? selectedText;

  /// Processing progress (0.0 - 1.0) for multi-page documents.
  final double progress;

  /// Current page being processed (for multi-page).
  final int currentPage;

  /// Total pages to process (for multi-page).
  final int totalPages;

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

  /// Creates a copy with updated values.
  OcrResultsScreenState copyWith({
    bool? isProcessing,
    bool? isInitializing,
    OcrResult? ocrResult,
    String? error,
    String? documentTitle,
    String? documentId,
    String? sourceImagePath,
    Uint8List? sourceImageBytes,
    OcrOptions? options,
    String? selectedText,
    double? progress,
    int? currentPage,
    int? totalPages,
    bool clearError = false,
    bool clearResult = false,
    bool clearSelectedText = false,
  }) {
    return OcrResultsScreenState(
      isProcessing: isProcessing ?? this.isProcessing,
      isInitializing: isInitializing ?? this.isInitializing,
      ocrResult: clearResult ? null : (ocrResult ?? this.ocrResult),
      error: clearError ? null : (error ?? this.error),
      documentTitle: documentTitle ?? this.documentTitle,
      documentId: documentId ?? this.documentId,
      sourceImagePath: sourceImagePath ?? this.sourceImagePath,
      sourceImageBytes: sourceImageBytes ?? this.sourceImageBytes,
      options: options ?? this.options,
      selectedText:
          clearSelectedText ? null : (selectedText ?? this.selectedText),
      progress: progress ?? this.progress,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OcrResultsScreenState &&
        other.isProcessing == isProcessing &&
        other.isInitializing == isInitializing &&
        other.ocrResult == ocrResult &&
        other.error == error &&
        other.documentTitle == documentTitle &&
        other.documentId == documentId &&
        other.sourceImagePath == sourceImagePath &&
        other.options == options &&
        other.selectedText == selectedText &&
        other.progress == progress &&
        other.currentPage == currentPage &&
        other.totalPages == totalPages;
  }

  @override
  int get hashCode => Object.hash(
        isProcessing,
        isInitializing,
        ocrResult,
        error,
        documentTitle,
        documentId,
        sourceImagePath,
        options,
        selectedText,
        progress,
        currentPage,
        totalPages,
      );
}

/// State notifier for the OCR results screen.
///
/// Manages OCR processing, text extraction, and user actions.
class OcrResultsScreenNotifier extends StateNotifier<OcrResultsScreenState> {
  /// Creates an [OcrResultsScreenNotifier] with the given OCR service.
  OcrResultsScreenNotifier(this._ocrService)
      : super(const OcrResultsScreenState());

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
      clearError: true,
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
      clearError: true,
      clearResult: true,
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
      clearError: true,
      clearResult: true,
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
    state = state.copyWith(clearError: true);
  }

  /// Sets the selected text (for partial copying).
  void setSelectedText(String? text) {
    state = state.copyWith(
      selectedText: text,
      clearSelectedText: text == null,
    );
  }

  /// Clears the selected text.
  void clearSelectedText() {
    state = state.copyWith(clearSelectedText: true);
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

    // Listen for errors and show snackbar
    ref.listen<OcrResultsScreenState>(ocrResultsScreenProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            action: SnackBarAction(
              label: 'Dismiss',
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
        title: Text(state.documentTitle ?? 'OCR Results'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
        actions: [
          if (state.hasResult) ...[
            // Search button
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _showSearchSheet(context, state, theme),
              tooltip: 'Search in text',
            ),
            // Copy all button
            IconButton(
              icon: const Icon(Icons.copy_all),
              onPressed: state.canCopy
                  ? () => _copyAllText(context, state)
                  : null,
              tooltip: 'Copy all text',
            ),
            // Share button
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: state.canCopy
                  ? () => _shareText(context, state)
                  : null,
              tooltip: 'Share text',
            ),
          ],
          // More options menu
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(value, state, notifier),
            itemBuilder: (context) => [
              if (state.canRunOcr)
                const PopupMenuItem(
                  value: 'rerun',
                  child: ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('Re-run OCR'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem(
                value: 'options',
                child: ListTile(
                  leading: Icon(Icons.tune),
                  title: Text('OCR Options'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (state.hasResult && widget.onSaveRequested != null)
                const PopupMenuItem(
                  value: 'save',
                  child: ListTile(
                    leading: Icon(Icons.save),
                    title: Text('Save to Document'),
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
              label: const Text('Copy Selection'),
              tooltip: 'Copy selected text to clipboard',
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
    if (state.isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing OCR...'),
          ],
        ),
      );
    }

    if (state.isProcessing) {
      return _ProcessingView(
        progress: state.progress,
        currentPage: state.currentPage,
        totalPages: state.totalPages,
        theme: theme,
      );
    }

    if (state.hasResult) {
      return _ResultsView(
        result: state.ocrResult!,
        searchQuery: _searchQuery,
        theme: theme,
        onTextSelected: notifier.setSelectedText,
        selectedText: state.selectedText,
      );
    }

    if (state.isEmpty) {
      return _EmptyResultView(
        onRetry: state.canRunOcr ? () => notifier.runOcr() : null,
        theme: theme,
      );
    }

    // No OCR run yet - show prompt
    return _PromptView(
      canRunOcr: state.canRunOcr,
      onRunOcr: () => notifier.runOcr(),
      theme: theme,
    );
  }

  void _handleMenuAction(
    String action,
    OcrResultsScreenState state,
    OcrResultsScreenNotifier notifier,
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
            const SnackBar(content: Text('OCR text saved to document')),
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

    await Clipboard.setData(
      ClipboardData(text: state.ocrResult!.trimmedText),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied ${state.ocrResult!.wordCount} words to clipboard',
          ),
          action: SnackBarAction(
            label: 'Dismiss',
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

    await Clipboard.setData(
      ClipboardData(text: state.selectedText!),
    );

    // Count words in selected text
    final wordCount = _countWords(state.selectedText!);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied $wordCount ${wordCount == 1 ? 'word' : 'words'} to clipboard',
          ),
          action: SnackBarAction(
            label: 'Dismiss',
            onPressed: () {},
          ),
        ),
      );
    }

    // Clear selection after copying
    notifier.clearSelectedText();
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
    final fileName = '${title.replaceAll(RegExp(r'[^\w\s]'), '_')}_$timestamp.txt';
    final filePath = p.join(tempDir.path, fileName);
    final file = File(filePath);
    await file.writeAsString(text);

    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'text/plain')],
      subject: title,
    );
  }

  void _showSearchSheet(
    BuildContext context,
    OcrResultsScreenState state,
    ThemeData theme,
  ) {
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
                hintText: 'Search in text...',
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
                '${_countOccurrences(state.ocrResult!.text, _searchQuery)} matches found',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
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
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _OcrOptionsSheet(
        options: state.options,
        onOptionsChanged: (options) {
          notifier.setOptions(options);
          Navigator.pop(context);
        },
        onRunOcr: () {
          Navigator.pop(context);
          notifier.runOcr();
        },
      ),
    );
  }
}

/// Processing view showing OCR progress.
class _ProcessingView extends StatelessWidget {
  const _ProcessingView({
    required this.progress,
    required this.currentPage,
    required this.totalPages,
    required this.theme,
  });

  final double progress;
  final int currentPage;
  final int totalPages;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: totalPages > 1 ? progress : null,
              strokeWidth: 4,
            ),
            const SizedBox(height: 24),
            Text(
              'Extracting text...',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (totalPages > 1)
              Text(
                'Processing page $currentPage of $totalPages',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Text(
                'This may take a moment',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (totalPages > 1) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progress,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).toInt()}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// View showing OCR results with selectable, copyable text.
class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.result,
    required this.searchQuery,
    required this.theme,
    required this.onTextSelected,
    this.selectedText,
  });

  final OcrResult result;
  final String searchQuery;
  final ThemeData theme;
  final void Function(String?) onTextSelected;
  final String? selectedText;

  /// Counts words in selected text.
  int _countSelectedWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedText != null && selectedText!.isNotEmpty;
    final selectedWordCount = hasSelection ? _countSelectedWords(selectedText!) : 0;

    return Column(
      children: [
        // Metadata bar
        _MetadataBar(result: result, theme: theme),

        // Word count badge for selected text
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: hasSelection ? 1.0 : 0.0,
            child: hasSelection
                ? _SelectionBadge(
                    wordCount: selectedWordCount,
                    theme: theme,
                  )
                : const SizedBox.shrink(),
          ),
        ),

        // Text content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selectable text with optional highlighting
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                  child: SelectableText(
                    result.trimmedText,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                      color: theme.colorScheme.onSurface,
                    ),
                    contextMenuBuilder: (context, editableTextState) {
                      return AdaptiveTextSelectionToolbar.editableText(
                        editableTextState: editableTextState,
                      );
                    },
                    onSelectionChanged: (selection, cause) {
                      if (selection.isCollapsed) {
                        onTextSelected(null);
                      } else {
                        final selectedText = result.trimmedText.substring(
                          selection.start,
                          selection.end,
                        );
                        onTextSelected(selectedText);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Copy hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Long press to select and copy text',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Metadata bar showing OCR result statistics.
class _MetadataBar extends StatelessWidget {
  const _MetadataBar({
    required this.result,
    required this.theme,
  });

  final OcrResult result;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MetadataItem(
            icon: Icons.text_fields,
            label: 'Words',
            value: '${result.wordCount ?? 0}',
            theme: theme,
          ),
          _MetadataItem(
            icon: Icons.format_line_spacing,
            label: 'Lines',
            value: '${result.lineCount ?? 0}',
            theme: theme,
          ),
          _MetadataItem(
            icon: Icons.timer_outlined,
            label: 'Time',
            value: result.processingTimeMs != null
                ? '${(result.processingTimeMs! / 1000).toStringAsFixed(1)}s'
                : 'N/A',
            theme: theme,
          ),
          if (result.confidence != null)
            _MetadataItem(
              icon: Icons.check_circle_outline,
              label: 'Confidence',
              value: result.confidencePercent,
              theme: theme,
            ),
        ],
      ),
    );
  }
}

/// Single metadata item in the metadata bar.
class _MetadataItem extends StatelessWidget {
  const _MetadataItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge showing selected word count.
class _SelectionBadge extends StatelessWidget {
  const _SelectionBadge({
    required this.wordCount,
    required this.theme,
  });

  final int wordCount;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.text_fields,
              size: 14,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 6),
            Text(
              '$wordCount ${wordCount == 1 ? 'mot sélectionné' : 'mots sélectionnés'}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// View shown when OCR completed but found no text.
class _EmptyResultView extends StatelessWidget {
  const _EmptyResultView({
    required this.onRetry,
    required this.theme,
  });

  final VoidCallback? onRetry;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.text_snippet_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No text found',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The image may not contain readable text,\nor the quality may be too low.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// View shown when OCR has not been run yet.
class _PromptView extends StatelessWidget {
  const _PromptView({
    required this.canRunOcr,
    required this.onRunOcr,
    required this.theme,
  });

  final bool canRunOcr;
  final VoidCallback onRunOcr;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.document_scanner_outlined,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Extract Text',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Run OCR to extract readable text\nfrom this document.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: canRunOcr ? onRunOcr : null,
              icon: const Icon(Icons.text_fields),
              label: const Text('Run OCR'),
            ),
            const SizedBox(height: 16),
            Text(
              'All processing happens locally on your device',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for OCR options configuration.
class _OcrOptionsSheet extends StatefulWidget {
  const _OcrOptionsSheet({
    required this.options,
    required this.onOptionsChanged,
    required this.onRunOcr,
  });

  final OcrOptions options;
  final void Function(OcrOptions) onOptionsChanged;
  final VoidCallback onRunOcr;

  @override
  State<_OcrOptionsSheet> createState() => _OcrOptionsSheetState();
}

class _OcrOptionsSheetState extends State<_OcrOptionsSheet> {
  late OcrLanguage _language;
  late OcrPageSegmentationMode _pageMode;

  @override
  void initState() {
    super.initState();
    _language = widget.options.language;
    _pageMode = widget.options.pageSegmentationMode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'OCR Options',
                  style: theme.textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Language selection
            Text(
              'Language',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<OcrLanguage>(
              value: _language,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                OcrLanguage.latin,
                OcrLanguage.chinese,
                OcrLanguage.japanese,
                OcrLanguage.korean,
                OcrLanguage.devanagari,
              ]
                  .map((lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(lang.displayName),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _language = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Page segmentation mode
            Text(
              'Document Type',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildModeChip(
                  'Auto',
                  OcrPageSegmentationMode.auto,
                  theme,
                ),
                _buildModeChip(
                  'Single Column',
                  OcrPageSegmentationMode.singleColumn,
                  theme,
                ),
                _buildModeChip(
                  'Single Block',
                  OcrPageSegmentationMode.singleBlock,
                  theme,
                ),
                _buildModeChip(
                  'Sparse Text',
                  OcrPageSegmentationMode.sparseText,
                  theme,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final options = widget.options.copyWith(
                        language: _language,
                        pageSegmentationMode: _pageMode,
                      );
                      widget.onOptionsChanged(options);
                    },
                    child: const Text('Apply'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final options = widget.options.copyWith(
                        language: _language,
                        pageSegmentationMode: _pageMode,
                      );
                      widget.onOptionsChanged(options);
                      widget.onRunOcr();
                    },
                    icon: const Icon(Icons.text_fields),
                    label: const Text('Run OCR'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(
    String label,
    OcrPageSegmentationMode mode,
    ThemeData theme,
  ) {
    final isSelected = _pageMode == mode;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _pageMode = mode);
        }
      },
    );
  }
}
