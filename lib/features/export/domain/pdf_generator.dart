import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Riverpod provider for [PDFGenerator].
///
/// Provides a singleton instance of the PDF generator for
/// dependency injection throughout the application.
final pdfGeneratorProvider = Provider<PDFGenerator>((ref) {
  return PDFGenerator();
});

/// Exception thrown when PDF generation operations fail.
///
/// Contains the original error message and optional underlying exception.
class PDFGeneratorException implements Exception {
  /// Creates a [PDFGeneratorException] with the given [message].
  const PDFGeneratorException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'PDFGeneratorException: $message (caused by: $cause)';
    }
    return 'PDFGeneratorException: $message';
  }
}

/// Result of a PDF generation operation.
///
/// Contains the generated PDF data and metadata about the generation.
@immutable
class GeneratedPDF {
  /// Creates a [GeneratedPDF] with the generated data.
  const GeneratedPDF({
    required this.bytes,
    required this.pageCount,
    required this.title,
    this.author,
    this.subject,
    this.keywords,
    this.creationDate,
  });

  /// The generated PDF bytes.
  final Uint8List bytes;

  /// Number of pages in the PDF.
  final int pageCount;

  /// Title of the PDF document.
  final String title;

  /// Author of the PDF document.
  final String? author;

  /// Subject of the PDF document.
  final String? subject;

  /// Keywords for the PDF document.
  final List<String>? keywords;

  /// Creation date of the PDF.
  final DateTime? creationDate;

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

  /// Creates a copy with updated values.
  GeneratedPDF copyWith({
    Uint8List? bytes,
    int? pageCount,
    String? title,
    String? author,
    String? subject,
    List<String>? keywords,
    DateTime? creationDate,
    bool clearAuthor = false,
    bool clearSubject = false,
    bool clearKeywords = false,
    bool clearCreationDate = false,
  }) {
    return GeneratedPDF(
      bytes: bytes ?? this.bytes,
      pageCount: pageCount ?? this.pageCount,
      title: title ?? this.title,
      author: clearAuthor ? null : (author ?? this.author),
      subject: clearSubject ? null : (subject ?? this.subject),
      keywords: clearKeywords ? null : (keywords ?? this.keywords),
      creationDate:
          clearCreationDate ? null : (creationDate ?? this.creationDate),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeneratedPDF &&
        listEquals(other.bytes, bytes) &&
        other.pageCount == pageCount &&
        other.title == title &&
        other.author == author &&
        other.subject == subject &&
        listEquals(other.keywords, keywords) &&
        other.creationDate == creationDate;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(bytes),
        pageCount,
        title,
        author,
        subject,
        keywords != null ? Object.hashAll(keywords!) : null,
        creationDate,
      );

  @override
  String toString() => 'GeneratedPDF(title: $title, pages: $pageCount, '
      'size: $fileSizeFormatted)';
}

/// Page size options for PDF generation.
enum PDFPageSize {
  /// A4 paper size (210 x 297 mm).
  a4,

  /// US Letter paper size (8.5 x 11 inches).
  letter,

  /// US Legal paper size (8.5 x 14 inches).
  legal,

  /// Fit to image size (auto-determine from content).
  fitToImage,
}

/// Page orientation for PDF generation.
enum PDFOrientation {
  /// Portrait orientation (height > width).
  portrait,

  /// Landscape orientation (width > height).
  landscape,

  /// Auto-detect based on image dimensions.
  auto,
}

/// Image fit mode for PDF pages.
enum PDFImageFit {
  /// Fill the page completely (may crop edges).
  fill,

  /// Fit within the page (may have margins).
  contain,

  /// Cover the page while maintaining aspect ratio.
  cover,

  /// Use original image size (may extend beyond page).
  original,
}

/// Configuration for PDF generation.
///
/// Provides control over page size, orientation, margins, and metadata.
@immutable
class PDFGeneratorOptions {
  /// Creates [PDFGeneratorOptions] with specified parameters.
  const PDFGeneratorOptions({
    this.pageSize = PDFPageSize.a4,
    this.orientation = PDFOrientation.auto,
    this.imageFit = PDFImageFit.contain,
    this.marginLeft = 0,
    this.marginRight = 0,
    this.marginTop = 0,
    this.marginBottom = 0,
    this.title = 'Scanned Document',
    this.author,
    this.subject,
    this.keywords,
    this.producer = 'Scanaï',
    this.creator = 'Scanaï Document Scanner',
    this.imageQuality = 85,
    this.compressImages = true,
    this.maxWidth = 2000,
  });

