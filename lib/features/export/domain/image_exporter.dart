import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

/// Riverpod provider for [ImageExporter].
///
/// Provides a singleton instance of the image exporter for
/// dependency injection throughout the application.
final imageExporterProvider = Provider<ImageExporter>((ref) {
  return ImageExporter();
});

/// Exception thrown when image export operations fail.
///
/// Contains the original error message and optional underlying exception.
class ImageExporterException implements Exception {
  /// Creates an [ImageExporterException] with the given [message].
  const ImageExporterException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'ImageExporterException: $message (caused by: $cause)';
    }
    return 'ImageExporterException: $message';
  }
}

/// Result of an image export operation.
///
/// Contains information about the exported image(s) and metadata.
@immutable
class ExportedImage {
  /// Creates an [ExportedImage] with the export data.
  const ExportedImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
    this.quality,
    this.originalFileName,
  });

  /// The exported image bytes.
  final Uint8List bytes;

  /// Width of the exported image in pixels.
  final int width;

  /// Height of the exported image in pixels.
  final int height;

  /// Output format of the exported image.
  final ExportImageFormat format;

  /// Quality setting used for export (JPEG only, 1-100).
  final int? quality;

  /// Original file name if available.
  final String? originalFileName;

  /// File size in bytes.
  int get fileSize => bytes.length;

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

  /// Suggested file extension based on format.
  String get fileExtension => format == ExportImageFormat.jpeg ? 'jpg' : 'png';

  /// Creates a copy with updated values.
  ExportedImage copyWith({
    Uint8List? bytes,
    int? width,
    int? height,
    ExportImageFormat? format,
    int? quality,
    String? originalFileName,
    bool clearQuality = false,
    bool clearOriginalFileName = false,
  }) {
    return ExportedImage(
      bytes: bytes ?? this.bytes,
      width: width ?? this.width,
      height: height ?? this.height,
      format: format ?? this.format,
      quality: clearQuality ? null : (quality ?? this.quality),
      originalFileName: clearOriginalFileName
          ? null
          : (originalFileName ?? this.originalFileName),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExportedImage &&
        listEquals(other.bytes, bytes) &&
        other.width == width &&
        other.height == height &&
        other.format == format &&
        other.quality == quality &&
        other.originalFileName == originalFileName;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(bytes),
        width,
        height,
        format,
        quality,
        originalFileName,
      );

  @override
  String toString() => 'ExportedImage(${width}x$height, format: $format, '
      'size: $fileSizeFormatted)';
}

/// Result of a batch export operation.
///
/// Contains a list of exported images and summary metadata.
@immutable
class BatchExportResult {
  /// Creates a [BatchExportResult] with the exported images.
  const BatchExportResult({
    required this.exportedImages,
    required this.totalFileSize,
    this.outputDirectory,
    this.baseName,
  });

  /// List of exported images.
  final List<ExportedImage> exportedImages;

  /// Total file size of all exported images in bytes.
  final int totalFileSize;

  /// Directory where images were saved (if saved to disk).
  final String? outputDirectory;

  /// Base name used for exported files.
  final String? baseName;

  /// Number of exported images.
  int get imageCount => exportedImages.length;

  /// Human-readable total file size string.
  String get totalFileSizeFormatted {
    if (totalFileSize < 1024) {
      return '$totalFileSize B';
    } else if (totalFileSize < 1024 * 1024) {
      return '${(totalFileSize / 1024).toStringAsFixed(1)} KB';
    } else if (totalFileSize < 1024 * 1024 * 1024) {
      return '${(totalFileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(totalFileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BatchExportResult &&
        listEquals(other.exportedImages, exportedImages) &&
        other.totalFileSize == totalFileSize &&
        other.outputDirectory == outputDirectory &&
        other.baseName == baseName;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(exportedImages),
        totalFileSize,
        outputDirectory,
        baseName,
      );

  @override
  String toString() => 'BatchExportResult(images: $imageCount, '
      'totalSize: $totalFileSizeFormatted)';
}

/// Output format for exported images.
enum ExportImageFormat {
  /// JPEG format with configurable quality.
  ///
  /// Recommended for document scans - smaller file size.
  jpeg,

