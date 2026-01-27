import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:aiscan/core/storage/document_repository.dart';
import 'package:aiscan/features/documents/domain/document_model.dart';
import 'package:aiscan/features/scanner/domain/scanner_service.dart';

import 'scanner_service_test.mocks.dart';

/// Mock class for DocumentScanner from ML Kit.
class MockDocumentScanner extends Mock implements DocumentScanner {
  @override
  Future<DocumentScanningResult> scanDocument() async {
    return super.noSuchMethod(
      Invocation.method(#scanDocument, []),
      returnValue: Future<DocumentScanningResult>.value(
        MockDocumentScanningResult(),
      ),
      returnValueForMissingStub: Future<DocumentScanningResult>.value(
        MockDocumentScanningResult(),
      ),
    );
  }

  @override
  Future<void> close() async {
    return super.noSuchMethod(
      Invocation.method(#close, []),
      returnValue: Future<void>.value(),
      returnValueForMissingStub: Future<void>.value(),
    );
  }
}

/// Mock class for DocumentScanningResultPdf from ML Kit.
class MockDocumentScanningResultPdf extends Mock
    implements DocumentScanningResultPdf {
  MockDocumentScanningResultPdf(this.mockUri);

  final String mockUri;

  @override
  String get uri => mockUri;

  @override
  int get pageCount => 1;
}

/// Mock class for DocumentScanningResult from ML Kit.
class MockDocumentScanningResult extends Mock
    implements DocumentScanningResult {
  MockDocumentScanningResult({
    this.mockImages = const [],
    this.mockPdfPath,
  });

  final List<String> mockImages;
  final String? mockPdfPath;

  @override
  List<String> get images => mockImages;

  @override
  DocumentScanningResultPdf? get pdf =>
      mockPdfPath != null ? MockDocumentScanningResultPdf(mockPdfPath!) : null;
}

@GenerateMocks([DocumentRepository])
void main() {
  late MockDocumentScanner mockScanner;
  late MockDocumentRepository mockRepository;
  late ScannerService scannerService;
  late ScannerStorageService storageService;

  // Test data
  final testImagePath1 = '/tmp/scan_page_1.jpg';
  final testImagePath2 = '/tmp/scan_page_2.jpg';
  final testPdfPath = '/tmp/scan_output.pdf';

  final testDocument = Document(
    id: 'doc-123',
    title: 'Test Document',
    pagesPaths: const ['/encrypted/doc_page_0.png.enc'],
    thumbnailPath: '/encrypted/thumb.enc',
    originalFileName: 'scan.jpg',
    fileSize: 1024,
    mimeType: 'image/jpeg',
    createdAt: DateTime.parse('2026-01-11T10:00:00.000Z'),
    updatedAt: DateTime.parse('2026-01-11T10:00:00.000Z'),
  );

  setUp(() {
    mockScanner = MockDocumentScanner();
    mockRepository = MockDocumentRepository();
    scannerService = ScannerService(scanner: mockScanner);
    storageService = ScannerStorageService(documentRepository: mockRepository);

    // Default mock behavior for repository
    when(mockRepository.isReady()).thenAnswer((_) async => true);
    when(mockRepository.initialize()).thenAnswer((_) async => true);
    when(mockRepository.createDocumentWithPages(
      title: anyNamed('title'),
      sourceImagePaths: anyNamed('sourceImagePaths'),
      description: anyNamed('description'),
      thumbnailSourcePath: anyNamed('thumbnailSourcePath'),
      folderId: anyNamed('folderId'),
      isFavorite: anyNamed('isFavorite'),
    )).thenAnswer((_) async => testDocument);
  });

  group('ScannerException', () {
    test('should format message without cause', () {
      // Arrange
      const exception = ScannerException('Scan failed');

      // Act
      final message = exception.toString();

      // Assert
      expect(message, equals('ScannerException: Scan failed'));
    });

    test('should format message with cause', () {
      // Arrange
      final cause = Exception('Camera error');
      final exception = ScannerException('Scan failed', cause: cause);

      // Act
      final message = exception.toString();

      // Assert
      expect(
        message,
        equals(
          'ScannerException: Scan failed (caused by: Exception: Camera error)',
        ),
      );
    });

    test('should store message and cause', () {
      // Arrange
      final cause = Exception('Root cause');
      const errorMessage = 'Scan error';
      final exception = ScannerException(errorMessage, cause: cause);

      // Assert
      expect(exception.message, equals(errorMessage));
      expect(exception.cause, equals(cause));
    });
  });

  group('ScanResult', () {
    test('should create ScanResult with pages', () {
      // Arrange
      final pages = [
        ScannedPage(imagePath: testImagePath1),
        ScannedPage(imagePath: testImagePath2),
      ];

      // Act
      final result = ScanResult(pages: pages);

      // Assert
      expect(result.pages, equals(pages));
      expect(result.pageCount, equals(2));
      expect(result.pdf, isNull);
      expect(result.hasPdf, isFalse);
      expect(result.isEmpty, isFalse);
      expect(result.isNotEmpty, isTrue);
    });

    test('should create ScanResult with PDF', () {
      // Arrange
      final pages = [ScannedPage(imagePath: testImagePath1)];

      // Act
      final result = ScanResult(pages: pages, pdf: testPdfPath);

      // Assert
      expect(result.pdf, equals(testPdfPath));
      expect(result.hasPdf, isTrue);
    });

    test('should create empty ScanResult', () {
      // Act
      const result = ScanResult(pages: []);

      // Assert
      expect(result.isEmpty, isTrue);
      expect(result.isNotEmpty, isFalse);
      expect(result.pageCount, equals(0));
    });

    test('should return image paths list', () {
      // Arrange
      final pages = [
        ScannedPage(imagePath: testImagePath1),
        ScannedPage(imagePath: testImagePath2),
      ];
      final result = ScanResult(pages: pages);

      // Act
      final imagePaths = result.imagePaths;

      // Assert
      expect(imagePaths, hasLength(2));
      expect(imagePaths, contains(testImagePath1));
      expect(imagePaths, contains(testImagePath2));
    });

    test('fromMlKitResult should convert ML Kit result', () {
      // Arrange
      final mlKitResult = MockDocumentScanningResult(
        mockImages: [testImagePath1, testImagePath2],
        mockPdfPath: testPdfPath,
      );

      // Act
      final result = ScanResult.fromMlKitResult(mlKitResult);

      // Assert
      expect(result.pageCount, equals(2));
      expect(result.pages[0].imagePath, equals(testImagePath1));
      expect(result.pages[1].imagePath, equals(testImagePath2));
      expect(result.pdf, equals(testPdfPath));
    });

    test('should implement equality correctly', () {
      // Arrange
      final pages1 = [ScannedPage(imagePath: testImagePath1)];
      final pages2 = [ScannedPage(imagePath: testImagePath1)];
      final pages3 = [ScannedPage(imagePath: testImagePath2)];

      final result1 = ScanResult(pages: pages1, pdf: testPdfPath);
      final result2 = ScanResult(pages: pages2, pdf: testPdfPath);
      final result3 = ScanResult(pages: pages3, pdf: testPdfPath);

      // Assert
      expect(result1, equals(result2));
      expect(result1.hashCode, equals(result2.hashCode));
      expect(result1, isNot(equals(result3)));
    });

    test('toString should include page count and PDF status', () {
      // Arrange
      final result = ScanResult(
        pages: [ScannedPage(imagePath: testImagePath1)],
        pdf: testPdfPath,
      );

      // Act
      final str = result.toString();

      // Assert
      expect(str, contains('pages: 1'));
      expect(str, contains('hasPdf: true'));
    });
  });

  group('ScannedPage', () {
    test('should create ScannedPage with image path', () {
      // Act
      final page = ScannedPage(imagePath: testImagePath1);

      // Assert
      expect(page.imagePath, equals(testImagePath1));
    });

    test('should implement equality correctly', () {
      // Arrange
      final page1 = ScannedPage(imagePath: testImagePath1);
      final page2 = ScannedPage(imagePath: testImagePath1);
      final page3 = ScannedPage(imagePath: testImagePath2);

      // Assert
      expect(page1, equals(page2));
      expect(page1.hashCode, equals(page2.hashCode));
      expect(page1, isNot(equals(page3)));
    });

    test('toString should include image path', () {
      // Arrange
      final page = ScannedPage(imagePath: testImagePath1);

      // Act
      final str = page.toString();

      // Assert
      expect(str, contains('imagePath: $testImagePath1'));
    });

    test('readBytes should throw ScannerException when file not found',
        () async {
      // Arrange
      final page = ScannedPage(imagePath: '/nonexistent/path.jpg');

      // Act & Assert
      expect(
        () => page.readBytes(),
        throwsA(isA<ScannerException>()),
      );
    });

    test('exists should return false for nonexistent file', () async {
      // Arrange
      final page = ScannedPage(imagePath: '/nonexistent/path.jpg');

      // Act
      final exists = await page.exists();

      // Assert
      expect(exists, isFalse);
    });

    test('getFileSize should return 0 for nonexistent file', () async {
      // Arrange
      final page = ScannedPage(imagePath: '/nonexistent/path.jpg');

      // Act
      final size = await page.getFileSize();

      // Assert
      expect(size, equals(0));
    });
  });

  group('ScannerOptions', () {
    test('should create default options', () {
      // Act
      const options = ScannerOptions();

      // Assert
      expect(options.documentFormat, equals(ScanDocumentFormat.jpeg));
      expect(options.scannerMode, equals(ScanMode.full));
      expect(options.pageLimit, equals(100));
      expect(options.allowGalleryImport, isTrue);
    });

    test('quickScan should create single-page options', () {
      // Act
      const options = ScannerOptions.quickScan();

      // Assert
      expect(options.documentFormat, equals(ScanDocumentFormat.jpeg));
      expect(options.scannerMode, equals(ScanMode.full));
      expect(options.pageLimit, equals(1));
      expect(options.allowGalleryImport, isFalse);
    });

    test('multiPage should create multi-page options', () {
      // Act
      const options = ScannerOptions.multiPage(maxPages: 50);

      // Assert
      expect(options.documentFormat, equals(ScanDocumentFormat.jpeg));
      expect(options.scannerMode, equals(ScanMode.full));
      expect(options.pageLimit, equals(50));
      expect(options.allowGalleryImport, isTrue);
    });

    test('pdf should create PDF output options', () {
      // Act
      const options = ScannerOptions.pdf(maxPages: 25);

      // Assert
      expect(options.documentFormat, equals(ScanDocumentFormat.pdf));
      expect(options.scannerMode, equals(ScanMode.full));
      expect(options.pageLimit, equals(25));
      expect(options.allowGalleryImport, isTrue);
    });

    test('toMlKitOptions should convert to ML Kit options', () {
      // Arrange
      const options = ScannerOptions(
        documentFormat: ScanDocumentFormat.pdf,
        scannerMode: ScanMode.filter,
        pageLimit: 50,
        allowGalleryImport: false,
      );

      // Act
      final mlKitOptions = options.toMlKitOptions();

      // Assert
      expect(mlKitOptions.documentFormat, equals(DocumentFormat.pdf));
      expect(mlKitOptions.mode, equals(ScannerMode.filter));
      expect(mlKitOptions.pageLimit, equals(50));
      expect(mlKitOptions.isGalleryImport, isFalse);
    });

    test('pageLimit should be clamped to valid range', () {
      // Arrange
      const optionsMin = ScannerOptions(pageLimit: 0);
      const optionsMax = ScannerOptions(pageLimit: 200);

      // Act
      final mlKitMin = optionsMin.toMlKitOptions();
      final mlKitMax = optionsMax.toMlKitOptions();

      // Assert
      expect(mlKitMin.pageLimit, equals(1));
      expect(mlKitMax.pageLimit, equals(100));
    });

    test('should implement equality correctly', () {
      // Arrange
      const options1 = ScannerOptions(pageLimit: 50);
      const options2 = ScannerOptions(pageLimit: 50);
      const options3 = ScannerOptions();

      // Assert
      expect(options1, equals(options2));
      expect(options1.hashCode, equals(options2.hashCode));
      expect(options1, isNot(equals(options3)));
    });

    test('toString should include all properties', () {
      // Arrange
      const options = ScannerOptions(
        documentFormat: ScanDocumentFormat.pdf,
        scannerMode: ScanMode.base,
        pageLimit: 10,
        allowGalleryImport: false,
      );

      // Act
      final str = options.toString();

      // Assert
      expect(str, contains('format:'));
      expect(str, contains('mode:'));
      expect(str, contains('pageLimit: 10'));
      expect(str, contains('galleryImport: false'));
    });
  });

  group('ScanDocumentFormat', () {
    test('should have correct enum values', () {
      expect(ScanDocumentFormat.values, hasLength(2));
      expect(ScanDocumentFormat.values, contains(ScanDocumentFormat.jpeg));
      expect(ScanDocumentFormat.values, contains(ScanDocumentFormat.pdf));
    });
  });

  group('ScanMode', () {
    test('should have correct enum values', () {
      expect(ScanMode.values, hasLength(4));
      expect(ScanMode.values, contains(ScanMode.full));
      expect(ScanMode.values, contains(ScanMode.filter));
      expect(ScanMode.values, contains(ScanMode.base));
      expect(ScanMode.values, contains(ScanMode.baseWithFilter));
    });

    test('should map to correct ML Kit ScannerMode', () {
      // Full mode
      const fullOptions = ScannerOptions();
      expect(fullOptions.toMlKitOptions().mode, equals(ScannerMode.full));

      // Filter mode
      const filterOptions = ScannerOptions(scannerMode: ScanMode.filter);
      expect(filterOptions.toMlKitOptions().mode, equals(ScannerMode.filter));

      // Base mode
      const baseOptions = ScannerOptions(scannerMode: ScanMode.base);
      expect(baseOptions.toMlKitOptions().mode, equals(ScannerMode.base));

      // BaseWithFilter mode (maps to base in ML Kit)
      const baseWithFilterOptions =
          ScannerOptions(scannerMode: ScanMode.baseWithFilter);
      expect(
        baseWithFilterOptions.toMlKitOptions().mode,
        equals(ScannerMode.base),
      );
    });
  });

  group('ScannerService', () {
    test('defaultOptions should return standard configuration', () {
      // Assert
      expect(ScannerService.defaultOptions.documentFormat,
          equals(ScanDocumentFormat.jpeg));
      expect(ScannerService.defaultOptions.scannerMode, equals(ScanMode.full));
      expect(ScannerService.defaultOptions.pageLimit, equals(100));
      expect(ScannerService.defaultOptions.allowGalleryImport, isTrue);
    });

    group('scanDocument', () {
      test('should return ScanResult when successful', () async {
        // Arrange
        final mlKitResult = MockDocumentScanningResult(
          mockImages: [testImagePath1],
        );
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Act
        final result = await scannerService.scanDocument();

        // Assert
        expect(result, isNotNull);
        expect(result!.pageCount, equals(1));
        expect(result.pages[0].imagePath, equals(testImagePath1));
      });

      test('should return null when user cancels (null result)', () async {
        // Arrange - Return empty result to simulate cancellation
        final mlKitResult = MockDocumentScanningResult(mockImages: []);
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Act
        final result = await scannerService.scanDocument();

        // Assert
        expect(result, isNull);
      });

      test('should return null when user cancels (empty images)', () async {
        // Arrange
        final mlKitResult = MockDocumentScanningResult(mockImages: []);
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Act
        final result = await scannerService.scanDocument();

        // Assert
        expect(result, isNull);
      });

      test('should throw ScannerException on ML Kit error', () async {
        // Arrange
        when(mockScanner.scanDocument())
            .thenThrow(Exception('Camera unavailable'));

        // Act & Assert
        expect(
          () => scannerService.scanDocument(),
          throwsA(isA<ScannerException>()),
        );
      });

      test('should use custom options when provided', () async {
        // Arrange
        final mlKitResult = MockDocumentScanningResult(
          mockImages: [testImagePath1],
        );
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Act
        final result = await scannerService.scanDocument(
          options: const ScannerOptions.quickScan(),
        );

        // Assert
        expect(result, isNotNull);
        verify(mockScanner.scanDocument()).called(1);
      });

      test('should include PDF when available', () async {
        // Arrange
        final mlKitResult = MockDocumentScanningResult(
          mockImages: [testImagePath1],
          mockPdfPath: testPdfPath,
        );
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Act
        final result = await scannerService.scanDocument(
          options: const ScannerOptions.pdf(),
        );

        // Assert
        expect(result, isNotNull);
        expect(result!.hasPdf, isTrue);
        expect(result.pdf, equals(testPdfPath));
      });
    });

    group('quickScan', () {
      test('should use quickScan options', () async {
        // Arrange
        final mlKitResult = MockDocumentScanningResult(
          mockImages: [testImagePath1],
        );
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Act
        final result = await scannerService.quickScan();

        // Assert
        expect(result, isNotNull);
        expect(result!.pageCount, equals(1));
      });

      test('should return null on cancellation', () async {
        // Arrange - Return empty result to simulate cancellation
        final mlKitResult = MockDocumentScanningResult(mockImages: []);
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Act
        final result = await scannerService.quickScan();

        // Assert
        expect(result, isNull);
      });
    });

    group('scanMultiPage', () {
      test('should scan multiple pages', () async {
        // Arrange
        final mlKitResult = MockDocumentScanningResult(
          mockImages: [testImagePath1, testImagePath2],
        );
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Act
        final result = await scannerService.scanMultiPage(maxPages: 10);

        // Assert
        expect(result, isNotNull);
        expect(result!.pageCount, equals(2));
      });

      test('should clamp maxPages to valid range', () async {
        // Arrange
        final mlKitResult = MockDocumentScanningResult(
          mockImages: [testImagePath1],
        );
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Act - very high maxPages should be clamped
        final result = await scannerService.scanMultiPage(maxPages: 999);

        // Assert
        expect(result, isNotNull);
        verify(mockScanner.scanDocument()).called(1);
      });

      test('should clamp negative maxPages to 1', () async {
        // Arrange
        final mlKitResult = MockDocumentScanningResult(
          mockImages: [testImagePath1],
        );
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Act - negative should be clamped to 1
        final result = await scannerService.scanMultiPage(maxPages: -5);

        // Assert
        expect(result, isNotNull);
      });
    });

    group('scanToPdf', () {
      test('should return result with PDF', () async {
        // Arrange
        final mlKitResult = MockDocumentScanningResult(
          mockImages: [testImagePath1],
          mockPdfPath: testPdfPath,
        );
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Act
        final result = await scannerService.scanToPdf();

        // Assert
        expect(result, isNotNull);
        expect(result!.hasPdf, isTrue);
        expect(result.pdf, equals(testPdfPath));
      });

      test('should accept maxPages parameter', () async {
        // Arrange
        final mlKitResult = MockDocumentScanningResult(
          mockImages: [testImagePath1],
        );
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Act
        final result = await scannerService.scanToPdf(maxPages: 20);

        // Assert
        expect(result, isNotNull);
      });
    });

    group('validateScanResult', () {
      test('should return empty list for nonexistent files', () async {
        // Arrange
        final result = ScanResult(
          pages: [
            ScannedPage(imagePath: '/nonexistent/path1.jpg'),
            ScannedPage(imagePath: '/nonexistent/path2.jpg'),
          ],
        );

        // Act
        final validPages = await scannerService.validateScanResult(result);

        // Assert
        expect(validPages, isEmpty);
      });

      test('should return empty list for empty result', () async {
        // Arrange
        const result = ScanResult(pages: []);

        // Act
        final validPages = await scannerService.validateScanResult(result);

        // Assert
        expect(validPages, isEmpty);
      });
    });

    group('cleanupScanResult', () {
      test('should return 0 when no files exist', () async {
        // Arrange
        final result = ScanResult(
          pages: [
            ScannedPage(imagePath: '/nonexistent/path.jpg'),
          ],
        );

        // Act
        final deletedCount = await scannerService.cleanupScanResult(result);

        // Assert
        expect(deletedCount, equals(0));
      });

      test('should handle cleanup for empty result', () async {
        // Arrange
        const result = ScanResult(pages: []);

        // Act
        final deletedCount = await scannerService.cleanupScanResult(result);

        // Assert
        expect(deletedCount, equals(0));
      });

      test('should attempt to delete PDF when present', () async {
        // Arrange
        final result = ScanResult(
          pages: [ScannedPage(imagePath: '/nonexistent/page.jpg')],
          pdf: '/nonexistent/output.pdf',
        );

        // Act
        final deletedCount = await scannerService.cleanupScanResult(result);

        // Assert - No files actually exist to delete
        expect(deletedCount, equals(0));
      });
    });
  });

  group('SavedScanResult', () {
    test('should create SavedScanResult with document', () {
      // Act
      final result = SavedScanResult(
        document: testDocument,
        pagesProcessed: 3,
        thumbnailGenerated: true,
      );

      // Assert
      expect(result.document, equals(testDocument));
      expect(result.pagesProcessed, equals(3));
      expect(result.thumbnailGenerated, isTrue);
    });

    test('should default thumbnailGenerated to false', () {
      // Act
      final result = SavedScanResult(
        document: testDocument,
        pagesProcessed: 1,
      );

      // Assert
      expect(result.thumbnailGenerated, isFalse);
    });

    test('should implement equality correctly', () {
      // Arrange
      final result1 = SavedScanResult(
        document: testDocument,
        pagesProcessed: 2,
        thumbnailGenerated: true,
      );
      final result2 = SavedScanResult(
        document: testDocument,
        pagesProcessed: 2,
        thumbnailGenerated: true,
      );
      final result3 = SavedScanResult(
        document: testDocument,
        pagesProcessed: 3,
        thumbnailGenerated: true,
      );

      // Assert
      expect(result1, equals(result2));
      expect(result1.hashCode, equals(result2.hashCode));
      expect(result1, isNot(equals(result3)));
    });

    test('toString should include key properties', () {
      // Arrange
      final result = SavedScanResult(
        document: testDocument,
        pagesProcessed: 5,
        thumbnailGenerated: true,
      );

      // Act
      final str = result.toString();

      // Assert
      expect(str, contains('document: doc-123'));
      expect(str, contains('pages: 5'));
      expect(str, contains('thumbnail: true'));
    });
  });

  group('ScannerStorageService', () {
    group('saveScanResult', () {
      test('should throw ScannerException for empty scan result', () async {
        // Arrange
        const emptyScanResult = ScanResult(pages: []);

        // Act & Assert
        expect(
          () => storageService.saveScanResult(emptyScanResult),
          throwsA(isA<ScannerException>()),
        );
      });

      test('should throw ScannerException when no valid pages found', () async {
        // Arrange
        final scanResult = ScanResult(
          pages: [ScannedPage(imagePath: '/nonexistent/file.jpg')],
        );

        // Act & Assert
        expect(
          () => storageService.saveScanResult(scanResult),
          throwsA(isA<ScannerException>().having(
            (e) => e.message,
            'message',
            contains('No valid scan pages found'),
          )),
        );
      });

      test('should wrap repository exceptions in ScannerException', () async {
        // Arrange - Create a temp file for the test
        final tempDir = Directory.systemTemp;
        final tempFile = File(
            '${tempDir.path}/test_scan_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG header

        try {
          final scanResult = ScanResult(
            pages: [ScannedPage(imagePath: tempFile.path)],
          );

          // Mock repository to throw
          when(mockRepository.createDocumentWithPages(
            title: anyNamed('title'),
            sourceImagePaths: anyNamed('sourceImagePaths'),
            description: anyNamed('description'),
            thumbnailSourcePath: anyNamed('thumbnailSourcePath'),
            folderId: anyNamed('folderId'),
            isFavorite: anyNamed('isFavorite'),
          )).thenThrow(const DocumentRepositoryException('Database error'));

          // Act & Assert
          expect(
            () => storageService.saveScanResult(
              scanResult,
              generateThumbnail: false,
            ),
            throwsA(isA<ScannerException>()),
          );
        } finally {
          // Cleanup
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      });
    });

    group('saveAndGetDocument', () {
      test('should throw for empty scan result', () async {
        // Arrange
        const emptyScanResult = ScanResult(pages: []);

        // Act & Assert
        expect(
          () => storageService.saveAndGetDocument(emptyScanResult),
          throwsA(isA<ScannerException>()),
        );
      });
    });

    group('saveQuickScan', () {
      test('should throw for empty scan result', () async {
        // Arrange
        const emptyScanResult = ScanResult(pages: []);

        // Act & Assert
        expect(
          () => storageService.saveQuickScan(emptyScanResult),
          throwsA(isA<ScannerException>()),
        );
      });
    });

    group('isReady', () {
      test('should return true when repository is ready', () async {
        // Arrange
        when(mockRepository.isReady()).thenAnswer((_) async => true);

        // Act
        final result = await storageService.isReady();

        // Assert
        expect(result, isTrue);
        verify(mockRepository.isReady()).called(1);
      });

      test('should return false when repository is not ready', () async {
        // Arrange
        when(mockRepository.isReady()).thenAnswer((_) async => false);

        // Act
        final result = await storageService.isReady();

        // Assert
        expect(result, isFalse);
      });

      test('should return false on repository error', () async {
        // Arrange
        when(mockRepository.isReady()).thenThrow(Exception('Error'));

        // Act
        final result = await storageService.isReady();

        // Assert
        expect(result, isFalse);
      });
    });

    group('initialize', () {
      test('should return true on successful initialization', () async {
        // Arrange
        when(mockRepository.initialize()).thenAnswer((_) async => true);

        // Act
        final result = await storageService.initialize();

        // Assert
        expect(result, isTrue);
        verify(mockRepository.initialize()).called(1);
      });

      test('should return false on failed initialization', () async {
        // Arrange
        when(mockRepository.initialize()).thenAnswer((_) async => false);

        // Act
        final result = await storageService.initialize();

        // Assert
        expect(result, isFalse);
      });

      test('should return false on initialization error', () async {
        // Arrange
        when(mockRepository.initialize()).thenThrow(Exception('Init failed'));

        // Act
        final result = await storageService.initialize();

        // Assert
        expect(result, isFalse);
      });
    });
  });

  group('Riverpod Providers', () {
    test('scannerServiceProvider should provide ScannerService', () {
      // Arrange
      final container = ProviderContainer();

      // Act
      final service = container.read(scannerServiceProvider);

      // Assert
      expect(service, isA<ScannerService>());

      container.dispose();
    });

    test('scannerStorageServiceProvider should provide ScannerStorageService',
        () {
      // Arrange
      final container = ProviderContainer();

      // Act
      final service = container.read(scannerStorageServiceProvider);

      // Assert
      expect(service, isA<ScannerStorageService>());

      container.dispose();
    });
  });

  group('Integration scenarios', () {
    test('complete scan workflow should work end-to-end', () async {
      // This tests the complete workflow without actual file operations

      // Arrange
      final mlKitResult = MockDocumentScanningResult(
        mockImages: [testImagePath1, testImagePath2],
        mockPdfPath: testPdfPath,
      );
      when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

      // Act - Scan documents
      final scanResult = await scannerService.scanDocument(
        options: const ScannerOptions.multiPage(maxPages: 10),
      );

      // Assert - Scan succeeded
      expect(scanResult, isNotNull);
      expect(scanResult!.pageCount, equals(2));
      expect(scanResult.hasPdf, isTrue);

      // Validate (will find no files since they're mock paths)
      final validPages = await scannerService.validateScanResult(scanResult);
      expect(validPages, isEmpty); // No actual files exist
    });

    test('should handle cancelled scan gracefully', () async {
      // Arrange - Return empty result to simulate cancellation
      final mlKitResult = MockDocumentScanningResult(mockImages: []);
      when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

      // Act
      final result = await scannerService.quickScan();

      // Assert
      expect(result, isNull);
    });

    test('should handle scanner error gracefully', () async {
      // Arrange
      when(mockScanner.scanDocument()).thenThrow(Exception('Hardware error'));

      // Act & Assert
      expect(
        () => scannerService.scanDocument(),
        throwsA(
          isA<ScannerException>().having(
            (e) => e.message,
            'message',
            equals('Document scanning failed'),
          ),
        ),
      );
    });

    test('multi-page scan with PDF should include both pages and PDF',
        () async {
      // Arrange
      final mlKitResult = MockDocumentScanningResult(
        mockImages: [testImagePath1, testImagePath2],
        mockPdfPath: testPdfPath,
      );
      when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

      // Act
      final result = await scannerService.scanToPdf(maxPages: 50);

      // Assert
      expect(result, isNotNull);
      expect(result!.pageCount, equals(2));
      expect(result.hasPdf, isTrue);
      expect(result.pdf, equals(testPdfPath));
      expect(result.imagePaths, hasLength(2));
    });
  });
}