  /// Default options for document scanning.
  static const PDFGeneratorOptions document = PDFGeneratorOptions(
    marginLeft: 20,
    marginRight: 20,
    marginTop: 20,
    marginBottom: 20,
  );

  /// Options for full-page image output (no margins).
  static const PDFGeneratorOptions fullPage = PDFGeneratorOptions(
    imageFit: PDFImageFit.fill,
  );

  /// Options for photo output (fit to image size).
  static const PDFGeneratorOptions photo = PDFGeneratorOptions(
    pageSize: PDFPageSize.fitToImage,
    imageFit: PDFImageFit.original,
  );

  /// Page size for the PDF.
  final PDFPageSize pageSize;

  /// Page orientation.
  final PDFOrientation orientation;

  /// How images should fit within pages.
  final PDFImageFit imageFit;

  /// Left margin in points (1 point = 1/72 inch).
  final double marginLeft;

  /// Right margin in points.
  final double marginRight;

  /// Top margin in points.
  final double marginTop;

  /// Bottom margin in points.
  final double marginBottom;

  /// Document title for PDF metadata.
  final String title;

  /// Document author for PDF metadata.
  final String? author;

  /// Document subject for PDF metadata.
  final String? subject;

  /// Document keywords for PDF metadata.
  final List<String>? keywords;

  /// PDF producer metadata.
  final String producer;

  /// PDF creator metadata.
  final String creator;

  /// Image quality for JPEG compression (1-100).
  final int imageQuality;

  /// Whether to compress images in the PDF.
  final bool compressImages;

  /// Maximum width in pixels for image resizing during compression.
  ///
  /// Images wider than this value will be resized proportionally before
  /// embedding in the PDF. Default is 2000px, which is sufficient for
  /// A4 at 300 DPI.
  final int maxWidth;

  /// Total horizontal margin.
  double get horizontalMargin => marginLeft + marginRight;

  /// Total vertical margin.
  double get verticalMargin => marginTop + marginBottom;

  /// Creates a copy with updated values.
  PDFGeneratorOptions copyWith({
    PDFPageSize? pageSize,
    PDFOrientation? orientation,
    PDFImageFit? imageFit,
    double? marginLeft,
    double? marginRight,
    double? marginTop,
    double? marginBottom,
    String? title,
    String? author,
    String? subject,
    List<String>? keywords,
    String? producer,
    String? creator,
    int? imageQuality,
    bool? compressImages,
    int? maxWidth,
    bool clearAuthor = false,
    bool clearSubject = false,
    bool clearKeywords = false,
  }) {
    return PDFGeneratorOptions(
      pageSize: pageSize ?? this.pageSize,
      orientation: orientation ?? this.orientation,
      imageFit: imageFit ?? this.imageFit,
      marginLeft: marginLeft ?? this.marginLeft,
      marginRight: marginRight ?? this.marginRight,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
      title: title ?? this.title,
      author: clearAuthor ? null : (author ?? this.author),
      subject: clearSubject ? null : (subject ?? this.subject),
      keywords: clearKeywords ? null : (keywords ?? this.keywords),
      producer: producer ?? this.producer,
      creator: creator ?? this.creator,
      imageQuality: imageQuality ?? this.imageQuality,
      compressImages: compressImages ?? this.compressImages,
      maxWidth: maxWidth ?? this.maxWidth,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PDFGeneratorOptions &&
        other.pageSize == pageSize &&
        other.orientation == orientation &&
        other.imageFit == imageFit &&
        other.marginLeft == marginLeft &&
        other.marginRight == marginRight &&
        other.marginTop == marginTop &&
        other.marginBottom == marginBottom &&
        other.title == title &&
        other.author == author &&
        other.subject == subject &&
        listEquals(other.keywords, keywords) &&
        other.producer == producer &&
        other.creator == creator &&
        other.imageQuality == imageQuality &&
        other.compressImages == compressImages &&
        other.maxWidth == maxWidth;
  }

  @override
  int get hashCode => Object.hash(
        pageSize,
        orientation,
        imageFit,
        marginLeft,
        marginRight,
        marginTop,
        marginBottom,
        title,
        author,
        subject,
        keywords != null ? Object.hashAll(keywords!) : null,
        producer,
        creator,
        imageQuality,
        compressImages,
        maxWidth,
      );

  @override
  String toString() => 'PDFGeneratorOptions('
      'pageSize: $pageSize, '
      'orientation: $orientation, '
      'imageFit: $imageFit, '
      'title: $title)';
}

/// Represents a page to be added to a PDF.
///
/// Each page can be created from image bytes or a file path.
@immutable
class PDFPage {
  /// Creates a [PDFPage] from image bytes.
  const PDFPage.fromBytes({
    required this.imageBytes,
    this.orientation,
  }) : imagePath = null;

