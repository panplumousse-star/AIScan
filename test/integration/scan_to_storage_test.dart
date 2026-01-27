import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:image/image.dart' as img;

import 'package:aiscan/core/security/encryption_service.dart';
import 'package:aiscan/core/security/secure_storage_service.dart';
import 'package:aiscan/core/storage/database_helper.dart';
import 'package:aiscan/core/storage/document_repository.dart';
import 'package:aiscan/features/documents/domain/document_model.dart';
import 'package:aiscan/features/scanner/domain/scanner_service.dart';

import 'scan_to_storage_test.mocks.dart';

/// Mock class for DocumentScanner from ML Kit.
class MockDocumentScanner extends Mock implements DocumentScanner {
  @override
  Future<DocumentScanningResult?> scanDocument() async {
    return super.noSuchMethod(
      Invocation.method(#scanDocument, []),
      returnValue: Future<DocumentScanningResult?>.value(),
      returnValueForMissingStub: Future<DocumentScanningResult?>.value(),
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

/// Mock class for DocumentScanningResult from ML Kit.
class MockDocumentScanningResult extends Mock
    implements DocumentScanningResult {
  MockDocumentScanningResult({this.mockImages = const [], this.mockPdf});

  final List<String> mockImages;
  final String? mockPdf;

  @override
  List<String> get images => mockImages;

  @override
  String? get pdf => mockPdf;
}

@GenerateMocks([
  SecureStorageService,
  EncryptionService,
  DatabaseHelper,
  DocumentRepository,
])
void main() {
  late MockDocumentScanner mockScanner;
  late MockSecureStorageService mockSecureStorage;
  late MockEncryptionService mockEncryption;
  late MockDatabaseHelper mockDatabase;
  late MockDocumentRepository mockRepository;
  late ScannerService scannerService;
  late ScannerStorageService storageService;

  // Test directories for temporary files
  late Directory testTempDir;

  // Test document
  final testDocument = Document(
    id: 'doc-123',
    title: 'Test Document',
    filePath: '/encrypted/doc.enc',
    thumbnailPath: '/encrypted/thumb.enc',
    originalFileName: 'scan.jpg',
    pageCount: 1,
    fileSize: 1024,
    mimeType: 'image/jpeg',
    createdAt: DateTime.parse('2026-01-11T10:00:00.000Z'),
    updatedAt: DateTime.parse('2026-01-11T10:00:00.000Z'),
  );

  /// Creates a test JPEG image file.
  Future<String> createTestImageFile(
    Directory dir,
    String name, {
    int width = 100,
    int height = 100,
  }) async {
    final image = img.Image(width: width, height: height);
    // Fill with a gradient for visual distinction
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        image.setPixelRgb(x, y, x * 255 ~/ width, y * 255 ~/ height, 128);
      }
    }
    final jpegBytes = img.encodeJpg(image, quality: 85);
    final filePath = '${dir.path}/$name';
    await File(filePath).writeAsBytes(jpegBytes);
    return filePath;
  }

  /// Creates multiple test image files.
  Future<List<String>> createTestImageFiles(
    Directory dir,
    int count, {
    String prefix = 'scan_page_',
  }) async {
    final paths = <String>[];
    for (int i = 0; i < count; i++) {
      final path = await createTestImageFile(dir, '$prefix$i.jpg');
      paths.add(path);
    }
    return paths;
  }

  setUpAll(() async {
    // Create a unique temp directory for test files
    testTempDir = await Directory.systemTemp.createTemp(
      'scan_to_storage_test_',
    );
  });

  tearDownAll(() async {
    // Clean up test directory
    if (await testTempDir.exists()) {
      await testTempDir.delete(recursive: true);
    }
  });

  setUp(() {
    mockScanner = MockDocumentScanner();
    mockSecureStorage = MockSecureStorageService();
    mockEncryption = MockEncryptionService();
    mockDatabase = MockDatabaseHelper();
    mockRepository = MockDocumentRepository();

    scannerService = ScannerService(scanner: mockScanner);
    storageService = ScannerStorageService(documentRepository: mockRepository);

    // Default mock behaviors
    when(mockRepository.isReady()).thenAnswer((_) async => true);
    when(mockRepository.initialize()).thenAnswer((_) async => true);
    when(
      mockRepository.createDocument(
        title: anyNamed('title'),
        sourceFilePath: anyNamed('sourceFilePath'),
        description: anyNamed('description'),
        thumbnailSourcePath: anyNamed('thumbnailSourcePath'),
        pageCount: anyNamed('pageCount'),
        folderId: anyNamed('folderId'),
        isFavorite: anyNamed('isFavorite'),
      ),
    ).thenAnswer((_) async => testDocument);
  });

  group('Scan-to-Storage Integration Flow', () {
    group('Complete Workflow Tests', () {
      test(
        'should complete full scan-to-storage workflow for single page',
        () async {
          // Arrange - Create test image file
          final testImagePath = await createTestImageFile(
            testTempDir,
            'single_scan.jpg',
          );

          final mlKitResult = MockDocumentScanningResult(
            mockImages: [testImagePath],
          );
          when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

          // Act - Scan document
          final scanResult = await scannerService.scanDocument();

          // Assert - Scan succeeded
          expect(scanResult, isNotNull);
          expect(scanResult!.pageCount, equals(1));
          expect(scanResult.pages.first.imagePath, equals(testImagePath));

          // Act - Save to storage (with generateThumbnail: false to avoid image processing)
          final savedResult = await storageService.saveScanResult(
            scanResult,
            title: 'Single Page Document',
            generateThumbnail: false,
          );

          // Assert - Save succeeded
          expect(savedResult.document, equals(testDocument));
          expect(savedResult.pagesProcessed, equals(1));

          // Verify repository was called with correct parameters
          verify(
            mockRepository.createDocument(
              title: 'Single Page Document',
              sourceFilePath: testImagePath,
              description: null,
              thumbnailSourcePath: null,
              pageCount: 1,
              folderId: null,
              isFavorite: false,
            ),
          ).called(1);
        },
      );

      test(
        'should complete full scan-to-storage workflow for multi-page document',
        () async {
          // Arrange - Create multiple test image files
          final testImagePaths = await createTestImageFiles(
            testTempDir,
            3,
            prefix: 'multi_page_',
          );

          final mlKitResult = MockDocumentScanningResult(
            mockImages: testImagePaths,
          );
          when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

          // Act - Scan document
          final scanResult = await scannerService.scanMultiPage(maxPages: 10);

          // Assert - Scan succeeded with all pages
          expect(scanResult, isNotNull);
          expect(scanResult!.pageCount, equals(3));

          // Act - Save to storage
          final savedResult = await storageService.saveScanResult(
            scanResult,
            title: 'Multi-Page Document',
            generateThumbnail: false,
          );

          // Assert - Save used correct page count
          expect(savedResult.pagesProcessed, equals(3));

          // Verify repository was called with correct page count
          verify(
            mockRepository.createDocument(
              title: 'Multi-Page Document',
              sourceFilePath: testImagePaths.first, // First page is primary
              description: null,
              thumbnailSourcePath: null,
              pageCount: 3,
              folderId: null,
              isFavorite: false,
            ),
          ).called(1);
        },
      );

      test('should complete single page scan workflow for one-click scan',
          () async {
        // Arrange - Create test image
        final testImagePath = await createTestImageFile(
          testTempDir,
          'single_page_scan.jpg',
        );

        final mlKitResult = MockDocumentScanningResult(
          mockImages: [testImagePath],
        );
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Act - Single page scan via domain service
        final scanResult = await scannerService.quickScan();

        // Assert - Scan succeeded
        expect(scanResult, isNotNull);
        expect(scanResult!.pageCount, equals(1));

        // Act - Save using single page save method
        final savedResult = await storageService.saveQuickScan(scanResult);

        // Assert - Save succeeded with auto-generated title
        expect(savedResult.document, isNotNull);

        // Verify repository was called (title will be auto-generated)
        verify(
          mockRepository.createDocument(
            title: anyNamed('title'),
            sourceFilePath: testImagePath,
            description: null,
            thumbnailSourcePath: anyNamed('thumbnailSourcePath'),
            pageCount: 1,
            folderId: null,
            isFavorite: false,
          ),
        ).called(1);
      });

      test(
        'should save document with metadata (description, folder, favorite)',
        () async {
          // Arrange
          final testImagePath = await createTestImageFile(
            testTempDir,
            'metadata_scan.jpg',
          );

          final mlKitResult = MockDocumentScanningResult(
            mockImages: [testImagePath],
          );
          when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

          // Act
          final scanResult = await scannerService.scanDocument();
          expect(scanResult, isNotNull);

          await storageService.saveScanResult(
            scanResult!,
            title: 'Important Document',
            description: 'Tax return 2025',
            folderId: 'folder-taxes',
            isFavorite: true,
            generateThumbnail: false,
          );

          // Assert - Verify all metadata was passed
          verify(
            mockRepository.createDocument(
              title: 'Important Document',
              sourceFilePath: testImagePath,
              description: 'Tax return 2025',
              thumbnailSourcePath: null,
              pageCount: 1,
              folderId: 'folder-taxes',
              isFavorite: true,
            ),
          ).called(1);
        },
      );

      test('should use saveAndGetDocument convenience method', () async {
        // Arrange
        final testImagePath = await createTestImageFile(
          testTempDir,
          'convenience_scan.jpg',
        );

        final mlKitResult = MockDocumentScanningResult(
          mockImages: [testImagePath],
        );
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Act
        final scanResult = await scannerService.scanDocument();
        expect(scanResult, isNotNull);

        final document = await storageService.saveAndGetDocument(
          scanResult!,
          title: 'Quick Access Document',
          generateThumbnail: false,
        );

        // Assert - Returns Document directly
        expect(document, equals(testDocument));
        expect(document.id, equals('doc-123'));
      });
    });

    group('Scan Result Validation', () {
      test('should validate scan result files exist before saving', () async {
        // Arrange - Create scan result with non-existent file
        final scanResult = ScanResult(
          pages: [ScannedPage(imagePath: '/nonexistent/file.jpg')],
        );

        // Act & Assert - Should throw because file doesn't exist
        expect(
          () => storageService.saveScanResult(scanResult),
          throwsA(
            isA<ScannerException>().having(
              (e) => e.message,
              'message',
              contains('No valid scan pages found'),
            ),
          ),
        );
      });

      test('should filter out invalid pages and save valid ones', () async {
        // Arrange - Mix of valid and invalid file paths
        final validImagePath = await createTestImageFile(
          testTempDir,
          'valid_scan.jpg',
        );

        final scanResult = ScanResult(
          pages: [
            ScannedPage(imagePath: '/nonexistent/invalid.jpg'),
            ScannedPage(imagePath: validImagePath),
            ScannedPage(imagePath: '/another/invalid.jpg'),
          ],
        );

        // Act
        final savedResult = await storageService.saveScanResult(
          scanResult,
          title: 'Partial Valid Document',
          generateThumbnail: false,
        );

        // Assert - Only valid page was processed
        expect(savedResult.pagesProcessed, equals(1));

        // Verify the valid file path was used
        verify(
          mockRepository.createDocument(
            title: 'Partial Valid Document',
            sourceFilePath: validImagePath,
            description: null,
            thumbnailSourcePath: null,
            pageCount: 1,
            folderId: null,
            isFavorite: false,
          ),
        ).called(1);
      });

      test('should reject empty scan result', () async {
        // Arrange
        const emptyScanResult = ScanResult(pages: []);

        // Act & Assert
        expect(
          () => storageService.saveScanResult(emptyScanResult),
          throwsA(
            isA<ScannerException>().having(
              (e) => e.message,
              'message',
              equals('Cannot save empty scan result'),
            ),
          ),
        );
      });
    });

    group('Scanner Service Methods', () {
      test('scanDocument should return scan result with pages', () async {
        // Arrange
        final testImagePath = await createTestImageFile(
          testTempDir,
          'scan_doc.jpg',
        );

        final mlKitResult = MockDocumentScanningResult(
          mockImages: [testImagePath],
        );
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Act
        final result = await scannerService.scanDocument();

        // Assert
        expect(result, isNotNull);
        expect(result!.pageCount, equals(1));
        expect(result.pages.first.imagePath, equals(testImagePath));
        verify(mockScanner.scanDocument()).called(1);
      });

      test('scanDocument should return null when user cancels', () async {
        // Arrange
        when(mockScanner.scanDocument()).thenAnswer((_) async => null);

        // Act
        final result = await scannerService.scanDocument();

        // Assert
        expect(result, isNull);
      });

      test('scanToPdf should return result with PDF path', () async {
        // Arrange
        final testImagePath = await createTestImageFile(
          testTempDir,
          'pdf_scan.jpg',
        );
        final testPdfPath = '${testTempDir.path}/output.pdf';
        // Create a placeholder PDF file
        await File(
          testPdfPath,
        ).writeAsBytes([0x25, 0x50, 0x44, 0x46]); // PDF header

        final mlKitResult = MockDocumentScanningResult(
          mockImages: [testImagePath],
          mockPdf: testPdfPath,
        );
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Act
        final result = await scannerService.scanToPdf();

        // Assert
        expect(result, isNotNull);
        expect(result!.hasPdf, isTrue);
        expect(result.pdf, equals(testPdfPath));
      });

      test('validateScanResult should return only existing files', () async {
        // Arrange
        final existingPath = await createTestImageFile(
          testTempDir,
          'existing.jpg',
        );

        final scanResult = ScanResult(
          pages: [
            ScannedPage(imagePath: existingPath),
            ScannedPage(imagePath: '/nonexistent.jpg'),
          ],
        );

        // Act
        final validPages = await scannerService.validateScanResult(scanResult);

        // Assert
        expect(validPages, hasLength(1));
        expect(validPages.first.imagePath, equals(existingPath));
      });

      test('cleanupScanResult should delete temporary scan files', () async {
        // Arrange - Create files that will be deleted
        final cleanupDir = await Directory(
          '${testTempDir.path}/cleanup',
        ).create();
        final imagePath1 = await createTestImageFile(
          cleanupDir,
          'to_delete_1.jpg',
        );
        final imagePath2 = await createTestImageFile(
          cleanupDir,
          'to_delete_2.jpg',
        );

        final scanResult = ScanResult(
          pages: [
            ScannedPage(imagePath: imagePath1),
            ScannedPage(imagePath: imagePath2),
          ],
        );

        // Verify files exist
        expect(await File(imagePath1).exists(), isTrue);
        expect(await File(imagePath2).exists(), isTrue);

        // Act
        final deletedCount = await scannerService.cleanupScanResult(scanResult);

        // Assert
        expect(deletedCount, equals(2));
        expect(await File(imagePath1).exists(), isFalse);
        expect(await File(imagePath2).exists(), isFalse);
      });
    });

    group('Error Handling', () {
      test('should handle scanner hardware error gracefully', () async {
        // Arrange
        when(
          mockScanner.scanDocument(),
        ).thenThrow(Exception('Camera unavailable'));

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

      test('should handle repository error during save', () async {
        // Arrange
        final testImagePath = await createTestImageFile(
          testTempDir,
          'repo_error.jpg',
        );

        when(
          mockRepository.createDocument(
            title: anyNamed('title'),
            sourceFilePath: anyNamed('sourceFilePath'),
            description: anyNamed('description'),
            thumbnailSourcePath: anyNamed('thumbnailSourcePath'),
            pageCount: anyNamed('pageCount'),
            folderId: anyNamed('folderId'),
            isFavorite: anyNamed('isFavorite'),
          ),
        ).thenThrow(const DocumentRepositoryException('Database error'));

        final scanResult = ScanResult(
          pages: [ScannedPage(imagePath: testImagePath)],
        );

        // Act & Assert
        expect(
          () => storageService.saveScanResult(
            scanResult,
            title: 'Error Test',
            generateThumbnail: false,
          ),
          throwsA(
            isA<ScannerException>().having(
              (e) => e.message,
              'message',
              contains('Failed to save scan result'),
            ),
          ),
        );
      });

      test('should handle file system errors during save', () async {
        // Arrange - Use a path that will fail (read-only or invalid)
        final testImagePath = await createTestImageFile(
          testTempDir,
          'fs_error.jpg',
        );

        when(
          mockRepository.createDocument(
            title: anyNamed('title'),
            sourceFilePath: anyNamed('sourceFilePath'),
            description: anyNamed('description'),
            thumbnailSourcePath: anyNamed('thumbnailSourcePath'),
            pageCount: anyNamed('pageCount'),
            folderId: anyNamed('folderId'),
            isFavorite: anyNamed('isFavorite'),
          ),
        ).thenThrow(const FileSystemException('Permission denied'));

        final scanResult = ScanResult(
          pages: [ScannedPage(imagePath: testImagePath)],
        );

        // Act & Assert
        expect(
          () => storageService.saveScanResult(
            scanResult,
            title: 'FS Error Test',
            generateThumbnail: false,
          ),
          throwsA(isA<ScannerException>()),
        );
      });

      test('should wrap ScannerException and rethrow', () async {
        // Arrange
        final testImagePath = await createTestImageFile(
          testTempDir,
          'scanner_ex.jpg',
        );

        when(
          mockRepository.createDocument(
            title: anyNamed('title'),
            sourceFilePath: anyNamed('sourceFilePath'),
            description: anyNamed('description'),
            thumbnailSourcePath: anyNamed('thumbnailSourcePath'),
            pageCount: anyNamed('pageCount'),
            folderId: anyNamed('folderId'),
            isFavorite: anyNamed('isFavorite'),
          ),
        ).thenThrow(const ScannerException('Custom scanner error'));

        final scanResult = ScanResult(
          pages: [ScannedPage(imagePath: testImagePath)],
        );

        // Act & Assert
        expect(
          () => storageService.saveScanResult(
            scanResult,
            title: 'Scanner Exception Test',
            generateThumbnail: false,
          ),
          throwsA(
            isA<ScannerException>().having(
              (e) => e.message,
              'message',
              equals('Custom scanner error'),
            ),
          ),
        );
      });
    });

    group('Storage Service State', () {
      test('isReady should return true when repository is ready', () async {
        // Arrange
        when(mockRepository.isReady()).thenAnswer((_) async => true);

        // Act
        final isReady = await storageService.isReady();

        // Assert
        expect(isReady, isTrue);
        verify(mockRepository.isReady()).called(1);
      });

      test(
        'isReady should return false when repository is not ready',
        () async {
          // Arrange
          when(mockRepository.isReady()).thenAnswer((_) async => false);

          // Act
          final isReady = await storageService.isReady();

          // Assert
          expect(isReady, isFalse);
        },
      );

      test('isReady should return false on repository error', () async {
        // Arrange
        when(mockRepository.isReady()).thenThrow(Exception('Connection error'));

        // Act
        final isReady = await storageService.isReady();

        // Assert
        expect(isReady, isFalse);
      });

      test('initialize should initialize repository', () async {
        // Arrange
        when(mockRepository.initialize()).thenAnswer((_) async => true);

        // Act
        final initialized = await storageService.initialize();

        // Assert
        expect(initialized, isTrue);
        verify(mockRepository.initialize()).called(1);
      });

      test('initialize should return false on error', () async {
        // Arrange
        when(mockRepository.initialize()).thenThrow(Exception('Init failed'));

        // Act
        final initialized = await storageService.initialize();

        // Assert
        expect(initialized, isFalse);
      });
    });

    group('Thumbnail Generation', () {
      test(
        'should save without thumbnail when generateThumbnail is false',
        () async {
          // Arrange
          final testImagePath = await createTestImageFile(
            testTempDir,
            'no_thumb.jpg',
          );

          final scanResult = ScanResult(
            pages: [ScannedPage(imagePath: testImagePath)],
          );

          // Act
          final savedResult = await storageService.saveScanResult(
            scanResult,
            title: 'No Thumbnail Document',
            generateThumbnail: false,
          );

          // Assert
          expect(savedResult.thumbnailGenerated, isFalse);

          // Verify thumbnailSourcePath was null
          verify(
            mockRepository.createDocument(
              title: 'No Thumbnail Document',
              sourceFilePath: testImagePath,
              description: null,
              thumbnailSourcePath: null,
              pageCount: 1,
              folderId: null,
              isFavorite: false,
            ),
          ).called(1);
        },
      );
    });

    group('Scanned Page Operations', () {
      test('ScannedPage.readBytes should return file contents', () async {
        // Arrange
        final imagePath = await createTestImageFile(
          testTempDir,
          'read_bytes.jpg',
        );
        final page = ScannedPage(imagePath: imagePath);

        // Act
        final bytes = await page.readBytes();

        // Assert
        expect(bytes, isNotEmpty);
        expect(bytes.length, greaterThan(0));
        // Should be valid JPEG (starts with FFD8)
        expect(bytes[0], equals(0xFF));
        expect(bytes[1], equals(0xD8));
      });

      test(
        'ScannedPage.readBytes should throw for non-existent file',
        () async {
          // Arrange
          final page = ScannedPage(imagePath: '/nonexistent/file.jpg');

          // Act & Assert
          expect(() => page.readBytes(), throwsA(isA<ScannerException>()));
        },
      );

      test('ScannedPage.exists should check file existence', () async {
        // Arrange
        final imagePath = await createTestImageFile(
          testTempDir,
          'exists_check.jpg',
        );
        final existingPage = ScannedPage(imagePath: imagePath);
        final nonExistingPage = ScannedPage(imagePath: '/nonexistent/file.jpg');

        // Act & Assert
        expect(await existingPage.exists(), isTrue);
        expect(await nonExistingPage.exists(), isFalse);
      });

      test('ScannedPage.getFileSize should return file size', () async {
        // Arrange
        final imagePath = await createTestImageFile(
          testTempDir,
          'file_size.jpg',
        );
        final page = ScannedPage(imagePath: imagePath);

        // Act
        final size = await page.getFileSize();

        // Assert
        expect(size, greaterThan(0));
      });

      test(
        'ScannedPage.getFileSize should return 0 for non-existent file',
        () async {
          // Arrange
          final page = ScannedPage(imagePath: '/nonexistent/file.jpg');

          // Act
          final size = await page.getFileSize();

          // Assert
          expect(size, equals(0));
        },
      );
    });

    group('ScanResult Operations', () {
      test('should provide imagePaths list', () async {
        // Arrange
        final path1 = await createTestImageFile(testTempDir, 'paths_1.jpg');
        final path2 = await createTestImageFile(testTempDir, 'paths_2.jpg');

        final result = ScanResult(
          pages: [
            ScannedPage(imagePath: path1),
            ScannedPage(imagePath: path2),
          ],
        );

        // Act
        final paths = result.imagePaths;

        // Assert
        expect(paths, hasLength(2));
        expect(paths, contains(path1));
        expect(paths, contains(path2));
      });

      test('should track PDF availability', () async {
        // Arrange
        final testImagePath = await createTestImageFile(
          testTempDir,
          'pdf_track.jpg',
        );
        final pdfPath = '${testTempDir.path}/track.pdf';

        final resultWithPdf = ScanResult(
          pages: [ScannedPage(imagePath: testImagePath)],
          pdf: pdfPath,
        );
        final resultWithoutPdf = ScanResult(
          pages: [ScannedPage(imagePath: testImagePath)],
        );

        // Assert
        expect(resultWithPdf.hasPdf, isTrue);
        expect(resultWithPdf.pdf, equals(pdfPath));
        expect(resultWithoutPdf.hasPdf, isFalse);
        expect(resultWithoutPdf.pdf, isNull);
      });

      test('should report isEmpty and isNotEmpty correctly', () {
        // Arrange
        const emptyResult = ScanResult(pages: []);
        final nonEmptyResult = ScanResult(
          pages: [ScannedPage(imagePath: '/test.jpg')],
        );

        // Assert
        expect(emptyResult.isEmpty, isTrue);
        expect(emptyResult.isNotEmpty, isFalse);
        expect(nonEmptyResult.isEmpty, isFalse);
        expect(nonEmptyResult.isNotEmpty, isTrue);
      });
    });

    group('Riverpod Provider Integration', () {
      test('scannerServiceProvider should provide ScannerService', () {
        // Arrange
        final container = ProviderContainer();

        // Act
        final service = container.read(scannerServiceProvider);

        // Assert
        expect(service, isA<ScannerService>());

        container.dispose();
      });

      test(
        'scannerStorageServiceProvider should provide ScannerStorageService',
        () {
          // Arrange
          final container = ProviderContainer();

          // Act
          final service = container.read(scannerStorageServiceProvider);

          // Assert
          expect(service, isA<ScannerStorageService>());

          container.dispose();
        },
      );
    });

    group('End-to-End Flow Scenarios', () {
      test('complete flow: scan -> validate -> save -> verify', () async {
        // Arrange - Create realistic multi-page scan
        final imageDir = await Directory(
          '${testTempDir.path}/e2e_scan',
        ).create();
        final imagePaths = await createTestImageFiles(
          imageDir,
          2,
          prefix: 'e2e_page_',
        );

        final mlKitResult = MockDocumentScanningResult(mockImages: imagePaths);
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Step 1: Scan
        final scanResult = await scannerService.scanDocument(
          options: const ScannerOptions.multiPage(maxPages: 10),
        );
        expect(scanResult, isNotNull);
        expect(scanResult!.pageCount, equals(2));

        // Step 2: Validate
        final validPages = await scannerService.validateScanResult(scanResult);
        expect(validPages, hasLength(2));

        // Step 3: Save
        final savedResult = await storageService.saveScanResult(
          scanResult,
          title: 'E2E Test Document',
          description: 'End-to-end test',
          generateThumbnail: false,
        );

        // Step 4: Verify
        expect(savedResult.document, isNotNull);
        expect(savedResult.pagesProcessed, equals(2));
        verify(
          mockRepository.createDocument(
            title: 'E2E Test Document',
            sourceFilePath: imagePaths.first,
            description: 'End-to-end test',
            thumbnailSourcePath: null,
            pageCount: 2,
            folderId: null,
            isFavorite: false,
          ),
        ).called(1);
      });

      test('workflow with PDF generation', () async {
        // Arrange
        final imageDir = await Directory(
          '${testTempDir.path}/pdf_e2e',
        ).create();
        final imagePath = await createTestImageFile(imageDir, 'pdf_e2e.jpg');
        final pdfPath = '${imageDir.path}/output.pdf';
        await File(
          pdfPath,
        ).writeAsBytes([0x25, 0x50, 0x44, 0x46]); // PDF header

        final mlKitResult = MockDocumentScanningResult(
          mockImages: [imagePath],
          mockPdf: pdfPath,
        );
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Act
        final scanResult = await scannerService.scanToPdf();

        // Assert
        expect(scanResult, isNotNull);
        expect(scanResult!.hasPdf, isTrue);
        expect(scanResult.pdf, equals(pdfPath));

        // Save
        final savedResult = await storageService.saveScanResult(
          scanResult,
          title: 'PDF Document',
          generateThumbnail: false,
        );
        expect(savedResult.document, isNotNull);
      });

      test('single page scan one-click workflow', () async {
        // Arrange
        final imagePath = await createTestImageFile(
          testTempDir,
          'one_click.jpg',
        );

        final mlKitResult = MockDocumentScanningResult(mockImages: [imagePath]);
        when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

        // Act - Single page scan via domain service
        final scanResult = await scannerService.quickScan();
        expect(scanResult, isNotNull);

        final savedResult = await storageService.saveQuickScan(scanResult!);

        // Assert - Auto-generated title used
        expect(savedResult.document, isNotNull);
        verify(
          mockRepository.createDocument(
            title: anyNamed('title'), // Auto-generated
            sourceFilePath: imagePath,
            description: null,
            thumbnailSourcePath: anyNamed('thumbnailSourcePath'),
            pageCount: 1,
            folderId: null,
            isFavorite: false,
          ),
        ).called(1);
      });

      test('workflow with cleanup after save', () async {
        // Arrange
        final cleanupDir = await Directory(
          '${testTempDir.path}/cleanup_e2e',
        ).create();
        final imagePath = await createTestImageFile(
          cleanupDir,
          'cleanup_test.jpg',
        );

        final scanResult = ScanResult(
          pages: [ScannedPage(imagePath: imagePath)],
        );

        // Verify file exists before save
        expect(await File(imagePath).exists(), isTrue);

        // Act - Save with cleanup enabled (default)
        await storageService.saveScanResult(
          scanResult,
          title: 'Cleanup Test',
          generateThumbnail: false,
        );

        // Assert - Note: The cleanup is done by the storage service
        // The mock repository doesn't actually cleanup, so file would still exist
        // In real integration, the file would be deleted after save
        // This tests that the flow doesn't throw
      });

      test('workflow preserves original file when cleanup disabled', () async {
        // Arrange
        final noCleanupDir = await Directory(
          '${testTempDir.path}/no_cleanup',
        ).create();
        final imagePath = await createTestImageFile(
          noCleanupDir,
          'no_cleanup.jpg',
        );

        final scanResult = ScanResult(
          pages: [ScannedPage(imagePath: imagePath)],
        );

        // Act - Save with cleanup disabled
        await storageService.saveScanResult(
          scanResult,
          title: 'No Cleanup Test',
          generateThumbnail: false,
          cleanupAfterSave: false,
        );

        // Assert - File should still exist since we're using mocks
        // In real scenario with cleanupAfterSave: false, file is preserved
        expect(await File(imagePath).exists(), isTrue);
      });
    });
  });

  group('Scanner Options Integration', () {
    test('single page scan options should limit to single page', () async {
      // Arrange
      final imagePath =
          await createTestImageFile(testTempDir, 'single_page_opt.jpg');

      final mlKitResult = MockDocumentScanningResult(mockImages: [imagePath]);
      when(mockScanner.scanDocument()).thenAnswer((_) async => mlKitResult);

      // Act
      const options = ScannerOptions.quickScan();

      // Assert
      expect(options.pageLimit, equals(1));
      expect(options.allowGalleryImport, isFalse);
      expect(options.documentFormat, equals(ScanDocumentFormat.jpeg));
    });

    test('multiPage options should allow multiple pages', () {
      // Act
      const options = ScannerOptions.multiPage(maxPages: 50);

      // Assert
      expect(options.pageLimit, equals(50));
      expect(options.allowGalleryImport, isTrue);
    });

    test('pdf options should set PDF format', () {
      // Act
      const options = ScannerOptions.pdf(maxPages: 25);

      // Assert
      expect(options.documentFormat, equals(ScanDocumentFormat.pdf));
      expect(options.pageLimit, equals(25));
    });

    test('toMlKitOptions should convert options correctly', () {
      // Arrange
      const options = ScannerOptions(
        documentFormat: ScanDocumentFormat.pdf,
        scannerMode: ScanMode.filter,
        pageLimit: 75,
        allowGalleryImport: false,
      );

      // Act
      final mlKitOptions = options.toMlKitOptions();

      // Assert
      expect(mlKitOptions.documentFormat, equals(DocumentFormat.pdf));
      expect(mlKitOptions.mode, equals(ScannerMode.filter));
      expect(mlKitOptions.pageLimit, equals(75));
      expect(mlKitOptions.isGalleryImport, isFalse);
    });
  });

  group('SavedScanResult Model', () {
    test('should create SavedScanResult with all properties', () {
      // Act
      final result = SavedScanResult(
        document: testDocument,
        pagesProcessed: 5,
        thumbnailGenerated: true,
      );

      // Assert
      expect(result.document, equals(testDocument));
      expect(result.pagesProcessed, equals(5));
      expect(result.thumbnailGenerated, isTrue);
    });

    test('should implement equality correctly', () {
      // Arrange
      final result1 = SavedScanResult(
        document: testDocument,
        pagesProcessed: 3,
        thumbnailGenerated: true,
      );
      final result2 = SavedScanResult(
        document: testDocument,
        pagesProcessed: 3,
        thumbnailGenerated: true,
      );
      final result3 = SavedScanResult(
        document: testDocument,
        pagesProcessed: 5,
        thumbnailGenerated: true,
      );

      // Assert
      expect(result1, equals(result2));
      expect(result1.hashCode, equals(result2.hashCode));
      expect(result1, isNot(equals(result3)));
    });

    test('toString should include relevant info', () {
      // Arrange
      final result = SavedScanResult(
        document: testDocument,
        pagesProcessed: 3,
        thumbnailGenerated: true,
      );

      // Act
      final str = result.toString();

      // Assert
      expect(str, contains('document: doc-123'));
      expect(str, contains('pages: 3'));
      expect(str, contains('thumbnail: true'));
    });
  });
}
