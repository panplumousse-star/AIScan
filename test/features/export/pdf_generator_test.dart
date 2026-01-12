import 'dart:io';
import 'dart:typed_data';

import 'package:aiscan/features/export/domain/pdf_generator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
      final bytes = Uint8List.fromList(
          List.generate(1024 * 1024 * 2, (i) => 0)); // 2MB
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
        creationDate: DateTime(2024, 1, 1),
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
      expect(options.producer, 'AIScan');
      expect(options.creator, 'AIScan Document Scanner');
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
        pageSize: PDFPageSize.a4,
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
        pageSize: PDFPageSize.a4,
      );

      const options2 = PDFGeneratorOptions(
        title: 'Test',
        pageSize: PDFPageSize.a4,
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
        pageSize: PDFPageSize.a4,
      );

      const options2 = PDFGeneratorOptions(
        title: 'Test',
        pageSize: PDFPageSize.a4,
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
      final page2 = PDFPage.fromBytes(
          imageBytes: Uint8List.fromList([1, 2, 3]));
      final page3 = PDFPage.fromBytes(
          imageBytes: Uint8List.fromList([4, 5, 6]));

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
      final page2 = PDFPage.fromBytes(
          imageBytes: Uint8List.fromList([1, 2, 3]));

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

    test('generateFromBytes should throw PDFGeneratorException on invalid input',
        () async {
      expect(
        () => generator.generateFromBytes(imageBytesList: []),
        throwsA(isA<PDFGeneratorException>()),
      );
    });

    test('generateFromFiles should throw PDFGeneratorException on invalid input',
        () async {
      expect(
        () => generator.generateFromFiles(imagePaths: []),
        throwsA(isA<PDFGeneratorException>()),
      );
    });

    test('generateFromPages should throw PDFGeneratorException on invalid input',
        () async {
      expect(
        () => generator.generateFromPages(pages: []),
        throwsA(isA<PDFGeneratorException>()),
      );
    });

    test('generateToFile should throw PDFGeneratorException on empty output path',
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
}