  /// PNG format for lossless compression.
  ///
  /// Use for images requiring transparency or pixel-perfect quality.
  png,
}

/// Resize mode for exported images.
enum ExportResizeMode {
  /// Export at original size (no resize).
  original,

  /// Fit within maximum dimensions while maintaining aspect ratio.
  fitWithin,

  /// Resize to exact dimensions (may distort aspect ratio).
  exact,

  /// Scale by a percentage factor.
  scale,
}

/// Configuration for image export operations.
///
/// Provides control over output format, quality, and dimensions.
@immutable
class ImageExportOptions {
  /// Creates [ImageExportOptions] with specified parameters.
  const ImageExportOptions({
    this.format = ExportImageFormat.jpeg,
    this.quality = 90,
    this.resizeMode = ExportResizeMode.original,
    this.maxWidth,
    this.maxHeight,
    this.scaleFactor = 1.0,
    this.preserveMetadata = false,
  });

  /// Default options for high-quality JPEG export.
  static const ImageExportOptions highQuality = ImageExportOptions(
    quality: 95,
  );

  /// Options for web sharing (smaller file size).
  static const ImageExportOptions webOptimized = ImageExportOptions(
    quality: 80,
    resizeMode: ExportResizeMode.fitWithin,
    maxWidth: 2000,
    maxHeight: 2000,
  );

  /// Options for thumbnail generation.
  static const ImageExportOptions thumbnail = ImageExportOptions(
    quality: 75,
    resizeMode: ExportResizeMode.fitWithin,
    maxWidth: 300,
    maxHeight: 300,
  );

  /// Options for preview generation.
  static const ImageExportOptions preview = ImageExportOptions(
    quality: 85,
    resizeMode: ExportResizeMode.fitWithin,
    maxWidth: 800,
    maxHeight: 800,
  );

  /// Options for PNG export (lossless).
  static const ImageExportOptions lossless = ImageExportOptions(
    format: ExportImageFormat.png,
  );

  /// Output format for the exported image.
  final ExportImageFormat format;

  /// Quality for JPEG export (1-100). Ignored for PNG.
  ///
  /// Higher values produce better quality but larger files.
  /// Recommended: 90+ for documents, 75-85 for web sharing.
  final int quality;

  /// Resize mode for the export.
  final ExportResizeMode resizeMode;

  /// Maximum width for [ExportResizeMode.fitWithin] mode.
  final int? maxWidth;

  /// Maximum height for [ExportResizeMode.fitWithin] mode.
  final int? maxHeight;

  /// Scale factor for [ExportResizeMode.scale] mode.
  ///
  /// 1.0 = 100% (original size), 0.5 = 50%, 2.0 = 200%.
  final double scaleFactor;

  /// Whether to preserve EXIF and other metadata.
  ///
  /// Note: Currently not implemented - metadata is stripped.
  final bool preserveMetadata;

