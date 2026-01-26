import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

import '../../../core/storage/document_repository.dart';
import '../../documents/domain/document_model.dart';

/// Riverpod provider for [ScannerService].
///
/// Provides a singleton instance of the scanner service for
/// dependency injection throughout the application.
final scannerServiceProvider = Provider<ScannerService>((ref) {
  return ScannerService();
});

/// Riverpod provider for [ScannerStorageService].
///
/// This provider includes the document repository and PDF generator
/// dependencies for saving scanned documents to encrypted storage.
final scannerStorageServiceProvider = Provider<ScannerStorageService>((ref) {
  final documentRepository = ref.watch(documentRepositoryProvider);
  return ScannerStorageService(
    documentRepository: documentRepository,
  );
});

/// Exception thrown when scanning operations fail.
///
/// Contains the original error message and optional underlying exception.
class ScannerException implements Exception {
  /// Creates a [ScannerException] with the given [message].
  const ScannerException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'ScannerException: $message (caused by: $cause)';
    }
    return 'ScannerException: $message';
  }
}

/// Result of a document scanning operation.
///
/// Contains the scanned page images and optional PDF if generated.
/// This is a wrapper around ML Kit's [DocumentScanningResult] that
/// provides a cleaner API for the application.
@immutable
class ScanResult {
  /// Creates a [ScanResult] with the scanned pages.
  const ScanResult({
    required this.pages,
    this.pdf,
  });

  /// Creates a [ScanResult] from ML Kit's [DocumentScanningResult].
  factory ScanResult.fromMlKitResult(DocumentScanningResult result) {
    return ScanResult(
      pages: result.images.map((path) => ScannedPage(imagePath: path)).toList(),
      pdf: result.pdf?.uri,
    );
  }

  /// List of scanned pages with their image paths.
  final List<ScannedPage> pages;

  /// Path to the generated PDF file, if PDF format was requested.
  final String? pdf;

  /// Number of pages in this scan result.
  int get pageCount => pages.length;

  /// Whether this result has a PDF.
  bool get hasPdf => pdf != null;

  /// Whether this result is empty (no pages scanned).
  bool get isEmpty => pages.isEmpty;

  /// Whether this result has pages.
  bool get isNotEmpty => pages.isNotEmpty;

  /// Gets all image paths from the scanned pages.
  List<String> get imagePaths => pages.map((page) => page.imagePath).toList();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScanResult &&
        listEquals(other.pages, pages) &&
        other.pdf == pdf;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(pages), pdf);

  @override
  String toString() => 'ScanResult(pages: ${pages.length}, hasPdf: $hasPdf)';
}

/// Represents a single scanned page.
@immutable
class ScannedPage {
  /// Creates a [ScannedPage] with the given [imagePath].
  const ScannedPage({
    required this.imagePath,
  });

  /// Path to the scanned image file on disk.
  ///
  /// This file is in JPEG or PNG format depending on the scanner options.
  /// The path is temporary and should be processed before it's cleaned up.
  final String imagePath;

  /// Reads the image bytes from disk.
  ///
  /// Throws [ScannerException] if the file cannot be read.
  Future<Uint8List> readBytes() async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw const ScannerException('Scanned image file not found');
      }
      return await file.readAsBytes();
    } on Object catch (e) {
      if (e is ScannerException) rethrow;
      throw ScannerException('Failed to read scanned image', cause: e);
    }
  }

  /// Checks if the scanned image file exists.
  Future<bool> exists() async {
    return await File(imagePath).exists();
  }

  /// Gets the file size in bytes.
  ///
  /// Returns 0 if the file doesn't exist.
  Future<int> getFileSize() async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } on Object catch (_) {
      return 0;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScannedPage && other.imagePath == imagePath;
  }

  @override
  int get hashCode => imagePath.hashCode;

  @override
  String toString() => 'ScannedPage(imagePath: $imagePath)';
}

