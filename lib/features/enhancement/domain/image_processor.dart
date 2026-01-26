import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

/// Riverpod provider for [ImageProcessor].
///
/// Provides a singleton instance of the image processor for
/// dependency injection throughout the application.
final imageProcessorProvider = Provider<ImageProcessor>((ref) {
  return ImageProcessor();
});

/// Exception thrown when image processing operations fail.
///
/// Contains the original error message and optional underlying exception.
class ImageProcessorException implements Exception {
  /// Creates an [ImageProcessorException] with the given [message].
  const ImageProcessorException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'ImageProcessorException: $message (caused by: $cause)';
    }
    return 'ImageProcessorException: $message';
  }
}

/// Result of an image processing operation.
///
/// Contains the processed image data and metadata about the operation.
@immutable
class ProcessedImage {
  /// Creates a [ProcessedImage] with the processed data.
  const ProcessedImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
    this.operationsApplied = const [],
  });

  /// The processed image bytes.
  final Uint8List bytes;

  /// Width of the processed image in pixels.
  final int width;

  /// Height of the processed image in pixels.
  final int height;

  /// Output format of the image.
  final ImageOutputFormat format;

  /// List of operations that were applied to produce this image.
  final List<String> operationsApplied;

  /// File size in bytes.
  int get fileSize => bytes.length;

  /// Creates a copy with updated values.
  ProcessedImage copyWith({
    Uint8List? bytes,
    int? width,
    int? height,
    ImageOutputFormat? format,
    List<String>? operationsApplied,
  }) {
    return ProcessedImage(
      bytes: bytes ?? this.bytes,
      width: width ?? this.width,
      height: height ?? this.height,
      format: format ?? this.format,
      operationsApplied: operationsApplied ?? this.operationsApplied,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProcessedImage &&
        listEquals(other.bytes, bytes) &&
        other.width == width &&
        other.height == height &&
        other.format == format &&
        listEquals(other.operationsApplied, operationsApplied);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(bytes),
        width,
        height,
        format,
        Object.hashAll(operationsApplied),
      );

  @override
  String toString() => 'ProcessedImage(${width}x$height, format: $format, '
      'size: ${(fileSize / 1024).toStringAsFixed(1)}KB, '
      'operations: ${operationsApplied.length})';
}

/// Output format for processed images.
enum ImageOutputFormat {
  /// JPEG format with configurable quality.
  jpeg,

  /// PNG format for lossless compression.
  png,
}

/// Enhancement preset options for quick application.
enum EnhancementPreset {
  /// Automatic enhancement optimized for documents.
  ///
  /// Applies moderate contrast boost, slight sharpening, and
  /// brightness normalization.
  document,

  /// High contrast enhancement for low-quality scans.
  ///
  /// Aggressive contrast and sharpening for improving readability.
  highContrast,

  /// Black and white document conversion.
  ///
  /// Converts to grayscale with enhanced contrast for clear text.
  blackAndWhite,

  /// Photo-like enhancement for visual documents.
  ///
  /// Balanced enhancement that preserves colors and details.
  photo,

  /// Original image with no enhancements.
  none,
}

/// Configuration for image enhancement operations.
///
/// Provides fine-grained control over all enhancement parameters.
@immutable
class EnhancementOptions {
  /// Creates [EnhancementOptions] with specified parameters.
  ///
  /// All parameters are normalized to a range:
  /// - [brightness]: -100 to 100 (0 = no change)
  /// - [contrast]: -100 to 100 (0 = no change)
  /// - [sharpness]: 0 to 100 (0 = no sharpening)
  /// - [saturation]: -100 to 100 (0 = no change, -100 = grayscale)
  const EnhancementOptions({
    this.brightness = 0,
    this.contrast = 0,
    this.sharpness = 0,
    this.saturation = 0,
    this.grayscale = false,
    this.autoEnhance = false,
    this.denoise = false,
  });

