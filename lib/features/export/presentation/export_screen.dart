import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/image_exporter.dart';
import '../domain/pdf_generator.dart';

/// Export format options.
enum ExportFormat {
  /// Export as PDF document.
  pdf,

  /// Export as JPEG image.
  jpeg,

  /// Export as PNG image.
  png,
}

/// Export quality presets.
enum ExportQuality {
  /// Maximum quality, larger file size.
  high,

  /// Balanced quality and file size.
  medium,

  /// Optimized for sharing, smaller file size.
  low,
}

/// Result of an export operation.
@immutable
class ExportResult {
  /// Creates an [ExportResult].
  const ExportResult({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.format,
  });

  /// Path to the exported file.
  final String filePath;

  /// Name of the exported file.
  final String fileName;

  /// Size of the exported file in bytes.
  final int fileSize;

  /// Format of the exported file.
  final ExportFormat format;

  /// Human-readable file size string.
  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// File extension based on format.
  String get fileExtension {
    switch (format) {
      case ExportFormat.pdf:
        return 'pdf';
      case ExportFormat.jpeg:
        return 'jpg';
      case ExportFormat.png:
        return 'png';
    }
  }

  /// MIME type based on format.
  String get mimeType {
    switch (format) {
      case ExportFormat.pdf:
        return 'application/pdf';
      case ExportFormat.jpeg:
        return 'image/jpeg';
      case ExportFormat.png:
        return 'image/png';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExportResult &&
        other.filePath == filePath &&
        other.fileName == fileName &&
        other.fileSize == fileSize &&
        other.format == format;
  }

  @override
  int get hashCode => Object.hash(filePath, fileName, fileSize, format);

  @override
  String toString() => 'ExportResult(file: $fileName, size: $fileSizeFormatted)';
}

/// State for the export screen.
@immutable
class ExportScreenState {
  /// Creates an [ExportScreenState] with default values.
  const ExportScreenState({
    this.format = ExportFormat.pdf,
    this.quality = ExportQuality.high,
    this.isExporting = false,
    this.isSharing = false,
    this.exportProgress = 0.0,
    this.error,
    this.lastExportResult,
    this.imageBytesList,
    this.documentTitle,
    this.pageCount = 1,
  });

  /// Selected export format.
  final ExportFormat format;

  /// Selected export quality.
  final ExportQuality quality;

  /// Whether export is in progress.
  final bool isExporting;

  /// Whether sharing is in progress.
  final bool isSharing;

  /// Export progress (0.0 to 1.0).
  final double exportProgress;

  /// Error message, if any.
  final String? error;

  /// Result of the last export operation.
  final ExportResult? lastExportResult;

  /// Source images to export.
  final List<Uint8List>? imageBytesList;

  /// Title for the exported document.
  final String? documentTitle;

  /// Number of pages to export.
  final int pageCount;

  /// Whether we're in any loading state.
  bool get isLoading => isExporting || isSharing;

  /// Whether we have images to export.
  bool get hasImages => imageBytesList != null && imageBytesList!.isNotEmpty;

  /// Whether export is ready.
  bool get canExport => hasImages && !isLoading;

  /// Whether we can share.
  bool get canShare => lastExportResult != null && !isLoading;

  /// Creates a copy with updated values.
  ExportScreenState copyWith({
    ExportFormat? format,
    ExportQuality? quality,
    bool? isExporting,
    bool? isSharing,
    double? exportProgress,
    String? error,
    ExportResult? lastExportResult,
    List<Uint8List>? imageBytesList,
    String? documentTitle,
    int? pageCount,
    bool clearError = false,
    bool clearExportResult = false,
  }) {
    return ExportScreenState(
      format: format ?? this.format,
      quality: quality ?? this.quality,
      isExporting: isExporting ?? this.isExporting,
      isSharing: isSharing ?? this.isSharing,
      exportProgress: exportProgress ?? this.exportProgress,
      error: clearError ? null : (error ?? this.error),
      lastExportResult: clearExportResult
          ? null
          : (lastExportResult ?? this.lastExportResult),
      imageBytesList: imageBytesList ?? this.imageBytesList,
      documentTitle: documentTitle ?? this.documentTitle,
      pageCount: pageCount ?? this.pageCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExportScreenState &&
        other.format == format &&
        other.quality == quality &&
        other.isExporting == isExporting &&
        other.isSharing == isSharing &&
        other.exportProgress == exportProgress &&
        other.error == error &&
        other.lastExportResult == lastExportResult &&
        other.documentTitle == documentTitle &&
        other.pageCount == pageCount;
  }

  @override
  int get hashCode => Object.hash(
        format,
        quality,
        isExporting,
        isSharing,
        exportProgress,
        error,
        lastExportResult,
        documentTitle,
        pageCount,
      );
}

/// State notifier for the export screen.
///
/// Manages export format selection, quality settings, and sharing functionality.
class ExportScreenNotifier extends StateNotifier<ExportScreenState> {
  /// Creates an [ExportScreenNotifier] with the given dependencies.
  ExportScreenNotifier(
    this._pdfGenerator,
    this._imageExporter,
  ) : super(const ExportScreenState());