/// Configuration options for document scanning.
///
/// Provides a clean abstraction over ML Kit's [DocumentScannerOptions].
@immutable
class ScannerOptions {
  /// Creates [ScannerOptions] with default values.
  ///
  /// Default configuration:
  /// - JPEG format for optimal file size
  /// - Full mode with edge detection, cropping, and enhancement
  /// - Up to 100 pages per scan session
  /// - Gallery import enabled
  const ScannerOptions({
    this.documentFormat = ScanDocumentFormat.jpeg,
    this.scannerMode = ScanMode.full,
    this.pageLimit = 100,
    this.allowGalleryImport = true,
  });

  /// Creates [ScannerOptions] for quick single-page scanning.
  ///
  /// Optimized for one-click scan workflow with single page capture.
  const ScannerOptions.quickScan()
      : documentFormat = ScanDocumentFormat.jpeg,
        scannerMode = ScanMode.full,
        pageLimit = 1,
        allowGalleryImport = false;

  /// Creates [ScannerOptions] for multi-page document scanning.
  ///
  /// Allows scanning up to [maxPages] pages in a single session.
  const ScannerOptions.multiPage({int maxPages = 100})
      : documentFormat = ScanDocumentFormat.jpeg,
        scannerMode = ScanMode.full,
        pageLimit = maxPages,
        allowGalleryImport = true;

  /// Creates [ScannerOptions] for PDF output.
  ///
  /// Generates a PDF file in addition to individual page images.
  const ScannerOptions.pdf({int maxPages = 100})
      : documentFormat = ScanDocumentFormat.pdf,
        scannerMode = ScanMode.full,
        pageLimit = maxPages,
        allowGalleryImport = true;

  /// The output format for scanned documents.
  final ScanDocumentFormat documentFormat;

  /// The scanner mode controlling available features.
  final ScanMode scannerMode;

  /// Maximum number of pages that can be scanned in one session.
  ///
  /// Range: 1-100. Default is 100.
  final int pageLimit;

  /// Whether to allow importing images from the device gallery.
  ///
  /// When enabled, users can select existing photos in addition
  /// to capturing new ones with the camera.
  final bool allowGalleryImport;

  /// Converts to ML Kit's [DocumentScannerOptions].
  DocumentScannerOptions toMlKitOptions() {
    return DocumentScannerOptions(
      documentFormat: _toMlKitDocumentFormat(),
      mode: _toMlKitScannerMode(),
      pageLimit: pageLimit.clamp(1, 100),
      isGalleryImport: allowGalleryImport,
    );
  }

  DocumentFormat _toMlKitDocumentFormat() {
    switch (documentFormat) {
      case ScanDocumentFormat.jpeg:
        return DocumentFormat.jpeg;
      case ScanDocumentFormat.pdf:
        return DocumentFormat.pdf;
    }
  }

  ScannerMode _toMlKitScannerMode() {
    switch (scannerMode) {
      case ScanMode.full:
        return ScannerMode.full;
      case ScanMode.filter:
        return ScannerMode.filter;
      case ScanMode.base:
        return ScannerMode.base;
      case ScanMode.baseWithFilter:
        return ScannerMode
            .base; // baseWithFilter not available, fallback to base
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScannerOptions &&
        other.documentFormat == documentFormat &&
        other.scannerMode == scannerMode &&
        other.pageLimit == pageLimit &&
        other.allowGalleryImport == allowGalleryImport;
  }

  @override
  int get hashCode => Object.hash(
        documentFormat,
        scannerMode,
        pageLimit,
        allowGalleryImport,
      );

  @override
  String toString() => 'ScannerOptions('
      'format: $documentFormat, '
      'mode: $scannerMode, '
      'pageLimit: $pageLimit, '
      'galleryImport: $allowGalleryImport)';
}

/// Document output format options.
enum ScanDocumentFormat {
  /// JPEG image format.
  ///
  /// Produces individual JPEG images for each page.
  /// Best for document processing and OCR.
  jpeg,

  /// PDF document format.
  ///
  /// Produces a multi-page PDF document.
  /// Best for sharing and printing.
  pdf,
}

/// Scanner mode options controlling available features.
enum ScanMode {
  /// Full mode with all features.
  ///
  /// Includes automatic edge detection, perspective correction,
  /// cropping controls, and image enhancement filters.
  /// This is the recommended mode for best quality results.
  full,