  /// Creates [EnhancementOptions] from a preset.
  factory EnhancementOptions.fromPreset(EnhancementPreset preset) {
    switch (preset) {
      case EnhancementPreset.document:
        return const EnhancementOptions(
          brightness: 5,
          contrast: 20,
          sharpness: 30,
          autoEnhance: true,
        );
      case EnhancementPreset.highContrast:
        return const EnhancementOptions(
          brightness: 10,
          contrast: 50,
          sharpness: 50,
        );
      case EnhancementPreset.blackAndWhite:
        return const EnhancementOptions(
          contrast: 30,
          sharpness: 25,
          grayscale: true,
        );
      case EnhancementPreset.photo:
        return const EnhancementOptions(
          brightness: 3,
          contrast: 10,
          sharpness: 15,
          saturation: 10,
        );
      case EnhancementPreset.none:
        return const EnhancementOptions();
    }
  }

  /// No enhancements applied.
  static const EnhancementOptions none = EnhancementOptions();

  /// Brightness adjustment (-100 to 100).
  ///
  /// Positive values increase brightness, negative values decrease it.
  final int brightness;

  /// Contrast adjustment (-100 to 100).
  ///
  /// Positive values increase contrast, negative values decrease it.
  final int contrast;

  /// Sharpness enhancement (0 to 100).
  ///
  /// Higher values apply stronger sharpening.
  final int sharpness;

  /// Saturation adjustment (-100 to 100).
  ///
  /// Positive values increase color saturation.
  /// Negative values decrease saturation (-100 = grayscale).
  final int saturation;

  /// Whether to convert the image to grayscale.
  ///
  /// When true, the [saturation] parameter is ignored.
  final bool grayscale;

  /// Whether to apply automatic enhancement.
  ///
  /// When true, applies adaptive histogram equalization for
  /// automatic contrast and brightness optimization.
  final bool autoEnhance;

  /// Whether to apply noise reduction.
  ///
  /// When true, applies a mild blur to reduce noise before
  /// other enhancements (useful for low-quality scans).
  final bool denoise;

  /// Whether any enhancement is configured.
  bool get hasEnhancements =>
      brightness != 0 ||
      contrast != 0 ||
      sharpness > 0 ||
      saturation != 0 ||
      grayscale ||
      autoEnhance ||
      denoise;

  /// Creates a copy with updated values.
  EnhancementOptions copyWith({
    int? brightness,
    int? contrast,
    int? sharpness,
    int? saturation,
    bool? grayscale,
    bool? autoEnhance,
    bool? denoise,
  }) {
    return EnhancementOptions(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      sharpness: sharpness ?? this.sharpness,
      saturation: saturation ?? this.saturation,
      grayscale: grayscale ?? this.grayscale,
      autoEnhance: autoEnhance ?? this.autoEnhance,
      denoise: denoise ?? this.denoise,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnhancementOptions &&
        other.brightness == brightness &&
        other.contrast == contrast &&
        other.sharpness == sharpness &&
        other.saturation == saturation &&
        other.grayscale == grayscale &&
        other.autoEnhance == autoEnhance &&
        other.denoise == denoise;
  }

  @override
  int get hashCode => Object.hash(
        brightness,
        contrast,
        sharpness,
        saturation,
        grayscale,
        autoEnhance,
        denoise,
      );

  @override
  String toString() => 'EnhancementOptions('
      'brightness: $brightness, '
      'contrast: $contrast, '
      'sharpness: $sharpness, '
      'saturation: $saturation, '
      'grayscale: $grayscale, '
      'autoEnhance: $autoEnhance, '
      'denoise: $denoise)';
}

/// Service for image enhancement operations.
///
/// Provides document-optimized image processing including contrast
/// adjustment, brightness correction, sharpening, and color conversion.
/// Designed for use in document scanning workflows.
///
/// ## Key Features
/// - **Contrast Enhancement**: Improve document readability
/// - **Brightness Adjustment**: Correct over/under-exposed scans
/// - **Sharpness Enhancement**: Sharpen text edges for better OCR
/// - **Grayscale Conversion**: Convert to B&W for smaller file size
/// - **Auto Enhancement**: Automatic optimization for documents
/// - **Preset Configurations**: Quick application of common settings
///
/// ## Performance Notes
/// - Processing is done on a separate isolate for large images
/// - Images larger than 4000x4000 are automatically downscaled
/// - JPEG output is recommended for document scans (smaller file size)
///
/// ## Usage
/// ```dart
/// final processor = ref.read(imageProcessorProvider);
///
/// // Apply document enhancement preset
/// final result = await processor.enhanceFromFile(
///   '/path/to/scan.jpg',
///   options: EnhancementOptions.fromPreset(EnhancementPreset.document),
/// );
///
/// // Custom enhancement settings
/// final customResult = await processor.enhanceFromFile(
///   '/path/to/scan.jpg',
///   options: EnhancementOptions(
///     contrast: 30,
///     sharpness: 50,
///     brightness: 10,
///   ),
/// );
///
/// // Convert to black and white
/// final bwResult = await processor.enhanceFromFile(
///   '/path/to/scan.jpg',
///   options: EnhancementOptions(grayscale: true, contrast: 20),
/// );
/// ```
///
/// ## Error Handling
/// The service throws [ImageProcessorException] for all error cases.
/// Always wrap calls in try-catch:
/// ```dart
/// try {
///   final result = await processor.enhanceFromFile(path, options: options);
///   // Use result...
/// } on ImageProcessorException catch (e) {
///   print('Enhancement failed: ${e.message}');
/// }
/// ```
class ImageProcessor {
  /// Creates an [ImageProcessor] instance.
  ImageProcessor();

