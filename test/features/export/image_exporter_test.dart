import 'dart:io';
import 'dart:typed_data';

import 'package:aiscan/features/export/domain/image_exporter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  // Helper to create a test image
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

  // Helper to create a PNG test image
  Uint8List createTestPngImage({int width = 100, int height = 100}) {
    final image = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixel(x, y, img.ColorRgb8(128, 128, 128));
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  group('ImageExporterException', () {
    test('should create exception with message only', () {
      const exception = ImageExporterException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.cause, isNull);
      expect(exception.toString(), 'ImageExporterException: Test error');
    });

    test('should create exception with message and cause', () {
      final cause = Exception('Underlying error');
      final exception = ImageExporterException('Test error', cause: cause);

      expect(exception.message, 'Test error');
      expect(exception.cause, cause);
      expect(
        exception.toString(),
        'ImageExporterException: Test error (caused by: $cause)',
      );
    });
  });

  group('ExportedImage', () {
    test('should create with required fields', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = ExportedImage(
        bytes: bytes,
        width: 100,
        height: 200,
        format: ExportImageFormat.jpeg,
      );

      expect(result.bytes, bytes);
      expect(result.width, 100);
      expect(result.height, 200);
      expect(result.format, ExportImageFormat.jpeg);
      expect(result.quality, isNull);
      expect(result.originalFileName, isNull);
    });

    test('should create with all fields', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = ExportedImage(
        bytes: bytes,
        width: 100,
        height: 200,
        format: ExportImageFormat.jpeg,
        quality: 90,
        originalFileName: 'test.jpg',
      );

      expect(result.bytes, bytes);
      expect(result.width, 100);
      expect(result.height, 200);
      expect(result.format, ExportImageFormat.jpeg);
      expect(result.quality, 90);
      expect(result.originalFileName, 'test.jpg');
    });

    test('should calculate fileSize correctly', () {
      final bytes = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      final result = ExportedImage(
        bytes: bytes,
        width: 100,
        height: 100,
        format: ExportImageFormat.jpeg,
      );

      expect(result.fileSize, 1000);
    });

    test('should format file size in bytes', () {
      final bytes = Uint8List.fromList(List.generate(500, (i) => 0));
      final result = ExportedImage(
        bytes: bytes,
        width: 100,
        height: 100,
        format: ExportImageFormat.jpeg,
      );

      expect(result.fileSizeFormatted, '500 B');
    });

    test('should format file size in KB', () {
      final bytes = Uint8List.fromList(List.generate(2048, (i) => 0));
      final result = ExportedImage(
        bytes: bytes,
        width: 100,
        height: 100,
        format: ExportImageFormat.jpeg,
      );

      expect(result.fileSizeFormatted, '2.0 KB');
    });

    test('should format file size in MB', () {
      final bytes = Uint8List.fromList(
          List.generate(1024 * 1024 * 2, (i) => 0)); // 2MB
      final result = ExportedImage(
        bytes: bytes,
        width: 100,
        height: 100,
        format: ExportImageFormat.jpeg,
      );

      expect(result.fileSizeFormatted, '2.0 MB');
    });

    test('should return correct file extension for jpeg', () {
      final result = ExportedImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        width: 100,
        height: 100,
        format: ExportImageFormat.jpeg,
      );

      expect(result.fileExtension, 'jpg');
    });

    test('should return correct file extension for png', () {
      final result = ExportedImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        width: 100,
        height: 100,
        format: ExportImageFormat.png,
      );

      expect(result.fileExtension, 'png');
    });

    test('should support copyWith for all fields', () {
      final original = ExportedImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        width: 100,
        height: 100,
        format: ExportImageFormat.jpeg,
        quality: 90,
        originalFileName: 'original.jpg',
      );

      final modified = original.copyWith(
        width: 200,
        quality: 80,
      );

      expect(modified.width, 200);
      expect(modified.quality, 80);
      expect(modified.height, 100); // Unchanged
      expect(modified.originalFileName, 'original.jpg'); // Unchanged
    });

    test('should support copyWith with clear flags', () {
      final original = ExportedImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        width: 100,
        height: 100,
        format: ExportImageFormat.jpeg,
        quality: 90,
        originalFileName: 'original.jpg',
      );

      final modified = original.copyWith(
        clearQuality: true,
        clearOriginalFileName: true,
      );

      expect(modified.quality, isNull);
      expect(modified.originalFileName, isNull);
      expect(modified.width, 100); // Unchanged
    });

    test('should have correct equality', () {
      final bytes = Uint8List.fromList([1, 2, 3]);

      final result1 = ExportedImage(
        bytes: bytes,
        width: 100,
        height: 100,
        format: ExportImageFormat.jpeg,
        quality: 90,
      );

      final result2 = ExportedImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        width: 100,
        height: 100,
        format: ExportImageFormat.jpeg,
        quality: 90,
      );

      final result3 = ExportedImage(
        bytes: bytes,
        width: 200, // Different
        height: 100,
        format: ExportImageFormat.jpeg,
      );

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });

    test('should have correct hashCode', () {
      final bytes = Uint8List.fromList([1, 2, 3]);

      final result1 = ExportedImage(
        bytes: bytes,
        width: 100,
        height: 100,
        format: ExportImageFormat.jpeg,
      );

      final result2 = ExportedImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        width: 100,
        height: 100,
        format: ExportImageFormat.jpeg,
      );

      expect(result1.hashCode, equals(result2.hashCode));
    });

    test('should have meaningful toString', () {
      final result = ExportedImage(
        bytes: Uint8List.fromList(List.generate(1000, (i) => 0)),
        width: 100,
        height: 200,
        format: ExportImageFormat.jpeg,
      );

      expect(result.toString(), contains('100x200'));
      expect(result.toString(), contains('jpeg'));
    });
  });

  group('BatchExportResult', () {
    test('should create with required fields', () {
      final exportedImages = <ExportedImage>[
        ExportedImage(
          bytes: Uint8List.fromList([1, 2, 3]),
          width: 100,
          height: 100,
          format: ExportImageFormat.jpeg,
        ),
        ExportedImage(
          bytes: Uint8List.fromList([4, 5, 6]),
          width: 200,
          height: 200,
          format: ExportImageFormat.jpeg,
        ),
      ];

      final result = BatchExportResult(
        exportedImages: exportedImages,
        totalFileSize: 6,
      );

      expect(result.exportedImages, exportedImages);
      expect(result.totalFileSize, 6);
      expect(result.outputDirectory, isNull);
      expect(result.baseName, isNull);
      expect(result.imageCount, 2);
    });

    test('should create with all fields', () {
      final exportedImages = <ExportedImage>[
        ExportedImage(
          bytes: Uint8List.fromList([1, 2, 3]),
          width: 100,
          height: 100,
          format: ExportImageFormat.jpeg,
        ),
      ];

      final result = BatchExportResult(
        exportedImages: exportedImages,
        totalFileSize: 3,
        outputDirectory: '/path/to/output',
        baseName: 'scan',
      );

      expect(result.outputDirectory, '/path/to/output');
      expect(result.baseName, 'scan');
    });

    test('should format total file size in bytes', () {
      final result = BatchExportResult(
        exportedImages: [],
        totalFileSize: 500,
      );

      expect(result.totalFileSizeFormatted, '500 B');
    });

    test('should format total file size in KB', () {
      final result = BatchExportResult(
        exportedImages: [],
        totalFileSize: 2048,
      );

      expect(result.totalFileSizeFormatted, '2.0 KB');
    });

    test('should format total file size in MB', () {
      final result = BatchExportResult(
        exportedImages: [],
        totalFileSize: 1024 * 1024 * 2,
      );

      expect(result.totalFileSizeFormatted, '2.0 MB');
    });

    test('should have correct equality', () {
      final images = <ExportedImage>[
        ExportedImage(
          bytes: Uint8List.fromList([1, 2, 3]),
          width: 100,
          height: 100,
          format: ExportImageFormat.jpeg,
        ),
      ];

      final result1 = BatchExportResult(
        exportedImages: images,
        totalFileSize: 3,
      );

      final result2 = BatchExportResult(
        exportedImages: [
          ExportedImage(
            bytes: Uint8List.fromList([1, 2, 3]),
            width: 100,
            height: 100,
            format: ExportImageFormat.jpeg,
          ),
        ],
        totalFileSize: 3,
      );

      final result3 = BatchExportResult(
        exportedImages: images,
        totalFileSize: 100, // Different
      );

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });

    test('should have correct hashCode', () {
      final images = <ExportedImage>[
        ExportedImage(
          bytes: Uint8List.fromList([1, 2, 3]),
          width: 100,
          height: 100,
          format: ExportImageFormat.jpeg,
        ),
      ];

      final result1 = BatchExportResult(
        exportedImages: images,
        totalFileSize: 3,
      );

      final result2 = BatchExportResult(
        exportedImages: [
          ExportedImage(
            bytes: Uint8List.fromList([1, 2, 3]),
            width: 100,
            height: 100,
            format: ExportImageFormat.jpeg,
          ),
        ],
        totalFileSize: 3,
      );

      expect(result1.hashCode, equals(result2.hashCode));
    });

    test('should have meaningful toString', () {
      final result = BatchExportResult(
        exportedImages: [
          ExportedImage(
            bytes: Uint8List.fromList([1, 2, 3]),
            width: 100,
            height: 100,
            format: ExportImageFormat.jpeg,
          ),
          ExportedImage(
            bytes: Uint8List.fromList([4, 5, 6]),
            width: 200,
            height: 200,
            format: ExportImageFormat.jpeg,
          ),
        ],
        totalFileSize: 2048,
      );

      expect(result.toString(), contains('images: 2'));
      expect(result.toString(), contains('2.0 KB'));
    });
  });

  group('ExportImageFormat', () {
    test('should have all expected values', () {
      expect(ExportImageFormat.values, contains(ExportImageFormat.jpeg));
      expect(ExportImageFormat.values, contains(ExportImageFormat.png));
    });
  });

  group('ExportResizeMode', () {
    test('should have all expected values', () {
      expect(ExportResizeMode.values, contains(ExportResizeMode.original));
      expect(ExportResizeMode.values, contains(ExportResizeMode.fitWithin));
      expect(ExportResizeMode.values, contains(ExportResizeMode.exact));
      expect(ExportResizeMode.values, contains(ExportResizeMode.scale));
    });
  });

  group('ImageExportOptions', () {
    test('should create with default values', () {
      const options = ImageExportOptions();

      expect(options.format, ExportImageFormat.jpeg);
      expect(options.quality, 90);
      expect(options.resizeMode, ExportResizeMode.original);
      expect(options.maxWidth, isNull);
      expect(options.maxHeight, isNull);
      expect(options.scaleFactor, 1.0);
      expect(options.preserveMetadata, false);
    });

    test('should create highQuality preset correctly', () {
      const options = ImageExportOptions.highQuality;

      expect(options.format, ExportImageFormat.jpeg);
      expect(options.quality, 95);
      expect(options.resizeMode, ExportResizeMode.original);
    });

    test('should create webOptimized preset correctly', () {
      const options = ImageExportOptions.webOptimized;

      expect(options.format, ExportImageFormat.jpeg);
      expect(options.quality, 80);
      expect(options.resizeMode, ExportResizeMode.fitWithin);
      expect(options.maxWidth, 2000);
      expect(options.maxHeight, 2000);
    });

    test('should create thumbnail preset correctly', () {
      const options = ImageExportOptions.thumbnail;

      expect(options.format, ExportImageFormat.jpeg);
      expect(options.quality, 75);
      expect(options.resizeMode, ExportResizeMode.fitWithin);
      expect(options.maxWidth, 300);
      expect(options.maxHeight, 300);
    });

    test('should create preview preset correctly', () {
      const options = ImageExportOptions.preview;

      expect(options.format, ExportImageFormat.jpeg);
      expect(options.quality, 85);
      expect(options.resizeMode, ExportResizeMode.fitWithin);
      expect(options.maxWidth, 800);
      expect(options.maxHeight, 800);
    });

    test('should create lossless preset correctly', () {
      const options = ImageExportOptions.lossless;

      expect(options.format, ExportImageFormat.png);
      expect(options.resizeMode, ExportResizeMode.original);
    });

    test('should support copyWith for all fields', () {
      const original = ImageExportOptions(
        format: ExportImageFormat.jpeg,
        quality: 90,
        maxWidth: 1000,
      );

      final modified = original.copyWith(
        quality: 80,
        maxHeight: 500,
      );

      expect(modified.quality, 80);
      expect(modified.maxHeight, 500);
      expect(modified.format, ExportImageFormat.jpeg); // Unchanged
      expect(modified.maxWidth, 1000); // Unchanged
    });

    test('should support copyWith with clear flags', () {
      const original = ImageExportOptions(
        maxWidth: 1000,
        maxHeight: 800,
      );

      final modified = original.copyWith(
        clearMaxWidth: true,
        clearMaxHeight: true,
      );

      expect(modified.maxWidth, isNull);
      expect(modified.maxHeight, isNull);
      expect(modified.format, ExportImageFormat.jpeg); // Unchanged
    });

    test('should have correct equality', () {
      const options1 = ImageExportOptions(
        format: ExportImageFormat.jpeg,
        quality: 90,
      );

      const options2 = ImageExportOptions(
        format: ExportImageFormat.jpeg,
        quality: 90,
      );

      const options3 = ImageExportOptions(
        format: ExportImageFormat.png, // Different
        quality: 90,
      );

      expect(options1, equals(options2));
      expect(options1, isNot(equals(options3)));
    });

    test('should have correct hashCode', () {
      const options1 = ImageExportOptions(
        format: ExportImageFormat.jpeg,
        quality: 90,
      );

      const options2 = ImageExportOptions(
        format: ExportImageFormat.jpeg,
        quality: 90,
      );

      expect(options1.hashCode, equals(options2.hashCode));
    });

    test('should have meaningful toString', () {
      const options = ImageExportOptions(
        format: ExportImageFormat.jpeg,
        quality: 90,
        resizeMode: ExportResizeMode.fitWithin,
      );

      expect(options.toString(), contains('jpeg'));
      expect(options.toString(), contains('90'));
      expect(options.toString(), contains('fitWithin'));
    });
  });

  group('ImageExporter', () {
    late ImageExporter exporter;

    setUp(() {
      exporter = ImageExporter();
    });

    group('exportFromBytes', () {
      test('should export image successfully', () async {
        final testImage = createTestImage();

        final result = await exporter.exportFromBytes(testImage);

        expect(result.bytes, isNotEmpty);
        expect(result.width, 100);
        expect(result.height, 100);
        expect(result.format, ExportImageFormat.jpeg);
      });

      test('should preserve original file name if provided', () async {
        final testImage = createTestImage();

        final result = await exporter.exportFromBytes(
          testImage,
          originalFileName: 'test_image.jpg',
        );

        expect(result.originalFileName, 'test_image.jpg');
      });

      test('should export as PNG', () async {
        final testImage = createTestImage();

        final result = await exporter.exportFromBytes(
          testImage,
          options: const ImageExportOptions(format: ExportImageFormat.png),
        );

        expect(result.format, ExportImageFormat.png);
        // PNG magic bytes
        expect(result.bytes[0], 0x89);
        expect(result.bytes[1], 0x50);
        expect(result.bytes[2], 0x4E);
      });

      test('should respect quality parameter', () async {
        final testImage = createTestImage(width: 200, height: 200);

        final highQuality = await exporter.exportFromBytes(
          testImage,
          options: const ImageExportOptions(quality: 100),
        );

        final lowQuality = await exporter.exportFromBytes(
          testImage,
          options: const ImageExportOptions(quality: 10),
        );

        expect(highQuality.fileSize, greaterThan(lowQuality.fileSize));
      });

      test('should throw on empty bytes', () async {
        expect(
          () => exporter.exportFromBytes(Uint8List(0)),
          throwsA(isA<ImageExporterException>().having(
            (e) => e.message,
            'message',
            contains('cannot be empty'),
          )),
        );
      });

      test('should resize with fitWithin mode', () async {
        final testImage = createTestImage(width: 500, height: 300);

        final result = await exporter.exportFromBytes(
          testImage,
          options: const ImageExportOptions(
            resizeMode: ExportResizeMode.fitWithin,
            maxWidth: 200,
            maxHeight: 200,
          ),
        );

        expect(result.width, lessThanOrEqualTo(200));
        expect(result.height, lessThanOrEqualTo(200));
      });

      test('should not upscale with fitWithin mode', () async {
        final testImage = createTestImage(width: 50, height: 50);

        final result = await exporter.exportFromBytes(
          testImage,
          options: const ImageExportOptions(
            resizeMode: ExportResizeMode.fitWithin,
            maxWidth: 200,
            maxHeight: 200,
          ),
        );

        expect(result.width, 50);
        expect(result.height, 50);
      });

      test('should resize with scale mode', () async {
        final testImage = createTestImage(width: 100, height: 100);

        final result = await exporter.exportFromBytes(
          testImage,
          options: const ImageExportOptions(
            resizeMode: ExportResizeMode.scale,
            scaleFactor: 0.5,
          ),
        );

        expect(result.width, 50);
        expect(result.height, 50);
      });

      test('should resize with exact mode', () async {
        final testImage = createTestImage(width: 100, height: 100);

        final result = await exporter.exportFromBytes(
          testImage,
          options: const ImageExportOptions(
            resizeMode: ExportResizeMode.exact,
            maxWidth: 200,
            maxHeight: 150,
          ),
        );

        expect(result.width, 200);
        expect(result.height, 150);
      });

      test('should maintain original size with original mode', () async {
        final testImage = createTestImage(width: 100, height: 100);

        final result = await exporter.exportFromBytes(
          testImage,
          options: const ImageExportOptions(
            resizeMode: ExportResizeMode.original,
          ),
        );

        expect(result.width, 100);
        expect(result.height, 100);
      });
    });

    group('exportFromFile', () {
      late Directory tempDir;
      late String testImagePath;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('exporter_test_');
        testImagePath = '${tempDir.path}/test_image.jpg';

        final testImage = createTestImage();
        await File(testImagePath).writeAsBytes(testImage);
      });

      tearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('should export image from file', () async {
        final result = await exporter.exportFromFile(testImagePath);

        expect(result.bytes, isNotEmpty);
        expect(result.width, 100);
        expect(result.height, 100);
        expect(result.originalFileName, 'test_image.jpg');
      });

      test('should throw on empty path', () async {
        expect(
          () => exporter.exportFromFile(''),
          throwsA(isA<ImageExporterException>().having(
            (e) => e.message,
            'message',
            contains('cannot be empty'),
          )),
        );
      });

      test('should throw on non-existent file', () async {
        expect(
          () => exporter.exportFromFile('${tempDir.path}/nonexistent.jpg'),
          throwsA(isA<ImageExporterException>().having(
            (e) => e.message,
            'message',
            contains('not found'),
          )),
        );
      });
    });

    group('exportToFile', () {
      late Directory tempDir;
      late String outputPath;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('exporter_test_');
        outputPath = '${tempDir.path}/output.jpg';
      });

      tearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('should save exported image to file', () async {
        final testImage = createTestImage();

        final result = await exporter.exportToFile(
          testImage,
          outputPath: outputPath,
        );

        expect(result.bytes, isNotEmpty);
        expect(await File(outputPath).exists(), true);

        final savedBytes = await File(outputPath).readAsBytes();
        expect(savedBytes, result.bytes);
      });

      test('should create parent directories', () async {
        final testImage = createTestImage();
        final nestedPath = '${tempDir.path}/nested/dir/output.jpg';

        await exporter.exportToFile(
          testImage,
          outputPath: nestedPath,
        );

        expect(await File(nestedPath).exists(), true);
      });

      test('should throw on empty output path', () async {
        final testImage = createTestImage();

        expect(
          () => exporter.exportToFile(testImage, outputPath: ''),
          throwsA(isA<ImageExporterException>().having(
            (e) => e.message,
            'message',
            contains('cannot be empty'),
          )),
        );
      });
    });

    group('exportFileToFile', () {
      late Directory tempDir;
      late String inputPath;
      late String outputPath;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('exporter_test_');
        inputPath = '${tempDir.path}/input.jpg';
        outputPath = '${tempDir.path}/output.jpg';

        final testImage = createTestImage();
        await File(inputPath).writeAsBytes(testImage);
      });

      tearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('should export from file to file', () async {
        final result = await exporter.exportFileToFile(inputPath, outputPath);

        expect(result.bytes, isNotEmpty);
        expect(await File(outputPath).exists(), true);
      });

      test('should throw on empty paths', () async {
        expect(
          () => exporter.exportFileToFile('', outputPath),
          throwsA(isA<ImageExporterException>()),
        );

        expect(
          () => exporter.exportFileToFile(inputPath, ''),
          throwsA(isA<ImageExporterException>()),
        );
      });

      test('should throw on same input and output path', () async {
        expect(
          () => exporter.exportFileToFile(inputPath, inputPath),
          throwsA(isA<ImageExporterException>().having(
            (e) => e.message,
            'message',
            contains('must be different'),
          )),
        );
      });
    });

    group('exportBatch', () {
      test('should export multiple images', () async {
        final images = [
          createTestImage(width: 100, height: 100),
          createTestImage(width: 150, height: 150),
          createTestImage(width: 200, height: 200),
        ];

        final result = await exporter.exportBatch(imageBytesList: images);

        expect(result.imageCount, 3);
        expect(result.exportedImages.length, 3);
        expect(result.exportedImages[0].width, 100);
        expect(result.exportedImages[1].width, 150);
        expect(result.exportedImages[2].width, 200);
      });

      test('should throw on empty list', () async {
        expect(
          () => exporter.exportBatch(imageBytesList: []),
          throwsA(isA<ImageExporterException>().having(
            (e) => e.message,
            'message',
            contains('cannot be empty'),
          )),
        );
      });

      test('should throw on list with empty bytes', () async {
        expect(
          () => exporter.exportBatch(
            imageBytesList: [
              createTestImage(),
              Uint8List(0),
            ],
          ),
          throwsA(isA<ImageExporterException>().having(
            (e) => e.message,
            'message',
            contains('index 1'),
          )),
        );
      });
    });

    group('exportBatchFromFiles', () {
      late Directory tempDir;
      late List<String> imagePaths;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('exporter_test_');
        imagePaths = [];

        for (var i = 0; i < 3; i++) {
          final path = '${tempDir.path}/image_$i.jpg';
          final testImage = createTestImage(width: 100 + i * 50, height: 100 + i * 50);
          await File(path).writeAsBytes(testImage);
          imagePaths.add(path);
        }
      });

      tearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('should export multiple images from files', () async {
        final result = await exporter.exportBatchFromFiles(imagePaths: imagePaths);

        expect(result.imageCount, 3);
        expect(result.exportedImages.length, 3);
      });

      test('should throw on empty list', () async {
        expect(
          () => exporter.exportBatchFromFiles(imagePaths: []),
          throwsA(isA<ImageExporterException>().having(
            (e) => e.message,
            'message',
            contains('cannot be empty'),
          )),
        );
      });

      test('should throw on list with empty path', () async {
        expect(
          () => exporter.exportBatchFromFiles(
            imagePaths: [imagePaths[0], ''],
          ),
          throwsA(isA<ImageExporterException>().having(
            (e) => e.message,
            'message',
            contains('index 1'),
          )),
        );
      });
    });

    group('exportBatchToDirectory', () {
      late Directory tempDir;
      late String outputDirectory;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('exporter_test_');
        outputDirectory = '${tempDir.path}/output';
      });

      tearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('should export images to directory with numbered names', () async {
        final images = [
          createTestImage(),
          createTestImage(),
          createTestImage(),
        ];

        final result = await exporter.exportBatchToDirectory(
          imageBytesList: images,
          outputDirectory: outputDirectory,
          baseName: 'scan',
        );

        expect(result.imageCount, 3);
        expect(result.outputDirectory, outputDirectory);
        expect(result.baseName, 'scan');

        // Check files exist with correct names
        expect(await File('$outputDirectory/scan_001.jpg').exists(), true);
        expect(await File('$outputDirectory/scan_002.jpg').exists(), true);
        expect(await File('$outputDirectory/scan_003.jpg').exists(), true);
      });

      test('should create output directory if it does not exist', () async {
        final images = [createTestImage()];

        await exporter.exportBatchToDirectory(
          imageBytesList: images,
          outputDirectory: outputDirectory,
        );

        expect(await Directory(outputDirectory).exists(), true);
      });

      test('should use png extension for PNG format', () async {
        final images = [createTestImage()];

        await exporter.exportBatchToDirectory(
          imageBytesList: images,
          outputDirectory: outputDirectory,
          baseName: 'scan',
          options: const ImageExportOptions(format: ExportImageFormat.png),
        );

        expect(await File('$outputDirectory/scan_001.png').exists(), true);
      });

      test('should throw on empty list', () async {
        expect(
          () => exporter.exportBatchToDirectory(
            imageBytesList: [],
            outputDirectory: outputDirectory,
          ),
          throwsA(isA<ImageExporterException>().having(
            (e) => e.message,
            'message',
            contains('cannot be empty'),
          )),
        );
      });

      test('should throw on empty output directory', () async {
        expect(
          () => exporter.exportBatchToDirectory(
            imageBytesList: [createTestImage()],
            outputDirectory: '',
          ),
          throwsA(isA<ImageExporterException>().having(
            (e) => e.message,
            'message',
            contains('cannot be empty'),
          )),
        );
      });
    });

    group('createThumbnail', () {
      test('should create thumbnail with default dimensions', () async {
        final testImage = createTestImage(width: 500, height: 400);

        final result = await exporter.createThumbnail(testImage);

        expect(result.width, lessThanOrEqualTo(300));
        expect(result.height, lessThanOrEqualTo(300));
      });

      test('should create thumbnail with custom dimensions', () async {
        final testImage = createTestImage(width: 500, height: 400);

        final result = await exporter.createThumbnail(
          testImage,
          maxWidth: 150,
          maxHeight: 150,
        );

        expect(result.width, lessThanOrEqualTo(150));
        expect(result.height, lessThanOrEqualTo(150));
      });

      test('should maintain aspect ratio', () async {
        final testImage = createTestImage(width: 400, height: 200);

        final result = await exporter.createThumbnail(
          testImage,
          maxWidth: 200,
          maxHeight: 200,
        );

        // Original aspect ratio is 2:1
        expect(result.width, 200);
        expect(result.height, 100);
      });
    });

    group('createPreview', () {
      test('should create preview with default dimensions', () async {
        final testImage = createTestImage(width: 1000, height: 800);

        final result = await exporter.createPreview(testImage);

        expect(result.width, lessThanOrEqualTo(800));
        expect(result.height, lessThanOrEqualTo(800));
      });

      test('should create preview with custom dimensions', () async {
        final testImage = createTestImage(width: 1000, height: 800);

        final result = await exporter.createPreview(
          testImage,
          maxWidth: 400,
          maxHeight: 400,
        );

        expect(result.width, lessThanOrEqualTo(400));
        expect(result.height, lessThanOrEqualTo(400));
      });
    });

    group('stitchVertical', () {
      test('should stitch images vertically', () async {
        final images = [
          createTestImage(width: 100, height: 50),
          createTestImage(width: 100, height: 50),
          createTestImage(width: 100, height: 50),
        ];

        final result = await exporter.stitchVertical(imageBytesList: images);

        expect(result.width, 100);
        expect(result.height, 150); // 50 * 3
      });

      test('should center narrower images', () async {
        final images = [
          createTestImage(width: 100, height: 50),
          createTestImage(width: 50, height: 50),
        ];

        final result = await exporter.stitchVertical(imageBytesList: images);

        expect(result.width, 100); // Width of widest image
      });

      test('should add spacing between images', () async {
        final images = [
          createTestImage(width: 100, height: 50),
          createTestImage(width: 100, height: 50),
        ];

        final result = await exporter.stitchVertical(
          imageBytesList: images,
          spacing: 10,
        );

        expect(result.height, 110); // 50 + 10 + 50
      });

      test('should return single image for single element list', () async {
        final images = [createTestImage(width: 100, height: 50)];

        final result = await exporter.stitchVertical(imageBytesList: images);

        expect(result.width, 100);
        expect(result.height, 50);
      });

      test('should throw on empty list', () async {
        expect(
          () => exporter.stitchVertical(imageBytesList: []),
          throwsA(isA<ImageExporterException>().having(
            (e) => e.message,
            'message',
            contains('cannot be empty'),
          )),
        );
      });
    });

    group('stitchHorizontal', () {
      test('should stitch images horizontally', () async {
        final images = [
          createTestImage(width: 50, height: 100),
          createTestImage(width: 50, height: 100),
          createTestImage(width: 50, height: 100),
        ];

        final result = await exporter.stitchHorizontal(imageBytesList: images);

        expect(result.width, 150); // 50 * 3
        expect(result.height, 100);
      });

      test('should center shorter images', () async {
        final images = [
          createTestImage(width: 50, height: 100),
          createTestImage(width: 50, height: 50),
        ];

        final result = await exporter.stitchHorizontal(imageBytesList: images);

        expect(result.height, 100); // Height of tallest image
      });

      test('should add spacing between images', () async {
        final images = [
          createTestImage(width: 50, height: 100),
          createTestImage(width: 50, height: 100),
        ];

        final result = await exporter.stitchHorizontal(
          imageBytesList: images,
          spacing: 10,
        );

        expect(result.width, 110); // 50 + 10 + 50
      });

      test('should return single image for single element list', () async {
        final images = [createTestImage(width: 50, height: 100)];

        final result = await exporter.stitchHorizontal(imageBytesList: images);

        expect(result.width, 50);
        expect(result.height, 100);
      });

      test('should throw on empty list', () async {
        expect(
          () => exporter.stitchHorizontal(imageBytesList: []),
          throwsA(isA<ImageExporterException>().having(
            (e) => e.message,
            'message',
            contains('cannot be empty'),
          )),
        );
      });
    });
  });

  group('imageExporterProvider', () {
    test('should provide ImageExporter instance', () {
      final container = ProviderContainer();

      final exporter = container.read(imageExporterProvider);

      expect(exporter, isA<ImageExporter>());

      container.dispose();
    });

    test('should return same instance on multiple reads', () {
      final container = ProviderContainer();

      final exporter1 = container.read(imageExporterProvider);
      final exporter2 = container.read(imageExporterProvider);

      expect(identical(exporter1, exporter2), true);

      container.dispose();
    });
  });

  group('Error Handling', () {
    late ImageExporter exporter;

    setUp(() {
      exporter = ImageExporter();
    });

    test('exportFromBytes should throw ImageExporterException on invalid input',
        () async {
      expect(
        () => exporter.exportFromBytes(Uint8List(0)),
        throwsA(isA<ImageExporterException>()),
      );
    });

    test('exportFromBytes should throw on invalid image data', () async {
      expect(
        () => exporter.exportFromBytes(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<ImageExporterException>()),
      );
    });

    test('exportFromFile should throw ImageExporterException on invalid input',
        () async {
      expect(
        () => exporter.exportFromFile(''),
        throwsA(isA<ImageExporterException>()),
      );
    });

    test('exportToFile should throw ImageExporterException on empty path',
        () async {
      expect(
        () => exporter.exportToFile(
          createTestImage(),
          outputPath: '',
        ),
        throwsA(isA<ImageExporterException>()),
      );
    });

    test('exportBatch should throw ImageExporterException on empty list',
        () async {
      expect(
        () => exporter.exportBatch(imageBytesList: []),
        throwsA(isA<ImageExporterException>()),
      );
    });

    test('stitchVertical should throw ImageExporterException on empty list',
        () async {
      expect(
        () => exporter.stitchVertical(imageBytesList: []),
        throwsA(isA<ImageExporterException>()),
      );
    });

    test('stitchHorizontal should throw ImageExporterException on empty list',
        () async {
      expect(
        () => exporter.stitchHorizontal(imageBytesList: []),
        throwsA(isA<ImageExporterException>()),
      );
    });
  });

  group('Integration Tests', () {
    late ImageExporter exporter;
    late Directory tempDir;

    setUp(() async {
      exporter = ImageExporter();
      tempDir = await Directory.systemTemp.createTemp('exporter_integration_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should round-trip export and decode successfully', () async {
      final originalImage = createTestImage(width: 200, height: 150);

      final result = await exporter.exportFromBytes(originalImage);

      // Verify the exported image can be decoded
      final decodedImage = img.decodeImage(result.bytes);
      expect(decodedImage, isNotNull);
      expect(decodedImage!.width, 200);
      expect(decodedImage.height, 150);
    });

    test('should process PNG input correctly', () async {
      final pngImage = createTestPngImage(width: 100, height: 100);

      final result = await exporter.exportFromBytes(
        pngImage,
        options: const ImageExportOptions(format: ExportImageFormat.jpeg),
      );

      expect(result.bytes, isNotEmpty);
      expect(result.format, ExportImageFormat.jpeg);
    });

    test('should handle large images without memory issues', () async {
      // Create a moderately large image (but not too large for tests)
      final largeImage = createTestImage(width: 1000, height: 1000);

      final result = await exporter.exportFromBytes(
        largeImage,
        options: ImageExportOptions.webOptimized,
      );

      expect(result.bytes, isNotEmpty);
      expect(result.width, lessThanOrEqualTo(2000));
      expect(result.height, lessThanOrEqualTo(2000));
    });

    test('should complete batch export workflow', () async {
      // Create multiple test images
      final images = List.generate(5, (i) => createTestImage(
        width: 100 + i * 10,
        height: 100 + i * 10,
      ));

      // Export batch to directory
      final result = await exporter.exportBatchToDirectory(
        imageBytesList: images,
        outputDirectory: '${tempDir.path}/batch_output',
        baseName: 'document',
      );

      expect(result.imageCount, 5);

      // Verify all files exist
      for (var i = 1; i <= 5; i++) {
        final fileName = 'document_${i.toString().padLeft(3, '0')}.jpg';
        final filePath = '${tempDir.path}/batch_output/$fileName';
        expect(await File(filePath).exists(), true);
      }
    });

    test('should use preset options correctly', () async {
      final testImage = createTestImage(width: 1000, height: 800);

      // Test thumbnail preset
      final thumbnail = await exporter.exportFromBytes(
        testImage,
        options: ImageExportOptions.thumbnail,
      );
      expect(thumbnail.width, lessThanOrEqualTo(300));
      expect(thumbnail.height, lessThanOrEqualTo(300));

      // Test preview preset
      final preview = await exporter.exportFromBytes(
        testImage,
        options: ImageExportOptions.preview,
      );
      expect(preview.width, lessThanOrEqualTo(800));
      expect(preview.height, lessThanOrEqualTo(800));

      // Test high quality preset
      final highQuality = await exporter.exportFromBytes(
        testImage,
        options: ImageExportOptions.highQuality,
      );
      expect(highQuality.width, 1000);
      expect(highQuality.height, 800);
    });
  });
}