  /// Base mode with filter options.
  ///
  /// Includes basic scanning with image filter selection.
  baseWithFilter,

  /// Filter-only mode.
  ///
  /// Focuses on image enhancement filters without cropping.
  filter,

  /// Base mode without filters.
  ///
  /// Minimal interface for quick scanning without adjustments.
  base,
}

/// Service for document scanning using Google ML Kit.
///
/// Provides high-quality document scanning with automatic edge detection,
/// perspective correction, and image enhancement. Uses ML Kit's native
/// document scanner for optimal performance and accuracy.
///
/// ## Key Features
/// - **Automatic Edge Detection**: ML Kit automatically detects document edges
/// - **Perspective Correction**: Straightens tilted documents
/// - **Image Enhancement**: Auto-enhancement for better readability
/// - **Multi-Page Support**: Scan up to 100 pages in one session
/// - **Gallery Import**: Import existing photos as documents
///
/// ## Usage
/// ```dart
/// final scanner = ref.read(scannerServiceProvider);
///
/// // Quick single-page scan
/// final result = await scanner.scanDocument();
/// if (result != null) {
///   for (final page in result.pages) {
///     final bytes = await page.readBytes();
///     // Process the scanned image...
///   }
/// }
///
/// // Multi-page scanning with custom options
/// final multiPageResult = await scanner.scanDocument(
///   options: const ScannerOptions.multiPage(maxPages: 10),
/// );
///
/// // Scan for PDF output
/// final pdfResult = await scanner.scanDocument(
///   options: const ScannerOptions.pdf(),
/// );
/// if (pdfResult?.hasPdf ?? false) {
///   final pdfPath = pdfResult!.pdf!;
///   // Use the PDF file...
/// }
/// ```
///
/// ## Error Handling
/// The service throws [ScannerException] for all error cases.
/// Common error scenarios:
/// - User cancelled the scan
/// - Camera not available
/// - Insufficient storage space
/// - ML Kit initialization failed
///
/// Always wrap calls in try-catch for proper error handling:
/// ```dart
/// try {
///   final result = await scanner.scanDocument();
///   // Handle success...
/// } on ScannerException catch (e) {
///   // Handle scanning error...
///   print('Scan failed: ${e.message}');
/// }
/// ```
class ScannerService {
  /// Creates a [ScannerService] instance.
  ///
  /// Optionally accepts a custom [DocumentScanner] for testing.
  ScannerService({
    DocumentScanner? scanner,
  }) : _customScanner = scanner;

  /// Custom scanner injected for testing.
  final DocumentScanner? _customScanner;

  /// Default scanner options for standard scanning.
  static const ScannerOptions defaultOptions = ScannerOptions();

  /// Creates a new [DocumentScanner] with the given options.
  DocumentScanner _createScanner(ScannerOptions options) {
    return DocumentScanner(options: options.toMlKitOptions());
  }

  /// Scans a document using the device camera.
  ///
  /// Opens the ML Kit document scanner UI which handles:
  /// - Camera preview with edge detection overlay
  /// - Automatic document detection
  /// - Perspective correction
  /// - Image enhancement options
  /// - Multi-page capture (if enabled)
  ///
  /// Returns a [ScanResult] with the scanned pages, or `null` if the user
  /// cancelled the scan operation.
  ///
  /// The [options] parameter allows customizing the scanner behavior.
  /// If not specified, [defaultOptions] is used.
  ///
  /// Throws [ScannerException] if scanning fails for any reason other
  /// than user cancellation.
  ///
  /// Example:
  /// ```dart
  /// final result = await scanner.scanDocument();
  /// if (result != null && result.isNotEmpty) {
  ///   // Process scanned pages...
  /// }
  /// ```
  Future<ScanResult?> scanDocument({
    ScannerOptions options = defaultOptions,
  }) async {
    final scanner = _customScanner ?? _createScanner(options);

    try {
      final result = await scanner.scanDocument();

      // Empty result (no pages) indicates cancellation
      if (result.images.isEmpty) {
        return null;
      }

      return ScanResult.fromMlKitResult(result);
    } on Exception catch (e) {
      // ML Kit throws various exceptions for different error cases
      // We wrap them all in ScannerException for consistent error handling
      throw ScannerException(
        'Document scanning failed',
        cause: e,
      );
    } finally {
      // Close the scanner to release resources if we created it
      if (_customScanner == null) {
        await scanner.close();
      }
    }
  }