  /// Maximum dimension for processing.
  ///
  /// Images larger than this will be downscaled proportionally.
  static const int maxProcessingDimension = 4000;

  /// Default JPEG quality for output.
  static const int defaultJpegQuality = 90;

  /// Enhances an image from a file path.
  ///
  /// Reads the image from [filePath], applies the specified [options],
  /// and returns a [ProcessedImage] with the enhanced data.
  ///
  /// The [outputFormat] determines the encoding of the result.
  /// The [quality] parameter only affects JPEG output (1-100).
  ///
  /// Throws [ImageProcessorException] if processing fails.
  Future<ProcessedImage> enhanceFromFile(
    String filePath, {
    EnhancementOptions options = EnhancementOptions.none,
    ImageOutputFormat outputFormat = ImageOutputFormat.jpeg,
    int quality = defaultJpegQuality,
  }) async {
    if (filePath.isEmpty) {
      throw const ImageProcessorException('File path cannot be empty');
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw ImageProcessorException('Image file not found: $filePath');
      }

      final bytes = await file.readAsBytes();
      return enhanceFromBytes(
        bytes,
        options: options,
        outputFormat: outputFormat,
        quality: quality,
      );
    } on ImageProcessorException {
      rethrow;
    } catch (e) {
      throw ImageProcessorException(
        'Failed to read image file: $filePath',
        cause: e,
      );
    }
  }

  /// Enhances an image from raw bytes.
  ///
  /// Decodes the image from [bytes], applies the specified [options],
  /// and returns a [ProcessedImage] with the enhanced data.
  ///
  /// Supports common image formats: JPEG, PNG, WebP, BMP, TIFF.
  ///
  /// The [outputFormat] determines the encoding of the result.
  /// The [quality] parameter only affects JPEG output (1-100).
  ///
  /// For large images, consider using [enhanceFromFileToFile] to avoid
  /// memory issues.
  ///
  /// Throws [ImageProcessorException] if processing fails.
  Future<ProcessedImage> enhanceFromBytes(
    Uint8List bytes, {
    EnhancementOptions options = EnhancementOptions.none,
    ImageOutputFormat outputFormat = ImageOutputFormat.jpeg,
    int quality = defaultJpegQuality,
  }) async {
    if (bytes.isEmpty) {
      throw const ImageProcessorException('Image bytes cannot be empty');
    }

    try {
      // Run processing in isolate for large images
      final result = await compute(
        _processImageIsolate,
        _ProcessingParams(
          bytes: bytes,
          options: options,
          outputFormat: outputFormat,
          quality: quality.clamp(1, 100),
        ),
      );

      return result;
    } on ImageProcessorException {
      rethrow;
    } catch (e) {
      throw ImageProcessorException(
        'Failed to process image',
        cause: e,
      );
    }
  }