  final PDFGenerator _pdfGenerator;
  final ImageExporter _imageExporter;

  /// Sets the source images to export.
  void setImages(List<Uint8List> images, {String? title, int? pageCount}) {
    state = state.copyWith(
      imageBytesList: images,
      documentTitle: title,
      pageCount: pageCount ?? images.length,
    );
  }

  /// Sets the export format.
  void setFormat(ExportFormat format) {
    state = state.copyWith(format: format, clearExportResult: true);
  }

  /// Sets the export quality.
  void setQuality(ExportQuality quality) {
    state = state.copyWith(quality: quality, clearExportResult: true);
  }

  /// Clears the current error.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Gets JPEG quality based on the quality preset.
  int _getJpegQuality() {
    switch (state.quality) {
      case ExportQuality.high:
        return 95;
      case ExportQuality.medium:
        return 85;
      case ExportQuality.low:
        return 70;
    }
  }

  /// Exports the document with current settings.
  ///
  /// Returns the export result, or null on failure.
  Future<ExportResult?> export() async {
    if (!state.canExport) return null;

    state = state.copyWith(
      isExporting: true,
      exportProgress: 0.0,
      clearError: true,
      clearExportResult: true,
    );

    try {
      // Get temporary directory for export
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final baseName = state.documentTitle ?? 'scan';
      final sanitizedName = _sanitizeFileName(baseName);

      ExportResult result;

      switch (state.format) {
        case ExportFormat.pdf:
          result = await _exportAsPdf(tempDir, sanitizedName, timestamp);
          break;
        case ExportFormat.jpeg:
          result = await _exportAsJpeg(tempDir, sanitizedName, timestamp);
          break;
        case ExportFormat.png:
          result = await _exportAsPng(tempDir, sanitizedName, timestamp);
          break;
      }

      state = state.copyWith(
        isExporting: false,
        exportProgress: 1.0,
        lastExportResult: result,
      );

      return result;
    } on PDFGeneratorException catch (e) {
      state = state.copyWith(
        isExporting: false,
        error: 'Failed to create PDF: ${e.message}',
      );
      return null;
    } on ImageExporterException catch (e) {
      state = state.copyWith(
        isExporting: false,
        error: 'Failed to export image: ${e.message}',
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isExporting: false,
        error: 'Export failed: $e',
      );
      return null;
    }
  }

  /// Exports as PDF document.
  Future<ExportResult> _exportAsPdf(
    Directory tempDir,
    String baseName,
    int timestamp,
  ) async {
    final fileName = '${baseName}_$timestamp.pdf';
    final filePath = path.join(tempDir.path, fileName);

    state = state.copyWith(exportProgress: 0.2);

    final options = PDFGeneratorOptions(
      title: state.documentTitle ?? 'Scanned Document',
      imageQuality: _getJpegQuality(),
      pageSize: PDFPageSize.a4,
      orientation: PDFOrientation.auto,
      imageFit: PDFImageFit.contain,
    );

    state = state.copyWith(exportProgress: 0.5);

    final generatedPdf = await _pdfGenerator.generateFromBytes(
      imageBytesList: state.imageBytesList!,
      options: options,
    );

    state = state.copyWith(exportProgress: 0.8);

    // Write to file
    final file = File(filePath);
    await file.writeAsBytes(generatedPdf.bytes);

    return ExportResult(
      filePath: filePath,
      fileName: fileName,
      fileSize: generatedPdf.fileSize,
      format: ExportFormat.pdf,
    );
  }

