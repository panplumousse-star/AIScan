import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Riverpod provider for [OcrService].
///
/// Provides a singleton instance of the OCR service for
/// dependency injection throughout the application.
final ocrServiceProvider = Provider<OcrService>((ref) {
  return OcrService();
});

/// Exception thrown when OCR operations fail.
///
/// Contains the original error message and optional underlying exception.
class OcrException implements Exception {
  /// Creates an [OcrException] with the given [message].
  const OcrException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'OcrException: $message (caused by: $cause)';
    }
    return 'OcrException: $message';
  }
}

/// Result of an OCR text extraction operation.
///
/// Contains the extracted text, confidence metrics, and metadata
/// about the recognition process.
@immutable
class OcrResult {
  /// Creates an [OcrResult] with the extracted data.
  const OcrResult({
    required this.text,
    required this.language,
    this.confidence,
    this.processingTimeMs,
    this.wordCount,
    this.lineCount,
    this.blocks,
  });

  /// The extracted text from the image.
  final String text;

  /// The language used for recognition.
  final String language;

  /// Overall confidence score (0.0 - 1.0) if available.
  ///
  /// Null if confidence measurement was not requested or not available.
  final double? confidence;

  /// Processing time in milliseconds.
  final int? processingTimeMs;

  /// Number of words extracted.
  final int? wordCount;

  /// Number of lines extracted.
  final int? lineCount;

  /// Text blocks with position information.
  final List<OcrTextBlock>? blocks;

  /// Whether any text was extracted.
  bool get hasText => text.trim().isNotEmpty;

  /// Whether the result is empty (no text extracted).
  bool get isEmpty => text.trim().isEmpty;

  /// Whether the result has text.
  bool get isNotEmpty => text.trim().isNotEmpty;

  /// Gets a trimmed version of the extracted text.
  String get trimmedText => text.trim();

  /// Gets the text length.
  int get textLength => text.length;

  /// Formatted confidence as percentage string.
  String get confidencePercent {
    if (confidence == null) return 'N/A';
    return '${(confidence! * 100).toStringAsFixed(1)}%';
  }

  /// Creates a copy with updated values.
  OcrResult copyWith({
    String? text,
    String? language,
    double? confidence,
    int? processingTimeMs,
    int? wordCount,
    int? lineCount,
    List<OcrTextBlock>? blocks,
  }) {
    return OcrResult(
      text: text ?? this.text,
      language: language ?? this.language,
      confidence: confidence ?? this.confidence,
      processingTimeMs: processingTimeMs ?? this.processingTimeMs,
      wordCount: wordCount ?? this.wordCount,
      lineCount: lineCount ?? this.lineCount,
      blocks: blocks ?? this.blocks,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OcrResult &&
        other.text == text &&
        other.language == language &&
        other.confidence == confidence &&
        other.processingTimeMs == processingTimeMs &&
        other.wordCount == wordCount &&
        other.lineCount == lineCount;
  }

  @override
  int get hashCode => Object.hash(
        text,
        language,
        confidence,
        processingTimeMs,
        wordCount,
        lineCount,
      );

  @override
  String toString() => 'OcrResult('
      'text: ${text.length} chars, '
      'language: $language, '
      'confidence: $confidencePercent, '
      'words: $wordCount, '
      'lines: $lineCount)';
}

/// A block of text recognized by OCR with position information.
@immutable
class OcrTextBlock {
  const OcrTextBlock({
    required this.text,
    required this.boundingBox,
    this.lines = const [],
  });

  final String text;
  final Rect boundingBox;
  final List<OcrTextLine> lines;
}

/// A line of text within a block.
@immutable
class OcrTextLine {
  const OcrTextLine({
    required this.text,
    required this.boundingBox,
  });

  final String text;
  final Rect boundingBox;
}

/// Simple rectangle class for bounding boxes.
@immutable
class Rect {
  const Rect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
}

/// Supported OCR languages/scripts.
///
/// ML Kit supports different scripts rather than specific languages.
enum OcrLanguage {
  /// Latin script (English, French, German, Spanish, etc.)
  latin('latin'),

  /// Chinese script
  chinese('chinese'),

  /// Devanagari script (Hindi, Sanskrit, etc.)
  devanagari('devanagari'),

  /// Japanese script
  japanese('japanese'),

  /// Korean script
  korean('korean'),

  // Legacy codes for backward compatibility
  /// English language (uses Latin script).
  english('latin'),