  /// Creates a [PDFPage] from a file path.
  const PDFPage.fromFile({
    required this.imagePath,
    this.orientation,
  }) : imageBytes = null;

  /// Image bytes for this page (mutually exclusive with [imagePath]).
  final Uint8List? imageBytes;

  /// File path to the image for this page (mutually exclusive with [imageBytes]).
  final String? imagePath;

  /// Optional orientation override for this page.
  final PDFOrientation? orientation;

  /// Whether this page has image data.
  bool get hasImage => imageBytes != null || imagePath != null;

  /// Whether this page uses bytes.
  bool get usesBytes => imageBytes != null;

  /// Whether this page uses a file path.
  bool get usesFile => imagePath != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PDFPage &&
        ((imageBytes != null && other.imageBytes != null)
            ? listEquals(other.imageBytes, imageBytes)
            : other.imageBytes == imageBytes) &&
        other.imagePath == imagePath &&
        other.orientation == orientation;
  }

  @override
  int get hashCode => Object.hash(
        imageBytes != null ? Object.hashAll(imageBytes!) : null,
        imagePath,
        orientation,
      );

  @override
  String toString() {
    if (usesBytes) {
      return 'PDFPage(bytes: ${imageBytes!.length} bytes, '
          'orientation: $orientation)';
    } else if (usesFile) {
      return 'PDFPage(file: $imagePath, orientation: $orientation)';
    }
    return 'PDFPage(empty)';
  }
}

/// Service for generating PDF documents from scanned images.
///
/// Provides multi-page PDF generation with support for various page sizes,
/// orientations, and image fitting options. Optimized for document scanning
/// workflows with support for batch processing.
///
/// ## Key Features
/// - **Multi-Page Support**: Generate PDFs with multiple pages from image list
/// - **Flexible Page Sizes**: A4, Letter, Legal, or fit-to-image
/// - **Auto Orientation**: Automatically detect optimal page orientation
/// - **Image Fitting**: Fill, contain, cover, or original size options
/// - **Metadata Support**: Set title, author, subject, and keywords
/// - **Memory Efficient**: Process images from files to reduce memory usage
///
/// ## Usage
/// ```dart
/// final generator = ref.read(pdfGeneratorProvider);
///
/// // Generate from image bytes list
/// final result = await generator.generateFromBytes(
///   imageBytesList: [page1Bytes, page2Bytes],
///   options: PDFGeneratorOptions.document,
/// );
///
/// // Generate from file paths
/// final result = await generator.generateFromFiles(
///   imagePaths: ['/path/to/page1.jpg', '/path/to/page2.jpg'],
///   options: PDFGeneratorOptions(
///     title: 'My Document',
///     author: 'John Doe',
///   ),
/// );
///
/// // Save to file
/// await generator.generateToFile(
///   imagePaths: ['/path/to/page1.jpg'],
///   outputPath: '/path/to/output.pdf',
/// );
/// ```
///
/// ## Error Handling
/// The service throws [PDFGeneratorException] for all error cases.
/// Always wrap calls in try-catch:
/// ```dart
/// try {
///   final result = await generator.generateFromFiles(paths);
///   // Use result...
/// } on PDFGeneratorException catch (e) {
///   print('PDF generation failed: ${e.message}');
/// }
/// ```
class PDFGenerator {
  /// Creates a [PDFGenerator] instance.
  PDFGenerator();