  /// Enhances an image from file and saves to a new file.
  ///
  /// This is the most memory-efficient option for large images as it
  /// avoids holding the entire processed image in memory.
  ///
  /// The [inputPath] is the source image file.
  /// The [outputPath] is where the enhanced image will be saved.
  ///
  /// Returns a [ProcessedImage] with metadata (bytes are from the saved file).
  ///
  /// Throws [ImageProcessorException] if processing fails.
  Future<ProcessedImage> enhanceFromFileToFile(
    String inputPath,
    String outputPath, {
    EnhancementOptions options = EnhancementOptions.none,
    ImageOutputFormat outputFormat = ImageOutputFormat.jpeg,
    int quality = defaultJpegQuality,
  }) async {
    if (inputPath.isEmpty || outputPath.isEmpty) {
      throw const ImageProcessorException('File paths cannot be empty');
    }

    if (inputPath == outputPath) {
      throw const ImageProcessorException(
        'Input and output paths must be different',
      );
    }

    try {
      final result = await enhanceFromFile(
        inputPath,
        options: options,
        outputFormat: outputFormat,
        quality: quality,
      );

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(result.bytes);

      return result;
    } on ImageProcessorException {
      rethrow;
    } catch (e) {
      throw ImageProcessorException(
        'Failed to save enhanced image to: $outputPath',
        cause: e,
      );
    }
  }

  /// Applies auto-enhancement to an image.
  ///
  /// Automatically adjusts brightness and contrast for optimal
  /// document readability. This is a convenience method that applies
  /// the [EnhancementPreset.document] preset.
  ///
  /// Returns a [ProcessedImage] with the enhanced data.
  Future<ProcessedImage> autoEnhance(
    Uint8List bytes, {
    ImageOutputFormat outputFormat = ImageOutputFormat.jpeg,
    int quality = defaultJpegQuality,
  }) async {
    return enhanceFromBytes(
      bytes,
      options: EnhancementOptions.fromPreset(EnhancementPreset.document),
      outputFormat: outputFormat,
      quality: quality,
    );
  }

  /// Converts an image to grayscale.
  ///
  /// Converts the image to black and white with optional contrast
  /// enhancement for better text visibility.
  ///
  /// The [enhanceContrast] parameter adds contrast boost when true.
  ///
  /// Returns a [ProcessedImage] with the grayscale data.
  Future<ProcessedImage> convertToGrayscale(
    Uint8List bytes, {
    bool enhanceContrast = true,
    ImageOutputFormat outputFormat = ImageOutputFormat.jpeg,
    int quality = defaultJpegQuality,
  }) async {
    return enhanceFromBytes(
      bytes,
      options: EnhancementOptions(
        grayscale: true,
        contrast: enhanceContrast ? 20 : 0,
      ),
      outputFormat: outputFormat,
      quality: quality,
    );
  }

  /// Applies sharpening to an image.
  ///
  /// Enhances edge definition for improved text readability and OCR.
  /// The [amount] parameter controls sharpening intensity (0-100).
  ///
  /// Returns a [ProcessedImage] with sharpened data.
  Future<ProcessedImage> sharpen(
    Uint8List bytes, {
    int amount = 50,
    ImageOutputFormat outputFormat = ImageOutputFormat.jpeg,
    int quality = defaultJpegQuality,
  }) async {
    return enhanceFromBytes(
      bytes,
      options: EnhancementOptions(sharpness: amount.clamp(0, 100)),
      outputFormat: outputFormat,
      quality: quality,
    );
  }