  /// Exports as JPEG image(s).
  Future<ExportResult> _exportAsJpeg(
    Directory tempDir,
    String baseName,
    int timestamp,
  ) async {
    final quality = _getJpegQuality();

    if (state.imageBytesList!.length == 1) {
      // Single image export
      final fileName = '${baseName}_$timestamp.jpg';
      final filePath = path.join(tempDir.path, fileName);

      state = state.copyWith(exportProgress: 0.5);

      final exported = await _imageExporter.exportFromBytes(
        state.imageBytesList!.first,
        options: ImageExportOptions(
          format: ExportImageFormat.jpeg,
          quality: quality,
        ),
      );

      final file = File(filePath);
      await file.writeAsBytes(exported.bytes);

      return ExportResult(
        filePath: filePath,
        fileName: fileName,
        fileSize: exported.fileSize,
        format: ExportFormat.jpeg,
      );
    } else {
      // Multi-page: stitch vertically into single image
      state = state.copyWith(exportProgress: 0.3);

      final stitched = await _imageExporter.stitchVertical(
        imageBytesList: state.imageBytesList!,
        spacing: 20,
        options: ImageExportOptions(
          format: ExportImageFormat.jpeg,
          quality: quality,
        ),
      );

      state = state.copyWith(exportProgress: 0.7);

      final fileName = '${baseName}_$timestamp.jpg';
      final filePath = path.join(tempDir.path, fileName);

      final file = File(filePath);
      await file.writeAsBytes(stitched.bytes);

      return ExportResult(
        filePath: filePath,
        fileName: fileName,
        fileSize: stitched.fileSize,
        format: ExportFormat.jpeg,
      );
    }
  }

  /// Exports as PNG image(s).
  Future<ExportResult> _exportAsPng(
    Directory tempDir,
    String baseName,
    int timestamp,
  ) async {
    if (state.imageBytesList!.length == 1) {
      // Single image export
      final fileName = '${baseName}_$timestamp.png';
      final filePath = path.join(tempDir.path, fileName);

      state = state.copyWith(exportProgress: 0.5);

      final exported = await _imageExporter.exportFromBytes(
        state.imageBytesList!.first,
        options: const ImageExportOptions(
          format: ExportImageFormat.png,
        ),
      );

      final file = File(filePath);
      await file.writeAsBytes(exported.bytes);

      return ExportResult(
        filePath: filePath,
        fileName: fileName,
        fileSize: exported.fileSize,
        format: ExportFormat.png,
      );
    } else {
      // Multi-page: stitch vertically into single image
      state = state.copyWith(exportProgress: 0.3);

      final stitched = await _imageExporter.stitchVertical(
        imageBytesList: state.imageBytesList!,
        spacing: 20,
        options: const ImageExportOptions(
          format: ExportImageFormat.png,
        ),
      );

      state = state.copyWith(exportProgress: 0.7);

      final fileName = '${baseName}_$timestamp.png';
      final filePath = path.join(tempDir.path, fileName);

      final file = File(filePath);
      await file.writeAsBytes(stitched.bytes);

      return ExportResult(
        filePath: filePath,
        fileName: fileName,
        fileSize: stitched.fileSize,
        format: ExportFormat.png,
      );
    }
  }

  /// Shares the last exported file.
  ///
  /// Returns true if sharing was successful.
  Future<bool> share() async {
    if (!state.canShare) return false;

    state = state.copyWith(isSharing: true, clearError: true);

    try {
      final result = state.lastExportResult!;
      final file = XFile(
        result.filePath,
        mimeType: result.mimeType,
        name: result.fileName,
      );

      await Share.shareXFiles(
        [file],
        subject: state.documentTitle ?? 'Scanned Document',
      );

      state = state.copyWith(isSharing: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSharing: false,
        error: 'Failed to share: $e',
      );
      return false;
    }
  }

  /// Exports and immediately shares the document.
  ///
  /// Combines export and share into a single operation.
  Future<bool> exportAndShare() async {
    final result = await export();
    if (result == null) return false;
    return share();
  }