  /// Performs a quick single-page scan optimized for speed.
  ///
  /// This is a convenience method that uses [ScannerOptions.quickScan]
  /// for the fastest scanning experience. Ideal for the one-click scan
  /// workflow from the home screen.
  ///
  /// Returns a [ScanResult] with a single page, or `null` if cancelled.
  ///
  /// Example:
  /// ```dart
  /// final result = await scanner.quickScan();
  /// if (result != null) {
  ///   final page = result.pages.first;
  ///   // Process the single page...
  /// }
  /// ```
  Future<ScanResult?> quickScan() async {
    return scanDocument(options: const ScannerOptions.quickScan());
  }

  /// Scans multiple pages into a single document.
  ///
  /// This is a convenience method that uses [ScannerOptions.multiPage]
  /// for capturing multiple pages in one session.
  ///
  /// The [maxPages] parameter limits the number of pages (1-100, default 100).
  ///
  /// Returns a [ScanResult] with all scanned pages, or `null` if cancelled.
  ///
  /// Example:
  /// ```dart
  /// final result = await scanner.scanMultiPage(maxPages: 10);
  /// if (result != null) {
  ///   print('Scanned ${result.pageCount} pages');
  /// }
  /// ```
  Future<ScanResult?> scanMultiPage({int maxPages = 100}) async {
    return scanDocument(
      options: ScannerOptions.multiPage(maxPages: maxPages.clamp(1, 100)),
    );
  }

  /// Scans documents and generates a PDF file.
  ///
  /// This is a convenience method that uses [ScannerOptions.pdf]
  /// to produce both individual page images and a combined PDF.
  ///
  /// The [maxPages] parameter limits the number of pages (1-100, default 100).
  ///
  /// Returns a [ScanResult] with page images and a PDF path, or `null` if cancelled.
  ///
  /// Example:
  /// ```dart
  /// final result = await scanner.scanToPdf();
  /// if (result?.hasPdf ?? false) {
  ///   final pdfFile = File(result!.pdf!);
  ///   // Share or save the PDF...
  /// }
  /// ```
  Future<ScanResult?> scanToPdf({int maxPages = 100}) async {
    return scanDocument(
      options: ScannerOptions.pdf(maxPages: maxPages.clamp(1, 100)),
    );
  }

  /// Validates that scanned images exist and are accessible.
  ///
  /// Checks each page in the [result] to ensure the image files exist.
  /// Returns a list of [ScannedPage] objects that exist on disk.
  ///
  /// This is useful for handling edge cases where temporary files
  /// may have been cleaned up before processing.
  ///
  /// Example:
  /// ```dart
  /// final result = await scanner.scanDocument();
  /// if (result != null) {
  ///   final validPages = await scanner.validateScanResult(result);
  ///   if (validPages.length < result.pageCount) {
  ///     print('Some pages are missing!');
  ///   }
  /// }
  /// ```
  Future<List<ScannedPage>> validateScanResult(ScanResult result) async {
    final validPages = <ScannedPage>[];

    for (final page in result.pages) {
      if (await page.exists()) {
        validPages.add(page);
      }
    }

    return validPages;
  }

  /// Cleans up temporary scan result files.
  ///
  /// Deletes the image files from the [result] to free up storage.
  /// Call this after processing and saving the scanned images.
  ///
  /// Returns the number of files successfully deleted.
  ///
  /// Example:
  /// ```dart
  /// final result = await scanner.scanDocument();
  /// if (result != null) {
  ///   // Process and save the images...
  ///   await documentRepository.createDocument(...);
  ///
  ///   // Clean up temporary files
  ///   await scanner.cleanupScanResult(result);
  /// }
  /// ```
  Future<int> cleanupScanResult(ScanResult result) async {
    var deletedCount = 0;

    for (final page in result.pages) {
      try {
        final file = File(page.imagePath);
        if (await file.exists()) {
          await file.delete();
          deletedCount++;
        }
      } on Object catch (_) {
        // Ignore deletion errors - file may already be deleted
      }
    }

    // Also clean up PDF if present
    if (result.hasPdf) {
      try {
        final pdfFile = File(result.pdf!);
        if (await pdfFile.exists()) {
          await pdfFile.delete();
          deletedCount++;
        }
      } on Object catch (_) {
        // Ignore deletion errors
      }
    }

    return deletedCount;
  }
}

/// Result of saving a scan to encrypted storage.
///
/// Contains the created document and information about the save operation.
@immutable
class SavedScanResult {
  /// Creates a [SavedScanResult] with the saved document.
  const SavedScanResult({
    required this.document,
    required this.pagesProcessed,
    this.thumbnailGenerated = false,
  });