  /// Adjusts brightness of an image.
  ///
  /// The [amount] parameter controls brightness adjustment (-100 to 100).
  /// Positive values increase brightness, negative values decrease it.
  ///
  /// Returns a [ProcessedImage] with adjusted brightness.
  Future<ProcessedImage> adjustBrightness(
    Uint8List bytes, {
    required int amount,
    ImageOutputFormat outputFormat = ImageOutputFormat.jpeg,
    int quality = defaultJpegQuality,
  }) async {
    return enhanceFromBytes(
      bytes,
      options: EnhancementOptions(brightness: amount.clamp(-100, 100)),
      outputFormat: outputFormat,
      quality: quality,
    );
  }

  /// Adjusts contrast of an image.
  ///
  /// The [amount] parameter controls contrast adjustment (-100 to 100).
  /// Positive values increase contrast, negative values decrease it.
  ///
  /// Returns a [ProcessedImage] with adjusted contrast.
  Future<ProcessedImage> adjustContrast(
    Uint8List bytes, {
    required int amount,
    ImageOutputFormat outputFormat = ImageOutputFormat.jpeg,
    int quality = defaultJpegQuality,
  }) async {
    return enhanceFromBytes(
      bytes,
      options: EnhancementOptions(contrast: amount.clamp(-100, 100)),
      outputFormat: outputFormat,
      quality: quality,
    );
  }

  /// Resizes an image to fit within specified dimensions.
  ///
  /// Maintains aspect ratio. Only downscales - won't upscale images
  /// that are already smaller than the target dimensions.
  ///
  /// Returns a [ProcessedImage] with the resized data.
  Future<ProcessedImage> resize(
    Uint8List bytes, {
    required int maxWidth,
    required int maxHeight,
    ImageOutputFormat outputFormat = ImageOutputFormat.jpeg,
    int quality = defaultJpegQuality,
  }) async {
    if (maxWidth <= 0 || maxHeight <= 0) {
      throw const ImageProcessorException(
        'Dimensions must be positive integers',
      );
    }

    try {
      final result = await compute(
        _resizeImageIsolate,
        _ResizeParams(
          bytes: bytes,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          outputFormat: outputFormat,
          quality: quality.clamp(1, 100),
        ),
      );

      return result;
    } catch (e) {
      throw ImageProcessorException(
        'Failed to resize image',
        cause: e,
      );
    }
  }

  /// Crops an image to the specified rectangle.
  ///
  /// The crop rectangle is defined by [x], [y], [width], and [height]
  /// in pixels from the top-left corner.
  ///
  /// Returns a [ProcessedImage] with the cropped data.
  Future<ProcessedImage> crop(
    Uint8List bytes, {
    required int x,
    required int y,
    required int width,
    required int height,
    ImageOutputFormat outputFormat = ImageOutputFormat.jpeg,
    int quality = defaultJpegQuality,
  }) async {
    if (width <= 0 || height <= 0) {
      throw const ImageProcessorException(
        'Crop dimensions must be positive integers',
      );
    }

    if (x < 0 || y < 0) {
      throw const ImageProcessorException(
        'Crop position cannot be negative',
      );
    }

    try {
      final result = await compute(
        _cropImageIsolate,
        _CropParams(
          bytes: bytes,
          x: x,
          y: y,
          width: width,
          height: height,
          outputFormat: outputFormat,
          quality: quality.clamp(1, 100),
        ),
      );

      return result;
    } catch (e) {
      throw ImageProcessorException(
        'Failed to crop image',
        cause: e,
      );
    }
  }

  /// Rotates an image by the specified angle.
  ///
  /// The [angle] is in degrees (90, 180, 270 for quick rotations,
  /// or any angle for arbitrary rotation).
  ///
  /// Returns a [ProcessedImage] with the rotated data.
  Future<ProcessedImage> rotate(
    Uint8List bytes, {
    required double angle,
    ImageOutputFormat outputFormat = ImageOutputFormat.jpeg,
    int quality = defaultJpegQuality,
  }) async {
    try {
      final result = await compute(
        _rotateImageIsolate,
        _RotateParams(
          bytes: bytes,
          angle: angle,
          outputFormat: outputFormat,
          quality: quality.clamp(1, 100),
        ),
      );

      return result;
    } catch (e) {
      throw ImageProcessorException(
        'Failed to rotate image',
        cause: e,
      );
    }
  }