  /// Generates a PDF from a list of image byte arrays.
  ///
  /// Each element in [imageBytesList] becomes a page in the PDF.
  /// The [options] parameter controls page size, orientation, and metadata.
  ///
  /// Returns a [GeneratedPDF] containing the PDF bytes and metadata.
  ///
  /// Throws [PDFGeneratorException] if generation fails.
  Future<GeneratedPDF> generateFromBytes({
    required List<Uint8List> imageBytesList,
    PDFGeneratorOptions options = const PDFGeneratorOptions(),
  }) async {
    if (imageBytesList.isEmpty) {
      throw const PDFGeneratorException('Image bytes list cannot be empty');
    }

    // Validate all images have data
    for (var i = 0; i < imageBytesList.length; i++) {
      if (imageBytesList[i].isEmpty) {
        throw PDFGeneratorException('Image at index $i is empty');
      }
    }

    try {
      final pages = imageBytesList
          .map((bytes) => PDFPage.fromBytes(imageBytes: bytes))
          .toList();

      return _generatePDF(pages: pages, options: options);
    } on PDFGeneratorException {
      rethrow;
    } on Object catch (e) {
      throw PDFGeneratorException(
        'Failed to generate PDF from bytes',
        cause: e,
      );
    }
  }

  /// Generates a PDF from a list of image file paths.
  ///
  /// Each file in [imagePaths] becomes a page in the PDF.
  /// The [options] parameter controls page size, orientation, and metadata.
  ///
  /// This method is more memory-efficient for large images as it reads
  /// files on demand rather than holding all bytes in memory.
  ///
  /// Returns a [GeneratedPDF] containing the PDF bytes and metadata.
  ///
  /// Throws [PDFGeneratorException] if generation fails.
  Future<GeneratedPDF> generateFromFiles({
    required List<String> imagePaths,
    PDFGeneratorOptions options = const PDFGeneratorOptions(),
  }) async {
    if (imagePaths.isEmpty) {
      throw const PDFGeneratorException('Image paths list cannot be empty');
    }

    // Validate all paths are non-empty
    for (var i = 0; i < imagePaths.length; i++) {
      if (imagePaths[i].isEmpty) {
        throw PDFGeneratorException('Image path at index $i is empty');
      }
    }

    try {
      final pages =
          imagePaths.map((path) => PDFPage.fromFile(imagePath: path)).toList();

      return _generatePDF(pages: pages, options: options);
    } on PDFGeneratorException {
      rethrow;
    } on Object catch (e) {
      throw PDFGeneratorException(
        'Failed to generate PDF from files',
        cause: e,
      );
    }
  }

  /// Generates a PDF from a list of [PDFPage] objects.
  ///
  /// Provides maximum flexibility by allowing mixed sources (bytes and files)
  /// and per-page orientation overrides.
  ///
  /// Returns a [GeneratedPDF] containing the PDF bytes and metadata.
  ///
  /// Throws [PDFGeneratorException] if generation fails.
  Future<GeneratedPDF> generateFromPages({
    required List<PDFPage> pages,
    PDFGeneratorOptions options = const PDFGeneratorOptions(),
  }) async {
    if (pages.isEmpty) {
      throw const PDFGeneratorException('Pages list cannot be empty');
    }

    // Validate all pages have image data
    for (var i = 0; i < pages.length; i++) {
      if (!pages[i].hasImage) {
        throw PDFGeneratorException('Page at index $i has no image data');
      }
    }

    try {
      return _generatePDF(pages: pages, options: options);
    } on PDFGeneratorException {
      rethrow;
    } on Object catch (e) {
      throw PDFGeneratorException(
        'Failed to generate PDF from pages',
        cause: e,
      );
    }
  }