  /// Sanitizes a file name by removing invalid characters.
  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
  }
}

/// Riverpod provider for the export screen state.
final exportScreenProvider =
    StateNotifierProvider.autoDispose<ExportScreenNotifier, ExportScreenState>(
  (ref) {
    final pdfGenerator = ref.watch(pdfGeneratorProvider);
    final imageExporter = ref.watch(imageExporterProvider);
    return ExportScreenNotifier(pdfGenerator, imageExporter);
  },
);

/// Export options screen with format selection and share functionality.
///
/// Provides a comprehensive UI for exporting scanned documents:
/// - Format selection (PDF, JPEG, PNG)
/// - Quality presets (High, Medium, Low)
/// - Export progress indication
/// - Share sheet integration
///
/// ## Usage
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => ExportScreen(
///       imageBytesList: [page1Bytes, page2Bytes],
///       documentTitle: 'My Document',
///     ),
///   ),
/// );
///
/// // With callback
/// ExportScreen(
///   imageBytesList: [imageBytes],
///   onExportComplete: (result) {
///     // Handle the exported file
///   },
/// )
/// ```
class ExportScreen extends ConsumerStatefulWidget {
  /// Creates an [ExportScreen].
  const ExportScreen({
    super.key,
    required this.imageBytesList,
    this.documentTitle,
    this.onExportComplete,
  });

  /// List of images to export (one per page).
  final List<Uint8List> imageBytesList;

  /// Optional title for the exported document.
  final String? documentTitle;

  /// Callback invoked when export is complete.
  final void Function(ExportResult result)? onExportComplete;

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  @override
  void initState() {
    super.initState();

    // Initialize with source images after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(exportScreenProvider.notifier).setImages(
            widget.imageBytesList,
            title: widget.documentTitle,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exportScreenProvider);
    final notifier = ref.read(exportScreenProvider.notifier);
    final theme = Theme.of(context);

    // Listen for errors and show snackbar
    ref.listen<ExportScreenState>(exportScreenProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document preview
            _DocumentPreview(
              imageBytesList: widget.imageBytesList,
              pageCount: state.pageCount,
              theme: theme,
            ),
            const SizedBox(height: 24),

            // Format selection
            _FormatSection(
              selectedFormat: state.format,
              onFormatChanged: notifier.setFormat,
              enabled: !state.isLoading,
              theme: theme,
            ),
            const SizedBox(height: 20),

            // Quality selection (not shown for PNG as it's lossless)
            if (state.format != ExportFormat.png)
              _QualitySection(
                selectedQuality: state.quality,
                onQualityChanged: notifier.setQuality,
                enabled: !state.isLoading,
                theme: theme,
              ),

            // Export result info
            if (state.lastExportResult != null) ...[
              const SizedBox(height: 20),
              _ExportResultCard(
                result: state.lastExportResult!,
                theme: theme,
              ),
            ],

            // Progress indicator
            if (state.isExporting) ...[
              const SizedBox(height: 20),
              _ExportProgress(
                progress: state.exportProgress,
                theme: theme,
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _ActionBar(
        state: state,
        onExport: () => _handleExport(context, notifier),
        onShare: () => _handleShare(context, notifier),
        onExportAndShare: () => _handleExportAndShare(context, notifier),
        theme: theme,
      ),
    );
  }

  Future<void> _handleExport(
    BuildContext context,
    ExportScreenNotifier notifier,
  ) async {
    final result = await notifier.export();
    if (result != null && mounted) {
      widget.onExportComplete?.call(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported: ${result.fileName}'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () => notifier.share(),
          ),
        ),
      );
    }
  }

  Future<void> _handleShare(
    BuildContext context,
    ExportScreenNotifier notifier,
  ) async {
    await notifier.share();
  }

  Future<void> _handleExportAndShare(
    BuildContext context,
    ExportScreenNotifier notifier,
  ) async {
    final success = await notifier.exportAndShare();
    if (success && mounted) {
      final result = ref.read(exportScreenProvider).lastExportResult;
      if (result != null) {
        widget.onExportComplete?.call(result);
      }
    }
  }
}

/// Document preview section.
class _DocumentPreview extends StatelessWidget {
  const _DocumentPreview({
    required this.imageBytesList,
    required this.pageCount,
    required this.theme,
  });