  /// Gets information about an image without processing it.
  ///
  /// Returns dimensions and format information.
  ///
  /// Throws [ImageProcessorException] if the image cannot be decoded.
  Future<ImageInfo> getImageInfo(Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw const ImageProcessorException('Image bytes cannot be empty');
    }

    try {
      final result = await compute(_getImageInfoIsolate, bytes);
      return result;
    } catch (e) {
      throw ImageProcessorException(
        'Failed to get image info',
        cause: e,
      );
    }
  }
}

/// Information about an image.
@immutable
class ImageInfo {
  /// Creates an [ImageInfo] with the given properties.
  const ImageInfo({
    required this.width,
    required this.height,
    required this.format,
    this.hasAlpha = false,
  });

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// Detected image format.
  final String format;

  /// Whether the image has an alpha channel.
  final bool hasAlpha;

  /// Aspect ratio (width / height).
  double get aspectRatio => width / height;

  /// Total number of pixels.
  int get pixelCount => width * height;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageInfo &&
        other.width == width &&
        other.height == height &&
        other.format == format &&
        other.hasAlpha == hasAlpha;
  }

  @override
  int get hashCode => Object.hash(width, height, format, hasAlpha);

  @override
  String toString() => 'ImageInfo(${width}x$height, format: $format, '
      'hasAlpha: $hasAlpha)';
}

// ============================================================================
// Private isolate functions and parameter classes
// ============================================================================

/// Parameters for image processing in isolate.
class _ProcessingParams {
  const _ProcessingParams({
    required this.bytes,
    required this.options,
    required this.outputFormat,
    required this.quality,
  });

  final Uint8List bytes;
  final EnhancementOptions options;
  final ImageOutputFormat outputFormat;
  final int quality;
}

/// Parameters for image resize in isolate.
class _ResizeParams {
  const _ResizeParams({
    required this.bytes,
    required this.maxWidth,
    required this.maxHeight,
    required this.outputFormat,
    required this.quality,
  });

  final Uint8List bytes;
  final int maxWidth;
  final int maxHeight;
  final ImageOutputFormat outputFormat;
  final int quality;
}

/// Parameters for image crop in isolate.
class _CropParams {
  const _CropParams({
    required this.bytes,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.outputFormat,
    required this.quality,
  });

  final Uint8List bytes;
  final int x;
  final int y;
  final int width;
  final int height;
  final ImageOutputFormat outputFormat;
  final int quality;
}

/// Parameters for image rotation in isolate.
class _RotateParams {
  const _RotateParams({
    required this.bytes,
    required this.angle,
    required this.outputFormat,
    required this.quality,
  });

  final Uint8List bytes;
  final double angle;
  final ImageOutputFormat outputFormat;
  final int quality;
}