  /// Generates a PDF and saves it directly to a file.
  ///
  /// This is the most memory-efficient option as it writes directly to disk.
  ///
  /// The [imagePaths] list contains paths to source images.
  /// The [outputPath] is where the PDF will be saved.
  ///
  /// Returns a [GeneratedPDF] with metadata (bytes loaded from saved file).
  ///
  /// Throws [PDFGeneratorException] if generation fails.
  Future<GeneratedPDF> generateToFile({
    required List<String> imagePaths,
    required String outputPath,
    PDFGeneratorOptions options = const PDFGeneratorOptions(),
  }) async {
    if (outputPath.isEmpty) {
      throw const PDFGeneratorException('Output path cannot be empty');
    }

    try {
      final result = await generateFromFiles(
        imagePaths: imagePaths,
        options: options,
      );

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(result.bytes);

      return result;
    } on PDFGeneratorException {
      rethrow;
    } on Object catch (e) {
      throw PDFGeneratorException(
        'Failed to save PDF to: $outputPath',
        cause: e,
      );
    }
  }

  /// Generates a single-page PDF from image bytes.
  ///
  /// Convenience method for single-page documents.
  ///
  /// Returns a [GeneratedPDF] containing the PDF bytes and metadata.
  Future<GeneratedPDF> generateSinglePage({
    required Uint8List imageBytes,
    PDFGeneratorOptions options = const PDFGeneratorOptions(),
  }) async {
    return generateFromBytes(
      imageBytesList: [imageBytes],
      options: options,
    );
  }

  /// Generates a single-page PDF from an image file.
  ///
  /// Convenience method for single-page documents.
  ///
  /// Returns a [GeneratedPDF] containing the PDF bytes and metadata.
  Future<GeneratedPDF> generateSinglePageFromFile({
    required String imagePath,
    PDFGeneratorOptions options = const PDFGeneratorOptions(),
  }) async {
    return generateFromFiles(
      imagePaths: [imagePath],
      options: options,
    );
  }

  /// Internal method to generate PDF from pages.
  Future<GeneratedPDF> _generatePDF({
    required List<PDFPage> pages,
    required PDFGeneratorOptions options,
  }) async {
    // Use compute for background processing
    final result = await compute(
      _generatePDFIsolate,
      _PDFGenerationParams(
        pages: pages,
        options: options,
      ),
    );

    return result;
  }
}

/// Parameters for PDF generation in isolate.
class _PDFGenerationParams {
  const _PDFGenerationParams({
    required this.pages,
    required this.options,
  });