  /// Creates a copy with updated values.
  ImageExportOptions copyWith({
    ExportImageFormat? format,
    int? quality,
    ExportResizeMode? resizeMode,
    int? maxWidth,
    int? maxHeight,
    double? scaleFactor,
    bool? preserveMetadata,
    bool clearMaxWidth = false,
    bool clearMaxHeight = false,
  }) {
    return ImageExportOptions(
      format: format ?? this.format,
      quality: quality ?? this.quality,
      resizeMode: resizeMode ?? this.resizeMode,
      maxWidth: clearMaxWidth ? null : (maxWidth ?? this.maxWidth),
      maxHeight: clearMaxHeight ? null : (maxHeight ?? this.maxHeight),
      scaleFactor: scaleFactor ?? this.scaleFactor,
      preserveMetadata: preserveMetadata ?? this.preserveMetadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageExportOptions &&
        other.format == format &&
        other.quality == quality &&
        other.resizeMode == resizeMode &&
        other.maxWidth == maxWidth &&
        other.maxHeight == maxHeight &&
        other.scaleFactor == scaleFactor &&
        other.preserveMetadata == preserveMetadata;
  }

  @override
  int get hashCode => Object.hash(
        format,
        quality,
        resizeMode,
        maxWidth,
        maxHeight,
        scaleFactor,
        preserveMetadata,
      );

  @override
  String toString() => 'ImageExportOptions('
      'format: $format, '
      'quality: $quality, '
      'resizeMode: $resizeMode)';
}

/// Service for exporting document images as JPG or PNG files.
///
/// Provides high-quality image export with support for various formats,
/// quality settings, and resize options. Optimized for document scanning
/// workflows with batch export capabilities.
///
/// ## Key Features
/// - **JPEG Export**: High-quality JPEG with configurable compression
/// - **PNG Export**: Lossless PNG for pixel-perfect output
/// - **Resize Options**: Original, fit-within, exact, or scale modes
/// - **Batch Export**: Export multiple pages to individual files
/// - **Memory Efficient**: Uses isolates for background processing
///
/// ## Usage
/// ```dart
/// final exporter = ref.read(imageExporterProvider);
///
/// // Export single image
/// final result = await exporter.exportFromBytes(
///   imageBytes,
///   options: ImageExportOptions.highQuality,
/// );
///
/// // Export from file
/// final result = await exporter.exportFromFile(
///   '/path/to/scan.jpg',
///   options: ImageExportOptions(
///     format: ExportImageFormat.jpeg,
///     quality: 90,
///   ),
/// );
///
/// // Batch export multiple pages
/// final batch = await exporter.exportBatch(
///   imageBytesList: [page1, page2, page3],
///   options: ImageExportOptions.webOptimized,
/// );
///
/// // Save to file
/// await exporter.exportToFile(
///   imageBytes,
///   outputPath: '/path/to/output.jpg',
///   options: ImageExportOptions.highQuality,
/// );
/// ```
///
/// ## Error Handling
/// The service throws [ImageExporterException] for all error cases.
/// Always wrap calls in try-catch:
/// ```dart
/// try {
///   final result = await exporter.exportFromFile(path);
///   // Use result...
/// } on ImageExporterException catch (e) {
///   print('Export failed: ${e.message}');
/// }
/// ```
class ImageExporter {
  /// Creates an [ImageExporter] instance.
  ImageExporter();

  /// Default JPEG quality for export.
  static const int defaultJpegQuality = 90;

  /// Exports an image from raw bytes.
  ///
  /// Decodes the image from [bytes], applies resize options if specified,
  /// and encodes to the output format.
  ///
  /// Returns an [ExportedImage] containing the exported data.
  ///
  /// Throws [ImageExporterException] if export fails.
  Future<ExportedImage> exportFromBytes(
    Uint8List bytes, {
    ImageExportOptions options = const ImageExportOptions(),
    String? originalFileName,
  }) async {
    if (bytes.isEmpty) {
      throw const ImageExporterException('Image bytes cannot be empty');
    }

    try {
      final result = await compute(
        _exportImageIsolate,
        _ExportParams(
          bytes: bytes,
          options: options,
          originalFileName: originalFileName,
        ),
      );

      return result;
    } on ImageExporterException {
      rethrow;
    } on Object catch (e) {
      throw ImageExporterException(
        'Failed to export image',
        cause: e,
      );
    }
  }

  /// Exports an image from a file path.
  ///
  /// Reads the image from [filePath], applies resize options if specified,
  /// and encodes to the output format.
  ///
  /// Returns an [ExportedImage] containing the exported data.
  ///
  /// Throws [ImageExporterException] if export fails.
  Future<ExportedImage> exportFromFile(
    String filePath, {
    ImageExportOptions options = const ImageExportOptions(),
  }) async {
    if (filePath.isEmpty) {
      throw const ImageExporterException('File path cannot be empty');
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw ImageExporterException('Image file not found: $filePath');
      }

      final bytes = await file.readAsBytes();
      final fileName = path.basename(filePath);

      return exportFromBytes(
        bytes,
        options: options,
        originalFileName: fileName,
      );
    } on ImageExporterException {
      rethrow;
    } on Object catch (e) {
      throw ImageExporterException(
        'Failed to read image file: $filePath',
        cause: e,
      );
    }
  }