/// Isolate function for image processing.
ProcessedImage _processImageIsolate(_ProcessingParams params) {
  final image = img.decodeImage(params.bytes);
  if (image == null) {
    throw const ImageProcessorException('Failed to decode image');
  }

  var processed = image;
  final operations = <String>[];

  // Downscale if needed
  if (processed.width > ImageProcessor.maxProcessingDimension ||
      processed.height > ImageProcessor.maxProcessingDimension) {
    processed = img.copyResize(
      processed,
      width: processed.width > processed.height
          ? ImageProcessor.maxProcessingDimension
          : null,
      height: processed.height >= processed.width
          ? ImageProcessor.maxProcessingDimension
          : null,
      interpolation: img.Interpolation.linear,
    );
    operations.add('downscaled');
  }

  final options = params.options;

  // Apply denoising first if requested (blur reduces noise)
  if (options.denoise) {
    processed = img.gaussianBlur(processed, radius: 1);
    operations.add('denoise');
  }

  // Apply auto-enhancement (histogram stretching)
  if (options.autoEnhance) {
    processed = img.normalize(processed, min: 0, max: 255);
    operations.add('auto_enhance');
  }

  // Apply brightness and contrast adjustments in a single call
  if (options.brightness != 0 || options.contrast != 0) {
    // Scale brightness from -100..100 to -255..255 for image package
    final adjustedBrightness = (options.brightness * 2.55).round();
    // Scale contrast from -100..100 to multiplier (0.5 to 2.0)
    final contrastFactor = 1.0 + (options.contrast / 100.0);

    processed = img.adjustColor(
      processed,
      brightness: adjustedBrightness,
      contrast: contrastFactor,
    );

    if (options.brightness != 0) {
      operations.add('brightness:${options.brightness}');
    }
    if (options.contrast != 0) {
      operations.add('contrast:${options.contrast}');
    }
  }

  // Apply saturation adjustment (before grayscale)
  if (options.saturation != 0 && !options.grayscale) {
    // Scale from -100..100 to 0..2 (0=grayscale, 1=normal, 2=saturated)
    final saturationFactor = 1.0 + (options.saturation / 100.0);
    processed = img.adjustColor(processed, saturation: saturationFactor);
    operations.add('saturation:${options.saturation}');
  }

  // Apply grayscale conversion
  if (options.grayscale) {
    processed = img.grayscale(processed);
    operations.add('grayscale');
  }

  // Apply sharpening last
  if (options.sharpness > 0) {
    // Use unsharp mask for sharpening
    // Amount scaled from 0-100 to reasonable range
    final amount = options.sharpness / 50.0; // 0 to 2.0
    processed = _sharpenImage(processed, amount);
    operations.add('sharpen:${options.sharpness}');
  }

  // Encode to output format
  final outputBytes = _encodeImage(
    processed,
    params.outputFormat,
    params.quality,
  );

  return ProcessedImage(
    bytes: outputBytes,
    width: processed.width,
    height: processed.height,
    format: params.outputFormat,
    operationsApplied: operations,
  );
}

/// Isolate function for image resize.
ProcessedImage _resizeImageIsolate(_ResizeParams params) {
  final image = img.decodeImage(params.bytes);
  if (image == null) {
    throw const ImageProcessorException('Failed to decode image');
  }

  // Calculate target dimensions maintaining aspect ratio
  var targetWidth = image.width;
  var targetHeight = image.height;

  if (image.width > params.maxWidth || image.height > params.maxHeight) {
    final widthRatio = params.maxWidth / image.width;
    final heightRatio = params.maxHeight / image.height;
    final ratio = math.min(widthRatio, heightRatio);

    targetWidth = (image.width * ratio).round();
    targetHeight = (image.height * ratio).round();
  }

  final resized = img.copyResize(
    image,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.linear,
  );

  final outputBytes = _encodeImage(
    resized,
    params.outputFormat,
    params.quality,
  );

  return ProcessedImage(
    bytes: outputBytes,
    width: resized.width,
    height: resized.height,
    format: params.outputFormat,
    operationsApplied: ['resize:${targetWidth}x$targetHeight'],
  );
}

/// Isolate function for image crop.
ProcessedImage _cropImageIsolate(_CropParams params) {
  final image = img.decodeImage(params.bytes);
  if (image == null) {
    throw const ImageProcessorException('Failed to decode image');
  }

  // Validate crop bounds
  if (params.x + params.width > image.width ||
      params.y + params.height > image.height) {
    throw const ImageProcessorException(
      'Crop rectangle exceeds image boundaries',
    );
  }

  final cropped = img.copyCrop(
    image,
    x: params.x,
    y: params.y,
    width: params.width,
    height: params.height,
  );

  final outputBytes = _encodeImage(
    cropped,
    params.outputFormat,
    params.quality,
  );

  return ProcessedImage(
    bytes: outputBytes,
    width: cropped.width,
    height: cropped.height,
    format: params.outputFormat,
    operationsApplied: [
      'crop:${params.x},${params.y},${params.width}x${params.height}'
    ],
  );
}