  /// German language (uses Latin script).
  german('latin'),

  /// French language (uses Latin script).
  french('latin'),

  /// Spanish language (uses Latin script).
  spanish('latin'),

  /// Italian language (uses Latin script).
  italian('latin'),

  /// Portuguese language (uses Latin script).
  portuguese('latin');

  /// Creates an [OcrLanguage] with its script code.
  const OcrLanguage(this.code);

  /// The script code.
  final String code;

  /// Gets the ML Kit TextRecognitionScript for this language.
  TextRecognitionScript get mlKitScript {
    switch (code) {
      case 'chinese':
        return TextRecognitionScript.chinese;
      case 'devanagari':
        return TextRecognitionScript.devanagiri;
      case 'japanese':
        return TextRecognitionScript.japanese;
      case 'korean':
        return TextRecognitionScript.korean;
      case 'latin':
      default:
        return TextRecognitionScript.latin;
    }
  }

  /// Gets the display name for the language.
  String get displayName {
    switch (this) {
      case OcrLanguage.latin:
        return 'Latin (EN, FR, DE, ES...)';
      case OcrLanguage.chinese:
        return 'Chinese';
      case OcrLanguage.devanagari:
        return 'Devanagari';
      case OcrLanguage.japanese:
        return 'Japanese';
      case OcrLanguage.korean:
        return 'Korean';
      case OcrLanguage.english:
        return 'English';
      case OcrLanguage.german:
        return 'German';
      case OcrLanguage.french:
        return 'French';
      case OcrLanguage.spanish:
        return 'Spanish';
      case OcrLanguage.italian:
        return 'Italian';
      case OcrLanguage.portuguese:
        return 'Portuguese';
    }
  }
}

/// Page segmentation mode for OCR.
///
/// Note: ML Kit handles this automatically, but we keep this for API compatibility.
enum OcrPageSegmentationMode {
  /// Automatic page segmentation.
  auto(3),

  /// Single column of text.
  singleColumn(4),

  /// Single block of text.
  singleBlock(6),

  /// Single text line.
  singleLine(7),

  /// Single word.
  singleWord(8),

  /// Single character.
  singleChar(10),

  /// Sparse text.
  sparseText(11),

  /// Sparse text with OSD.
  sparseTextOsd(12);

  const OcrPageSegmentationMode(this.value);
  final int value;
}

/// OCR engine mode.
///
/// Note: ML Kit uses neural networks by default, but we keep this for API compatibility.
enum OcrEngineMode {
  /// Legacy engine only.
  legacyOnly(0),

  /// LSTM neural network engine only.
  lstmOnly(1),

  /// Combined engines.
  combined(2),

  /// Default mode.
  defaultMode(3);

  const OcrEngineMode(this.value);
  final int value;
}

/// Configuration options for OCR operations.
@immutable
class OcrOptions {
  /// Creates [OcrOptions] with specified parameters.
  const OcrOptions({
    this.language = OcrLanguage.latin,
    this.pageSegmentationMode = OcrPageSegmentationMode.auto,
    this.engineMode = OcrEngineMode.lstmOnly,
    this.preserveInterwordSpaces = true,
    this.enableDeskew = false,
    this.characterWhitelist,
    this.characterBlacklist,
  });

  /// Creates [OcrOptions] optimized for document scanning.
  const OcrOptions.document({
    OcrLanguage language = OcrLanguage.latin,
  })  : language = language,
        pageSegmentationMode = OcrPageSegmentationMode.auto,
        engineMode = OcrEngineMode.lstmOnly,
        preserveInterwordSpaces = true,
        enableDeskew = false,
        characterWhitelist = null,
        characterBlacklist = null;

  /// Creates [OcrOptions] optimized for single-line text.
  const OcrOptions.singleLine({
    OcrLanguage language = OcrLanguage.latin,
  })  : language = language,
        pageSegmentationMode = OcrPageSegmentationMode.singleLine,
        engineMode = OcrEngineMode.lstmOnly,
        preserveInterwordSpaces = true,
        enableDeskew = false,
        characterWhitelist = null,
        characterBlacklist = null;

  /// Creates [OcrOptions] optimized for sparse text.
  const OcrOptions.sparse({
    OcrLanguage language = OcrLanguage.latin,
  })  : language = language,
        pageSegmentationMode = OcrPageSegmentationMode.sparseText,
        engineMode = OcrEngineMode.lstmOnly,
        preserveInterwordSpaces = true,
        enableDeskew = false,
        characterWhitelist = null,
        characterBlacklist = null;

