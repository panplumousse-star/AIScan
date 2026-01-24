import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:aiscan/features/enhancement/domain/image_processor.dart';

void main() {
  late ImageProcessor processor;

  setUp(() {
    processor = ImageProcessor();
  });

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

  // Helper to create a gradient test image for contrast/brightness tests
  Uint8List createGradientTestImage({int width = 100, int height = 100}) {
    final image = img.Image(width: width, height: height);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final value = ((x / width) * 255).round();
        image.setPixel(x, y, img.ColorRgb8(value, value, value));
      }
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 100));
  }

  group('ImageProcessorException', () {
    test('should format message without cause', () {
      const exception = ImageProcessorException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.cause, isNull);
      expect(exception.toString(), 'ImageProcessorException: Test error');
    });

    test('should format message with cause', () {
      final cause = Exception('Root cause');
      final exception = ImageProcessorException('Test error', cause: cause);

      expect(exception.message, 'Test error');
      expect(exception.cause, cause);
      expect(
        exception.toString(),
        contains('ImageProcessorException: Test error'),
      );
      expect(exception.toString(), contains('caused by'));
    });
  });

  group('ProcessedImage', () {
    test('should create with required parameters', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = ProcessedImage(
        bytes: bytes,
        width: 100,
        height: 200,
        format: ImageOutputFormat.jpeg,
      );

      expect(result.bytes, bytes);
      expect(result.width, 100);
      expect(result.height, 200);
      expect(result.format, ImageOutputFormat.jpeg);
      expect(result.operationsApplied, isEmpty);
      expect(result.fileSize, 3);
    });

    test('should support operations list', () {
      final result = ProcessedImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        width: 100,
        height: 100,
        format: ImageOutputFormat.jpeg,
        operationsApplied: ['contrast:20', 'sharpen:50'],
      );

      expect(result.operationsApplied, ['contrast:20', 'sharpen:50']);
    });

    test('should implement copyWith', () {
      final original = ProcessedImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        width: 100,
        height: 100,
        format: ImageOutputFormat.jpeg,
        operationsApplied: ['test'],
      );

      final copied = original.copyWith(width: 200);

      expect(copied.width, 200);
      expect(copied.height, 100); // unchanged
      expect(copied.bytes, original.bytes);
      expect(copied.operationsApplied, original.operationsApplied);
    });

    test('should implement equality', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result1 = ProcessedImage(
        bytes: bytes,
        width: 100,
        height: 100,
        format: ImageOutputFormat.jpeg,
      );
      final result2 = ProcessedImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        width: 100,
        height: 100,
        format: ImageOutputFormat.jpeg,
      );
      final result3 = ProcessedImage(
        bytes: bytes,
        width: 200,
        height: 100,
        format: ImageOutputFormat.jpeg,
      );

      expect(result1, equals(result2));
      expect(result1.hashCode, equals(result2.hashCode));
      expect(result1, isNot(equals(result3)));
    });

    test('should format toString', () {
      final result = ProcessedImage(
        bytes: Uint8List(1024),
        width: 100,
        height: 200,
        format: ImageOutputFormat.jpeg,
        operationsApplied: ['test'],
      );

      expect(result.toString(), contains('100x200'));
      expect(result.toString(), contains('jpeg'));
      expect(result.toString(), contains('1.0KB'));
    });
  });

  group('EnhancementOptions', () {
    test('should create with defaults', () {
      const options = EnhancementOptions();

      expect(options.brightness, 0);
      expect(options.contrast, 0);
      expect(options.sharpness, 0);
      expect(options.saturation, 0);
      expect(options.grayscale, false);
      expect(options.autoEnhance, false);
      expect(options.denoise, false);
      expect(options.hasEnhancements, false);
    });

    test('should detect hasEnhancements', () {
      expect(const EnhancementOptions(brightness: 10).hasEnhancements, true);
      expect(const EnhancementOptions(contrast: 10).hasEnhancements, true);
      expect(const EnhancementOptions(sharpness: 10).hasEnhancements, true);
      expect(const EnhancementOptions(saturation: 10).hasEnhancements, true);
      expect(const EnhancementOptions(grayscale: true).hasEnhancements, true);
      expect(const EnhancementOptions(autoEnhance: true).hasEnhancements, true);
      expect(const EnhancementOptions(denoise: true).hasEnhancements, true);
      expect(const EnhancementOptions().hasEnhancements, false);
    });

    test('should create from document preset', () {
      final options = EnhancementOptions.fromPreset(EnhancementPreset.document);

      expect(options.brightness, 5);
      expect(options.contrast, 20);
      expect(options.sharpness, 30);
      expect(options.autoEnhance, true);
      expect(options.grayscale, false);
    });

    test('should create from highContrast preset', () {
      final options =
          EnhancementOptions.fromPreset(EnhancementPreset.highContrast);

      expect(options.brightness, 10);
      expect(options.contrast, 50);
      expect(options.sharpness, 50);
    });

    test('should create from blackAndWhite preset', () {
      final options =
          EnhancementOptions.fromPreset(EnhancementPreset.blackAndWhite);

      expect(options.contrast, 30);
      expect(options.sharpness, 25);
      expect(options.grayscale, true);
    });

    test('should create from photo preset', () {
      final options = EnhancementOptions.fromPreset(EnhancementPreset.photo);

      expect(options.brightness, 3);
      expect(options.contrast, 10);
      expect(options.sharpness, 15);
      expect(options.saturation, 10);
    });

    test('should create from none preset', () {
      final options = EnhancementOptions.fromPreset(EnhancementPreset.none);

      expect(options.hasEnhancements, false);
    });

    test('should implement copyWith', () {
      const original = EnhancementOptions(
        brightness: 10,
        contrast: 20,
      );

      final copied = original.copyWith(sharpness: 30);

      expect(copied.brightness, 10); // unchanged
      expect(copied.contrast, 20); // unchanged
      expect(copied.sharpness, 30); // changed
    });

    test('should implement equality', () {
      const options1 = EnhancementOptions(brightness: 10, contrast: 20);
      const options2 = EnhancementOptions(brightness: 10, contrast: 20);
      const options3 = EnhancementOptions(brightness: 10, contrast: 30);

      expect(options1, equals(options2));
      expect(options1.hashCode, equals(options2.hashCode));
      expect(options1, isNot(equals(options3)));
    });

    test('should format toString', () {
      const options = EnhancementOptions(
        brightness: 10,
        contrast: 20,
        sharpness: 30,
      );

      final str = options.toString();
      expect(str, contains('brightness: 10'));
      expect(str, contains('contrast: 20'));
      expect(str, contains('sharpness: 30'));
    });
  });

  group('ImageInfo', () {
    test('should create with required parameters', () {
      const info = ImageInfo(
        width: 1920,
        height: 1080,
        format: 'jpeg',
      );

      expect(info.width, 1920);
      expect(info.height, 1080);
      expect(info.format, 'jpeg');
      expect(info.hasAlpha, false);
    });

    test('should calculate aspect ratio', () {
      const info = ImageInfo(width: 1920, height: 1080, format: 'jpeg');

      expect(info.aspectRatio, closeTo(1.778, 0.001));
    });

    test('should calculate pixel count', () {
      const info = ImageInfo(width: 100, height: 200, format: 'png');

      expect(info.pixelCount, 20000);
    });

    test('should implement equality', () {
      const info1 = ImageInfo(width: 100, height: 200, format: 'jpeg');
      const info2 = ImageInfo(width: 100, height: 200, format: 'jpeg');
      const info3 = ImageInfo(width: 100, height: 200, format: 'png');

      expect(info1, equals(info2));
      expect(info1.hashCode, equals(info2.hashCode));
      expect(info1, isNot(equals(info3)));
    });

    test('should format toString', () {
      const info = ImageInfo(
        width: 100,
        height: 200,
        format: 'jpeg',
        hasAlpha: true,
      );

      final str = info.toString();
      expect(str, contains('100x200'));
      expect(str, contains('jpeg'));
      expect(str, contains('hasAlpha: true'));
    });
  });

  group('ImageProcessor.enhanceFromBytes', () {
    test('should process image without enhancements', () async {
      final testImage = createTestImage();

      final result = await processor.enhanceFromBytes(
        testImage,
        options: EnhancementOptions.none,
      );

      expect(result.bytes, isNotEmpty);
      expect(result.width, 100);
      expect(result.height, 100);
      expect(result.format, ImageOutputFormat.jpeg);
    });

    test('should apply brightness adjustment', () async {
      final testImage = createTestImage();

      final result = await processor.enhanceFromBytes(
        testImage,
        options: const EnhancementOptions(brightness: 50),
      );

      expect(result.bytes, isNotEmpty);
      expect(result.operationsApplied, contains('brightness:50'));
    });

    test('should apply contrast adjustment', () async {
      final testImage = createGradientTestImage();

      final result = await processor.enhanceFromBytes(
        testImage,
        options: const EnhancementOptions(contrast: 30),
      );

      expect(result.bytes, isNotEmpty);
      expect(result.operationsApplied, contains('contrast:30'));
    });

    test('should apply sharpening', () async {
      final testImage = createTestImage();

      final result = await processor.enhanceFromBytes(
        testImage,
        options: const EnhancementOptions(sharpness: 50),
      );

      expect(result.bytes, isNotEmpty);
      expect(result.operationsApplied, contains('sharpen:50'));
    });

    test('should convert to grayscale', () async {
      // Create a colorful image
      final image = img.Image(width: 100, height: 100);
      for (var y = 0; y < 100; y++) {
        for (var x = 0; x < 100; x++) {
          image.setPixel(x, y, img.ColorRgb8(255, 0, 0)); // Red
        }
      }
      final testImage = Uint8List.fromList(img.encodeJpg(image));

      final result = await processor.enhanceFromBytes(
        testImage,
        options: const EnhancementOptions(grayscale: true),
      );

      expect(result.bytes, isNotEmpty);
      expect(result.operationsApplied, contains('grayscale'));

      // Verify the output is grayscale
      final processedImage = img.decodeImage(result.bytes);
      expect(processedImage, isNotNull);

      // Check a few pixels - in grayscale, R=G=B
      final pixel = processedImage!.getPixel(50, 50);
      expect(pixel.r, equals(pixel.g));
      expect(pixel.g, equals(pixel.b));
    });

    test('should apply auto enhancement', () async {
      final testImage = createGradientTestImage();

      final result = await processor.enhanceFromBytes(
        testImage,
        options: const EnhancementOptions(autoEnhance: true),
      );

      expect(result.bytes, isNotEmpty);
      expect(result.operationsApplied, contains('auto_enhance'));
    });

    test('should apply denoising', () async {
      final testImage = createTestImage();

      final result = await processor.enhanceFromBytes(
        testImage,
        options: const EnhancementOptions(denoise: true),
      );

      expect(result.bytes, isNotEmpty);
      expect(result.operationsApplied, contains('denoise'));
    });

    test('should apply saturation adjustment', () async {
      final testImage = createTestImage();

      final result = await processor.enhanceFromBytes(
        testImage,
        options: const EnhancementOptions(saturation: 50),
      );

      expect(result.bytes, isNotEmpty);
      expect(result.operationsApplied, contains('saturation:50'));
    });

    test('should apply multiple enhancements', () async {
      final testImage = createTestImage();

      final result = await processor.enhanceFromBytes(
        testImage,
        options: const EnhancementOptions(
          brightness: 10,
          contrast: 20,
          sharpness: 30,
        ),
      );

      expect(result.bytes, isNotEmpty);
      expect(result.operationsApplied, contains('brightness:10'));
      expect(result.operationsApplied, contains('contrast:20'));
      expect(result.operationsApplied, contains('sharpen:30'));
    });

    test('should apply document preset', () async {
      final testImage = createTestImage();

      final result = await processor.enhanceFromBytes(
        testImage,
        options: EnhancementOptions.fromPreset(EnhancementPreset.document),
      );

      expect(result.bytes, isNotEmpty);
      expect(result.operationsApplied, contains('auto_enhance'));
      expect(result.operationsApplied, contains('brightness:5'));
      expect(result.operationsApplied, contains('contrast:20'));
      expect(result.operationsApplied, contains('sharpen:30'));
    });

    test('should output PNG format', () async {
      final testImage = createTestImage();

      final result = await processor.enhanceFromBytes(
        testImage,
        outputFormat: ImageOutputFormat.png,
      );

      expect(result.bytes, isNotEmpty);
      expect(result.format, ImageOutputFormat.png);

      // PNG magic number check
      expect(result.bytes[0], 0x89);
      expect(result.bytes[1], 0x50);
      expect(result.bytes[2], 0x4E);
    });

    test('should respect quality parameter for JPEG', () async {
      final testImage = createTestImage(width: 200, height: 200);

      final highQuality = await processor.enhanceFromBytes(
        testImage,
        outputFormat: ImageOutputFormat.jpeg,
        quality: 100,
      );

      final lowQuality = await processor.enhanceFromBytes(
        testImage,
        outputFormat: ImageOutputFormat.jpeg,
        quality: 10,
      );

      // Higher quality should produce larger file
      expect(highQuality.fileSize, greaterThan(lowQuality.fileSize));
    });

    test('should throw for empty bytes', () async {
      expect(
        () => processor.enhanceFromBytes(Uint8List(0)),
        throwsA(isA<ImageProcessorException>()),
      );
    });

    test('should throw for invalid image data', () async {
      expect(
        () => processor.enhanceFromBytes(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<ImageProcessorException>()),
      );
    });

    test('should downscale large images', () async {
      // Create an image larger than maxProcessingDimension
      final largeImage = img.Image(width: 5000, height: 3000);
      for (var y = 0; y < 3000; y++) {
        for (var x = 0; x < 5000; x++) {
          largeImage.setPixel(x, y, img.ColorRgb8(128, 128, 128));
        }
      }
      final bytes = Uint8List.fromList(img.encodeJpg(largeImage));

      final result = await processor.enhanceFromBytes(bytes);

      expect(result.width,
          lessThanOrEqualTo(ImageProcessor.maxProcessingDimension));
      expect(result.operationsApplied, contains('downscaled'));
    });
  });

  group('ImageProcessor.enhanceFromFile', () {
    late Directory tempDir;
    late String testImagePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('image_processor_test_');
      testImagePath = '${tempDir.path}/test_image.jpg';

      final testImage = createTestImage();
      await File(testImagePath).writeAsBytes(testImage);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should process image from file', () async {
      final result = await processor.enhanceFromFile(
        testImagePath,
        options: const EnhancementOptions(contrast: 20),
      );

      expect(result.bytes, isNotEmpty);
      expect(result.operationsApplied, contains('contrast:20'));
    });

    test('should throw for empty path', () async {
      expect(
        () => processor.enhanceFromFile(''),
        throwsA(isA<ImageProcessorException>()),
      );
    });

    test('should throw for non-existent file', () async {
      expect(
        () => processor.enhanceFromFile('/nonexistent/file.jpg'),
        throwsA(isA<ImageProcessorException>()),
      );
    });
  });

  group('ImageProcessor.enhanceFromFileToFile', () {
    late Directory tempDir;
    late String inputPath;
    late String outputPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('image_processor_test_');
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

    test('should save enhanced image to file', () async {
      final result = await processor.enhanceFromFileToFile(
        inputPath,
        outputPath,
        options: const EnhancementOptions(contrast: 20),
      );

      expect(result.bytes, isNotEmpty);
      expect(await File(outputPath).exists(), true);

      final savedBytes = await File(outputPath).readAsBytes();
      expect(savedBytes, result.bytes);
    });

    test('should throw for empty paths', () async {
      expect(
        () => processor.enhanceFromFileToFile('', outputPath),
        throwsA(isA<ImageProcessorException>()),
      );

      expect(
        () => processor.enhanceFromFileToFile(inputPath, ''),
        throwsA(isA<ImageProcessorException>()),
      );
    });

    test('should throw for same input and output path', () async {
      expect(
        () => processor.enhanceFromFileToFile(inputPath, inputPath),
        throwsA(isA<ImageProcessorException>()),
      );
    });
  });

  group('ImageProcessor.autoEnhance', () {
    test('should apply document preset', () async {
      final testImage = createTestImage();

      final result = await processor.autoEnhance(testImage);

      expect(result.bytes, isNotEmpty);
      expect(result.operationsApplied, contains('auto_enhance'));
    });
  });

  group('ImageProcessor.convertToGrayscale', () {
    test('should convert to grayscale', () async {
      final testImage = createTestImage();

      final result = await processor.convertToGrayscale(testImage);

      expect(result.bytes, isNotEmpty);
      expect(result.operationsApplied, contains('grayscale'));
    });

    test('should add contrast when enhanceContrast is true', () async {
      final testImage = createTestImage();

      final result = await processor.convertToGrayscale(
        testImage,
        enhanceContrast: true,
      );

      expect(result.operationsApplied, contains('contrast:20'));
    });

    test('should not add contrast when enhanceContrast is false', () async {
      final testImage = createTestImage();

      final result = await processor.convertToGrayscale(
        testImage,
        enhanceContrast: false,
      );

      expect(
        result.operationsApplied.where((op) => op.startsWith('contrast:')),
        isEmpty,
      );
    });
  });

  group('ImageProcessor.sharpen', () {
    test('should apply sharpening', () async {
      final testImage = createTestImage();

      final result = await processor.sharpen(testImage, amount: 75);

      expect(result.bytes, isNotEmpty);
      expect(result.operationsApplied, contains('sharpen:75'));
    });

    test('should clamp amount to valid range', () async {
      final testImage = createTestImage();

      final result = await processor.sharpen(testImage, amount: 150);

      expect(result.operationsApplied, contains('sharpen:100'));
    });
  });

  group('ImageProcessor.adjustBrightness', () {
    test('should increase brightness', () async {
      final testImage = createTestImage();

      final result = await processor.adjustBrightness(testImage, amount: 50);

      expect(result.bytes, isNotEmpty);
      expect(result.operationsApplied, contains('brightness:50'));
    });

    test('should decrease brightness', () async {
      final testImage = createTestImage();

      final result = await processor.adjustBrightness(testImage, amount: -50);

      expect(result.bytes, isNotEmpty);
      expect(result.operationsApplied, contains('brightness:-50'));
    });

    test('should clamp amount to valid range', () async {
      final testImage = createTestImage();

      final result = await processor.adjustBrightness(testImage, amount: 150);

      expect(result.operationsApplied, contains('brightness:100'));
    });
  });

  group('ImageProcessor.adjustContrast', () {
    test('should increase contrast', () async {
      final testImage = createGradientTestImage();

      final result = await processor.adjustContrast(testImage, amount: 50);

      expect(result.bytes, isNotEmpty);
      expect(result.operationsApplied, contains('contrast:50'));
    });

    test('should decrease contrast', () async {
      final testImage = createGradientTestImage();

      final result = await processor.adjustContrast(testImage, amount: -50);

      expect(result.bytes, isNotEmpty);
      expect(result.operationsApplied, contains('contrast:-50'));
    });
  });

  group('ImageProcessor.resize', () {
    test('should resize large image', () async {
      final testImage = createTestImage(width: 500, height: 300);

      final result = await processor.resize(
        testImage,
        maxWidth: 200,
        maxHeight: 200,
      );

      expect(result.width, lessThanOrEqualTo(200));
      expect(result.height, lessThanOrEqualTo(200));
      expect(result.operationsApplied.first, startsWith('resize:'));
    });

    test('should maintain aspect ratio', () async {
      final testImage = createTestImage(width: 400, height: 200);

      final result = await processor.resize(
        testImage,
        maxWidth: 200,
        maxHeight: 200,
      );

      // Original aspect ratio is 2:1
      expect(result.width, 200);
      expect(result.height, 100);
    });

    test('should not upscale small images', () async {
      final testImage = createTestImage(width: 50, height: 50);

      final result = await processor.resize(
        testImage,
        maxWidth: 200,
        maxHeight: 200,
      );

      expect(result.width, 50);
      expect(result.height, 50);
    });

    test('should throw for invalid dimensions', () async {
      final testImage = createTestImage();

      expect(
        () => processor.resize(testImage, maxWidth: 0, maxHeight: 100),
        throwsA(isA<ImageProcessorException>()),
      );

      expect(
        () => processor.resize(testImage, maxWidth: 100, maxHeight: -1),
        throwsA(isA<ImageProcessorException>()),
      );
    });
  });

  group('ImageProcessor.crop', () {
    test('should crop image', () async {
      final testImage = createTestImage(width: 200, height: 200);

      final result = await processor.crop(
        testImage,
        x: 50,
        y: 50,
        width: 100,
        height: 100,
      );

      expect(result.width, 100);
      expect(result.height, 100);
      expect(result.operationsApplied.first, startsWith('crop:'));
    });

    test('should throw for out of bounds crop', () async {
      final testImage = createTestImage(width: 100, height: 100);

      expect(
        () => processor.crop(
          testImage,
          x: 50,
          y: 50,
          width: 100, // exceeds bounds
          height: 50,
        ),
        throwsA(isA<ImageProcessorException>()),
      );
    });

    test('should throw for invalid dimensions', () async {
      final testImage = createTestImage();

      expect(
        () => processor.crop(testImage, x: 0, y: 0, width: 0, height: 50),
        throwsA(isA<ImageProcessorException>()),
      );

      expect(
        () => processor.crop(testImage, x: 0, y: 0, width: 50, height: -1),
        throwsA(isA<ImageProcessorException>()),
      );
    });

    test('should throw for negative position', () async {
      final testImage = createTestImage();

      expect(
        () => processor.crop(testImage, x: -1, y: 0, width: 50, height: 50),
        throwsA(isA<ImageProcessorException>()),
      );

      expect(
        () => processor.crop(testImage, x: 0, y: -1, width: 50, height: 50),
        throwsA(isA<ImageProcessorException>()),
      );
    });
  });

  group('ImageProcessor.rotate', () {
    test('should rotate 90 degrees', () async {
      final testImage = createTestImage(width: 100, height: 50);

      final result = await processor.rotate(testImage, angle: 90);

      expect(result.width, 50);
      expect(result.height, 100);
      expect(result.operationsApplied, contains('rotate:90.0'));
    });

    test('should rotate 180 degrees', () async {
      final testImage = createTestImage(width: 100, height: 50);

      final result = await processor.rotate(testImage, angle: 180);

      expect(result.width, 100);
      expect(result.height, 50);
      expect(result.operationsApplied, contains('rotate:180.0'));
    });

    test('should rotate 270 degrees', () async {
      final testImage = createTestImage(width: 100, height: 50);

      final result = await processor.rotate(testImage, angle: 270);

      expect(result.width, 50);
      expect(result.height, 100);
      expect(result.operationsApplied, contains('rotate:270.0'));
    });

    test('should handle arbitrary angles', () async {
      final testImage = createTestImage();

      final result = await processor.rotate(testImage, angle: 45);

      expect(result.bytes, isNotEmpty);
      expect(result.operationsApplied, contains('rotate:45.0'));
    });

    test('should handle negative angles', () async {
      final testImage = createTestImage(width: 100, height: 50);

      final result = await processor.rotate(testImage, angle: -90);

      expect(result.width, 50);
      expect(result.height, 100);
    });
  });

  group('ImageProcessor.getImageInfo', () {
    test('should get JPEG info', () async {
      final testImage = createTestImage(width: 150, height: 100);

      final info = await processor.getImageInfo(testImage);

      expect(info.width, 150);
      expect(info.height, 100);
      expect(info.format, 'jpeg');
      expect(info.pixelCount, 15000);
      expect(info.aspectRatio, 1.5);
    });

    test('should get PNG info', () async {
      final image = img.Image(width: 100, height: 100);
      final pngBytes = Uint8List.fromList(img.encodePng(image));

      final info = await processor.getImageInfo(pngBytes);

      expect(info.width, 100);
      expect(info.height, 100);
      expect(info.format, 'png');
    });

    test('should detect alpha channel', () async {
      final image = img.Image(width: 100, height: 100, numChannels: 4);
      final pngBytes = Uint8List.fromList(img.encodePng(image));

      final info = await processor.getImageInfo(pngBytes);

      expect(info.hasAlpha, true);
    });

    test('should throw for empty bytes', () async {
      expect(
        () => processor.getImageInfo(Uint8List(0)),
        throwsA(isA<ImageProcessorException>()),
      );
    });

    test('should throw for invalid image', () async {
      expect(
        () => processor.getImageInfo(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<ImageProcessorException>()),
      );
    });
  });

  group('ImageOutputFormat', () {
    test('should have jpeg and png formats', () {
      expect(ImageOutputFormat.values, contains(ImageOutputFormat.jpeg));
      expect(ImageOutputFormat.values, contains(ImageOutputFormat.png));
    });
  });

  group('EnhancementPreset', () {
    test('should have all expected presets', () {
      expect(EnhancementPreset.values, contains(EnhancementPreset.document));
      expect(
          EnhancementPreset.values, contains(EnhancementPreset.highContrast));
      expect(
          EnhancementPreset.values, contains(EnhancementPreset.blackAndWhite));
      expect(EnhancementPreset.values, contains(EnhancementPreset.photo));
      expect(EnhancementPreset.values, contains(EnhancementPreset.none));
    });
  });

  group('Riverpod Provider', () {
    test('should provide ImageProcessor instance', () {
      final container = ProviderContainer();

      final processor = container.read(imageProcessorProvider);

      expect(processor, isA<ImageProcessor>());

      container.dispose();
    });

    test('should provide same instance on multiple reads', () {
      final container = ProviderContainer();

      final processor1 = container.read(imageProcessorProvider);
      final processor2 = container.read(imageProcessorProvider);

      expect(identical(processor1, processor2), true);

      container.dispose();
    });
  });
}