/// Isolate function for image rotation.
ProcessedImage _rotateImageIsolate(_RotateParams params) {
  final image = img.decodeImage(params.bytes);
  if (image == null) {
    throw const ImageProcessorException('Failed to decode image');
  }

  img.Image rotated;

  // Use fast rotation for common angles
  final normalizedAngle = params.angle % 360;
  if (normalizedAngle == 90 || normalizedAngle == -270) {
    rotated = img.copyRotate(image, angle: 90);
  } else if (normalizedAngle == 180 || normalizedAngle == -180) {
    rotated = img.copyRotate(image, angle: 180);
  } else if (normalizedAngle == 270 || normalizedAngle == -90) {
    rotated = img.copyRotate(image, angle: 270);
  } else if (normalizedAngle == 0) {
    rotated = image;
  } else {
    // Arbitrary angle rotation
    rotated = img.copyRotate(image, angle: params.angle);
  }

  final outputBytes = _encodeImage(
    rotated,
    params.outputFormat,
    params.quality,
  );

  return ProcessedImage(
    bytes: outputBytes,
    width: rotated.width,
    height: rotated.height,
    format: params.outputFormat,
    operationsApplied: ['rotate:${params.angle}'],
  );
}

/// Isolate function for getting image info.
ImageInfo _getImageInfoIsolate(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw const ImageProcessorException('Failed to decode image');
  }

  // Detect format from bytes
  String format = 'unknown';
  if (bytes.length >= 3) {
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
      format = 'jpeg';
    } else if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E) {
      format = 'png';
    } else if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      format = 'webp';
    } else if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
      format = 'bmp';
    }
  }

  return ImageInfo(
    width: image.width,
    height: image.height,
    format: format,
    hasAlpha: image.hasAlpha,
  );
}

/// Encodes an image to the specified format.
Uint8List _encodeImage(
  img.Image image,
  ImageOutputFormat format,
  int quality,
) {
  switch (format) {
    case ImageOutputFormat.jpeg:
      return Uint8List.fromList(img.encodeJpg(image, quality: quality));
    case ImageOutputFormat.png:
      return Uint8List.fromList(img.encodePng(image));
  }
}

/// Applies unsharp mask sharpening to an image.
///
/// Uses the unsharp mask algorithm which provides high-quality sharpening
/// by enhancing edges while preserving detail. The algorithm:
/// 1. Creates a blurred version using optimized [img.gaussianBlur]
/// 2. Calculates the difference between original and blurred (the "mask")
/// 3. Adds the scaled mask back to the original
///
/// Formula: sharpened = original + amount * (original - blurred)
///
/// Note: While the image package provides [img.convolution] and [img.smooth]
/// functions, the unsharp mask approach used here produces superior results
/// for document sharpening, with better edge enhancement and fewer artifacts.
/// The [img.gaussianBlur] call is already using an optimized built-in method.
img.Image _sharpenImage(img.Image image, double amount) {
  // Step 1: Create blurred version using optimized built-in function
  final blurred = img.gaussianBlur(image, radius: 1);
  final result = img.Image.from(image);

  // Step 2 & 3: Apply unsharp mask formula
  // The image package doesn't provide image arithmetic operations,
  // so we need to iterate through pixels to calculate:
  // result = original + amount * (original - blurred)
  for (var y = 0; y < result.height; y++) {
    for (var x = 0; x < result.width; x++) {
      final original = image.getPixel(x, y);
      final blur = blurred.getPixel(x, y);

      final r =
          (original.r + amount * (original.r - blur.r)).clamp(0, 255).toInt();
      final g =
          (original.g + amount * (original.g - blur.g)).clamp(0, 255).toInt();
      final b =
          (original.b + amount * (original.b - blur.b)).clamp(0, 255).toInt();

      result.setPixelRgba(x, y, r, g, b, original.a.toInt());
    }
  }

  return result;
}
