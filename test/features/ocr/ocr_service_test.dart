import 'dart:io';
import 'dart:typed_data';

import 'package:aiscan/features/ocr/domain/ocr_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OcrException', () {
    test('should create exception with message only', () {
      const exception = OcrException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.cause, isNull);
      expect(exception.toString(), 'OcrException: Test error');
    });

    test('should create exception with message and cause', () {
      final cause = Exception('Underlying error');
      final exception = OcrException('Test error', cause: cause);

      expect(exception.message, 'Test error');
      expect(exception.cause, cause);
      expect(
        exception.toString(),
        'OcrException: Test error (caused by: $cause)',
      );
    });

    test('should handle null cause in toString', () {
      const exception = OcrException('No cause');

      expect(exception.toString(), 'OcrException: No cause');
      expect(exception.toString(), isNot(contains('caused by')));
    });

    test('should preserve various cause types', () {
      final errorCause = ArgumentError('Bad argument');
      final exception = OcrException('Test error', cause: errorCause);

      expect(exception.cause, isA<ArgumentError>());
      expect(exception.toString(), contains('Invalid argument'));
    });
  });

  group('OcrResult', () {
    test('should create with required fields', () {
      const result = OcrResult(
        text: 'Hello World',
        language: 'eng',
      );

      expect(result.text, 'Hello World');
      expect(result.language, 'eng');
      expect(result.confidence, isNull);
      expect(result.processingTimeMs, isNull);
      expect(result.wordCount, isNull);
      expect(result.lineCount, isNull);
    });

    test('should create with all fields', () {
      const result = OcrResult(
        text: 'Hello World\nSecond line',
        language: 'eng',
        confidence: 0.95,
        processingTimeMs: 150,
        wordCount: 4,
        lineCount: 2,
      );

      expect(result.text, 'Hello World\nSecond line');
      expect(result.language, 'eng');
      expect(result.confidence, 0.95);
      expect(result.processingTimeMs, 150);
      expect(result.wordCount, 4);
      expect(result.lineCount, 2);
    });

    group('hasText getter', () {
      test('should return true for non-empty text', () {
        const result = OcrResult(text: 'Hello', language: 'eng');

        expect(result.hasText, true);
      });

      test('should return false for empty text', () {
        const result = OcrResult(text: '', language: 'eng');

        expect(result.hasText, false);
      });

      test('should return false for whitespace only text', () {
        const result = OcrResult(text: '   \n\t  ', language: 'eng');

        expect(result.hasText, false);
      });
    });

    group('isEmpty getter', () {
      test('should return true for empty text', () {
        const result = OcrResult(text: '', language: 'eng');

        expect(result.isEmpty, true);
      });

      test('should return true for whitespace only', () {
        const result = OcrResult(text: '   ', language: 'eng');

        expect(result.isEmpty, true);
      });

      test('should return false for non-empty text', () {
        const result = OcrResult(text: 'Hello', language: 'eng');

        expect(result.isEmpty, false);
      });
    });

    group('isNotEmpty getter', () {
      test('should return true for non-empty text', () {
        const result = OcrResult(text: 'Hello', language: 'eng');

        expect(result.isNotEmpty, true);
      });

      test('should return false for empty text', () {
        const result = OcrResult(text: '', language: 'eng');

        expect(result.isNotEmpty, false);
      });
    });

    group('trimmedText getter', () {
      test('should return trimmed text', () {
        const result = OcrResult(text: '  Hello World  \n', language: 'eng');

        expect(result.trimmedText, 'Hello World');
      });

      test('should handle already trimmed text', () {
        const result = OcrResult(text: 'Hello', language: 'eng');

        expect(result.trimmedText, 'Hello');
      });
    });

    group('textLength getter', () {
      test('should return text length', () {
        const result = OcrResult(text: 'Hello', language: 'eng');

        expect(result.textLength, 5);
      });

      test('should return 0 for empty text', () {
        const result = OcrResult(text: '', language: 'eng');

        expect(result.textLength, 0);
      });
    });

    group('confidencePercent getter', () {
      test('should format confidence as percentage', () {
        const result = OcrResult(
          text: 'Hello',
          language: 'eng',
          confidence: 0.95,
        );

        expect(result.confidencePercent, '95.0%');
      });

      test('should format low confidence', () {
        const result = OcrResult(
          text: 'Hello',
          language: 'eng',
          confidence: 0.123,
        );

        expect(result.confidencePercent, '12.3%');
      });

      test('should return N/A for null confidence', () {
        const result = OcrResult(text: 'Hello', language: 'eng');

        expect(result.confidencePercent, 'N/A');
      });

      test('should format 100% confidence', () {
        const result = OcrResult(
          text: 'Hello',
          language: 'eng',
          confidence: 1.0,
        );

        expect(result.confidencePercent, '100.0%');
      });

      test('should format 0% confidence', () {
        const result = OcrResult(
          text: 'Hello',
          language: 'eng',
          confidence: 0.0,
        );

        expect(result.confidencePercent, '0.0%');
      });
    });

    group('copyWith', () {
      test('should copy with changed text', () {
        const original = OcrResult(
          text: 'Hello',
          language: 'eng',
          confidence: 0.9,
        );

        final copied = original.copyWith(text: 'World');

        expect(copied.text, 'World');
        expect(copied.language, 'eng'); // Unchanged
        expect(copied.confidence, 0.9); // Unchanged
      });

      test('should copy with changed language', () {
        const original = OcrResult(text: 'Hello', language: 'eng');

        final copied = original.copyWith(language: 'deu');

        expect(copied.text, 'Hello'); // Unchanged
        expect(copied.language, 'deu');
      });

      test('should copy with all changed fields', () {
        const original = OcrResult(
          text: 'Hello',
          language: 'eng',
          confidence: 0.9,
          processingTimeMs: 100,
          wordCount: 1,
          lineCount: 1,
        );

        final copied = original.copyWith(
          text: 'World',
          language: 'deu',
          confidence: 0.8,
          processingTimeMs: 200,
          wordCount: 2,
          lineCount: 2,
        );

        expect(copied.text, 'World');
        expect(copied.language, 'deu');
        expect(copied.confidence, 0.8);
        expect(copied.processingTimeMs, 200);
        expect(copied.wordCount, 2);
        expect(copied.lineCount, 2);
      });

      test('should not modify original', () {
        const original = OcrResult(text: 'Hello', language: 'eng');

        original.copyWith(text: 'World');

        expect(original.text, 'Hello');
      });
    });

    group('equality', () {
      test('should be equal with same values', () {
        const result1 = OcrResult(
          text: 'Hello',
          language: 'eng',
          confidence: 0.9,
          processingTimeMs: 100,
          wordCount: 1,
          lineCount: 1,
        );
        const result2 = OcrResult(
          text: 'Hello',
          language: 'eng',
          confidence: 0.9,
          processingTimeMs: 100,
          wordCount: 1,
          lineCount: 1,
        );

        expect(result1, equals(result2));
      });

      test('should not be equal with different text', () {
        const result1 = OcrResult(text: 'Hello', language: 'eng');
        const result2 = OcrResult(text: 'World', language: 'eng');

        expect(result1, isNot(equals(result2)));
      });

      test('should not be equal with different language', () {
        const result1 = OcrResult(text: 'Hello', language: 'eng');
        const result2 = OcrResult(text: 'Hello', language: 'deu');

        expect(result1, isNot(equals(result2)));
      });

      test('should not be equal with different confidence', () {
        const result1 = OcrResult(
          text: 'Hello',
          language: 'eng',
          confidence: 0.9,
        );
        const result2 = OcrResult(
          text: 'Hello',
          language: 'eng',
          confidence: 0.8,
        );

        expect(result1, isNot(equals(result2)));
      });

      test('should be equal to itself', () {
        const result = OcrResult(text: 'Hello', language: 'eng');

        expect(result, equals(result));
      });
    });

    group('hashCode', () {
      test('should be equal for equal results', () {
        const result1 = OcrResult(
          text: 'Hello',
          language: 'eng',
          confidence: 0.9,
        );
        const result2 = OcrResult(
          text: 'Hello',
          language: 'eng',
          confidence: 0.9,
        );

        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('should be different for different results', () {
        const result1 = OcrResult(text: 'Hello', language: 'eng');
        const result2 = OcrResult(text: 'World', language: 'eng');

        // Note: hashCode collisions are possible but unlikely for different values
        expect(result1.hashCode, isNot(equals(result2.hashCode)));
      });
    });

    group('toString', () {
      test('should contain text length', () {
        const result = OcrResult(text: 'Hello World', language: 'eng');

        expect(result.toString(), contains('11 chars'));
      });

      test('should contain language', () {
        const result = OcrResult(text: 'Hello', language: 'eng');

        expect(result.toString(), contains('eng'));
      });

      test('should contain confidence', () {
        const result = OcrResult(
          text: 'Hello',
          language: 'eng',
          confidence: 0.95,
        );

        expect(result.toString(), contains('95.0%'));
      });

      test('should show N/A for null confidence', () {
        const result = OcrResult(text: 'Hello', language: 'eng');

        expect(result.toString(), contains('N/A'));
      });

      test('should contain word and line counts', () {
        const result = OcrResult(
          text: 'Hello',
          language: 'eng',
          wordCount: 5,
          lineCount: 2,
        );

        expect(result.toString(), contains('words: 5'));
        expect(result.toString(), contains('lines: 2'));
      });
    });
  });

  group('OcrLanguage', () {
    test('should have expected languages', () {
      expect(OcrLanguage.values, contains(OcrLanguage.latin));
      expect(OcrLanguage.values, contains(OcrLanguage.chinese));
      expect(OcrLanguage.values, contains(OcrLanguage.devanagari));
      expect(OcrLanguage.values, contains(OcrLanguage.japanese));
      expect(OcrLanguage.values, contains(OcrLanguage.korean));
      expect(OcrLanguage.values, contains(OcrLanguage.english));
      expect(OcrLanguage.values, contains(OcrLanguage.german));
      expect(OcrLanguage.values, contains(OcrLanguage.french));
      expect(OcrLanguage.values, contains(OcrLanguage.spanish));
      expect(OcrLanguage.values, contains(OcrLanguage.italian));
      expect(OcrLanguage.values, contains(OcrLanguage.portuguese));
    });

    test('should have correct script codes', () {
      expect(OcrLanguage.latin.code, 'latin');
      expect(OcrLanguage.chinese.code, 'chinese');
      expect(OcrLanguage.devanagari.code, 'devanagari');
      expect(OcrLanguage.japanese.code, 'japanese');
      expect(OcrLanguage.korean.code, 'korean');
      // Legacy codes map to latin
      expect(OcrLanguage.english.code, 'latin');
      expect(OcrLanguage.german.code, 'latin');
      expect(OcrLanguage.french.code, 'latin');
      expect(OcrLanguage.spanish.code, 'latin');
      expect(OcrLanguage.italian.code, 'latin');
      expect(OcrLanguage.portuguese.code, 'latin');
    });

    test('should have human-readable display names', () {
      expect(OcrLanguage.latin.displayName, 'Latin (EN, FR, DE, ES...)');
      expect(OcrLanguage.chinese.displayName, 'Chinese');
      expect(OcrLanguage.devanagari.displayName, 'Devanagari');
      expect(OcrLanguage.japanese.displayName, 'Japanese');
      expect(OcrLanguage.korean.displayName, 'Korean');
      expect(OcrLanguage.english.displayName, 'English');
      expect(OcrLanguage.german.displayName, 'German');
      expect(OcrLanguage.french.displayName, 'French');
      expect(OcrLanguage.spanish.displayName, 'Spanish');
      expect(OcrLanguage.italian.displayName, 'Italian');
      expect(OcrLanguage.portuguese.displayName, 'Portuguese');
    });
  });

  group('OcrPageSegmentationMode', () {
    test('should have expected modes', () {
      expect(OcrPageSegmentationMode.values.length, 8);
      expect(OcrPageSegmentationMode.values, contains(OcrPageSegmentationMode.auto));
      expect(OcrPageSegmentationMode.values, contains(OcrPageSegmentationMode.singleColumn));
      expect(OcrPageSegmentationMode.values, contains(OcrPageSegmentationMode.singleBlock));
      expect(OcrPageSegmentationMode.values, contains(OcrPageSegmentationMode.singleLine));
      expect(OcrPageSegmentationMode.values, contains(OcrPageSegmentationMode.singleWord));
      expect(OcrPageSegmentationMode.values, contains(OcrPageSegmentationMode.singleChar));
      expect(OcrPageSegmentationMode.values, contains(OcrPageSegmentationMode.sparseText));
      expect(OcrPageSegmentationMode.values, contains(OcrPageSegmentationMode.sparseTextOsd));
    });

    test('should have correct Tesseract PSM values', () {
      expect(OcrPageSegmentationMode.auto.value, 3);
      expect(OcrPageSegmentationMode.singleColumn.value, 4);
      expect(OcrPageSegmentationMode.singleBlock.value, 6);
      expect(OcrPageSegmentationMode.singleLine.value, 7);
      expect(OcrPageSegmentationMode.singleWord.value, 8);
      expect(OcrPageSegmentationMode.singleChar.value, 10);
      expect(OcrPageSegmentationMode.sparseText.value, 11);
      expect(OcrPageSegmentationMode.sparseTextOsd.value, 12);
    });
  });

  group('OcrEngineMode', () {
    test('should have expected modes', () {
      expect(OcrEngineMode.values.length, 4);
      expect(OcrEngineMode.values, contains(OcrEngineMode.legacyOnly));
      expect(OcrEngineMode.values, contains(OcrEngineMode.lstmOnly));
      expect(OcrEngineMode.values, contains(OcrEngineMode.combined));
      expect(OcrEngineMode.values, contains(OcrEngineMode.defaultMode));
    });

    test('should have correct Tesseract OEM values', () {
      expect(OcrEngineMode.legacyOnly.value, 0);
      expect(OcrEngineMode.lstmOnly.value, 1);
      expect(OcrEngineMode.combined.value, 2);
      expect(OcrEngineMode.defaultMode.value, 3);
    });
  });

  group('OcrOptions', () {
    test('should create with default values', () {
      const options = OcrOptions();

      expect(options.language, OcrLanguage.latin);
      expect(options.pageSegmentationMode, OcrPageSegmentationMode.auto);
      expect(options.engineMode, OcrEngineMode.lstmOnly);
      expect(options.preserveInterwordSpaces, true);
      expect(options.enableDeskew, false);
      expect(options.characterWhitelist, isNull);
      expect(options.characterBlacklist, isNull);
    });

    group('presets', () {
      test('document preset should have correct values', () {
        const options = OcrOptions.document();

        expect(options.language, OcrLanguage.latin);
        expect(options.pageSegmentationMode, OcrPageSegmentationMode.auto);
        expect(options.engineMode, OcrEngineMode.lstmOnly);
        expect(options.preserveInterwordSpaces, true);
        expect(options.enableDeskew, false);
        expect(options.characterWhitelist, isNull);
        expect(options.characterBlacklist, isNull);
      });

      test('document preset should accept custom language', () {
        const options = OcrOptions.document(language: OcrLanguage.german);

        expect(options.language, OcrLanguage.german);
        expect(options.pageSegmentationMode, OcrPageSegmentationMode.auto);
      });

      test('singleLine preset should have correct values', () {
        const options = OcrOptions.singleLine();

        expect(options.language, OcrLanguage.latin);
        expect(options.pageSegmentationMode, OcrPageSegmentationMode.singleLine);
        expect(options.engineMode, OcrEngineMode.lstmOnly);
        expect(options.preserveInterwordSpaces, true);
      });

      test('singleLine preset should accept custom language', () {
        const options = OcrOptions.singleLine(language: OcrLanguage.french);

        expect(options.language, OcrLanguage.french);
        expect(options.pageSegmentationMode, OcrPageSegmentationMode.singleLine);
      });

      test('sparse preset should have correct values', () {
        const options = OcrOptions.sparse();

        expect(options.language, OcrLanguage.latin);
        expect(options.pageSegmentationMode, OcrPageSegmentationMode.sparseText);
        expect(options.engineMode, OcrEngineMode.lstmOnly);
        expect(options.preserveInterwordSpaces, true);
      });

      test('sparse preset should accept custom language', () {
        const options = OcrOptions.sparse(language: OcrLanguage.spanish);

        expect(options.language, OcrLanguage.spanish);
        expect(options.pageSegmentationMode, OcrPageSegmentationMode.sparseText);
      });

      test('numericOnly preset should have correct values', () {
        const options = OcrOptions.numericOnly();

        expect(options.language, OcrLanguage.latin);
        expect(options.pageSegmentationMode, OcrPageSegmentationMode.auto);
        expect(options.engineMode, OcrEngineMode.lstmOnly);
        expect(options.preserveInterwordSpaces, false);
        expect(options.characterWhitelist, '0123456789');
        expect(options.characterBlacklist, isNull);
      });

      test('numericOnly preset should accept custom language', () {
        const options = OcrOptions.numericOnly(language: OcrLanguage.japanese);

        expect(options.language, OcrLanguage.japanese);
        expect(options.characterWhitelist, '0123456789');
      });

      test('defaultDocument should be same as document preset', () {
        const defaultDoc = OcrOptions.defaultDocument;
        const docPreset = OcrOptions.document();

        expect(defaultDoc.language, docPreset.language);
        expect(defaultDoc.pageSegmentationMode, docPreset.pageSegmentationMode);
        expect(defaultDoc.engineMode, docPreset.engineMode);
      });
    });

    group('copyWith', () {
      test('should copy with changed language', () {
        const original = OcrOptions(language: OcrLanguage.latin);

        final copied = original.copyWith(language: OcrLanguage.german);

        expect(copied.language, OcrLanguage.german);
        expect(copied.pageSegmentationMode, OcrPageSegmentationMode.auto); // Unchanged
      });

      test('should copy with changed pageSegmentationMode', () {
        const original = OcrOptions();

        final copied = original.copyWith(
          pageSegmentationMode: OcrPageSegmentationMode.singleLine,
        );

        expect(copied.pageSegmentationMode, OcrPageSegmentationMode.singleLine);
        expect(copied.language, OcrLanguage.latin); // Unchanged
      });

      test('should copy with all fields changed', () {
        const original = OcrOptions();

        final copied = original.copyWith(
          language: OcrLanguage.german,
          pageSegmentationMode: OcrPageSegmentationMode.singleBlock,
          engineMode: OcrEngineMode.legacyOnly,
          preserveInterwordSpaces: false,
          enableDeskew: true,
          characterWhitelist: 'ABC',
          characterBlacklist: 'XYZ',
        );

        expect(copied.language, OcrLanguage.german);
        expect(copied.pageSegmentationMode, OcrPageSegmentationMode.singleBlock);
        expect(copied.engineMode, OcrEngineMode.legacyOnly);
        expect(copied.preserveInterwordSpaces, false);
        expect(copied.enableDeskew, true);
        expect(copied.characterWhitelist, 'ABC');
        expect(copied.characterBlacklist, 'XYZ');
      });

      test('should not modify original', () {
        const original = OcrOptions(language: OcrLanguage.latin);

        original.copyWith(language: OcrLanguage.german);

        expect(original.language, OcrLanguage.latin);
      });
    });

    // toTesseractArgs tests removed - ML Kit doesn't use Tesseract args

    group('equality', () {
      test('should be equal with same values', () {
        const options1 = OcrOptions(
          language: OcrLanguage.latin,
          pageSegmentationMode: OcrPageSegmentationMode.auto,
          engineMode: OcrEngineMode.lstmOnly,
          preserveInterwordSpaces: true,
          enableDeskew: false,
          characterWhitelist: 'ABC',
          characterBlacklist: 'XYZ',
        );
        const options2 = OcrOptions(
          language: OcrLanguage.latin,
          pageSegmentationMode: OcrPageSegmentationMode.auto,
          engineMode: OcrEngineMode.lstmOnly,
          preserveInterwordSpaces: true,
          enableDeskew: false,
          characterWhitelist: 'ABC',
          characterBlacklist: 'XYZ',
        );

        expect(options1, equals(options2));
      });

      test('should not be equal with different language', () {
        const options1 = OcrOptions(language: OcrLanguage.latin);
        const options2 = OcrOptions(language: OcrLanguage.chinese);

        expect(options1, isNot(equals(options2)));
      });

      test('should not be equal with different PSM', () {
        const options1 = OcrOptions(
          pageSegmentationMode: OcrPageSegmentationMode.auto,
        );
        const options2 = OcrOptions(
          pageSegmentationMode: OcrPageSegmentationMode.singleLine,
        );

        expect(options1, isNot(equals(options2)));
      });

      test('should be equal to itself', () {
        const options = OcrOptions();

        expect(options, equals(options));
      });
    });

    group('hashCode', () {
      test('should be equal for equal options', () {
        const options1 = OcrOptions(language: OcrLanguage.latin);
        const options2 = OcrOptions(language: OcrLanguage.latin);

        expect(options1.hashCode, equals(options2.hashCode));
      });

      test('should be different for different options', () {
        const options1 = OcrOptions(language: OcrLanguage.latin);
        const options2 = OcrOptions(language: OcrLanguage.chinese);

        expect(options1.hashCode, isNot(equals(options2.hashCode)));
      });
    });

    group('toString', () {
      test('should contain language display name', () {
        const options = OcrOptions(language: OcrLanguage.german);

        expect(options.toString(), contains('German'));
      });

      test('should contain script name', () {
        const options = OcrOptions(language: OcrLanguage.latin);

        expect(options.toString(), contains('latin'));
      });
    });
  });

  group('OcrService', () {
    late OcrService service;

    setUp(() {
      service = OcrService();
    });

    tearDown(() async {
      await service.dispose();
    });

    group('isReady', () {
      test('should return true for ML Kit (always ready)', () {
        expect(service.isReady, true);
      });
    });

    group('extractTextFromMultipleFiles validation', () {
      test('should throw on empty list', () async {
        expect(
          () => service.extractTextFromMultipleFiles([]),
          throwsA(isA<OcrException>().having(
            (e) => e.message,
            'message',
            contains('cannot be empty'),
          )),
        );
      });
    });

    group('extractTextWithProgress validation', () {
      test('should throw on empty list', () async {
        expect(
          () => service.extractTextWithProgress(
            [],
            onProgress: (current, total, result) {},
          ),
          throwsA(isA<OcrException>().having(
            (e) => e.message,
            'message',
            contains('cannot be empty'),
          )),
        );
      });
    });

    group('containsText', () {
      test('should return false when check fails', () async {
        // containsText catches exceptions and returns false
        final result = await service.containsText('/nonexistent/file.jpg');

        expect(result, false);
      });
    });

    group('clearCache', () {
      test('should not throw when called before initialization', () async {
        // Should complete without error
        await service.clearCache();
      });
    });

    group('getCacheSize', () {
      test('should return 0 for ML Kit', () async {
        final size = await service.getCacheSize();

        expect(size, 0);
      });
    });

    group('getCacheSizeFormatted', () {
      test('should return formatted size', () async {
        final formatted = await service.getCacheSizeFormatted();

        expect(formatted, '0 B');
      });
    });

    group('defaultLanguage', () {
      test('should be Latin', () {
        expect(OcrService.defaultLanguage, OcrLanguage.latin);
      });
    });
  });

  group('OcrService cache size formatting', () {
    // Test the formatting logic directly
    test('should format bytes correctly', () {
      // These tests verify the formatting logic pattern
      expect(formatCacheSize(500), '500 B');
      expect(formatCacheSize(1023), '1023 B');
    });

    test('should format KB correctly', () {
      expect(formatCacheSize(1024), '1.0 KB');
      expect(formatCacheSize(2048), '2.0 KB');
      expect(formatCacheSize(1536), '1.5 KB');
    });

    test('should format MB correctly', () {
      expect(formatCacheSize(1024 * 1024), '1.0 MB');
      expect(formatCacheSize(1024 * 1024 * 2), '2.0 MB');
      expect(formatCacheSize(1024 * 1024 + 512 * 1024), '1.5 MB');
    });
  });

  group('ocrServiceProvider', () {
    test('should provide OcrService instance', () {
      final container = ProviderContainer();

      final service = container.read(ocrServiceProvider);

      expect(service, isA<OcrService>());

      container.dispose();
    });

    test('should return same instance on multiple reads', () {
      final container = ProviderContainer();

      final service1 = container.read(ocrServiceProvider);
      final service2 = container.read(ocrServiceProvider);

      expect(identical(service1, service2), true);

      container.dispose();
    });
  });

  group('Integration Tests', () {
    late OcrService service;
    late Directory tempDir;

    setUp(() async {
      service = OcrService();
      tempDir = await Directory.systemTemp.createTemp('ocr_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should handle non-existent file path after initialization attempt', () async {
      // Even without proper initialization, the file check should happen first
      // when the service tries to process
      final nonExistentPath = '${tempDir.path}/nonexistent.jpg';

      expect(
        () => service.extractTextFromFile(nonExistentPath),
        throwsA(isA<OcrException>()),
      );
    });

    test('should validate empty bytes input', () async {
      expect(
        () => service.extractTextFromBytes(Uint8List(0)),
        throwsA(isA<OcrException>()),
      );
    });

    test('should validate empty image path', () async {
      expect(
        () => service.extractTextFromFile(''),
        throwsA(isA<OcrException>()),
      );
    });

    test('should create options with different presets', () {
      final docOptions = const OcrOptions.document();
      final lineOptions = const OcrOptions.singleLine();
      final sparseOptions = const OcrOptions.sparse();
      final numericOptions = const OcrOptions.numericOnly();

      expect(docOptions.pageSegmentationMode, OcrPageSegmentationMode.auto);
      expect(lineOptions.pageSegmentationMode, OcrPageSegmentationMode.singleLine);
      expect(sparseOptions.pageSegmentationMode, OcrPageSegmentationMode.sparseText);
      expect(numericOptions.characterWhitelist, '0123456789');
    });

    test('should support multiple language presets', () {
      final englishDoc = const OcrOptions.document(language: OcrLanguage.english);
      final germanDoc = const OcrOptions.document(language: OcrLanguage.german);
      final frenchDoc = const OcrOptions.document(language: OcrLanguage.french);

      expect(englishDoc.language.code, 'latin');
      expect(germanDoc.language.code, 'latin');
      expect(frenchDoc.language.code, 'latin');
    });
  });

  group('Error Handling', () {
    late OcrService service;

    setUp(() {
      service = OcrService();
    });

    test('extractTextFromFile should throw OcrException on invalid input', () async {
      expect(
        () => service.extractTextFromFile(''),
        throwsA(isA<OcrException>()),
      );
    });

    test('extractTextFromBytes should throw OcrException on invalid input', () async {
      expect(
        () => service.extractTextFromBytes(Uint8List(0)),
        throwsA(isA<OcrException>()),
      );
    });

    test('extractTextFromMultipleFiles should throw OcrException on empty list', () async {
      expect(
        () => service.extractTextFromMultipleFiles([]),
        throwsA(isA<OcrException>()),
      );
    });

    test('extractTextWithProgress should throw OcrException on empty list', () async {
      expect(
        () => service.extractTextWithProgress(
          [],
          onProgress: (current, total, result) {},
        ),
        throwsA(isA<OcrException>()),
      );
    });
  });

  group('OcrResult word and line counting', () {
    test('should count words correctly', () {
      // Testing the word count logic pattern
      const text = 'Hello World Test';
      final wordCount = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
      expect(wordCount, 3);
    });

    test('should count lines correctly', () {
      const text = 'Line 1\nLine 2\nLine 3';
      final lineCount = text.trim().isEmpty ? 0 : text.trim().split('\n').length;
      expect(lineCount, 3);
    });

    test('should handle empty text', () {
      const text = '';
      final wordCount = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
      final lineCount = text.trim().isEmpty ? 0 : text.trim().split('\n').length;
      expect(wordCount, 0);
      expect(lineCount, 0);
    });

    test('should handle whitespace only text', () {
      const text = '   \n\t  ';
      final trimmedText = text.trim();
      final wordCount = trimmedText.isEmpty ? 0 : trimmedText.split(RegExp(r'\s+')).length;
      final lineCount = trimmedText.isEmpty ? 0 : trimmedText.split('\n').length;
      expect(wordCount, 0);
      expect(lineCount, 0);
    });
  });

  group('OcrRecognizerTimeout', () {
    test('should have correct timeout values in seconds', () {
      expect(OcrRecognizerTimeout.immediate.seconds, 0);
      expect(OcrRecognizerTimeout.oneMinute.seconds, 60);
      expect(OcrRecognizerTimeout.fiveMinutes.seconds, 300);
      expect(OcrRecognizerTimeout.thirtyMinutes.seconds, 1800);
    });

    test('should have human-readable labels', () {
      expect(OcrRecognizerTimeout.immediate.label, 'Immediate');
      expect(OcrRecognizerTimeout.oneMinute.label, '1 minute');
      expect(OcrRecognizerTimeout.fiveMinutes.label, '5 minutes');
      expect(OcrRecognizerTimeout.thirtyMinutes.label, '30 minutes');
    });

    test('should create from seconds correctly', () {
      expect(OcrRecognizerTimeout.fromSeconds(0), OcrRecognizerTimeout.immediate);
      expect(OcrRecognizerTimeout.fromSeconds(-10), OcrRecognizerTimeout.immediate);
      expect(OcrRecognizerTimeout.fromSeconds(30), OcrRecognizerTimeout.oneMinute);
      expect(OcrRecognizerTimeout.fromSeconds(60), OcrRecognizerTimeout.oneMinute);
      expect(OcrRecognizerTimeout.fromSeconds(180), OcrRecognizerTimeout.fiveMinutes);
      expect(OcrRecognizerTimeout.fromSeconds(300), OcrRecognizerTimeout.fiveMinutes);
      expect(OcrRecognizerTimeout.fromSeconds(900), OcrRecognizerTimeout.thirtyMinutes);
      expect(OcrRecognizerTimeout.fromSeconds(1800), OcrRecognizerTimeout.thirtyMinutes);
      expect(OcrRecognizerTimeout.fromSeconds(3600), OcrRecognizerTimeout.thirtyMinutes);
    });
  });

  group('RecognizerUsageTracker', () {
    test('should initialize with current time', () {
      final tracker = RecognizerUsageTracker();

      expect(tracker.createdAt, isNotNull);
      expect(tracker.lastUsedAt, isNotNull);
      // Check times are very close (within 10ms)
      expect(
        tracker.createdAt.difference(tracker.lastUsedAt).inMilliseconds.abs(),
        lessThan(10),
      );
    });

    test('should update last used time when marked as used', () async {
      final tracker = RecognizerUsageTracker();
      final initialTime = tracker.lastUsedAt;

      await Future.delayed(const Duration(milliseconds: 10));
      tracker.markUsed();

      expect(tracker.lastUsedAt.isAfter(initialTime), true);
    });

    test('should calculate time since last use', () async {
      final tracker = RecognizerUsageTracker();

      await Future.delayed(const Duration(milliseconds: 100));

      final timeSinceLastUse = tracker.timeSinceLastUse;
      expect(timeSinceLastUse.inMilliseconds, greaterThanOrEqualTo(100));
    });

    test('should determine cleanup based on immediate timeout', () {
      final tracker = RecognizerUsageTracker();

      expect(tracker.shouldCleanup(OcrRecognizerTimeout.immediate), true);
    });

    test('should determine cleanup based on timeout threshold', () async {
      final tracker = RecognizerUsageTracker();

      // Should not cleanup immediately with oneMinute timeout
      expect(tracker.shouldCleanup(OcrRecognizerTimeout.oneMinute), false);

      // Wait a bit and check again (still shouldn't cleanup)
      await Future.delayed(const Duration(milliseconds: 100));
      expect(tracker.shouldCleanup(OcrRecognizerTimeout.oneMinute), false);
    });
  });

  group('Lifecycle Management', () {
    late OcrService service;

    setUp(() {
      service = OcrService();
    });

    tearDown(() async {
      await service.dispose();
    });

    group('setTimeout', () {
      test('should change timeout setting', () {
        service.setTimeout(OcrRecognizerTimeout.oneMinute);

        expect(service.getTimeout(), OcrRecognizerTimeout.oneMinute);
      });

      test('should update from default to different timeout', () {
        // Default is fiveMinutes
        expect(service.getTimeout(), OcrRecognizerTimeout.fiveMinutes);

        service.setTimeout(OcrRecognizerTimeout.thirtyMinutes);

        expect(service.getTimeout(), OcrRecognizerTimeout.thirtyMinutes);
      });

      test('should handle setting same timeout (no-op)', () {
        service.setTimeout(OcrRecognizerTimeout.fiveMinutes);

        // Should not throw or cause issues
        expect(service.getTimeout(), OcrRecognizerTimeout.fiveMinutes);
      });

      test('should handle immediate timeout', () {
        service.setTimeout(OcrRecognizerTimeout.immediate);

        expect(service.getTimeout(), OcrRecognizerTimeout.immediate);
      });

      test('should allow changing timeout multiple times', () {
        service.setTimeout(OcrRecognizerTimeout.oneMinute);
        expect(service.getTimeout(), OcrRecognizerTimeout.oneMinute);

        service.setTimeout(OcrRecognizerTimeout.thirtyMinutes);
        expect(service.getTimeout(), OcrRecognizerTimeout.thirtyMinutes);

        service.setTimeout(OcrRecognizerTimeout.immediate);
        expect(service.getTimeout(), OcrRecognizerTimeout.immediate);
      });
    });

    group('getRecognizerCount', () {
      test('should return 0 for new service', () {
        expect(service.getRecognizerCount(), 0);
      });

      test('should return 0 after clearCache', () async {
        await service.clearCache();

        expect(service.getRecognizerCount(), 0);
      });

      test('should return 0 after dispose', () async {
        await service.dispose();

        expect(service.getRecognizerCount(), 0);
      });
    });

    group('getActiveRecognizers', () {
      test('should return empty list for new service', () {
        expect(service.getActiveRecognizers(), isEmpty);
      });

      test('should return empty list after clearCache', () async {
        await service.clearCache();

        expect(service.getActiveRecognizers(), isEmpty);
      });
    });

    group('cleanup timer', () {
      test('should have timeout set', () {
        // Timer should be configurable
        // But we can verify timeout is set
        expect(service.getTimeout(), isNotNull);
      });

      test('should not start timer with immediate timeout', () {
        service.setTimeout(OcrRecognizerTimeout.immediate);

        // Service should still work
        expect(service.getTimeout(), OcrRecognizerTimeout.immediate);
      });

      test('should stop cleanup timer on dispose', () async {
        // This should stop the timer without throwing
        await service.dispose();

        expect(service.getRecognizerCount(), 0);
      });
    });

    group('clearCache', () {
      test('should clear all recognizers', () async {
        await service.clearCache();

        expect(service.getRecognizerCount(), 0);
        expect(service.getActiveRecognizers(), isEmpty);
      });

      test('should be safe to call multiple times', () async {
        await service.clearCache();
        await service.clearCache();

        expect(service.getRecognizerCount(), 0);
      });
    });

    group('dispose', () {
      test('should clear all recognizers', () async {
        await service.dispose();

        expect(service.getRecognizerCount(), 0);
      });

      test('should stop cleanup timer', () async {
        // Dispose should stop timer and clear state
        await service.dispose();

        expect(service.getRecognizerCount(), 0);
      });

      test('should be safe to call multiple times', () async {
        await service.dispose();
        await service.dispose();

        expect(service.getRecognizerCount(), 0);
      });

      test('should work on uninitialized service', () async {
        // Should not throw
        await service.dispose();

        expect(service.getRecognizerCount(), 0);
      });
    });

    group('initialization', () {
      test('should have default timeout configured', () {
        // Verify timeout is set
        expect(service.getTimeout(), OcrRecognizerTimeout.fiveMinutes);
      });
    });

    group('isReady', () {
      test('should return true for ML Kit', () {
        // ML Kit is always ready
        expect(service.isReady, true);
      });
    });

    group('availableLanguages', () {
      test('should return supported languages', () {
        final languages = service.availableLanguages;

        expect(languages, contains(OcrLanguage.latin));
        expect(languages, contains(OcrLanguage.chinese));
        expect(languages, contains(OcrLanguage.japanese));
        expect(languages, contains(OcrLanguage.korean));
        expect(languages, contains(OcrLanguage.devanagari));
      });
    });

    group('isLanguageAvailable', () {
      test('should return true for supported scripts', () {
        expect(service.isLanguageAvailable(OcrLanguage.latin), true);
        expect(service.isLanguageAvailable(OcrLanguage.chinese), true);
        expect(service.isLanguageAvailable(OcrLanguage.japanese), true);
        expect(service.isLanguageAvailable(OcrLanguage.korean), true);
        expect(service.isLanguageAvailable(OcrLanguage.devanagari), true);
      });

      test('should return true for legacy language codes', () {
        expect(service.isLanguageAvailable(OcrLanguage.english), true);
        expect(service.isLanguageAvailable(OcrLanguage.german), true);
        expect(service.isLanguageAvailable(OcrLanguage.french), true);
        expect(service.isLanguageAvailable(OcrLanguage.spanish), true);
      });
    });
  });
}

/// Helper function to test cache size formatting logic.
/// This mirrors the logic in OcrService.getCacheSizeFormatted().
String formatCacheSize(int size) {
  if (size < 1024) {
    return '$size B';
  } else if (size < 1024 * 1024) {
    return '${(size / 1024).toStringAsFixed(1)} KB';
  } else {
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