  /// Creates [OcrOptions] for numeric content only.
  const OcrOptions.numericOnly({
    OcrLanguage language = OcrLanguage.latin,
  })  : language = language,
        pageSegmentationMode = OcrPageSegmentationMode.auto,
        engineMode = OcrEngineMode.lstmOnly,
        preserveInterwordSpaces = false,
        enableDeskew = false,
        characterWhitelist = '0123456789',
        characterBlacklist = null;

  /// The language/script to use for recognition.
  final OcrLanguage language;

  /// Page segmentation mode (kept for API compatibility).
  final OcrPageSegmentationMode pageSegmentationMode;

  /// OCR engine mode (kept for API compatibility).
  final OcrEngineMode engineMode;

  /// Whether to preserve spaces between words.
  final bool preserveInterwordSpaces;

  /// Whether to apply automatic deskewing.
  final bool enableDeskew;

  /// Whitelist of characters to recognize.
  final String? characterWhitelist;

  /// Blacklist of characters to never recognize.
  final String? characterBlacklist;

  /// Default options for document OCR.
  static const OcrOptions defaultDocument = OcrOptions.document();

  /// Creates a copy with updated values.
  OcrOptions copyWith({
    OcrLanguage? language,
    OcrPageSegmentationMode? pageSegmentationMode,
    OcrEngineMode? engineMode,
    bool? preserveInterwordSpaces,
    bool? enableDeskew,
    String? characterWhitelist,
    String? characterBlacklist,
  }) {
    return OcrOptions(
      language: language ?? this.language,
      pageSegmentationMode: pageSegmentationMode ?? this.pageSegmentationMode,
      engineMode: engineMode ?? this.engineMode,
      preserveInterwordSpaces:
          preserveInterwordSpaces ?? this.preserveInterwordSpaces,
      enableDeskew: enableDeskew ?? this.enableDeskew,
      characterWhitelist: characterWhitelist ?? this.characterWhitelist,
      characterBlacklist: characterBlacklist ?? this.characterBlacklist,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OcrOptions &&
        other.language == language &&
        other.pageSegmentationMode == pageSegmentationMode &&
        other.engineMode == engineMode &&
        other.preserveInterwordSpaces == preserveInterwordSpaces &&
        other.enableDeskew == enableDeskew &&
        other.characterWhitelist == characterWhitelist &&
        other.characterBlacklist == characterBlacklist;
  }

  @override
  int get hashCode => Object.hash(
        language,
        pageSegmentationMode,
        engineMode,
        preserveInterwordSpaces,
        enableDeskew,
        characterWhitelist,
        characterBlacklist,
      );

  @override
  String toString() => 'OcrOptions('
      'language: ${language.displayName}, '
      'script: ${language.mlKitScript})';
}

/// Service for offline OCR using Google ML Kit.
///
/// Provides high-quality offline text recognition using Google's ML Kit
/// Text Recognition API. All processing is done locally on the device.
///
/// ## Key Features
/// - **Fast Processing**: Typically under 200ms per image
/// - **High Accuracy**: Neural network based recognition
/// - **Multi-Script Support**: Latin, Chinese, Japanese, Korean, Devanagari
/// - **Offline Processing**: No internet required
/// - **Privacy-First**: All data stays on device
///
/// ## Usage
/// ```dart
/// final ocr = ref.read(ocrServiceProvider);
///
/// // Initialize (optional, but recommended)
/// await ocr.initialize();
///
/// // Extract text from an image file
/// final result = await ocr.extractTextFromFile('/path/to/image.jpg');
/// if (result.hasText) {
///   print('Extracted: ${result.text}');
/// }
///
/// // Extract text from bytes
/// final bytesResult = await ocr.extractTextFromBytes(imageBytes);
/// ```
class OcrService {
  /// Creates an [OcrService] instance.
  OcrService();

  /// Cached text recognizers by script.
  final Map<TextRecognitionScript, TextRecognizer> _recognizers = {};

  /// Whether the service has been initialized.
  bool _isInitialized = false;

  /// Whether the service is ready for use.
  bool get isReady => true; // ML Kit is always ready

  /// Default language for OCR.
  static const OcrLanguage defaultLanguage = OcrLanguage.latin;