  /// The document that was created in encrypted storage.
  final Document document;

  /// Number of pages that were processed.
  final int pagesProcessed;

  /// Whether a thumbnail was generated for the document.
  final bool thumbnailGenerated;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedScanResult &&
        other.document == document &&
        other.pagesProcessed == pagesProcessed &&
        other.thumbnailGenerated == thumbnailGenerated;
  }

  @override
  int get hashCode => Object.hash(document, pagesProcessed, thumbnailGenerated);

  @override
  String toString() =>
      'SavedScanResult(document: ${document.id}, pages: $pagesProcessed, '
      'thumbnail: $thumbnailGenerated)';
}

/// Service for saving scanned documents to encrypted storage.
///
/// This service bridges the gap between the scanner output and the
/// encrypted document storage. It handles:
/// - Converting scan results to encrypted documents
/// - Generating thumbnails for document previews
/// - Cleaning up temporary scan files after saving
///
/// ## Security
/// All documents are saved encrypted using AES-256. The source scan
/// files are automatically cleaned up after successful encryption.
///
/// ## Usage
/// ```dart
/// final storageService = ref.read(scannerStorageServiceProvider);
/// final scannerService = ref.read(scannerServiceProvider);
///
/// // Scan a document
/// final scanResult = await scannerService.scanDocument();
/// if (scanResult != null) {
///   // Save to encrypted storage
///   final savedResult = await storageService.saveScanResult(
///     scanResult,
///     title: 'My Document',
///   );
///
///   // The document is now encrypted and stored
///   print('Saved document: ${savedResult.document.id}');
/// }
/// ```
///
/// ## Multi-Page Documents
/// For multi-page scans, this service:
/// 1. Uses the first page as the primary document
/// 2. Generates a thumbnail from the first page
/// 3. Records the total page count in metadata
///
/// Note: Future versions may support saving each page separately
/// with a linked document structure.
class ScannerStorageService {
  /// Creates a [ScannerStorageService] with the required dependencies.
  ScannerStorageService({
    required DocumentRepository documentRepository,
  }) : _documentRepository = documentRepository;

  /// The document repository for encrypted storage operations.
  final DocumentRepository _documentRepository;

  /// Default thumbnail width in pixels.
  static const int _thumbnailWidth = 300;

  /// Default thumbnail quality (JPEG compression).
  static const int _thumbnailQuality = 85;