  /// Exports an image and saves it directly to a file.
  ///
  /// This is convenient for direct file-to-file export operations.
  ///
  /// The [outputPath] should include the desired file extension.
  ///
  /// Returns an [ExportedImage] with the exported data.
  ///
  /// Throws [ImageExporterException] if export fails.
  Future<ExportedImage> exportToFile(
    Uint8List bytes, {
    required String outputPath,
    ImageExportOptions options = const ImageExportOptions(),
  }) async {
    if (outputPath.isEmpty) {
      throw const ImageExporterException('Output path cannot be empty');
    }

    try {
      final result = await exportFromBytes(bytes, options: options);

      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(result.bytes);

      return result;
    } on ImageExporterException {
      rethrow;
    } on Object catch (e) {
      throw ImageExporterException(
        'Failed to save image to: $outputPath',
        cause: e,
      );
    }
  }

  /// Exports an image from one file to another.
  ///
  /// Convenience method for file-to-file export.
  ///
  /// Returns an [ExportedImage] with the exported data.
  ///
  /// Throws [ImageExporterException] if export fails.
  Future<ExportedImage> exportFileToFile(
    String inputPath,
    String outputPath, {
    ImageExportOptions options = const ImageExportOptions(),
  }) async {
    if (inputPath.isEmpty || outputPath.isEmpty) {
      throw const ImageExporterException('File paths cannot be empty');
    }

    if (inputPath == outputPath) {
      throw const ImageExporterException(
        'Input and output paths must be different',
      );
    }

    try {
      final result = await exportFromFile(inputPath, options: options);

      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(result.bytes);

      return result;
    } on ImageExporterException {
      rethrow;
    } on Object catch (e) {
      throw ImageExporterException(
        'Failed to export from $inputPath to $outputPath',
        cause: e,
      );
    }
  }

  /// Exports multiple images as a batch operation.
  ///
  /// Each element in [imageBytesList] is exported with the same [options].
  ///
  /// Returns a [BatchExportResult] containing all exported images.
  ///
  /// Throws [ImageExporterException] if any export fails.
  Future<BatchExportResult> exportBatch({
    required List<Uint8List> imageBytesList,
    ImageExportOptions options = const ImageExportOptions(),
  }) async {
    if (imageBytesList.isEmpty) {
      throw const ImageExporterException('Image bytes list cannot be empty');
    }

    try {
      final exportedImages = <ExportedImage>[];
      var totalSize = 0;

      for (var i = 0; i < imageBytesList.length; i++) {
        if (imageBytesList[i].isEmpty) {
          throw ImageExporterException('Image at index $i is empty');
        }

        final result = await exportFromBytes(
          imageBytesList[i],
          options: options,
        );

        exportedImages.add(result);
        totalSize += result.fileSize;
      }

      return BatchExportResult(
        exportedImages: exportedImages,
        totalFileSize: totalSize,
      );
    } on ImageExporterException {
      rethrow;
    } on Object catch (e) {
      throw ImageExporterException(
        'Failed to export batch',
        cause: e,
      );
    }
  }

  /// Exports multiple images from files as a batch operation.
  ///
  /// Each file in [imagePaths] is exported with the same [options].
  ///
  /// Returns a [BatchExportResult] containing all exported images.
  ///
  /// Throws [ImageExporterException] if any export fails.
  Future<BatchExportResult> exportBatchFromFiles({
    required List<String> imagePaths,
    ImageExportOptions options = const ImageExportOptions(),
  }) async {
    if (imagePaths.isEmpty) {
      throw const ImageExporterException('Image paths list cannot be empty');
    }

    try {
      final exportedImages = <ExportedImage>[];
      var totalSize = 0;

      for (var i = 0; i < imagePaths.length; i++) {
        if (imagePaths[i].isEmpty) {
          throw ImageExporterException('Path at index $i is empty');
        }

        final result = await exportFromFile(imagePaths[i], options: options);
        exportedImages.add(result);
        totalSize += result.fileSize;
      }

      return BatchExportResult(
        exportedImages: exportedImages,
        totalFileSize: totalSize,
      );
    } on ImageExporterException {
      rethrow;
    } on Object catch (e) {
      throw ImageExporterException(
        'Failed to export batch from files',
        cause: e,
      );
    }
  }

