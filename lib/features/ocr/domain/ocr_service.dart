import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
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
  }) {
    return OcrResult(
      text: text ?? this.text,
      language: language ?? this.language,
      confidence: confidence ?? this.confidence,
      processingTimeMs: processingTimeMs ?? this.processingTimeMs,
      wordCount: wordCount ?? this.wordCount,
      lineCount: lineCount ?? this.lineCount,
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

/// Supported OCR languages.
///
/// Each language requires the corresponding traineddata file
/// to be present in the assets/tessdata directory.
enum OcrLanguage {
  /// English language.
  english('eng'),

  /// German language.
  german('deu'),

  /// French language.
  french('fra'),

  /// Spanish language.
  spanish('spa'),

  /// Italian language.
  italian('ita'),

  /// Portuguese language.
  portuguese('por'),

  /// Dutch language.
  dutch('nld'),

  /// Chinese Simplified.
  chineseSimplified('chi_sim'),

  /// Chinese Traditional.
  chineseTraditional('chi_tra'),

  /// Japanese language.
  japanese('jpn'),

  /// Korean language.
  korean('kor'),

  /// Arabic language.
  arabic('ara'),

  /// Russian language.
  russian('rus');

  /// Creates an [OcrLanguage] with its Tesseract code.
  const OcrLanguage(this.code);

  /// The Tesseract language code.
  final String code;

  /// Gets the display name for the language.
  String get displayName {
    switch (this) {
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
      case OcrLanguage.dutch:
        return 'Dutch';
      case OcrLanguage.chineseSimplified:
        return 'Chinese (Simplified)';
      case OcrLanguage.chineseTraditional:
        return 'Chinese (Traditional)';
      case OcrLanguage.japanese:
        return 'Japanese';
      case OcrLanguage.korean:
        return 'Korean';
      case OcrLanguage.arabic:
        return 'Arabic';
      case OcrLanguage.russian:
        return 'Russian';
    }
  }
}

/// Page segmentation mode for Tesseract OCR.
///
/// Controls how Tesseract segments the image for text recognition.
/// Different modes are optimized for different document layouts.
enum OcrPageSegmentationMode {
  /// Automatic page segmentation with OSD (Orientation and Script Detection).
  ///
  /// Best for general documents with unknown layout.
  auto(3),

  /// Assume a single column of text of variable sizes.
  ///
  /// Good for documents with a single column of text.
  singleColumn(4),

  /// Assume a single uniform block of vertically aligned text.
  ///
  /// Good for paragraphs of text.
  singleBlock(6),

  /// Treat the image as a single text line.
  ///
  /// Best for single-line text like license plates.
  singleLine(7),

  /// Treat the image as a single word.
  singleWord(8),

  /// Treat the image as a single character.
  singleChar(10),

  /// Sparse text - find as much text as possible in no particular order.
  ///
  /// Good for images with scattered text.
  sparseText(11),

  /// Sparse text with OSD.
  sparseTextOsd(12);

  /// Creates an [OcrPageSegmentationMode] with its Tesseract value.
  const OcrPageSegmentationMode(this.value);

  /// The Tesseract PSM value.
  final int value;
}

/// OCR engine mode for Tesseract.
///
/// Controls which OCR engine(s) to use for recognition.
enum OcrEngineMode {
  /// Legacy Tesseract engine only.
  ///
  /// Faster but less accurate.
  legacyOnly(0),

  /// LSTM neural network engine only.
  ///
  /// More accurate for most use cases.
  lstmOnly(1),

  /// Legacy engine + LSTM combined.
  ///
  /// May provide better results for some documents.
  combined(2),

  /// Default mode based on available data.
  defaultMode(3);

  /// Creates an [OcrEngineMode] with its Tesseract value.
  const OcrEngineMode(this.value);

  /// The Tesseract OEM value.
  final int value;
}

/// Configuration options for OCR operations.
///
/// Provides fine-grained control over Tesseract OCR parameters.
@immutable
class OcrOptions {
  /// Creates [OcrOptions] with specified parameters.
  const OcrOptions({
    this.language = OcrLanguage.english,
    this.pageSegmentationMode = OcrPageSegmentationMode.auto,
    this.engineMode = OcrEngineMode.lstmOnly,
    this.preserveInterwordSpaces = true,
    this.enableDeskew = false,
    this.characterWhitelist,
    this.characterBlacklist,
  });

  /// Creates [OcrOptions] optimized for document scanning.
  ///
  /// Uses settings that work well for scanned documents:
  /// - Auto page segmentation
  /// - LSTM engine for better accuracy
  /// - Preserve spacing between words
  const OcrOptions.document({
    OcrLanguage language = OcrLanguage.english,
  })  : language = language,
        pageSegmentationMode = OcrPageSegmentationMode.auto,
        engineMode = OcrEngineMode.lstmOnly,
        preserveInterwordSpaces = true,
        enableDeskew = false,
        characterWhitelist = null,
        characterBlacklist = null;

  /// Creates [OcrOptions] optimized for single-line text.
  ///
  /// Good for:
  /// - License plates
  /// - Serial numbers
  /// - Single line of text
  const OcrOptions.singleLine({
    OcrLanguage language = OcrLanguage.english,
  })  : language = language,
        pageSegmentationMode = OcrPageSegmentationMode.singleLine,
        engineMode = OcrEngineMode.lstmOnly,
        preserveInterwordSpaces = true,
        enableDeskew = false,
        characterWhitelist = null,
        characterBlacklist = null;

  /// Creates [OcrOptions] optimized for sparse text.
  ///
  /// Good for images with scattered text like:
  /// - Business cards
  /// - Receipts with varying layouts
  /// - Forms with fields
  const OcrOptions.sparse({
    OcrLanguage language = OcrLanguage.english,
  })  : language = language,
        pageSegmentationMode = OcrPageSegmentationMode.sparseText,
        engineMode = OcrEngineMode.lstmOnly,
        preserveInterwordSpaces = true,
        enableDeskew = false,
        characterWhitelist = null,
        characterBlacklist = null;

  /// Creates [OcrOptions] for numeric content only.
  ///
  /// Restricts recognition to digits, useful for:
  /// - Invoice numbers
  /// - Phone numbers
  /// - Numeric codes
  const OcrOptions.numericOnly({
    OcrLanguage language = OcrLanguage.english,
  })  : language = language,
        pageSegmentationMode = OcrPageSegmentationMode.auto,
        engineMode = OcrEngineMode.lstmOnly,
        preserveInterwordSpaces = false,
        enableDeskew = false,
        characterWhitelist = '0123456789',
        characterBlacklist = null;

  /// The language to use for recognition.
  final OcrLanguage language;

  /// Page segmentation mode controlling document layout analysis.
  final OcrPageSegmentationMode pageSegmentationMode;

  /// OCR engine mode.
  final OcrEngineMode engineMode;

  /// Whether to preserve spaces between words.
  ///
  /// When true, maintains original spacing.
  /// When false, may collapse multiple spaces.
  final bool preserveInterwordSpaces;

  /// Whether to apply automatic deskewing.
  ///
  /// Attempts to straighten tilted text before recognition.
  final bool enableDeskew;

  /// Whitelist of characters to recognize.
  ///
  /// If set, only these characters will be recognized.
  /// Example: '0123456789' for digits only.
  final String? characterWhitelist;

  /// Blacklist of characters to never recognize.
  ///
  /// These characters will be excluded from results.
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

  /// Generates Tesseract arguments map from these options.
  Map<String, String> toTesseractArgs() {
    final args = <String, String>{
      'psm': pageSegmentationMode.value.toString(),
      'oem': engineMode.value.toString(),
    };

    if (preserveInterwordSpaces) {
      args['preserve_interword_spaces'] = '1';
    }

    if (characterWhitelist != null && characterWhitelist!.isNotEmpty) {
      args['tessedit_char_whitelist'] = characterWhitelist!;
    }

    if (characterBlacklist != null && characterBlacklist!.isNotEmpty) {
      args['tessedit_char_blacklist'] = characterBlacklist!;
    }

    return args;
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
      'language: ${language.code}, '
      'psm: ${pageSegmentationMode.value}, '
      'oem: ${engineMode.value})';
}

/// Service for offline OCR using Tesseract.
///
/// Provides high-quality offline text recognition using the Tesseract OCR
/// engine. All processing is done locally on the device - no internet
/// connection is required and no data is sent to external servers.
///
/// ## Key Features
/// - **Offline Processing**: Works completely offline
/// - **Multi-Language Support**: Supports multiple languages (requires traineddata files)
/// - **Configurable**: Fine-grained control over recognition parameters
/// - **Privacy-First**: No data leaves the device
///
/// ## Setup Requirements
/// The Tesseract traineddata files must be:
/// 1. Included in assets/tessdata/ in your Flutter project
/// 2. Listed in pubspec.yaml under assets
/// 3. Copied to the device's documents directory on first use
///
/// Example assets directory structure:
/// ```
/// assets/
///   tessdata/
///     eng.traineddata    # English (required)
///     deu.traineddata    # German (optional)
///     fra.traineddata    # French (optional)
/// ```
///
/// ## Usage
/// ```dart
/// final ocr = ref.read(ocrServiceProvider);
///
/// // Initialize (must be called before first use)
/// await ocr.initialize();
///
/// // Extract text from an image file
/// final result = await ocr.extractTextFromFile('/path/to/image.jpg');
/// if (result.hasText) {
///   print('Extracted: ${result.text}');
/// }
///
/// // Extract text with custom options
/// final customResult = await ocr.extractTextFromFile(
///   '/path/to/image.jpg',
///   options: OcrOptions.sparse(language: OcrLanguage.german),
/// );
///
/// // Extract text from bytes
/// final bytesResult = await ocr.extractTextFromBytes(
///   imageBytes,
///   options: const OcrOptions.document(),
/// );
/// ```
///
/// ## Error Handling
/// The service throws [OcrException] for all error cases.
/// Always wrap calls in try-catch:
/// ```dart
/// try {
///   final result = await ocr.extractTextFromFile(path);
///   // Use result...
/// } on OcrException catch (e) {
///   print('OCR failed: ${e.message}');
/// }
/// ```
///
/// ## Performance Notes
/// - First initialization may take a few seconds as traineddata is copied
/// - LSTM engine provides best accuracy for most documents
/// - Larger images take longer to process
/// - Consider preprocessing (enhance contrast, sharpen) for better results
class OcrService {
  /// Creates an [OcrService] instance.
  OcrService();

  /// Whether the service has been initialized.
  bool _isInitialized = false;

  /// Path to the tessdata directory on the device.
  String? _tessdataPath;

  /// Available languages that have been initialized.
  final Set<OcrLanguage> _availableLanguages = {};

  /// Default language for OCR.
  static const OcrLanguage defaultLanguage = OcrLanguage.english;

  /// Asset path for tessdata files.
  static const String _tessdataAssetPath = 'assets/tessdata';

  /// Whether the service has been initialized and is ready for use.
  bool get isReady => _isInitialized && _tessdataPath != null;

  /// Gets the list of available languages.
  List<OcrLanguage> get availableLanguages => _availableLanguages.toList();

  /// Initializes the OCR service.
  ///
  /// This must be called before any OCR operations. It:
  /// 1. Creates the tessdata directory in app documents
  /// 2. Copies traineddata files from assets
  /// 3. Verifies the default language is available
  ///
  /// The [languages] parameter specifies which language files to initialize.
  /// If not specified, only English is initialized.
  ///
  /// Returns true if initialization was successful.
  ///
  /// Throws [OcrException] if initialization fails.
  ///
  /// Example:
  /// ```dart
  /// final ocr = ref.read(ocrServiceProvider);
  ///
  /// // Initialize with default language (English)
  /// await ocr.initialize();
  ///
  /// // Initialize with multiple languages
  /// await ocr.initialize(languages: [
  ///   OcrLanguage.english,
  ///   OcrLanguage.german,
  ///   OcrLanguage.french,
  /// ]);
  /// ```
  Future<bool> initialize({
    List<OcrLanguage> languages = const [OcrLanguage.english],
  }) async {
    if (_isInitialized) {
      // Already initialized - just verify requested languages
      await _ensureLanguagesAvailable(languages);
      return true;
    }

    try {
      // Get the app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final tessdataDir = Directory(p.join(appDir.path, 'tessdata'));

      // Create tessdata directory if it doesn't exist
      if (!await tessdataDir.exists()) {
        await tessdataDir.create(recursive: true);
      }

      _tessdataPath = tessdataDir.path;

      // Copy traineddata files for requested languages
      for (final language in languages) {
        await _copyTrainedData(language);
      }

      _isInitialized = true;

      debugPrint(
        'OCR Service initialized with languages: '
        '${_availableLanguages.map((l) => l.code).join(", ")}',
      );

      return true;
    } catch (e) {
      throw OcrException(
        'Failed to initialize OCR service',
        cause: e,
      );
    }
  }

  /// Copies a traineddata file from assets to the device.
  Future<void> _copyTrainedData(OcrLanguage language) async {
    if (_tessdataPath == null) {
      throw const OcrException('OCR service not initialized');
    }

    final filename = '${language.code}.traineddata';
    final destFile = File(p.join(_tessdataPath!, filename));

    // Skip if already exists
    if (await destFile.exists()) {
      _availableLanguages.add(language);
      return;
    }

    try {
      // Load from assets
      final assetPath = '$_tessdataAssetPath/$filename';
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();

      // Write to device storage
      await destFile.writeAsBytes(bytes);
      _availableLanguages.add(language);

      debugPrint('Copied traineddata for ${language.displayName}');
    } catch (e) {
      // Don't throw - just log that this language is not available
      debugPrint(
        'Warning: Could not load traineddata for ${language.displayName}: $e',
      );
    }
  }

  /// Ensures the specified languages are available.
  Future<void> _ensureLanguagesAvailable(List<OcrLanguage> languages) async {
    for (final language in languages) {
      if (!_availableLanguages.contains(language)) {
        await _copyTrainedData(language);
      }
    }
  }

  /// Checks if a specific language is available for OCR.
  ///
  /// Returns true if the language's traineddata file has been initialized.
  bool isLanguageAvailable(OcrLanguage language) {
    return _availableLanguages.contains(language);
  }

  /// Extracts text from an image file.
  ///
  /// The [imagePath] must be an absolute path to a valid image file.
  /// Supported formats: JPEG, PNG, TIFF, BMP, WebP.
  ///
  /// The [options] parameter allows customizing the recognition process.
  /// If not specified, [OcrOptions.defaultDocument] is used.
  ///
  /// Returns an [OcrResult] containing the extracted text and metadata.
  ///
  /// Throws [OcrException] if:
  /// - The service is not initialized
  /// - The image file doesn't exist
  /// - The requested language is not available
  /// - Text extraction fails
  ///
  /// Example:
  /// ```dart
  /// final result = await ocr.extractTextFromFile(
  ///   '/path/to/document.jpg',
  ///   options: const OcrOptions.document(),
  /// );
  /// print('Extracted text: ${result.text}');
  /// ```
  Future<OcrResult> extractTextFromFile(
    String imagePath, {
    OcrOptions options = OcrOptions.defaultDocument,
  }) async {
    if (!isReady) {
      throw const OcrException(
        'OCR service not initialized. Call initialize() first.',
      );
    }

    if (imagePath.isEmpty) {
      throw const OcrException('Image path cannot be empty');
    }

    // Verify file exists
    final file = File(imagePath);
    if (!await file.exists()) {
      throw OcrException('Image file not found: $imagePath');
    }

    // Verify language is available
    if (!isLanguageAvailable(options.language)) {
      // Try to initialize the language
      await _copyTrainedData(options.language);

      if (!isLanguageAvailable(options.language)) {
        throw OcrException(
          'Language ${options.language.displayName} (${options.language.code}) '
          'is not available. Ensure ${options.language.code}.traineddata '
          'is in assets/tessdata/',
        );
      }
    }

    try {
      final stopwatch = Stopwatch()..start();

      // Extract text using Tesseract
      final text = await FlutterTesseractOcr.extractText(
        imagePath,
        language: options.language.code,
        args: options.toTesseractArgs(),
      );

      stopwatch.stop();

      // Calculate word and line counts
      final trimmedText = text.trim();
      final wordCount = trimmedText.isEmpty
          ? 0
          : trimmedText.split(RegExp(r'\s+')).length;
      final lineCount = trimmedText.isEmpty
          ? 0
          : trimmedText.split('\n').length;

      return OcrResult(
        text: text,
        language: options.language.code,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        wordCount: wordCount,
        lineCount: lineCount,
      );
    } catch (e) {
      if (e is OcrException) {
        rethrow;
      }
      throw OcrException(
        'Failed to extract text from image',
        cause: e,
      );
    }
  }

  /// Extracts text from image bytes.
  ///
  /// The [bytes] must be a valid image in a supported format.
  /// This method writes the bytes to a temporary file, performs OCR,
  /// and then cleans up the temporary file.
  ///
  /// The [options] parameter allows customizing the recognition process.
  ///
  /// Returns an [OcrResult] containing the extracted text and metadata.
  ///
  /// Throws [OcrException] if text extraction fails.
  ///
  /// Example:
  /// ```dart
  /// final imageBytes = await file.readAsBytes();
  /// final result = await ocr.extractTextFromBytes(
  ///   imageBytes,
  ///   options: const OcrOptions.document(),
  /// );
  /// ```
  Future<OcrResult> extractTextFromBytes(
    Uint8List bytes, {
    OcrOptions options = OcrOptions.defaultDocument,
  }) async {
    if (!isReady) {
      throw const OcrException(
        'OCR service not initialized. Call initialize() first.',
      );
    }

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
  /// This is useful for multi-page documents where each page
  /// is a separate image file.
  ///
  /// Returns an [OcrResult] with the combined text from all images.
  /// The [wordCount] and [lineCount] reflect the totals across all pages.
  ///
  /// Throws [OcrException] if any image fails to process.
  ///
  /// Example:
  /// ```dart
  /// final result = await ocr.extractTextFromMultipleFiles(
  ///   ['/path/to/page1.jpg', '/path/to/page2.jpg'],
  ///   separator: '\n\n--- Page Break ---\n\n',
  /// );
  /// ```
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
      language: options.language.code,
      processingTimeMs: stopwatch.elapsedMilliseconds,
      wordCount: totalWords,
      lineCount: totalLines,
    );
  }

  /// Extracts text with progress callback.
  ///
  /// Similar to [extractTextFromMultipleFiles] but reports progress
  /// after each page is processed.
  ///
  /// The [onProgress] callback receives:
  /// - [currentPage]: The 0-based index of the page just processed
  /// - [totalPages]: The total number of pages to process
  /// - [partialResult]: The [OcrResult] for just that page
  ///
  /// Returns the combined [OcrResult] from all pages.
  ///
  /// Example:
  /// ```dart
  /// final result = await ocr.extractTextWithProgress(
  ///   imagePaths,
  ///   onProgress: (current, total, partial) {
  ///     print('Processed page ${current + 1} of $total');
  ///   },
  /// );
  /// ```
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
      language: options.language.code,
      processingTimeMs: stopwatch.elapsedMilliseconds,
      wordCount: totalWords,
      lineCount: totalLines,
    );
  }

  /// Quickly checks if an image contains text.
  ///
  /// This is a faster check than full text extraction, useful for
  /// filtering images that likely contain text before doing full OCR.
  ///
  /// Returns true if the image appears to contain text.
  ///
  /// Note: This may have false positives/negatives. For reliable
  /// text detection, use [extractTextFromFile] and check [OcrResult.hasText].
  Future<bool> containsText(
    String imagePath, {
    OcrLanguage language = OcrLanguage.english,
  }) async {
    try {
      final result = await extractTextFromFile(
        imagePath,
        options: OcrOptions(
          language: language,
          pageSegmentationMode: OcrPageSegmentationMode.sparseText,
          engineMode: OcrEngineMode.lstmOnly,
        ),
      );
      return result.hasText;
    } catch (_) {
      return false;
    }
  }

  /// Clears the tessdata directory cache.
  ///
  /// This removes all traineddata files from the device.
  /// Call [initialize] again after clearing to re-copy files.
  ///
  /// Use this to free up storage space or to force re-downloading
  /// of language files.
  Future<void> clearCache() async {
    if (_tessdataPath == null) return;

    try {
      final tessdataDir = Directory(_tessdataPath!);
      if (await tessdataDir.exists()) {
        await tessdataDir.delete(recursive: true);
      }
      _availableLanguages.clear();
      _isInitialized = false;
      _tessdataPath = null;

      debugPrint('OCR cache cleared');
    } catch (e) {
      throw OcrException('Failed to clear OCR cache', cause: e);
    }
  }

  /// Gets the storage size used by tessdata files.
  ///
  /// Returns the total size in bytes of all traineddata files.
  Future<int> getCacheSize() async {
    if (_tessdataPath == null) return 0;

    try {
      final tessdataDir = Directory(_tessdataPath!);
      if (!await tessdataDir.exists()) return 0;

      var totalSize = 0;
      await for (final entity in tessdataDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (_) {
      return 0;
    }
  }

  /// Gets a formatted string of the cache size.
  ///
  /// Returns a human-readable string like "4.2 MB".
  Future<String> getCacheSizeFormatted() async {
    final size = await getCacheSize();
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