  /// Saves a scan result to encrypted document storage.
  ///
  /// This method:
  /// 1. Validates the scan result
  /// 2. Converts each page to PNG format
  /// 3. Generates a thumbnail from the first page
  /// 4. Creates the document with encrypted page storage
  /// 5. Cleans up temporary scan files
  ///
  /// Pages are stored as individual PNG images (not PDF) for:
  /// - Better memory efficiency (no PDF parsing needed)
  /// - Native image display with Image.memory()
  /// - Lossless quality for OCR processing
  /// - PDF can be generated on-demand for export/sharing
  ///
  /// Parameters:
  /// - [scanResult]: The scan result to save
  /// - [title]: Optional title for the document (auto-generated if not provided)
  /// - [description]: Optional description
  /// - [folderId]: Optional folder to save the document in
  /// - [isFavorite]: Whether to mark the document as favorite
  /// - [generateThumbnail]: Whether to generate a thumbnail (default: true)
  /// - [cleanupAfterSave]: Whether to delete temp files after saving (default: true)
  ///
  /// Returns a [SavedScanResult] containing the created document.
  ///
  /// Throws [ScannerException] if saving fails.
  ///
  /// Example:
  /// ```dart
  /// final result = await storageService.saveScanResult(
  ///   scanResult,
  ///   title: 'Tax Document 2024',
  ///   folderId: 'folder-taxes',
  /// );
  /// ```
  Future<SavedScanResult> saveScanResult(
    ScanResult scanResult, {
    String? title,
    String? description,
    String? folderId,
    bool isFavorite = false,
    bool generateThumbnail = true,
    bool cleanupAfterSave = true,
  }) async {
    if (scanResult.isEmpty) {
      throw const ScannerException('Cannot save empty scan result');
    }

    // Validate that scan files exist
    final validPages = <ScannedPage>[];
    for (final page in scanResult.pages) {
      if (await page.exists()) {
        validPages.add(page);
      }
    }

    if (validPages.isEmpty) {
      throw const ScannerException(
        'No valid scan pages found - files may have been deleted',
      );
    }

    final pngTempPaths = <String>[];

    try {
      // Generate title if not provided
      final documentTitle = title ?? _generateDefaultTitle();

      // Use the first page for thumbnail
      final primaryPage = validPages.first;

      // Generate thumbnail if requested
      String? thumbnailPath;
      if (generateThumbnail) {
        thumbnailPath = await _generateThumbnail(primaryPage);
      }

      // Convert each page to PNG format (lossless for OCR quality)
      final tempDir = Directory.systemTemp;
      for (var i = 0; i < validPages.length; i++) {
        final page = validPages[i];
        final pngPath = await _convertToPng(page, tempDir, i);
        pngTempPaths.add(pngPath);
      }

      // Create the document in encrypted storage with multiple pages
      final document = await _documentRepository.createDocumentWithPages(
        title: documentTitle,
        sourceImagePaths: pngTempPaths,
        description: description,
        thumbnailSourcePath: thumbnailPath,
        folderId: folderId,
        isFavorite: isFavorite,
      );

      // Clean up temporary files if requested
      if (cleanupAfterSave) {
        await _cleanupScanFiles(scanResult);
        // Clean up temporary PNG files
        for (final pngPath in pngTempPaths) {
          await _deleteTempFile(pngPath);
        }
        // Also clean up temporary thumbnail if generated
        if (thumbnailPath != null) {
          await _deleteTempFile(thumbnailPath);
        }
      }

      return SavedScanResult(
        document: document,
        pagesProcessed: validPages.length,
        thumbnailGenerated: thumbnailPath != null,
      );
    } on Object catch (e) {
      // Clean up temporary PNG files on error
      for (final pngPath in pngTempPaths) {
        await _deleteTempFile(pngPath);
      }
      if (e is ScannerException) {
        rethrow;
      }
      throw ScannerException(
        'Failed to save scan result to encrypted storage',
        cause: e,
      );
    }
  }