  /// Exports multiple images to a directory.
  ///
  /// Each image is saved with the pattern: [baseName]_001.jpg, [baseName]_002.jpg, etc.
  ///
  /// Returns a [BatchExportResult] with export information.
  ///
  /// Throws [ImageExporterException] if export fails.
  Future<BatchExportResult> exportBatchToDirectory({
    required List<Uint8List> imageBytesList,
    required String outputDirectory,
    String baseName = 'scan',
    ImageExportOptions options = const ImageExportOptions(),
  }) async {
    if (imageBytesList.isEmpty) {
      throw const ImageExporterException('Image bytes list cannot be empty');
    }

    if (outputDirectory.isEmpty) {
      throw const ImageExporterException('Output directory cannot be empty');
    }

    try {
      // Ensure directory exists
      final dir = Directory(outputDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final exportedImages = <ExportedImage>[];
      var totalSize = 0;
      final extension =
          options.format == ExportImageFormat.jpeg ? 'jpg' : 'png';

      for (var i = 0; i < imageBytesList.length; i++) {
        if (imageBytesList[i].isEmpty) {
          throw ImageExporterException('Image at index $i is empty');
        }

        final result = await exportFromBytes(
          imageBytesList[i],
          options: options,
        );

        // Generate numbered filename
        final paddedNumber = (i + 1).toString().padLeft(3, '0');
        final fileName = '${baseName}_$paddedNumber.$extension';
        final filePath = path.join(outputDirectory, fileName);

        final outputFile = File(filePath);
        await outputFile.writeAsBytes(result.bytes);

        exportedImages.add(result.copyWith(
          originalFileName: fileName,
        ));
        totalSize += result.fileSize;
      }

      return BatchExportResult(
        exportedImages: exportedImages,
        totalFileSize: totalSize,
        outputDirectory: outputDirectory,
        baseName: baseName,
      );
    } on ImageExporterException {
      rethrow;
    } on Object catch (e) {
      throw ImageExporterException(
        'Failed to export batch to directory: $outputDirectory',
        cause: e,
      );
    }
  }

  /// Creates a thumbnail from an image.
  ///
  /// Convenience method that uses [ImageExportOptions.thumbnail] preset.
  ///
  /// Returns an [ExportedImage] containing the thumbnail.
  Future<ExportedImage> createThumbnail(
    Uint8List bytes, {
    int maxWidth = 300,
    int maxHeight = 300,
  }) async {
    return exportFromBytes(
      bytes,
      options: ImageExportOptions(
        quality: 75,
        resizeMode: ExportResizeMode.fitWithin,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
    );
  }

  /// Creates a preview image.
  ///
  /// Convenience method that uses [ImageExportOptions.preview] preset.
  ///
  /// Returns an [ExportedImage] containing the preview.
  Future<ExportedImage> createPreview(
    Uint8List bytes, {
    int maxWidth = 800,
    int maxHeight = 800,
  }) async {
    return exportFromBytes(
      bytes,
      options: ImageExportOptions(
        quality: 85,
        resizeMode: ExportResizeMode.fitWithin,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
    );
  }

  /// Stitches multiple images vertically into a single image.
  ///
  /// Useful for creating a single long image from multiple scanned pages.
  ///
  /// The [spacing] parameter adds pixels between images.
  ///
  /// Returns an [ExportedImage] containing the stitched result.
  ///
  /// Throws [ImageExporterException] if stitching fails.
  Future<ExportedImage> stitchVertical({
    required List<Uint8List> imageBytesList,
    int spacing = 0,
    ImageExportOptions options = const ImageExportOptions(),
  }) async {
    if (imageBytesList.isEmpty) {
      throw const ImageExporterException('Image bytes list cannot be empty');
    }

    if (imageBytesList.length == 1) {
      return exportFromBytes(imageBytesList[0], options: options);
    }

    try {
      final result = await compute(
        _stitchVerticalIsolate,
        _StitchParams(
          imageBytesList: imageBytesList,
          spacing: spacing,
          options: options,
        ),
      );

      return result;
    } on ImageExporterException {
      rethrow;
    } on Object catch (e) {
      throw ImageExporterException(
        'Failed to stitch images',
        cause: e,
      );
    }
  }

  /// Stitches multiple images horizontally into a single image.
  ///
  /// Useful for creating panoramic-style exports.
  ///
  /// The [spacing] parameter adds pixels between images.
  ///
  /// Returns an [ExportedImage] containing the stitched result.
  ///
  /// Throws [ImageExporterException] if stitching fails.
  Future<ExportedImage> stitchHorizontal({
    required List<Uint8List> imageBytesList,
    int spacing = 0,
    ImageExportOptions options = const ImageExportOptions(),
  }) async {
    if (imageBytesList.isEmpty) {
      throw const ImageExporterException('Image bytes list cannot be empty');
    }

    if (imageBytesList.length == 1) {
      return exportFromBytes(imageBytesList[0], options: options);
    }

    try {
      final result = await compute(
        _stitchHorizontalIsolate,
        _StitchParams(
          imageBytesList: imageBytesList,
          spacing: spacing,
          options: options,
        ),
      );

      return result;
    } on ImageExporterException {
      rethrow;
    } on Object catch (e) {
      throw ImageExporterException(
        'Failed to stitch images horizontally',
        cause: e,
      );
    }
  }
}

// ============================================================================
// Private isolate functions and parameter classes
// ============================================================================

/// Parameters for image export in isolate.
class _ExportParams {
  const _ExportParams({
    required this.bytes,
    required this.options,
    this.originalFileName,
  });

  final Uint8List bytes;
  final ImageExportOptions options;
  final String? originalFileName;
}

/// Parameters for image stitching in isolate.
class _StitchParams {
  const _StitchParams({
    required this.imageBytesList,
    required this.spacing,
    required this.options,
  });

  final List<Uint8List> imageBytesList;
  final int spacing;
  final ImageExportOptions options;
}

/// Isolate function for image export.
ExportedImage _exportImageIsolate(_ExportParams params) {
  final image = img.decodeImage(params.bytes);
  if (image == null) {
    throw const ImageExporterException('Failed to decode image');
  }

  var processed = image;

  // Apply resize based on mode
  processed = _applyResize(processed, params.options);

  // Encode to output format
  final outputBytes = _encodeImage(
    processed,
    params.options.format,
    params.options.quality,
  );

  return ExportedImage(
    bytes: outputBytes,
    width: processed.width,
    height: processed.height,
    format: params.options.format,
    quality: params.options.format == ExportImageFormat.jpeg
        ? params.options.quality
        : null,
    originalFileName: params.originalFileName,
  );
}

/// Isolate function for vertical stitching.
ExportedImage _stitchVerticalIsolate(_StitchParams params) {
  // Decode all images
  final images = <img.Image>[];
  var maxWidth = 0;
  var totalHeight = 0;

  for (var i = 0; i < params.imageBytesList.length; i++) {
    final decoded = img.decodeImage(params.imageBytesList[i]);
    if (decoded == null) {
      throw ImageExporterException('Failed to decode image at index $i');
    }
    images.add(decoded);
    maxWidth = math.max(maxWidth, decoded.width);
    totalHeight += decoded.height;
  }

  // Add spacing
  totalHeight += params.spacing * (images.length - 1);

  // Create composite image
  final composite = img.Image(width: maxWidth, height: totalHeight);

  // Fill with white background
  img.fill(composite, color: img.ColorRgb8(255, 255, 255));

  // Draw each image
  var yOffset = 0;
  for (final srcImage in images) {
    // Center horizontally
    final xOffset = (maxWidth - srcImage.width) ~/ 2;
    img.compositeImage(composite, srcImage, dstX: xOffset, dstY: yOffset);
    yOffset += srcImage.height + params.spacing;
  }

  // Apply resize if needed
  var processed = _applyResize(composite, params.options);

  // Encode to output format
  final outputBytes = _encodeImage(
    processed,
    params.options.format,
    params.options.quality,
  );

  return ExportedImage(
    bytes: outputBytes,
    width: processed.width,
    height: processed.height,
    format: params.options.format,
    quality: params.options.format == ExportImageFormat.jpeg
        ? params.options.quality
        : null,
  );
}

/// Isolate function for horizontal stitching.
ExportedImage _stitchHorizontalIsolate(_StitchParams params) {
  // Decode all images
  final images = <img.Image>[];
  var totalWidth = 0;
  var maxHeight = 0;

  for (var i = 0; i < params.imageBytesList.length; i++) {
    final decoded = img.decodeImage(params.imageBytesList[i]);
    if (decoded == null) {
      throw ImageExporterException('Failed to decode image at index $i');
    }
    images.add(decoded);
    totalWidth += decoded.width;
    maxHeight = math.max(maxHeight, decoded.height);
  }

  // Add spacing
  totalWidth += params.spacing * (images.length - 1);

  // Create composite image
  final composite = img.Image(width: totalWidth, height: maxHeight);

  // Fill with white background
  img.fill(composite, color: img.ColorRgb8(255, 255, 255));

  // Draw each image
  var xOffset = 0;
  for (final srcImage in images) {
    // Center vertically
    final yOffset = (maxHeight - srcImage.height) ~/ 2;
    img.compositeImage(composite, srcImage, dstX: xOffset, dstY: yOffset);
    xOffset += srcImage.width + params.spacing;
  }

  // Apply resize if needed
  var processed = _applyResize(composite, params.options);

  // Encode to output format
  final outputBytes = _encodeImage(
    processed,
    params.options.format,
    params.options.quality,
  );

  return ExportedImage(
    bytes: outputBytes,
    width: processed.width,
    height: processed.height,
    format: params.options.format,
    quality: params.options.format == ExportImageFormat.jpeg
        ? params.options.quality
        : null,
  );
}

/// Applies resize based on options.
img.Image _applyResize(img.Image image, ImageExportOptions options) {
  switch (options.resizeMode) {
    case ExportResizeMode.original:
      return image;

    case ExportResizeMode.fitWithin:
      final maxW = options.maxWidth ?? image.width;
      final maxH = options.maxHeight ?? image.height;

      if (image.width <= maxW && image.height <= maxH) {
        return image; // No resize needed
      }

      final widthRatio = maxW / image.width;
      final heightRatio = maxH / image.height;
      final ratio = math.min(widthRatio, heightRatio);

      final targetWidth = (image.width * ratio).round();
      final targetHeight = (image.height * ratio).round();

      return img.copyResize(
        image,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );

    case ExportResizeMode.exact:
      final exactWidth = options.maxWidth;
      final exactHeight = options.maxHeight;
      if (exactWidth == null || exactHeight == null) {
        return image; // Need both dimensions for exact mode
      }
      return img.copyResize(
        image,
        width: exactWidth,
        height: exactHeight,
        interpolation: img.Interpolation.linear,
      );

    case ExportResizeMode.scale:
      if (options.scaleFactor == 1.0) {
        return image; // No resize needed
      }
      final targetWidth = (image.width * options.scaleFactor).round();
      final targetHeight = (image.height * options.scaleFactor).round();

      return img.copyResize(
        image,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );
  }
}

/// Encodes an image to the specified format.
Uint8List _encodeImage(
  img.Image image,
  ExportImageFormat format,
  int quality,
) {
  switch (format) {
    case ExportImageFormat.jpeg:
      return Uint8List.fromList(
        img.encodeJpg(image, quality: quality.clamp(1, 100)),
      );
    case ExportImageFormat.png:
      return Uint8List.fromList(img.encodePng(image));
  }
}