  /// Gets or creates a text recognizer for the given script.
  TextRecognizer _getRecognizer(TextRecognitionScript script) {
    return _recognizers.putIfAbsent(
      script,
      () => TextRecognizer(script: script),
    );
  }

  /// Initializes the OCR service.
  ///
  /// This is optional for ML Kit but kept for API compatibility.
  /// ML Kit initializes lazily when first used.
  Future<bool> initialize({
    List<OcrLanguage> languages = const [OcrLanguage.latin],
  }) async {
    if (_isInitialized) return true;

    try {
      // Pre-create recognizers for requested languages
      for (final language in languages) {
        _getRecognizer(language.mlKitScript);
      }

      _isInitialized = true;
      debugPrint('OCR Service initialized with ML Kit');
      return true;
    } catch (e) {
      throw OcrException('Failed to initialize OCR service', cause: e);
    }
  }

  /// Checks if a specific language is available for OCR.
  ///
  /// ML Kit supports all configured scripts, so this always returns true
  /// for the supported scripts.
  bool isLanguageAvailable(OcrLanguage language) {
    return true; // ML Kit handles all supported scripts
  }

  /// Gets the list of available languages.
  List<OcrLanguage> get availableLanguages => [
        OcrLanguage.latin,
        OcrLanguage.chinese,
        OcrLanguage.japanese,
        OcrLanguage.korean,
        OcrLanguage.devanagari,
      ];

  /// Extracts text from an image file.
  ///
  /// The [imagePath] must be an absolute path to a valid image file.
  /// Supported formats: JPEG, PNG, BMP, WebP.
  ///
  /// Returns an [OcrResult] containing the extracted text and metadata.
  ///
  /// Throws [OcrException] if text extraction fails.
  Future<OcrResult> extractTextFromFile(
    String imagePath, {
    OcrOptions options = OcrOptions.defaultDocument,
  }) async {
    if (imagePath.isEmpty) {
      throw const OcrException('Image path cannot be empty');
    }

    // Verify file exists
    final file = File(imagePath);
    if (!await file.exists()) {
      throw OcrException('Image file not found: $imagePath');
    }

    try {
      final stopwatch = Stopwatch()..start();

      // Create InputImage from file
      final inputImage = InputImage.fromFilePath(imagePath);

      // Get the recognizer for the requested script
      final recognizer = _getRecognizer(options.language.mlKitScript);

      // Process the image
      final recognizedText = await recognizer.processImage(inputImage);

      stopwatch.stop();

      // Extract text and calculate statistics
      final text = recognizedText.text;
      final trimmedText = text.trim();
      final wordCount = trimmedText.isEmpty
          ? 0
          : trimmedText.split(RegExp(r'\s+')).length;
      final lineCount = trimmedText.isEmpty
          ? 0
          : trimmedText.split('\n').length;

      // Convert blocks to our format
      final blocks = recognizedText.blocks.map((block) {
        return OcrTextBlock(
          text: block.text,
          boundingBox: Rect(
            left: block.boundingBox.left,
            top: block.boundingBox.top,
            right: block.boundingBox.right,
            bottom: block.boundingBox.bottom,
          ),
          lines: block.lines.map((line) {
            return OcrTextLine(
              text: line.text,
              boundingBox: Rect(
                left: line.boundingBox.left,
                top: line.boundingBox.top,
                right: line.boundingBox.right,
                bottom: line.boundingBox.bottom,
              ),
            );
          }).toList(),
        );
      }).toList();

      // Apply character whitelist filter if specified
      String filteredText = text;
      if (options.characterWhitelist != null &&
          options.characterWhitelist!.isNotEmpty) {
        final whitelist = options.characterWhitelist!;
        filteredText = text.split('').where((char) {
          return whitelist.contains(char) || char == ' ' || char == '\n';
        }).join();
      }

      return OcrResult(
        text: filteredText,
        language: options.language.displayName,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        wordCount: wordCount,
        lineCount: lineCount,
        blocks: blocks,
      );
    } catch (e) {
      if (e is OcrException) rethrow;
      throw OcrException('Failed to extract text from image', cause: e);
    }
  }