  final List<PDFPage> pages;
  final PDFGeneratorOptions options;
}

/// Isolate function for PDF generation.
Future<GeneratedPDF> _generatePDFIsolate(_PDFGenerationParams params) async {
  final options = params.options;
  final creationDate = DateTime.now();

  final pdf = pw.Document(
    title: options.title,
    author: options.author,
    subject: options.subject,
    keywords: options.keywords?.join(', '),
    producer: options.producer,
    creator: options.creator,
  );

  for (var i = 0; i < params.pages.length; i++) {
    final page = params.pages[i];
    Uint8List imageBytes;

    // Load image bytes
    if (page.usesBytes) {
      imageBytes = page.imageBytes!;
    } else if (page.usesFile) {
      final file = File(page.imagePath!);
      if (!await file.exists()) {
        throw PDFGeneratorException('Image file not found: ${page.imagePath}');
      }
      imageBytes = await file.readAsBytes();
    } else {
      throw PDFGeneratorException('Page $i has no image data');
    }

    // Apply image compression before embedding in PDF
    imageBytes = _compressImageForPdf(imageBytes, options);

    // Decode image to get dimensions
    final pdfImage = pw.MemoryImage(imageBytes);

    // Determine page format (image dimensions not available without decoding)
    final pageFormat = _getPageFormat(options: options);

    // Determine orientation for this page
    final pageOrientation = page.orientation ?? options.orientation;

    // Calculate effective page format with orientation
    PdfPageFormat effectiveFormat;
    if (pageOrientation == PDFOrientation.landscape) {
      effectiveFormat = pageFormat.landscape;
    } else if (pageOrientation == PDFOrientation.portrait) {
      effectiveFormat = pageFormat.portrait;
    } else {
      // Auto orientation - use portrait as default since we can't detect
      // image dimensions without additional decoding
      effectiveFormat = pageFormat;
    }

    // Apply margins
    effectiveFormat = effectiveFormat.copyWith(
      marginLeft: options.marginLeft,
      marginRight: options.marginRight,
      marginTop: options.marginTop,
      marginBottom: options.marginBottom,
    );

    // Add page with image
    pdf.addPage(
      pw.Page(
        pageFormat: effectiveFormat,
        build: (context) {
          return _buildPageContent(
            image: pdfImage,
            options: options,
            pageFormat: effectiveFormat,
          );
        },
      ),
    );
  }

  // Generate PDF bytes
  final pdfBytes = await pdf.save();

  return GeneratedPDF(
    bytes: Uint8List.fromList(pdfBytes),
    pageCount: params.pages.length,
    title: options.title,
    author: options.author,
    subject: options.subject,
    keywords: options.keywords,
    creationDate: creationDate,
  );
}

/// Gets the PDF page format based on options.
PdfPageFormat _getPageFormat({
  required PDFGeneratorOptions options,
  double? imageWidth,
  double? imageHeight,
}) {
  switch (options.pageSize) {
    case PDFPageSize.a4:
      return PdfPageFormat.a4;
    case PDFPageSize.letter:
      return PdfPageFormat.letter;
    case PDFPageSize.legal:
      return PdfPageFormat.legal;
    case PDFPageSize.fitToImage:
      if (imageWidth != null && imageHeight != null) {
        return PdfPageFormat(
          imageWidth,
          imageHeight,
          marginAll: 0,
        );
      }
      // Fallback to A4 if dimensions not available
      return PdfPageFormat.a4;
  }
}

/// Builds the page content with the image.
pw.Widget _buildPageContent({
  required pw.MemoryImage image,
  required PDFGeneratorOptions options,
  required PdfPageFormat pageFormat,
}) {
  // Calculate available space for image
  final availableWidth = pageFormat.availableWidth;
  final availableHeight = pageFormat.availableHeight;

  pw.BoxFit boxFit;
  switch (options.imageFit) {
    case PDFImageFit.fill:
      boxFit = pw.BoxFit.fill;
    case PDFImageFit.contain:
      boxFit = pw.BoxFit.contain;
    case PDFImageFit.cover:
      boxFit = pw.BoxFit.cover;
    case PDFImageFit.original:
      boxFit = pw.BoxFit.scaleDown;
  }

  return pw.Center(
    child: pw.Image(
      image,
      width: availableWidth,
      height: availableHeight,
      fit: boxFit,
    ),
  );
}

/// Compresses an image for PDF embedding.
///
/// Applies JPEG compression and optional resizing to reduce PDF file size.
/// Returns the original bytes if compression is disabled or if decoding fails.
///
/// The [imageBytes] are the raw image bytes to compress.
/// The [options] control compression quality and maximum dimensions.
///
/// Returns compressed image bytes, or original bytes if compression is
/// disabled or image decoding fails.
Uint8List _compressImageForPdf(
    Uint8List imageBytes, PDFGeneratorOptions options) {
  // Preserve backward compatibility when compression is disabled
  if (!options.compressImages) {
    return imageBytes;
  }

  // Decode the image
  final decodedImage = img.decodeImage(imageBytes);
  if (decodedImage == null) {
    // Return original bytes if decode fails (graceful degradation)
    return imageBytes;
  }

  // Resize if wider than maxWidth, maintaining aspect ratio
  img.Image processedImage;
  if (decodedImage.width > options.maxWidth) {
    processedImage = img.copyResize(
      decodedImage,
      width: options.maxWidth,
      interpolation: img.Interpolation.linear,
    );
  } else {
    processedImage = decodedImage;
  }

  // Re-encode as JPEG with specified quality (clamped to valid range)
  final quality = options.imageQuality.clamp(1, 100);
  final compressedBytes = img.encodeJpg(processedImage, quality: quality);

  return Uint8List.fromList(compressedBytes);
}