  final List<Uint8List> imageBytesList;
  final int pageCount;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: imageBytesList.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < imageBytesList.length - 1 ? 12 : 0,
                ),
                child: _PageThumbnail(
                  imageBytes: imageBytesList[index],
                  pageNumber: index + 1,
                  totalPages: pageCount,
                  theme: theme,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$pageCount ${pageCount == 1 ? 'page' : 'pages'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Single page thumbnail.
class _PageThumbnail extends StatelessWidget {
  const _PageThumbnail({
    required this.imageBytes,
    required this.pageNumber,
    required this.totalPages,
    required this.theme,
  });

  final Uint8List imageBytes;
  final int pageNumber;
  final int totalPages;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.memory(
              imageBytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
          if (totalPages > 1)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$pageNumber',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Format selection section.
class _FormatSection extends StatelessWidget {
  const _FormatSection({
    required this.selectedFormat,
    required this.onFormatChanged,
    required this.enabled,
    required this.theme,
  });

  final ExportFormat selectedFormat;
  final ValueChanged<ExportFormat> onFormatChanged;
  final bool enabled;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Format',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _FormatOption(
                format: ExportFormat.pdf,
                icon: Icons.picture_as_pdf_outlined,
                label: 'PDF',
                description: 'Best for documents',
                isSelected: selectedFormat == ExportFormat.pdf,
                onTap: enabled ? () => onFormatChanged(ExportFormat.pdf) : null,
                theme: theme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FormatOption(
                format: ExportFormat.jpeg,
                icon: Icons.image_outlined,
                label: 'JPEG',
                description: 'Smaller size',
                isSelected: selectedFormat == ExportFormat.jpeg,
                onTap: enabled ? () => onFormatChanged(ExportFormat.jpeg) : null,
                theme: theme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FormatOption(
                format: ExportFormat.png,
                icon: Icons.photo_outlined,
                label: 'PNG',
                description: 'Lossless',
                isSelected: selectedFormat == ExportFormat.png,
                onTap: enabled ? () => onFormatChanged(ExportFormat.png) : null,
                theme: theme,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Single format option card.
class _FormatOption extends StatelessWidget {
  const _FormatOption({
    required this.format,
    required this.icon,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  final ExportFormat format;
  final IconData icon;
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback? onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                      : colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quality selection section.
class _QualitySection extends StatelessWidget {
  const _QualitySection({
    required this.selectedQuality,
    required this.onQualityChanged,
    required this.enabled,
    required this.theme,
  });

  final ExportQuality selectedQuality;
  final ValueChanged<ExportQuality> onQualityChanged;
  final bool enabled;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quality',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<ExportQuality>(
          segments: const [
            ButtonSegment(
              value: ExportQuality.low,
              label: Text('Small'),
              icon: Icon(Icons.compress, size: 18),
            ),
            ButtonSegment(
              value: ExportQuality.medium,
              label: Text('Medium'),
              icon: Icon(Icons.tune, size: 18),
            ),
            ButtonSegment(
              value: ExportQuality.high,
              label: Text('High'),
              icon: Icon(Icons.high_quality_outlined, size: 18),
            ),
          ],
          selected: {selectedQuality},
          onSelectionChanged: enabled
              ? (selection) {
                  if (selection.isNotEmpty) {
                    onQualityChanged(selection.first);
                  }
                }
              : null,
          showSelectedIcon: false,
        ),
        const SizedBox(height: 8),
        Text(
          _getQualityDescription(selectedQuality),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _getQualityDescription(ExportQuality quality) {
    switch (quality) {
      case ExportQuality.high:
        return 'Best quality, larger file size (95% JPEG quality)';
      case ExportQuality.medium:
        return 'Balanced quality and size (85% JPEG quality)';
      case ExportQuality.low:
        return 'Optimized for sharing, smaller size (70% JPEG quality)';
    }
  }
}

/// Export result information card.
class _ExportResultCard extends StatelessWidget {
  const _ExportResultCard({
    required this.result,
    required this.theme,
  });

  final ExportResult result;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: colorScheme.secondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to share',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.fileName} (${result.fileSizeFormatted})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Export progress indicator.
class _ExportProgress extends StatelessWidget {
  const _ExportProgress({
    required this.progress,
    required this.theme,
  });

  final double progress;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Exporting...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

/// Bottom action bar with export and share buttons.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.state,
    required this.onExport,
    required this.onShare,
    required this.onExportAndShare,
    required this.theme,
  });

  final ExportScreenState state;
  final VoidCallback onExport;
  final VoidCallback onShare;
  final VoidCallback onExportAndShare;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          // Export only button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: state.canExport ? onExport : null,
              icon: state.isExporting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : const Icon(Icons.save_alt_outlined),
              label: Text(state.isExporting ? 'Exporting...' : 'Export'),
            ),
          ),
          const SizedBox(width: 12),
          // Export and share button (primary action)
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: state.canExport || state.canShare
                  ? (state.canShare ? onShare : onExportAndShare)
                  : null,
              icon: state.isSharing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : Icon(state.canShare ? Icons.share : Icons.share_outlined),
              label: Text(
                state.isSharing
                    ? 'Sharing...'
                    : (state.canShare ? 'Share' : 'Export & Share'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