  /// Converts a scanned page (JPEG) to PNG format for lossless storage.
  ///
  /// PNG is preferred for:
  /// - Lossless compression (better OCR accuracy)
  /// - No further quality degradation on re-encoding
  /// - Better for text documents
  ///
  /// Returns the path to the generated PNG file.
  Future<String> _convertToPng(
    ScannedPage page,
    Directory tempDir,
    int pageIndex,
  ) async {
    try {
      final sourceBytes = await page.readBytes();

      // Use compute to offload heavy image processing to a background isolate
      // to avoid blocking the main UI thread.
      final pngBytes = await compute(_processPngIsolate, sourceBytes);

      // Save to temp file
      final pngPath = path.join(
        tempDir.path,
        'page_${pageIndex}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      final pngFile = File(pngPath);
      await pngFile.writeAsBytes(pngBytes);

      return pngPath;
    } on Object catch (e) {
      if (e is ScannerException) rethrow;
      throw ScannerException(
        'Failed to convert page $pageIndex to PNG',
        cause: e,
      );
    }
  }

  /// Saves a scan result and returns the document directly.
  ///
  /// This is a convenience method that returns just the [Document]
  /// instead of a [SavedScanResult].
  ///
  /// Example:
  /// ```dart
  /// final document = await storageService.saveAndGetDocument(
  ///   scanResult,
  ///   title: 'Invoice',
  /// );
  /// ```
  Future<Document> saveAndGetDocument(
    ScanResult scanResult, {
    String? title,
    String? description,
    String? folderId,
    bool isFavorite = false,
    bool generateThumbnail = true,
    bool cleanupAfterSave = true,
  }) async {
    final result = await saveScanResult(
      scanResult,
      title: title,
      description: description,
      folderId: folderId,
      isFavorite: isFavorite,
      generateThumbnail: generateThumbnail,
      cleanupAfterSave: cleanupAfterSave,
    );
    return result.document;
  }

  /// Saves a quick scan result with automatic title generation.
  ///
  /// Optimized for the one-click scan workflow where the user
  /// wants to save quickly without entering details.
  ///
  /// Example:
  /// ```dart
  /// final result = await storageService.saveQuickScan(scanResult);
  /// ```
  Future<SavedScanResult> saveQuickScan(ScanResult scanResult) async {
    return saveScanResult(scanResult);
  }

  /// Checks if the storage service is ready for use.
  ///
  /// This verifies that the document repository is initialized
  /// and the encryption key is available.
  Future<bool> isReady() async {
    try {
      return await _documentRepository.isReady();
    } on Object catch (_) {
      return false;
    }
  }

  /// Initializes the storage service.
  ///
  /// This should be called during app startup to ensure:
  /// - The document repository is initialized
  /// - The encryption key is available
  ///
  /// Returns true if initialization was successful.
  Future<bool> initialize() async {
    try {
      return await _documentRepository.initialize();
    } on Object catch (_) {
      return false;
    }
  }

  /// Generates a default document title based on the current date/time.
  String _generateDefaultTitle() {
    final now = DateTime.now();
    final formatter = DateFormat('MMM d, yyyy HH:mm');
    return 'Scan ${formatter.format(now)}';
  }

  /// Generates a thumbnail from a scanned page.
  ///
  /// Returns the path to the generated thumbnail file, or null if
  /// thumbnail generation fails.
  Future<String?> _generateThumbnail(ScannedPage page) async {
    try {
      final sourceFile = File(page.imagePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      // Read the source image
      final bytes = await sourceFile.readAsBytes();

      // Use compute to offload heavy image processing to a background isolate
      final thumbnailBytes = await compute(_processThumbnailIsolate, {
        'bytes': bytes,
        'width': _thumbnailWidth,
        'quality': _thumbnailQuality,
      });

      // Save to a temporary file
      final tempDir = Directory.systemTemp;
      final thumbnailFile = File(
        '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await thumbnailFile.writeAsBytes(thumbnailBytes);

      return thumbnailFile.path;
    } on Object catch (_) {
      // Thumbnail generation is not critical - return null on failure
      return null;
    }
  }

  /// Cleans up temporary scan files.
  Future<void> _cleanupScanFiles(ScanResult scanResult) async {
    for (final page in scanResult.pages) {
      await _deleteTempFile(page.imagePath);
    }

    // Also clean up PDF if present
    if (scanResult.hasPdf) {
      await _deleteTempFile(scanResult.pdf!);
    }
  }

  /// Safely deletes a temporary file.
  Future<void> _deleteTempFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } on Object catch (_) {
      // Ignore deletion errors - file may already be deleted
    }
  }
}

/// Helper function for PNG conversion in background isolate.
Uint8List _processPngIsolate(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) throw Exception('Failed to decode scanned image');
  return img.encodePng(image);
}

/// Helper function for Thumbnail generation in background isolate.
Uint8List _processThumbnailIsolate(Map<String, dynamic> params) {
  final bytes = params['bytes'] as Uint8List;
  final width = params['width'] as int;
  final quality = params['quality'] as int;

  final image = img.decodeImage(bytes);
  if (image == null) throw Exception('Failed to decode image for thumbnail');

  final thumbnail = img.copyResize(
    image,
    width: width,
    interpolation: img.Interpolation.linear,
  );
  return img.encodeJpg(thumbnail, quality: quality);
}
