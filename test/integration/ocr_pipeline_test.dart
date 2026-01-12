import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:aiscan/core/storage/database_helper.dart';
import 'package:aiscan/core/storage/document_repository.dart';
import 'package:aiscan/features/documents/domain/document_model.dart';
import 'package:aiscan/features/ocr/domain/ocr_service.dart';
import 'package:aiscan/features/search/domain/search_service.dart';

import 'ocr_pipeline_test.mocks.dart';

@GenerateMocks([
  OcrService,
  DocumentRepository,
  DatabaseHelper,
  SearchService,
])
void main() {
  late MockOcrService mockOcrService;
  late MockDocumentRepository mockDocumentRepository;
  late MockDatabaseHelper mockDatabaseHelper;
  late MockSearchService mockSearchService;

  // Test directories for temporary files
  late Directory testTempDir;

  // Test documents
  final testDocument = Document(
    id: 'doc-ocr-001',
    title: 'OCR Test Document',
    filePath: '/encrypted/ocr_doc.enc',
    thumbnailPath: '/encrypted/ocr_thumb.enc',
    originalFileName: 'ocr_test.jpg',
    pageCount: 1,
    fileSize: 2048,
    mimeType: 'image/jpeg',
    ocrStatus: OcrStatus.pending,
    createdAt: DateTime.parse('2026-01-11T10:00:00.000Z'),
    updatedAt: DateTime.parse('2026-01-11T10:00:00.000Z'),
  );

  final testDocumentWithOcr = Document(
    id: 'doc-ocr-001',
    title: 'OCR Test Document',
    filePath: '/encrypted/ocr_doc.enc',
    thumbnailPath: '/encrypted/ocr_thumb.enc',
    originalFileName: 'ocr_test.jpg',
    pageCount: 1,
    fileSize: 2048,
    mimeType: 'image/jpeg',
    ocrStatus: OcrStatus.completed,
    ocrText: 'Sample extracted text from document. Invoice #12345.',
    createdAt: DateTime.parse('2026-01-11T10:00:00.000Z'),
    updatedAt: DateTime.parse('2026-01-11T10:05:00.000Z'),
  );

  final multiPageDocument = Document(
    id: 'doc-ocr-002',
    title: 'Multi-Page OCR Document',
    filePath: '/encrypted/multi_doc.enc',
    thumbnailPath: '/encrypted/multi_thumb.enc',
    originalFileName: 'multi_page.pdf',
    pageCount: 3,
    fileSize: 8192,
    mimeType: 'application/pdf',
    ocrStatus: OcrStatus.pending,
    createdAt: DateTime.parse('2026-01-11T11:00:00.000Z'),
    updatedAt: DateTime.parse('2026-01-11T11:00:00.000Z'),
  );

  /// Creates a test image file with optional text-like patterns.
  Future<String> createTestImageFile(
    Directory dir,
    String name, {
    int width = 200,
    int height = 100,
  }) async {
    final image = img.Image(width: width, height: height);
    // Fill with white background
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        image.setPixelRgb(x, y, 255, 255, 255);
      }
    }
    // Add some dark pixels to simulate text
    for (int y = 20; y < 40; y++) {
      for (int x = 20; x < 180; x += 10) {
        image.setPixelRgb(x, y, 0, 0, 0);
        image.setPixelRgb(x + 1, y, 0, 0, 0);
      }
    }
    final jpegBytes = img.encodeJpg(image, quality: 90);
    final filePath = '${dir.path}/$name';
    await File(filePath).writeAsBytes(jpegBytes);
    return filePath;
  }

  /// Creates multiple test image files for multi-page documents.
  Future<List<String>> createTestImageFiles(
    Directory dir,
    int count, {
    String prefix = 'page_',
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
      'ocr_pipeline_test_',
    );
  });

  tearDownAll(() async {
    // Clean up test directory
    if (await testTempDir.exists()) {
      await testTempDir.delete(recursive: true);
    }
  });

  setUp(() {
    mockOcrService = MockOcrService();
    mockDocumentRepository = MockDocumentRepository();
    mockDatabaseHelper = MockDatabaseHelper();
    mockSearchService = MockSearchService();

    // Default mock behaviors
    when(mockOcrService.isReady).thenReturn(false);
    when(mockOcrService.availableLanguages).thenReturn([OcrLanguage.english]);
    when(mockOcrService.isLanguageAvailable(any)).thenReturn(true);

    when(mockSearchService.isReady).thenReturn(false);
    when(mockSearchService.initialize()).thenAnswer((_) async => true);

    when(mockDocumentRepository.isReady()).thenAnswer((_) async => true);
    when(mockDocumentRepository.initialize()).thenAnswer((_) async => true);
    when(mockDocumentRepository.getDocument(any))
        .thenAnswer((_) async => testDocument);
    when(
      mockDocumentRepository.updateDocumentOcr(
        any,
        any,
        status: anyNamed('status'),
      ),
    ).thenAnswer((_) async => testDocumentWithOcr);

    when(mockDatabaseHelper.initialize()).thenAnswer((_) async {});
    when(mockDatabaseHelper.rebuildFtsIndex()).thenAnswer((_) async {});
  });

  group('OCR Pipeline Integration Tests', () {
    group('Complete OCR Workflow', () {
      test(
        'should complete full OCR workflow: scan -> extract text -> update document -> enable search',
        () async {
          // Arrange - Create test image
          final testImagePath = await createTestImageFile(
            testTempDir,
            'full_workflow.jpg',
          );

          final ocrResult = OcrResult(
            text: 'Invoice #12345\nAmount: \$500.00\nDate: 2026-01-11',
            language: 'eng',
            confidence: 0.95,
            processingTimeMs: 1500,
            wordCount: 5,
            lineCount: 3,
          );

          when(mockOcrService.isReady).thenReturn(true);
          when(mockOcrService.initialize()).thenAnswer((_) async => true);
          when(
            mockOcrService.extractTextFromFile(
              testImagePath,
              options: anyNamed('options'),
            ),
          ).thenAnswer((_) async => ocrResult);

          when(mockDocumentRepository.getDecryptedFilePath(testDocument))
              .thenAnswer((_) async => testImagePath);

          // Act - Step 1: Initialize OCR service
          final initialized = await mockOcrService.initialize();
          expect(initialized, isTrue);

          // Act - Step 2: Get decrypted file path
          final decryptedPath = await mockDocumentRepository.getDecryptedFilePath(
            testDocument,
          );
          expect(decryptedPath, equals(testImagePath));

          // Act - Step 3: Extract text from document
          final result = await mockOcrService.extractTextFromFile(
            decryptedPath,
            options: const OcrOptions.document(),
          );

          // Assert - OCR succeeded
          expect(result.hasText, isTrue);
          expect(result.text, contains('Invoice #12345'));
          expect(result.confidence, greaterThan(0.9));

          // Act - Step 4: Update document with OCR text
          final updatedDoc = await mockDocumentRepository.updateDocumentOcr(
            testDocument.id,
            result.text,
            status: OcrStatus.completed,
          );

          // Assert - Document updated
          expect(updatedDoc.ocrStatus, equals(OcrStatus.completed));
          expect(updatedDoc.hasOcrText, isTrue);

          // Verify all steps were called
          verify(mockOcrService.initialize()).called(1);
          verify(mockDocumentRepository.getDecryptedFilePath(testDocument))
              .called(1);
          verify(
            mockOcrService.extractTextFromFile(
              testImagePath,
              options: anyNamed('options'),
            ),
          ).called(1);
          verify(
            mockDocumentRepository.updateDocumentOcr(
              testDocument.id,
              result.text,
              status: OcrStatus.completed,
            ),
          ).called(1);
        },
      );

      test('should process multi-page document with combined OCR results', () async {
        // Arrange - Create multiple test images
        final testDir = await Directory(
          '${testTempDir.path}/multi_page_ocr',
        ).create();
        final imagePaths = await createTestImageFiles(testDir, 3);

        final page1Result = const OcrResult(
          text: 'Page 1 content - Introduction',
          language: 'eng',
          processingTimeMs: 500,
          wordCount: 4,
          lineCount: 1,
        );
        final page2Result = const OcrResult(
          text: 'Page 2 content - Details',
          language: 'eng',
          processingTimeMs: 600,
          wordCount: 4,
          lineCount: 1,
        );
        final page3Result = const OcrResult(
          text: 'Page 3 content - Conclusion',
          language: 'eng',
          processingTimeMs: 550,
          wordCount: 4,
          lineCount: 1,
        );

        final combinedResult = const OcrResult(
          text: 'Page 1 content - Introduction\n\n'
              'Page 2 content - Details\n\n'
              'Page 3 content - Conclusion',
          language: 'eng',
          processingTimeMs: 1650,
          wordCount: 12,
          lineCount: 3,
        );

        when(mockOcrService.isReady).thenReturn(true);
        when(
          mockOcrService.extractTextFromMultipleFiles(
            imagePaths,
            options: anyNamed('options'),
            separator: anyNamed('separator'),
          ),
        ).thenAnswer((_) async => combinedResult);

        // Act - Extract text from all pages
        final result = await mockOcrService.extractTextFromMultipleFiles(
          imagePaths,
          options: const OcrOptions.document(),
          separator: '\n\n',
        );

        // Assert
        expect(result.hasText, isTrue);
        expect(result.text, contains('Page 1'));
        expect(result.text, contains('Page 2'));
        expect(result.text, contains('Page 3'));
        expect(result.wordCount, equals(12));
        expect(result.lineCount, equals(3));
      });

      test(
        'should track progress during multi-page OCR with callback',
        () async {
          // Arrange
          final testDir = await Directory(
            '${testTempDir.path}/progress_ocr',
          ).create();
          final imagePaths = await createTestImageFiles(testDir, 3);

          final progressUpdates = <Map<String, dynamic>>[];
          final progressCallback = (
            int current,
            int total,
            OcrResult partial,
          ) {
            progressUpdates.add({
              'current': current,
              'total': total,
              'hasText': partial.hasText,
            });
          };

          final finalResult = const OcrResult(
            text: 'Combined text from all pages',
            language: 'eng',
            processingTimeMs: 1500,
            wordCount: 6,
            lineCount: 1,
          );

          when(mockOcrService.isReady).thenReturn(true);
          when(
            mockOcrService.extractTextWithProgress(
              imagePaths,
              options: anyNamed('options'),
              onProgress: anyNamed('onProgress'),
              separator: anyNamed('separator'),
            ),
          ).thenAnswer((invocation) async {
            // Simulate progress callbacks
            final callback = invocation.namedArguments[#onProgress] as Function;
            for (int i = 0; i < imagePaths.length; i++) {
              final partialResult = OcrResult(
                text: 'Page ${i + 1} text',
                language: 'eng',
                processingTimeMs: 500,
                wordCount: 3,
                lineCount: 1,
              );
              callback(i, imagePaths.length, partialResult);
            }
            return finalResult;
          });

          // Act
          final result = await mockOcrService.extractTextWithProgress(
            imagePaths,
            options: const OcrOptions.document(),
            onProgress: progressCallback,
          );

          // Assert
          expect(result.hasText, isTrue);
          expect(progressUpdates.length, equals(3));
          expect(progressUpdates[0]['current'], equals(0));
          expect(progressUpdates[1]['current'], equals(1));
          expect(progressUpdates[2]['current'], equals(2));
        },
      );
    });

    group('OCR Service Initialization', () {
      test('should initialize OCR service with default language', () async {
        // Arrange
        when(mockOcrService.initialize()).thenAnswer((_) async => true);

        // Act
        final result = await mockOcrService.initialize();

        // Assert
        expect(result, isTrue);
        verify(mockOcrService.initialize()).called(1);
      });

      test('should initialize OCR service with multiple languages', () async {
        // Arrange
        when(
          mockOcrService.initialize(
            languages: anyNamed('languages'),
          ),
        ).thenAnswer((_) async => true);

        // Act
        final result = await mockOcrService.initialize(
          languages: [
            OcrLanguage.english,
            OcrLanguage.german,
            OcrLanguage.french,
          ],
        );

        // Assert
        expect(result, isTrue);
        verify(
          mockOcrService.initialize(
            languages: [
              OcrLanguage.english,
              OcrLanguage.german,
              OcrLanguage.french,
            ],
          ),
        ).called(1);
      });

      test('should handle initialization failure gracefully', () async {
        // Arrange
        when(mockOcrService.initialize()).thenThrow(
          const OcrException('Failed to load traineddata'),
        );

        // Act & Assert
        expect(
          () => mockOcrService.initialize(),
          throwsA(
            isA<OcrException>().having(
              (e) => e.message,
              'message',
              contains('traineddata'),
            ),
          ),
        );
      });
    });

    group('OCR Options and Presets', () {
      test('should use document preset for standard documents', () async {
        // Arrange
        final testImagePath = await createTestImageFile(
          testTempDir,
          'doc_preset.jpg',
        );

        const options = OcrOptions.document();
        final result = OcrResult(
          text: 'Document text with standard layout',
          language: 'eng',
          processingTimeMs: 1000,
          wordCount: 5,
          lineCount: 1,
        );

        when(mockOcrService.isReady).thenReturn(true);
        when(
          mockOcrService.extractTextFromFile(
            testImagePath,
            options: options,
          ),
        ).thenAnswer((_) async => result);

        // Act
        final extracted = await mockOcrService.extractTextFromFile(
          testImagePath,
          options: options,
        );

        // Assert
        expect(extracted.hasText, isTrue);
        expect(options.pageSegmentationMode, equals(OcrPageSegmentationMode.auto));
        expect(options.engineMode, equals(OcrEngineMode.lstmOnly));
      });

      test('should use sparse preset for scattered text', () async {
        // Arrange
        final testImagePath = await createTestImageFile(
          testTempDir,
          'sparse_preset.jpg',
        );

        const options = OcrOptions.sparse();
        final result = OcrResult(
          text: 'Name: John\nPhone: 555-1234',
          language: 'eng',
          processingTimeMs: 800,
          wordCount: 4,
          lineCount: 2,
        );

        when(mockOcrService.isReady).thenReturn(true);
        when(
          mockOcrService.extractTextFromFile(
            testImagePath,
            options: options,
          ),
        ).thenAnswer((_) async => result);

        // Act
        final extracted = await mockOcrService.extractTextFromFile(
          testImagePath,
          options: options,
        );

        // Assert
        expect(extracted.hasText, isTrue);
        expect(
          options.pageSegmentationMode,
          equals(OcrPageSegmentationMode.sparseText),
        );
      });

      test('should use numericOnly preset for numbers', () async {
        // Arrange
        final testImagePath = await createTestImageFile(
          testTempDir,
          'numeric_preset.jpg',
        );

        const options = OcrOptions.numericOnly();
        final result = OcrResult(
          text: '1234567890',
          language: 'eng',
          processingTimeMs: 300,
          wordCount: 1,
          lineCount: 1,
        );

        when(mockOcrService.isReady).thenReturn(true);
        when(
          mockOcrService.extractTextFromFile(
            testImagePath,
            options: options,
          ),
        ).thenAnswer((_) async => result);

        // Act
        final extracted = await mockOcrService.extractTextFromFile(
          testImagePath,
          options: options,
        );

        // Assert
        expect(extracted.hasText, isTrue);
        expect(options.characterWhitelist, equals('0123456789'));
      });

      test('should use singleLine preset for license plates', () async {
        // Arrange
        final testImagePath = await createTestImageFile(
          testTempDir,
          'single_line.jpg',
        );

        const options = OcrOptions.singleLine();
        final result = OcrResult(
          text: 'ABC 1234',
          language: 'eng',
          processingTimeMs: 200,
          wordCount: 2,
          lineCount: 1,
        );

        when(mockOcrService.isReady).thenReturn(true);
        when(
          mockOcrService.extractTextFromFile(
            testImagePath,
            options: options,
          ),
        ).thenAnswer((_) async => result);

        // Act
        final extracted = await mockOcrService.extractTextFromFile(
          testImagePath,
          options: options,
        );

        // Assert
        expect(extracted.hasText, isTrue);
        expect(
          options.pageSegmentationMode,
          equals(OcrPageSegmentationMode.singleLine),
        );
      });
    });

    group('OCR to Search Integration', () {
      test(
        'should enable full-text search after OCR completes',
        () async {
          // Arrange
          final ocrText = 'Contract agreement between parties. Invoice #12345.';

          final searchResults = SearchResults(
            query: 'Invoice',
            results: [
              SearchResult(
                document: testDocumentWithOcr,
                score: -0.85,
                matchedFields: ['ocr_text'],
                snippets: [
                  const SearchSnippet(
                    text: '...Invoice #12345...',
                    field: 'ocr_text',
                    highlights: [
                      [3, 10]
                    ],
                  ),
                ],
              ),
            ],
            totalCount: 1,
            searchTimeMs: 15,
            options: const SearchOptions.defaults(),
          );

          when(mockSearchService.isReady).thenReturn(true);
          when(
            mockSearchService.search(
              'Invoice',
              options: anyNamed('options'),
            ),
          ).thenAnswer((_) async => searchResults);

          when(mockDocumentRepository.updateDocumentOcr(
            testDocument.id,
            ocrText,
            status: OcrStatus.completed,
          )).thenAnswer((_) async => testDocumentWithOcr);

          // Act - Step 1: Update document with OCR text
          final updatedDoc = await mockDocumentRepository.updateDocumentOcr(
            testDocument.id,
            ocrText,
            status: OcrStatus.completed,
          );
          expect(updatedDoc.hasOcrText, isTrue);

          // Act - Step 2: Search for text in OCR content
          final results = await mockSearchService.search(
            'Invoice',
            options: const SearchOptions.ocrTextOnly(),
          );

          // Assert - Document found via OCR text search
          expect(results.hasResults, isTrue);
          expect(results.count, equals(1));
          expect(results.results.first.matchedOcrText, isTrue);
          expect(results.results.first.document.id, equals(testDocumentWithOcr.id));
        },
      );

      test('should index OCR text in FTS5 for fast searching', () async {
        // Arrange
        const ocrText = 'Important contract document with legal terms.';

        final searchResults = SearchResults(
          query: 'legal',
          results: [
            SearchResult(
              document: testDocumentWithOcr.copyWith(ocrText: ocrText),
              score: -0.75,
              matchedFields: ['ocr_text'],
            ),
          ],
          totalCount: 1,
          searchTimeMs: 8,
          options: const SearchOptions.defaults(),
        );

        when(mockSearchService.isReady).thenReturn(true);
        when(
          mockSearchService.search(
            'legal',
            options: anyNamed('options'),
          ),
        ).thenAnswer((_) async => searchResults);

        // Act
        final results = await mockSearchService.search(
          'legal',
          options: const SearchOptions.ocrTextOnly(),
        );

        // Assert
        expect(results.searchTimeMs, lessThan(100)); // FTS should be fast
        expect(results.hasResults, isTrue);
      });

      test('should return empty results for text not in documents', () async {
        // Arrange
        when(mockSearchService.isReady).thenReturn(true);
        when(
          mockSearchService.search(
            'nonexistent_term_xyz',
            options: anyNamed('options'),
          ),
        ).thenAnswer(
          (_) async => const SearchResults.empty(
            query: 'nonexistent_term_xyz',
          ),
        );

        // Act
        final results = await mockSearchService.search(
          'nonexistent_term_xyz',
          options: const SearchOptions.ocrTextOnly(),
        );

        // Assert
        expect(results.hasResults, isFalse);
        expect(results.count, equals(0));
      });
    });

    group('Error Handling', () {
      test('should handle OCR service not initialized', () async {
        // Arrange
        final testImagePath = await createTestImageFile(
          testTempDir,
          'not_init.jpg',
        );

        when(mockOcrService.isReady).thenReturn(false);
        when(
          mockOcrService.extractTextFromFile(
            testImagePath,
            options: anyNamed('options'),
          ),
        ).thenThrow(
          const OcrException(
            'OCR service not initialized. Call initialize() first.',
          ),
        );

        // Act & Assert
        expect(
          () => mockOcrService.extractTextFromFile(
            testImagePath,
            options: const OcrOptions.document(),
          ),
          throwsA(
            isA<OcrException>().having(
              (e) => e.message,
              'message',
              contains('not initialized'),
            ),
          ),
        );
      });

      test('should handle invalid image file gracefully', () async {
        // Arrange
        const invalidPath = '/nonexistent/path/image.jpg';

        when(mockOcrService.isReady).thenReturn(true);
        when(
          mockOcrService.extractTextFromFile(
            invalidPath,
            options: anyNamed('options'),
          ),
        ).thenThrow(
          const OcrException('Image file not found: /nonexistent/path/image.jpg'),
        );

        // Act & Assert
        expect(
          () => mockOcrService.extractTextFromFile(
            invalidPath,
            options: const OcrOptions.document(),
          ),
          throwsA(
            isA<OcrException>().having(
              (e) => e.message,
              'message',
              contains('not found'),
            ),
          ),
        );
      });

      test('should handle unavailable language', () async {
        // Arrange
        final testImagePath = await createTestImageFile(
          testTempDir,
          'unavail_lang.jpg',
        );

        when(mockOcrService.isReady).thenReturn(true);
        when(mockOcrService.isLanguageAvailable(OcrLanguage.japanese))
            .thenReturn(false);
        when(
          mockOcrService.extractTextFromFile(
            testImagePath,
            options: const OcrOptions(language: OcrLanguage.japanese),
          ),
        ).thenThrow(
          const OcrException(
            'Language Japanese (jpn) is not available. '
            'Ensure jpn.traineddata is in assets/tessdata/',
          ),
        );

        // Act & Assert
        expect(
          () => mockOcrService.extractTextFromFile(
            testImagePath,
            options: const OcrOptions(language: OcrLanguage.japanese),
          ),
          throwsA(
            isA<OcrException>().having(
              (e) => e.message,
              'message',
              contains('not available'),
            ),
          ),
        );
      });

      test('should handle corrupted image data', () async {
        // Arrange
        final corruptedPath = '${testTempDir.path}/corrupted.jpg';
        await File(corruptedPath).writeAsBytes([0x00, 0x01, 0x02]); // Invalid JPEG

        when(mockOcrService.isReady).thenReturn(true);
        when(
          mockOcrService.extractTextFromFile(
            corruptedPath,
            options: anyNamed('options'),
          ),
        ).thenThrow(
          const OcrException('Failed to extract text from image'),
        );

        // Act & Assert
        expect(
          () => mockOcrService.extractTextFromFile(
            corruptedPath,
            options: const OcrOptions.document(),
          ),
          throwsA(isA<OcrException>()),
        );
      });

      test('should handle empty image bytes', () async {
        // Arrange
        when(mockOcrService.isReady).thenReturn(true);
        when(
          mockOcrService.extractTextFromBytes(
            Uint8List(0),
            options: anyNamed('options'),
          ),
        ).thenThrow(
          const OcrException('Image bytes cannot be empty'),
        );

        // Act & Assert
        expect(
          () => mockOcrService.extractTextFromBytes(
            Uint8List(0),
            options: const OcrOptions.document(),
          ),
          throwsA(
            isA<OcrException>().having(
              (e) => e.message,
              'message',
              contains('empty'),
            ),
          ),
        );
      });

      test('should update document OCR status to failed on error', () async {
        // Arrange
        final testImagePath = await createTestImageFile(
          testTempDir,
          'fail_ocr.jpg',
        );

        final failedDocument = testDocument.copyWith(
          ocrStatus: OcrStatus.failed,
        );

        when(mockOcrService.isReady).thenReturn(true);
        when(
          mockOcrService.extractTextFromFile(
            testImagePath,
            options: anyNamed('options'),
          ),
        ).thenThrow(const OcrException('Text extraction failed'));

        when(
          mockDocumentRepository.updateDocumentOcr(
            testDocument.id,
            null,
            status: OcrStatus.failed,
          ),
        ).thenAnswer((_) async => failedDocument);

        // Act - Attempt OCR and handle failure
        OcrException? caughtException;
        try {
          await mockOcrService.extractTextFromFile(
            testImagePath,
            options: const OcrOptions.document(),
          );
        } on OcrException catch (e) {
          caughtException = e;
          // Update document status to failed
          await mockDocumentRepository.updateDocumentOcr(
            testDocument.id,
            null,
            status: OcrStatus.failed,
          );
        }

        // Assert
        expect(caughtException, isNotNull);
        verify(
          mockDocumentRepository.updateDocumentOcr(
            testDocument.id,
            null,
            status: OcrStatus.failed,
          ),
        ).called(1);
      });
    });

    group('OCR Result Model', () {
      test('should create OcrResult with all properties', () {
        // Arrange & Act
        const result = OcrResult(
          text: 'Sample text',
          language: 'eng',
          confidence: 0.95,
          processingTimeMs: 1500,
          wordCount: 2,
          lineCount: 1,
        );

        // Assert
        expect(result.text, equals('Sample text'));
        expect(result.language, equals('eng'));
        expect(result.confidence, equals(0.95));
        expect(result.processingTimeMs, equals(1500));
        expect(result.wordCount, equals(2));
        expect(result.lineCount, equals(1));
      });

      test('should correctly compute hasText for various inputs', () {
        // Empty text
        const emptyResult = OcrResult(text: '', language: 'eng');
        expect(emptyResult.hasText, isFalse);
        expect(emptyResult.isEmpty, isTrue);

        // Whitespace only
        const whitespaceResult = OcrResult(text: '   \n\t  ', language: 'eng');
        expect(whitespaceResult.hasText, isFalse);

        // Actual text
        const textResult = OcrResult(text: 'Hello', language: 'eng');
        expect(textResult.hasText, isTrue);
        expect(textResult.isNotEmpty, isTrue);
      });

      test('should format confidence as percentage', () {
        const result = OcrResult(
          text: 'Text',
          language: 'eng',
          confidence: 0.8567,
        );
        expect(result.confidencePercent, equals('85.7%'));

        const noConfResult = OcrResult(text: 'Text', language: 'eng');
        expect(noConfResult.confidencePercent, equals('N/A'));
      });

      test('should implement copyWith correctly', () {
        const original = OcrResult(
          text: 'Original',
          language: 'eng',
          confidence: 0.9,
          processingTimeMs: 1000,
          wordCount: 1,
          lineCount: 1,
        );

        final modified = original.copyWith(
          text: 'Modified',
          confidence: 0.95,
        );

        expect(modified.text, equals('Modified'));
        expect(modified.language, equals('eng')); // Unchanged
        expect(modified.confidence, equals(0.95));
        expect(modified.processingTimeMs, equals(1000)); // Unchanged
      });

      test('should implement equality correctly', () {
        const result1 = OcrResult(
          text: 'Same',
          language: 'eng',
          confidence: 0.9,
        );
        const result2 = OcrResult(
          text: 'Same',
          language: 'eng',
          confidence: 0.9,
        );
        const result3 = OcrResult(
          text: 'Different',
          language: 'eng',
          confidence: 0.9,
        );

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
        expect(result1, isNot(equals(result3)));
      });
    });

    group('OCR Options Model', () {
      test('should create default OcrOptions', () {
        const options = OcrOptions();

        expect(options.language, equals(OcrLanguage.english));
        expect(options.pageSegmentationMode, equals(OcrPageSegmentationMode.auto));
        expect(options.engineMode, equals(OcrEngineMode.lstmOnly));
        expect(options.preserveInterwordSpaces, isTrue);
        expect(options.enableDeskew, isFalse);
      });

      test('should generate correct Tesseract args', () {
        const options = OcrOptions(
          pageSegmentationMode: OcrPageSegmentationMode.singleBlock,
          engineMode: OcrEngineMode.combined,
          preserveInterwordSpaces: true,
          characterWhitelist: 'ABC123',
        );

        final args = options.toTesseractArgs();

        expect(args['psm'], equals('6'));
        expect(args['oem'], equals('2'));
        expect(args['preserve_interword_spaces'], equals('1'));
        expect(args['tessedit_char_whitelist'], equals('ABC123'));
      });

      test('should create presets with correct configuration', () {
        const docOptions = OcrOptions.document();
        expect(docOptions.pageSegmentationMode, equals(OcrPageSegmentationMode.auto));

        const sparseOptions = OcrOptions.sparse();
        expect(
          sparseOptions.pageSegmentationMode,
          equals(OcrPageSegmentationMode.sparseText),
        );

        const lineOptions = OcrOptions.singleLine();
        expect(
          lineOptions.pageSegmentationMode,
          equals(OcrPageSegmentationMode.singleLine),
        );

        const numericOptions = OcrOptions.numericOnly();
        expect(numericOptions.characterWhitelist, equals('0123456789'));
      });
    });

    group('OCR Cache Management', () {
      test('should report cache size', () async {
        // Arrange
        when(mockOcrService.getCacheSize()).thenAnswer((_) async => 4194304);
        when(mockOcrService.getCacheSizeFormatted())
            .thenAnswer((_) async => '4.0 MB');

        // Act
        final size = await mockOcrService.getCacheSize();
        final formatted = await mockOcrService.getCacheSizeFormatted();

        // Assert
        expect(size, equals(4194304));
        expect(formatted, equals('4.0 MB'));
      });

      test('should clear OCR cache', () async {
        // Arrange
        when(mockOcrService.clearCache()).thenAnswer((_) async {});

        // Act
        await mockOcrService.clearCache();

        // Assert
        verify(mockOcrService.clearCache()).called(1);
      });
    });

    group('Language Support', () {
      test('should check available languages', () {
        // Arrange
        when(mockOcrService.availableLanguages).thenReturn([
          OcrLanguage.english,
          OcrLanguage.german,
        ]);
        when(mockOcrService.isLanguageAvailable(OcrLanguage.english))
            .thenReturn(true);
        when(mockOcrService.isLanguageAvailable(OcrLanguage.japanese))
            .thenReturn(false);

        // Act & Assert
        expect(mockOcrService.availableLanguages, hasLength(2));
        expect(mockOcrService.isLanguageAvailable(OcrLanguage.english), isTrue);
        expect(mockOcrService.isLanguageAvailable(OcrLanguage.japanese), isFalse);
      });

      test('OcrLanguage enum should have correct codes', () {
        expect(OcrLanguage.english.code, equals('eng'));
        expect(OcrLanguage.german.code, equals('deu'));
        expect(OcrLanguage.french.code, equals('fra'));
        expect(OcrLanguage.spanish.code, equals('spa'));
        expect(OcrLanguage.japanese.code, equals('jpn'));
        expect(OcrLanguage.chineseSimplified.code, equals('chi_sim'));
      });

      test('OcrLanguage enum should have display names', () {
        expect(OcrLanguage.english.displayName, equals('English'));
        expect(OcrLanguage.german.displayName, equals('German'));
        expect(
          OcrLanguage.chineseSimplified.displayName,
          equals('Chinese (Simplified)'),
        );
      });
    });

    group('Quick Text Detection', () {
      test('should quickly check if image contains text', () async {
        // Arrange
        final testImagePath = await createTestImageFile(
          testTempDir,
          'quick_check.jpg',
        );

        when(mockOcrService.isReady).thenReturn(true);
        when(
          mockOcrService.containsText(
            testImagePath,
            language: anyNamed('language'),
          ),
        ).thenAnswer((_) async => true);

        // Act
        final hasText = await mockOcrService.containsText(
          testImagePath,
          language: OcrLanguage.english,
        );

        // Assert
        expect(hasText, isTrue);
      });

      test('should return false for image without text', () async {
        // Arrange
        final blankImagePath = await createTestImageFile(
          testTempDir,
          'blank_image.jpg',
        );

        when(mockOcrService.isReady).thenReturn(true);
        when(
          mockOcrService.containsText(
            blankImagePath,
            language: anyNamed('language'),
          ),
        ).thenAnswer((_) async => false);

        // Act
        final hasText = await mockOcrService.containsText(blankImagePath);

        // Assert
        expect(hasText, isFalse);
      });
    });

    group('Riverpod Provider Integration', () {
      test('ocrServiceProvider should provide OcrService', () {
        // Arrange
        final container = ProviderContainer();

        // Act
        final service = container.read(ocrServiceProvider);

        // Assert
        expect(service, isA<OcrService>());

        container.dispose();
      });

      test('searchServiceProvider should provide SearchService', () {
        // This would require a proper container setup with dependencies
        // For now, we verify the provider exists and can be accessed
        final container = ProviderContainer(
          overrides: [
            databaseHelperProvider.overrideWithValue(mockDatabaseHelper),
            documentRepositoryProvider.overrideWithValue(mockDocumentRepository),
          ],
        );

        // Act
        final service = container.read(searchServiceProvider);

        // Assert
        expect(service, isA<SearchService>());

        container.dispose();
      });
    });

    group('End-to-End OCR Scenarios', () {
      test('complete E2E: scan document -> OCR -> search finds document', () async {
        // Arrange - Setup complete pipeline
        final testDir = await Directory(
          '${testTempDir.path}/e2e_ocr',
        ).create();
        final imagePath = await createTestImageFile(testDir, 'e2e_test.jpg');

        final ocrResult = const OcrResult(
          text: 'ACME Corporation\nInvoice #INV-2026-001\nTotal: \$1,500.00',
          language: 'eng',
          confidence: 0.92,
          processingTimeMs: 1200,
          wordCount: 6,
          lineCount: 3,
        );

        final documentWithOcr = testDocument.copyWith(
          ocrStatus: OcrStatus.completed,
          ocrText: ocrResult.text,
        );

        final searchResults = SearchResults(
          query: 'ACME Invoice',
          results: [
            SearchResult(
              document: documentWithOcr,
              score: -0.9,
              matchedFields: ['ocr_text'],
            ),
          ],
          totalCount: 1,
          searchTimeMs: 10,
          options: const SearchOptions.defaults(),
        );

        when(mockOcrService.isReady).thenReturn(true);
        when(mockOcrService.initialize()).thenAnswer((_) async => true);
        when(
          mockOcrService.extractTextFromFile(
            imagePath,
            options: anyNamed('options'),
          ),
        ).thenAnswer((_) async => ocrResult);

        when(mockDocumentRepository.getDecryptedFilePath(testDocument))
            .thenAnswer((_) async => imagePath);
        when(
          mockDocumentRepository.updateDocumentOcr(
            testDocument.id,
            ocrResult.text,
            status: OcrStatus.completed,
          ),
        ).thenAnswer((_) async => documentWithOcr);

        when(mockSearchService.isReady).thenReturn(true);
        when(mockSearchService.initialize()).thenAnswer((_) async => true);
        when(
          mockSearchService.search(
            'ACME Invoice',
            options: anyNamed('options'),
          ),
        ).thenAnswer((_) async => searchResults);

        // Act - Step 1: Initialize services
        await mockOcrService.initialize();
        await mockSearchService.initialize();

        // Act - Step 2: Get document file path
        final decryptedPath = await mockDocumentRepository.getDecryptedFilePath(
          testDocument,
        );

        // Act - Step 3: Perform OCR
        final ocr = await mockOcrService.extractTextFromFile(
          decryptedPath,
          options: const OcrOptions.document(),
        );
        expect(ocr.hasText, isTrue);
        expect(ocr.confidence, greaterThan(0.9));

        // Act - Step 4: Update document with OCR text
        final updatedDoc = await mockDocumentRepository.updateDocumentOcr(
          testDocument.id,
          ocr.text,
          status: OcrStatus.completed,
        );
        expect(updatedDoc.ocrStatus, equals(OcrStatus.completed));

        // Act - Step 5: Search for document by OCR content
        final results = await mockSearchService.search(
          'ACME Invoice',
          options: const SearchOptions(
            field: SearchField.ocrText,
            matchMode: SearchMatchMode.allWords,
          ),
        );

        // Assert - Document found
        expect(results.hasResults, isTrue);
        expect(results.count, equals(1));
        expect(results.results.first.document.id, equals(testDocument.id));
        expect(results.results.first.matchedOcrText, isTrue);
      });

      test('complete E2E: batch OCR processing for multiple documents', () async {
        // Arrange
        final testDir = await Directory(
          '${testTempDir.path}/batch_ocr',
        ).create();

        final documents = [
          testDocument.copyWith(id: 'batch-001'),
          testDocument.copyWith(id: 'batch-002'),
          testDocument.copyWith(id: 'batch-003'),
        ];

        final imagePaths = await createTestImageFiles(testDir, 3);

        when(mockOcrService.isReady).thenReturn(true);

        // Setup for each document
        for (int i = 0; i < documents.length; i++) {
          when(mockDocumentRepository.getDecryptedFilePath(documents[i]))
              .thenAnswer((_) async => imagePaths[i]);

          when(
            mockOcrService.extractTextFromFile(
              imagePaths[i],
              options: anyNamed('options'),
            ),
          ).thenAnswer((_) async => OcrResult(
                text: 'Document ${i + 1} content',
                language: 'eng',
                processingTimeMs: 800 + (i * 100),
                wordCount: 3,
                lineCount: 1,
              ));

          when(
            mockDocumentRepository.updateDocumentOcr(
              documents[i].id,
              'Document ${i + 1} content',
              status: OcrStatus.completed,
            ),
          ).thenAnswer((_) async => documents[i].copyWith(
                ocrStatus: OcrStatus.completed,
                ocrText: 'Document ${i + 1} content',
              ));
        }

        // Act - Process all documents
        final results = <OcrResult>[];
        for (int i = 0; i < documents.length; i++) {
          final path = await mockDocumentRepository.getDecryptedFilePath(
            documents[i],
          );
          final ocr = await mockOcrService.extractTextFromFile(
            path,
            options: const OcrOptions.document(),
          );
          results.add(ocr);

          await mockDocumentRepository.updateDocumentOcr(
            documents[i].id,
            ocr.text,
            status: OcrStatus.completed,
          );
        }

        // Assert
        expect(results.length, equals(3));
        expect(results.every((r) => r.hasText), isTrue);

        // Verify all documents were processed
        for (int i = 0; i < documents.length; i++) {
          verify(mockDocumentRepository.getDecryptedFilePath(documents[i]))
              .called(1);
          verify(
            mockDocumentRepository.updateDocumentOcr(
              documents[i].id,
              'Document ${i + 1} content',
              status: OcrStatus.completed,
            ),
          ).called(1);
        }
      });
    });
  });
}
