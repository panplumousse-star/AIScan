import 'dart:io';
import 'dart:typed_data';

import 'package:aiscan/features/export/domain/pdf_generator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('PDFGeneratorException', () {
    test('should create exception with message only', () {
      const exception = PDFGeneratorException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.cause, isNull);
      expect(exception.toString(), 'PDFGeneratorException: Test error');
    });

    test('should create exception with message and cause', () {
      final cause = Exception('Underlying error');
      final exception = PDFGeneratorException('Test error', cause: cause);

      expect(exception.message, 'Test error');
      expect(exception.cause, cause);
      expect(
        exception.toString(),
        'PDFGeneratorException: Test error (caused by: $cause)',
      );
    });
  });

  group('GeneratedPDF', () {
    test('should create with required fields', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = GeneratedPDF(
        bytes: bytes,
        pageCount: 2,
        title: 'Test Document',
      );

      expect(result.bytes, bytes);
      expect(result.pageCount, 2);
      expect(result.title, 'Test Document');
      expect(result.author, isNull);
      expect(result.subject, isNull);
      expect(result.keywords, isNull);
      expect(result.creationDate, isNull);
    });

    test('should create with all fields', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final creationDate = DateTime(2024, 1, 15, 10, 30);
      final result = GeneratedPDF(
        bytes: bytes,
        pageCount: 3,
        title: 'Test Document',
        author: 'John Doe',
        subject: 'Test Subject',
        keywords: ['test', 'document', 'pdf'],
        creationDate: creationDate,
      );

      expect(result.bytes, bytes);
      expect(result.pageCount, 3);
      expect(result.title, 'Test Document');
      expect(result.author, 'John Doe');
      expect(result.subject, 'Test Subject');
      expect(result.keywords, ['test', 'document', 'pdf']);
      expect(result.creationDate, creationDate);
    });

    test('should calculate fileSize correctly', () {
      final bytes = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      final result = GeneratedPDF(
        bytes: bytes,
        pageCount: 1,
        title: 'Test',
      );

      expect(result.fileSize, 1000);
    });

    test('should format file size in bytes', () {
      final bytes = Uint8List.fromList(List.generate(500, (i) => 0));
      final result = GeneratedPDF(
        bytes: bytes,
        pageCount: 1,
        title: 'Test',
      );

      expect(result.fileSizeFormatted, '500 B');
    });

    test('should format file size in KB', () {
      final bytes = Uint8List.fromList(List.generate(2048, (i) => 0));
      final result = GeneratedPDF(
        bytes: bytes,
        pageCount: 1,
        title: 'Test',
      );

      expect(result.fileSizeFormatted, '2.0 KB');
    });

    test('should format file size in MB', () {
      final bytes =
          Uint8List.fromList(List.generate(1024 * 1024 * 2, (i) => 0)); // 2MB
      final result = GeneratedPDF(
        bytes: bytes,
        pageCount: 1,
        title: 'Test',
      );

      expect(result.fileSizeFormatted, '2.0 MB');
    });

    test('should support copyWith for all fields', () {
      final original = GeneratedPDF(
        bytes: Uint8List.fromList([1, 2, 3]),
        pageCount: 1,
        title: 'Original',
        author: 'Author',
        subject: 'Subject',
        keywords: ['key1'],
        creationDate: DateTime(2024),
      );

      final modified = original.copyWith(
        title: 'Modified',
        pageCount: 2,
      );

      expect(modified.title, 'Modified');
      expect(modified.pageCount, 2);
      expect(modified.author, 'Author'); // Unchanged
      expect(modified.subject, 'Subject'); // Unchanged
    });

    test('should support copyWith with clear flags', () {
      final original = GeneratedPDF(
        bytes: Uint8List.fromList([1, 2, 3]),
        pageCount: 1,
        title: 'Original',
        author: 'Author',
        subject: 'Subject',
      );

      final modified = original.copyWith(
        clearAuthor: true,
        clearSubject: true,
      );

      expect(modified.author, isNull);
      expect(modified.subject, isNull);
      expect(modified.title, 'Original'); // Unchanged
    });

    test('should have correct equality', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final creationDate = DateTime(2024, 1, 15);

      final result1 = GeneratedPDF(
        bytes: bytes,
        pageCount: 1,
        title: 'Test',
        author: 'Author',
        creationDate: creationDate,
      );

      final result2 = GeneratedPDF(
        bytes: Uint8List.fromList([1, 2, 3]),
        pageCount: 1,
        title: 'Test',
        author: 'Author',
        creationDate: creationDate,
      );

      final result3 = GeneratedPDF(
        bytes: bytes,
        pageCount: 2, // Different
        title: 'Test',
      );

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });

    test('should have correct hashCode', () {
      final bytes = Uint8List.fromList([1, 2, 3]);

      final result1 = GeneratedPDF(
        bytes: bytes,
        pageCount: 1,
        title: 'Test',
      );

      final result2 = GeneratedPDF(
        bytes: Uint8List.fromList([1, 2, 3]),
        pageCount: 1,
        title: 'Test',
      );

      expect(result1.hashCode, equals(result2.hashCode));
    });

    test('should have meaningful toString', () {
      final result = GeneratedPDF(
        bytes: Uint8List.fromList(List.generate(1000, (i) => 0)),
        pageCount: 3,
        title: 'My Document',
      );

      expect(result.toString(), contains('My Document'));
      expect(result.toString(), contains('3'));
    });
  });

  group('PDFPageSize', () {
    test('should have all expected values', () {
      expect(PDFPageSize.values, contains(PDFPageSize.a4));
      expect(PDFPageSize.values, contains(PDFPageSize.letter));
      expect(PDFPageSize.values, contains(PDFPageSize.legal));
      expect(PDFPageSize.values, contains(PDFPageSize.fitToImage));
    });
  });

  group('PDFOrientation', () {
    test('should have all expected values', () {
      expect(PDFOrientation.values, contains(PDFOrientation.portrait));
      expect(PDFOrientation.values, contains(PDFOrientation.landscape));
      expect(PDFOrientation.values, contains(PDFOrientation.auto));
    });
  });

  group('PDFImageFit', () {
    test('should have all expected values', () {
      expect(PDFImageFit.values, contains(PDFImageFit.fill));
      expect(PDFImageFit.values, contains(PDFImageFit.contain));
      expect(PDFImageFit.values, contains(PDFImageFit.cover));
      expect(PDFImageFit.values, contains(PDFImageFit.original));
    });
  });

  group('PDFGeneratorOptions', () {
    test('should create with default values', () {
      const options = PDFGeneratorOptions();

      expect(options.pageSize, PDFPageSize.a4);
      expect(options.orientation, PDFOrientation.auto);
      expect(options.imageFit, PDFImageFit.contain);
      expect(options.marginLeft, 0);
      expect(options.marginRight, 0);
      expect(options.marginTop, 0);
      expect(options.marginBottom, 0);
      expect(options.title, 'Scanned Document');
      expect(options.author, isNull);
      expect(options.subject, isNull);
      expect(options.keywords, isNull);
      expect(options.producer, 'Scanaï');
      expect(options.creator, 'Scanaï Document Scanner');
      expect(options.imageQuality, 85);
      expect(options.compressImages, true);
    });

    test('should create document preset correctly', () {
      const options = PDFGeneratorOptions.document;

      expect(options.pageSize, PDFPageSize.a4);
      expect(options.orientation, PDFOrientation.auto);
      expect(options.imageFit, PDFImageFit.contain);
      expect(options.marginLeft, 20);
      expect(options.marginRight, 20);
      expect(options.marginTop, 20);
      expect(options.marginBottom, 20);
    });

    test('should create fullPage preset correctly', () {
      const options = PDFGeneratorOptions.fullPage;

      expect(options.pageSize, PDFPageSize.a4);
      expect(options.imageFit, PDFImageFit.fill);
      expect(options.marginLeft, 0);
      expect(options.marginRight, 0);
      expect(options.marginTop, 0);
      expect(options.marginBottom, 0);
    });

    test('should create photo preset correctly', () {
      const options = PDFGeneratorOptions.photo;

      expect(options.pageSize, PDFPageSize.fitToImage);
      expect(options.imageFit, PDFImageFit.original);
    });

    test('should calculate horizontal margin correctly', () {
      const options = PDFGeneratorOptions(
        marginLeft: 10,
        marginRight: 15,
      );

      expect(options.horizontalMargin, 25);
    });

    test('should calculate vertical margin correctly', () {
      const options = PDFGeneratorOptions(
        marginTop: 20,
        marginBottom: 30,
      );

      expect(options.verticalMargin, 50);
    });

    test('should support copyWith for all fields', () {
      const original = PDFGeneratorOptions(
        title: 'Original',
        author: 'Author',
      );

      final modified = original.copyWith(
        title: 'Modified',
        pageSize: PDFPageSize.letter,
      );

      expect(modified.title, 'Modified');
      expect(modified.pageSize, PDFPageSize.letter);
      expect(modified.author, 'Author'); // Unchanged
    });

    test('should support copyWith with clear flags', () {
      const original = PDFGeneratorOptions(
        title: 'Title',
        author: 'Author',
        subject: 'Subject',
        keywords: ['key1', 'key2'],
      );

      final modified = original.copyWith(
        clearAuthor: true,
        clearSubject: true,
        clearKeywords: true,
      );

      expect(modified.author, isNull);
      expect(modified.subject, isNull);
      expect(modified.keywords, isNull);
      expect(modified.title, 'Title'); // Unchanged
    });

    test('should have correct equality', () {
      const options1 = PDFGeneratorOptions(
        title: 'Test',
      );

      const options2 = PDFGeneratorOptions(
        title: 'Test',
      );

      const options3 = PDFGeneratorOptions(
        title: 'Test',
        pageSize: PDFPageSize.letter, // Different
      );

      expect(options1, equals(options2));
      expect(options1, isNot(equals(options3)));
    });

    test('should have correct hashCode', () {
      const options1 = PDFGeneratorOptions(
        title: 'Test',
      );

      const options2 = PDFGeneratorOptions(
        title: 'Test',
      );

      expect(options1.hashCode, equals(options2.hashCode));
    });

    test('should have meaningful toString', () {
      const options = PDFGeneratorOptions(
        title: 'My Document',
        pageSize: PDFPageSize.letter,
      );

      expect(options.toString(), contains('letter'));
      expect(options.toString(), contains('My Document'));
    });

    group('maxWidth parameter', () {
      test('should have default value of 2000', () {
        const options = PDFGeneratorOptions();

        expect(options.maxWidth, 2000);
      });

      test('should create options with custom maxWidth', () {
        const options = PDFGeneratorOptions(
          maxWidth: 1500,
        );

        expect(options.maxWidth, 1500);
      });

      test('should support different maxWidth values', () {
        const smallOptions = PDFGeneratorOptions(maxWidth: 800);
        const mediumOptions = PDFGeneratorOptions(maxWidth: 1200);
        const largeOptions = PDFGeneratorOptions(maxWidth: 3000);

        expect(smallOptions.maxWidth, 800);
        expect(mediumOptions.maxWidth, 1200);
        expect(largeOptions.maxWidth, 3000);
      });

      test('should support copyWith for maxWidth', () {
        const original = PDFGeneratorOptions(
          title: 'Test',
          maxWidth: 1000,
        );

        final modified = original.copyWith(maxWidth: 1500);

        expect(modified.maxWidth, 1500);
        expect(modified.title, 'Test'); // Unchanged
      });

      test('should preserve maxWidth when not specified in copyWith', () {
        const original = PDFGeneratorOptions(
          title: 'Test',
          maxWidth: 1200,
        );

        final modified = original.copyWith(title: 'Modified');

        expect(modified.maxWidth, 1200); // Unchanged
        expect(modified.title, 'Modified');
      });

      test('should include maxWidth in equality check', () {
        const options1 = PDFGeneratorOptions(
          title: 'Test',
          maxWidth: 1500,
        );

        const options2 = PDFGeneratorOptions(
          title: 'Test',
          maxWidth: 1500,
        );

        const options3 = PDFGeneratorOptions(
          title: 'Test',
        );

        expect(options1, equals(options2));
        expect(options1, isNot(equals(options3)));
      });

      test('should include maxWidth in hashCode', () {
        const options1 = PDFGeneratorOptions(
          title: 'Test',
          maxWidth: 1500,
        );

        const options2 = PDFGeneratorOptions(
          title: 'Test',
          maxWidth: 1500,
        );

        expect(options1.hashCode, equals(options2.hashCode));
      });

      test('should work with preset options', () {
        const documentPreset = PDFGeneratorOptions.document;
        const fullPagePreset = PDFGeneratorOptions.fullPage;
        const photoPreset = PDFGeneratorOptions.photo;

        // All presets should have the default maxWidth
        expect(documentPreset.maxWidth, 2000);
        expect(fullPagePreset.maxWidth, 2000);
        expect(photoPreset.maxWidth, 2000);
      });

      test('should allow maxWidth to be combined with other options', () {
        const options = PDFGeneratorOptions(
          pageSize: PDFPageSize.letter,
          orientation: PDFOrientation.landscape,
          imageQuality: 90,
          maxWidth: 1800,
        );

        expect(options.pageSize, PDFPageSize.letter);
        expect(options.orientation, PDFOrientation.landscape);
        expect(options.imageQuality, 90);
        expect(options.compressImages, true);
        expect(options.maxWidth, 1800);
      });
    });
  });

  group('PDFPage', () {
    test('should create from bytes', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final page = PDFPage.fromBytes(imageBytes: bytes);

      expect(page.imageBytes, bytes);
      expect(page.imagePath, isNull);
      expect(page.orientation, isNull);
      expect(page.hasImage, true);
      expect(page.usesBytes, true);
      expect(page.usesFile, false);
    });

    test('should create from file', () {
      const page = PDFPage.fromFile(imagePath: '/path/to/image.jpg');

      expect(page.imageBytes, isNull);
      expect(page.imagePath, '/path/to/image.jpg');
      expect(page.orientation, isNull);
      expect(page.hasImage, true);
      expect(page.usesBytes, false);
      expect(page.usesFile, true);
    });

    test('should support orientation override', () {
      final page = PDFPage.fromBytes(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        orientation: PDFOrientation.landscape,
      );

      expect(page.orientation, PDFOrientation.landscape);
    });

    test('should have correct equality for bytes', () {
      final bytes = Uint8List.fromList([1, 2, 3]);

      final page1 = PDFPage.fromBytes(imageBytes: bytes);
      final page2 =
          PDFPage.fromBytes(imageBytes: Uint8List.fromList([1, 2, 3]));
      final page3 =
          PDFPage.fromBytes(imageBytes: Uint8List.fromList([4, 5, 6]));

      expect(page1, equals(page2));
      expect(page1, isNot(equals(page3)));
    });

    test('should have correct equality for files', () {
      const page1 = PDFPage.fromFile(imagePath: '/path/to/file.jpg');
      const page2 = PDFPage.fromFile(imagePath: '/path/to/file.jpg');
      const page3 = PDFPage.fromFile(imagePath: '/path/to/other.jpg');

      expect(page1, equals(page2));
      expect(page1, isNot(equals(page3)));
    });

    test('should have correct hashCode', () {
      final bytes = Uint8List.fromList([1, 2, 3]);

      final page1 = PDFPage.fromBytes(imageBytes: bytes);
      final page2 =
          PDFPage.fromBytes(imageBytes: Uint8List.fromList([1, 2, 3]));

      expect(page1.hashCode, equals(page2.hashCode));
    });

    test('should have meaningful toString for bytes', () {
      final page = PDFPage.fromBytes(
        imageBytes: Uint8List.fromList([1, 2, 3, 4, 5]),
      );

      expect(page.toString(), contains('bytes'));
      expect(page.toString(), contains('5'));
    });

    test('should have meaningful toString for file', () {
      const page = PDFPage.fromFile(imagePath: '/path/to/image.jpg');

      expect(page.toString(), contains('file'));
      expect(page.toString(), contains('/path/to/image.jpg'));
    });
  });

  group('PDFGenerator', () {
    late PDFGenerator generator;

    setUp(() {
      generator = PDFGenerator();
    });

    group('generateFromBytes', () {
      test('should throw on empty list', () async {
        expect(
          () => generator.generateFromBytes(imageBytesList: []),
          throwsA(isA<PDFGeneratorException>().having(
            (e) => e.message,
            'message',
            contains('cannot be empty'),
          )),
        );
      });

      test('should throw on list with empty bytes', () async {
        expect(
          () => generator.generateFromBytes(
            imageBytesList: [
              Uint8List.fromList([1, 2, 3]),
              Uint8List.fromList([]), // Empty
            ],
          ),
          throwsA(isA<PDFGeneratorException>().having(
            (e) => e.message,
            'message',
            contains('index 1'),
          )),
        );
      });
    });

    group('generateFromFiles', () {
      test('should throw on empty list', () async {
        expect(
          () => generator.generateFromFiles(imagePaths: []),
          throwsA(isA<PDFGeneratorException>().having(
            (e) => e.message,
            'message',
            contains('cannot be empty'),
          )),
        );
      });

      test('should throw on list with empty path', () async {
        expect(
          () => generator.generateFromFiles(
            imagePaths: ['/valid/path.jpg', ''],
          ),
          throwsA(isA<PDFGeneratorException>().having(
            (e) => e.message,
            'message',
            contains('index 1'),
          )),
        );
      });
    });

    group('generateFromPages', () {
      test('should throw on empty list', () async {
        expect(
          () => generator.generateFromPages(pages: []),
          throwsA(isA<PDFGeneratorException>().having(
            (e) => e.message,
            'message',
            contains('cannot be empty'),
          )),
        );
      });
    });

    group('generateToFile', () {
      test('should throw on empty output path', () async {
        expect(
          () => generator.generateToFile(
            imagePaths: ['/path/to/image.jpg'],
            outputPath: '',
          ),
          throwsA(isA<PDFGeneratorException>().having(
            (e) => e.message,
            'message',
            contains('Output path cannot be empty'),
          )),
        );
      });
    });
  });

  group('pdfGeneratorProvider', () {
    test('should provide PDFGenerator instance', () {
      final container = ProviderContainer();

      final generator = container.read(pdfGeneratorProvider);

      expect(generator, isA<PDFGenerator>());
    });

    test('should return same instance on multiple reads', () {
      final container = ProviderContainer();

      final generator1 = container.read(pdfGeneratorProvider);
      final generator2 = container.read(pdfGeneratorProvider);

      expect(identical(generator1, generator2), true);
    });
  });

  group('Integration Tests', () {
    late PDFGenerator generator;
    late Directory tempDir;

    setUp(() async {
      generator = PDFGenerator();
      tempDir = await Directory.systemTemp.createTemp('pdf_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    // Note: Full integration tests with actual image processing require
    // valid image files. These tests are skipped in unit test context.
    // They should be run as part of integration testing on device.

    test('should handle non-existent file', () async {
      expect(
        () => generator.generateFromFiles(
          imagePaths: ['${tempDir.path}/nonexistent.jpg'],
        ),
        throwsA(isA<PDFGeneratorException>()),
      );
    });

    test('should use document preset options correctly', () async {
      const options = PDFGeneratorOptions.document;

      expect(options.marginLeft, 20);
      expect(options.marginRight, 20);
      expect(options.marginTop, 20);
      expect(options.marginBottom, 20);
      expect(options.imageFit, PDFImageFit.contain);
    });

    test('should use fullPage preset options correctly', () async {
      const options = PDFGeneratorOptions.fullPage;

      expect(options.marginLeft, 0);
      expect(options.marginRight, 0);
      expect(options.marginTop, 0);
      expect(options.marginBottom, 0);
      expect(options.imageFit, PDFImageFit.fill);
    });

    test('should use photo preset options correctly', () async {
      const options = PDFGeneratorOptions.photo;

      expect(options.pageSize, PDFPageSize.fitToImage);
      expect(options.imageFit, PDFImageFit.original);
    });

    test('should create options with custom metadata', () async {
      const options = PDFGeneratorOptions(
        title: 'Custom Title',
        author: 'Custom Author',
        subject: 'Custom Subject',
        keywords: ['keyword1', 'keyword2'],
      );

      expect(options.title, 'Custom Title');
      expect(options.author, 'Custom Author');
      expect(options.subject, 'Custom Subject');
      expect(options.keywords, ['keyword1', 'keyword2']);
    });
  });

  group('Error Handling', () {
    late PDFGenerator generator;

    setUp(() {
      generator = PDFGenerator();
    });

    test(
        'generateFromBytes should throw PDFGeneratorException on invalid input',
        () async {
      expect(
        () => generator.generateFromBytes(imageBytesList: []),
        throwsA(isA<PDFGeneratorException>()),
      );
    });

    test(
        'generateFromFiles should throw PDFGeneratorException on invalid input',
        () async {
      expect(
        () => generator.generateFromFiles(imagePaths: []),
        throwsA(isA<PDFGeneratorException>()),
      );
    });

    test(
        'generateFromPages should throw PDFGeneratorException on invalid input',
        () async {
      expect(
        () => generator.generateFromPages(pages: []),
        throwsA(isA<PDFGeneratorException>()),
      );
    });

    test(
        'generateToFile should throw PDFGeneratorException on empty output path',
        () async {
      expect(
        () => generator.generateToFile(
          imagePaths: ['/valid/path.jpg'],
          outputPath: '',
        ),
        throwsA(isA<PDFGeneratorException>()),
      );
    });
  });

  group('Compression', () {
    // Helper to create a test image with specified dimensions
    Uint8List createTestImage({
      int width = 100,
      int height = 100,
      img.Color? fillColor,
    }) {
      final image = img.Image(width: width, height: height);
      final color = fillColor ?? img.ColorRgb8(128, 128, 128);

      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          image.setPixel(x, y, color);
        }
      }

      return Uint8List.fromList(img.encodeJpg(image));
    }

    // Helper to create a larger image for compression testing
    Uint8List createLargeTestImage({
      int width = 3000,
      int height = 2000,
    }) {
      final image = img.Image(width: width, height: height);

      // Create a gradient pattern for better compression testing
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final r = ((x / width) * 255).round();
          final g = ((y / height) * 255).round();
          final b = ((x + y) / (width + height) * 255).round();
          image.setPixel(x, y, img.ColorRgb8(r, g, b));
        }
      }

      return Uint8List.fromList(img.encodeJpg(image));
    }

    group('compressImages flag', () {
      test('should compress images when compressImages is true (default)',
          () async {
        final generator = PDFGenerator();
        final largeImage = createLargeTestImage();

        // Generate with compression enabled (default)
        final compressedResult = await generator.generateFromBytes(
          imageBytesList: [largeImage],
        );

        // Generate with compression disabled
        final uncompressedResult = await generator.generateFromBytes(
          imageBytesList: [largeImage],
          options: const PDFGeneratorOptions(
            compressImages: false,
          ),
        );

        // Compressed PDF should be smaller
        expect(
          compressedResult.fileSize,
          lessThan(uncompressedResult.fileSize),
        );
      });

      test('should preserve original bytes when compressImages is false',
          () async {
        final generator = PDFGenerator();
        final testImage = createTestImage(width: 500, height: 500);

        // Generate with compression disabled
        final result = await generator.generateFromBytes(
          imageBytesList: [testImage],
          options: const PDFGeneratorOptions(
            compressImages: false,
          ),
        );

        // The PDF should still generate successfully
        expect(result.bytes, isNotEmpty);
        expect(result.pageCount, 1);
      });

      test('should default compressImages to true', () {
        const options = PDFGeneratorOptions();
        expect(options.compressImages, true);
      });
    });

    group('imageQuality parameter', () {
      test('should use default quality of 85', () {
        const options = PDFGeneratorOptions();
        expect(options.imageQuality, 85);
      });

      test('should produce smaller files with lower quality', () async {
        final generator = PDFGenerator();
        final largeImage = createLargeTestImage(width: 2000, height: 1500);

        // Generate with high quality
        final highQualityResult = await generator.generateFromBytes(
          imageBytesList: [largeImage],
          options: const PDFGeneratorOptions(
            imageQuality: 95,
          ),
        );

        // Generate with low quality
        final lowQualityResult = await generator.generateFromBytes(
          imageBytesList: [largeImage],
          options: const PDFGeneratorOptions(
            imageQuality: 50,
          ),
        );

        // Lower quality should produce smaller file
        expect(
          lowQualityResult.fileSize,
          lessThan(highQualityResult.fileSize),
        );
      });

      test('should support custom imageQuality values', () {
        const options = PDFGeneratorOptions(imageQuality: 75);
        expect(options.imageQuality, 75);
      });

      test('should preserve imageQuality in copyWith', () {
        const original = PDFGeneratorOptions(imageQuality: 60);
        final modified = original.copyWith(title: 'Modified');

        expect(modified.imageQuality, 60);
      });

      test('should update imageQuality with copyWith', () {
        const original = PDFGeneratorOptions();
        final modified = original.copyWith(imageQuality: 50);

        expect(modified.imageQuality, 50);
      });
    });

    group('maxWidth resizing', () {
      test('should resize images wider than maxWidth', () async {
        final generator = PDFGenerator();
        // Create image wider than default maxWidth of 2000
        final wideImage = createLargeTestImage(width: 4000);

        // Generate with small maxWidth
        final smallMaxWidthResult = await generator.generateFromBytes(
          imageBytesList: [wideImage],
          options: const PDFGeneratorOptions(
            maxWidth: 1000,
          ),
        );

        // Generate with larger maxWidth
        final largeMaxWidthResult = await generator.generateFromBytes(
          imageBytesList: [wideImage],
          options: const PDFGeneratorOptions(
            maxWidth: 3000,
          ),
        );

        // Smaller maxWidth should produce smaller file
        expect(
          smallMaxWidthResult.fileSize,
          lessThan(largeMaxWidthResult.fileSize),
        );
      });

      test('should not resize images smaller than maxWidth', () async {
        final generator = PDFGenerator();
        // Create image smaller than maxWidth
        final smallImage = createTestImage(width: 500, height: 400);

        // Generate with large maxWidth
        final result = await generator.generateFromBytes(
          imageBytesList: [smallImage],
        );

        // Should still generate successfully
        expect(result.bytes, isNotEmpty);
        expect(result.pageCount, 1);
      });

      test('should use default maxWidth of 2000', () {
        const options = PDFGeneratorOptions();
        expect(options.maxWidth, 2000);
      });
    });

    group('graceful degradation', () {
      test('should return original bytes when decode fails with compression',
          () async {
        final generator = PDFGenerator();
        // Invalid image bytes that cannot be decoded
        final invalidBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

        // When compression is enabled but decoding fails, the original bytes
        // are returned (graceful degradation). The PDF library will then try
        // to process these bytes and may throw an error.
        // This tests that the compression function doesn't crash unexpectedly.
        var errorThrown = false;
        try {
          await generator.generateFromBytes(
            imageBytesList: [invalidBytes],
          );
          // If it gets here, the PDF library handled the invalid bytes somehow
        } catch (e) {
          // Expected - the PDF library couldn't handle the invalid bytes
          // The error could be an Exception or Error (e.g., RangeError)
          errorThrown = true;
        }
        // We expect an error to be thrown when invalid image bytes are provided
        expect(errorThrown, isTrue);
      });

      test('should generate PDF with valid images mixed with compression',
          () async {
        final generator = PDFGenerator();
        final testImage = createTestImage(width: 800, height: 600);

        // Should work with compression
        final result = await generator.generateFromBytes(
          imageBytesList: [testImage],
        );

        expect(result.bytes, isNotEmpty);
        expect(result.pageCount, 1);
      });
    });

    group('quality clamping', () {
      test('should accept quality at lower bound (1)', () async {
        final generator = PDFGenerator();
        final testImage = createTestImage(width: 500, height: 500);

        final result = await generator.generateFromBytes(
          imageBytesList: [testImage],
          options: const PDFGeneratorOptions(
            imageQuality: 1,
          ),
        );

        expect(result.bytes, isNotEmpty);
        expect(result.pageCount, 1);
      });

      test('should accept quality at upper bound (100)', () async {
        final generator = PDFGenerator();
        final testImage = createTestImage(width: 500, height: 500);

        final result = await generator.generateFromBytes(
          imageBytesList: [testImage],
          options: const PDFGeneratorOptions(
            imageQuality: 100,
          ),
        );

        expect(result.bytes, isNotEmpty);
        expect(result.pageCount, 1);
      });
    });

    group('multi-page compression', () {
      test('should compress all pages in multi-page PDF', () async {
        final generator = PDFGenerator();
        final image1 = createLargeTestImage(width: 2500, height: 1800);
        final image2 = createLargeTestImage(width: 2500, height: 1800);

        // Generate with compression
        final compressedResult = await generator.generateFromBytes(
          imageBytesList: [image1, image2],
          options: const PDFGeneratorOptions(
            imageQuality: 70,
            maxWidth: 1500,
          ),
        );

        // Generate without compression
        final uncompressedResult = await generator.generateFromBytes(
          imageBytesList: [image1, image2],
          options: const PDFGeneratorOptions(
            compressImages: false,
          ),
        );

        // Compressed PDF should be significantly smaller
        expect(compressedResult.pageCount, 2);
        expect(uncompressedResult.pageCount, 2);
        expect(
          compressedResult.fileSize,
          lessThan(uncompressedResult.fileSize),
        );
      });
    });

    group('Compression with different image formats', () {
      test('should handle PNG images with compression', () async {
        final generator = PDFGenerator();

        // Create a PNG image
        final image = img.Image(width: 800, height: 600);
        for (var y = 0; y < 600; y++) {
          for (var x = 0; x < 800; x++) {
            image.setPixel(x, y, img.ColorRgb8(100, 150, 200));
          }
        }
        final pngBytes = Uint8List.fromList(img.encodePng(image));

        // Should compress PNG and convert to JPEG
        final result = await generator.generateFromBytes(
          imageBytesList: [pngBytes],
        );

        expect(result.bytes, isNotEmpty);
        expect(result.pageCount, 1);
      });
    });

    group('Compression options interaction', () {
      test('should work with document preset', () async {
        final generator = PDFGenerator();
        final testImage = createTestImage(width: 1000, height: 800);

        final result = await generator.generateFromBytes(
          imageBytesList: [testImage],
          options: PDFGeneratorOptions.document,
        );

        expect(result.bytes, isNotEmpty);
        expect(result.pageCount, 1);
      });

      test('should work with fullPage preset', () async {
        final generator = PDFGenerator();
        final testImage = createTestImage(width: 1000, height: 800);

        final result = await generator.generateFromBytes(
          imageBytesList: [testImage],
          options: PDFGeneratorOptions.fullPage,
        );

        expect(result.bytes, isNotEmpty);
        expect(result.pageCount, 1);
      });

      test('should work with photo preset', () async {
        final generator = PDFGenerator();
        final testImage = createTestImage(width: 1000, height: 800);

        final result = await generator.generateFromBytes(
          imageBytesList: [testImage],
          options: PDFGeneratorOptions.photo,
        );

        expect(result.bytes, isNotEmpty);
        expect(result.pageCount, 1);
      });

      test('should combine compression with custom margins', () async {
        final generator = PDFGenerator();
        final testImage = createTestImage(width: 1000, height: 800);

        final result = await generator.generateFromBytes(
          imageBytesList: [testImage],
          options: const PDFGeneratorOptions(
            imageQuality: 80,
            maxWidth: 1500,
            marginLeft: 20,
            marginRight: 20,
            marginTop: 20,
            marginBottom: 20,
          ),
        );

        expect(result.bytes, isNotEmpty);
        expect(result.pageCount, 1);
      });
    });
  });
}