  /// Extracts text from image bytes.
  ///
  /// The [bytes] must be a valid image in a supported format.
  /// This method writes the bytes to a temporary file, performs OCR,
  /// and then cleans up the temporary file.
  ///
  /// Returns an [OcrResult] containing the extracted text and metadata.
  Future<OcrResult> extractTextFromBytes(
    Uint8List bytes, {
    OcrOptions options = OcrOptions.defaultDocument,
  }) async {
    if (bytes.isEmpty) {
      throw const OcrException('Image bytes cannot be empty');
    }

    // Write to a temporary file
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      p.join(tempDir.path, 'ocr_temp_${DateTime.now().millisecondsSinceEpoch}.jpg'),
    );

    try {
      await tempFile.writeAsBytes(bytes);
      final result = await extractTextFromFile(
        tempFile.path,
        options: options,
      );
      return result;
    } finally {
      // Clean up temporary file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  /// Extracts text from multiple images and combines the results.
  ///
  /// Processes each image in the [imagePaths] list and combines
  /// the extracted text, separated by the [separator] string.
  ///
  /// Returns an [OcrResult] with the combined text from all images.
  Future<OcrResult> extractTextFromMultipleFiles(
    List<String> imagePaths, {
    OcrOptions options = OcrOptions.defaultDocument,
    String separator = '\n\n',
  }) async {
    if (imagePaths.isEmpty) {
      throw const OcrException('Image paths list cannot be empty');
    }

    final stopwatch = Stopwatch()..start();
    final textParts = <String>[];
    var totalWords = 0;
    var totalLines = 0;

    for (var i = 0; i < imagePaths.length; i++) {
      try {
        final result = await extractTextFromFile(
          imagePaths[i],
          options: options,
        );
        if (result.hasText) {
          textParts.add(result.text);
          totalWords += result.wordCount ?? 0;
          totalLines += result.lineCount ?? 0;
        }
      } catch (e) {
        throw OcrException(
          'Failed to extract text from page ${i + 1}: ${imagePaths[i]}',
          cause: e,
        );
      }
    }

    stopwatch.stop();

    return OcrResult(
      text: textParts.join(separator),
      language: options.language.displayName,
      processingTimeMs: stopwatch.elapsedMilliseconds,
      wordCount: totalWords,
      lineCount: totalLines,
    );
  }

  /// Extracts text with progress callback.
  ///
  /// Similar to [extractTextFromMultipleFiles] but reports progress
  /// after each page is processed.
  Future<OcrResult> extractTextWithProgress(
    List<String> imagePaths, {
    OcrOptions options = OcrOptions.defaultDocument,
    required void Function(int currentPage, int totalPages, OcrResult partialResult) onProgress,
    String separator = '\n\n',
  }) async {
    if (imagePaths.isEmpty) {
      throw const OcrException('Image paths list cannot be empty');
    }

    final stopwatch = Stopwatch()..start();
    final textParts = <String>[];
    var totalWords = 0;
    var totalLines = 0;

    for (var i = 0; i < imagePaths.length; i++) {
      final result = await extractTextFromFile(
        imagePaths[i],
        options: options,
      );

      if (result.hasText) {
        textParts.add(result.text);
        totalWords += result.wordCount ?? 0;
        totalLines += result.lineCount ?? 0;
      }

      onProgress(i, imagePaths.length, result);
    }

    stopwatch.stop();

    return OcrResult(
      text: textParts.join(separator),
      language: options.language.displayName,
      processingTimeMs: stopwatch.elapsedMilliseconds,
      wordCount: totalWords,
      lineCount: totalLines,
    );
  }

  /// Quickly checks if an image contains text.
  ///
  /// Returns true if the image appears to contain text.
  Future<bool> containsText(
    String imagePath, {
    OcrLanguage language = OcrLanguage.latin,
  }) async {
    try {
      final result = await extractTextFromFile(
        imagePath,
        options: OcrOptions(language: language),
      );
      return result.hasText;
    } catch (_) {
      return false;
    }
  }

  /// Clears cached recognizers.
  ///
  /// Call this to free up memory when OCR is no longer needed.
  Future<void> clearCache() async {
    for (final recognizer in _recognizers.values) {
      await recognizer.close();
    }
    _recognizers.clear();
    _isInitialized = false;
    debugPrint('OCR cache cleared');
  }

  /// Gets the storage size used (always 0 for ML Kit as it uses system libraries).
  Future<int> getCacheSize() async => 0;

  /// Gets a formatted string of the cache size.
  Future<String> getCacheSizeFormatted() async => '0 B';

  /// Closes all recognizers and releases resources.
  ///
  /// Call this when the service is no longer needed.
  Future<void> dispose() async {
    await clearCache();
  }
}
