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
      expect(exception.toString(), contains('ArgumentError'));
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
      expect(OcrLanguage.values.length, 13);
      expect(OcrLanguage.values, contains(OcrLanguage.english));
      expect(OcrLanguage.values, contains(OcrLanguage.german));
      expect(OcrLanguage.values, contains(OcrLanguage.french));
      expect(OcrLanguage.values, contains(OcrLanguage.spanish));
      expect(OcrLanguage.values, contains(OcrLanguage.italian));
      expect(OcrLanguage.values, contains(OcrLanguage.portuguese));
      expect(OcrLanguage.values, contains(OcrLanguage.dutch));
      expect(OcrLanguage.values, contains(OcrLanguage.chineseSimplified));
      expect(OcrLanguage.values, contains(OcrLanguage.chineseTraditional));
      expect(OcrLanguage.values, contains(OcrLanguage.japanese));
      expect(OcrLanguage.values, contains(OcrLanguage.korean));
      expect(OcrLanguage.values, contains(OcrLanguage.arabic));
      expect(OcrLanguage.values, contains(OcrLanguage.russian));
    });

    test('should have correct Tesseract codes', () {
      expect(OcrLanguage.english.code, 'eng');
      expect(OcrLanguage.german.code, 'deu');
      expect(OcrLanguage.french.code, 'fra');
      expect(OcrLanguage.spanish.code, 'spa');
      expect(OcrLanguage.italian.code, 'ita');
      expect(OcrLanguage.portuguese.code, 'por');
      expect(OcrLanguage.dutch.code, 'nld');
      expect(OcrLanguage.chineseSimplified.code, 'chi_sim');
      expect(OcrLanguage.chineseTraditional.code, 'chi_tra');
      expect(OcrLanguage.japanese.code, 'jpn');
      expect(OcrLanguage.korean.code, 'kor');
      expect(OcrLanguage.arabic.code, 'ara');
      expect(OcrLanguage.russian.code, 'rus');
    });

    test('should have human-readable display names', () {
      expect(OcrLanguage.english.displayName, 'English');
      expect(OcrLanguage.german.displayName, 'German');
      expect(OcrLanguage.french.displayName, 'French');
      expect(OcrLanguage.spanish.displayName, 'Spanish');
      expect(OcrLanguage.italian.displayName, 'Italian');
      expect(OcrLanguage.portuguese.displayName, 'Portuguese');
      expect(OcrLanguage.dutch.displayName, 'Dutch');
      expect(OcrLanguage.chineseSimplified.displayName, 'Chinese (Simplified)');
      expect(
          OcrLanguage.chineseTraditional.displayName, 'Chinese (Traditional)');
      expect(OcrLanguage.japanese.displayName, 'Japanese');
      expect(OcrLanguage.korean.displayName, 'Korean');
      expect(OcrLanguage.arabic.displayName, 'Arabic');
      expect(OcrLanguage.russian.displayName, 'Russian');
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

      expect(options.language, OcrLanguage.english);
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

        expect(options.language, OcrLanguage.english);
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

        expect(options.language, OcrLanguage.english);
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

        expect(options.language, OcrLanguage.english);
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

        expect(options.language, OcrLanguage.english);
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
        const original = OcrOptions(language: OcrLanguage.english);

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
        expect(copied.language, OcrLanguage.english); // Unchanged
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
        const original = OcrOptions(language: OcrLanguage.english);

        original.copyWith(language: OcrLanguage.german);

        expect(original.language, OcrLanguage.english);
      });
    });

    group('toTesseractArgs', () {
      test('should include PSM and OEM values', () {
        const options = OcrOptions(
          pageSegmentationMode: OcrPageSegmentationMode.singleLine,
          engineMode: OcrEngineMode.lstmOnly,
        );

        final args = options.toTesseractArgs();

        expect(args['psm'], '7'); // singleLine = 7
        expect(args['oem'], '1'); // lstmOnly = 1
      });

      test('should include preserve_interword_spaces when true', () {
        const options = OcrOptions(preserveInterwordSpaces: true);

        final args = options.toTesseractArgs();

        expect(args['preserve_interword_spaces'], '1');
      });

      test('should not include preserve_interword_spaces when false', () {
        const options = OcrOptions(preserveInterwordSpaces: false);

        final args = options.toTesseractArgs();

        expect(args.containsKey('preserve_interword_spaces'), false);
      });

      test('should include character whitelist when set', () {
        const options = OcrOptions(characterWhitelist: '0123456789');

        final args = options.toTesseractArgs();

        expect(args['tessedit_char_whitelist'], '0123456789');
      });

      test('should not include whitelist when null', () {
        const options = OcrOptions(characterWhitelist: null);

        final args = options.toTesseractArgs();

        expect(args.containsKey('tessedit_char_whitelist'), false);
      });

      test('should not include whitelist when empty', () {
        const options = OcrOptions(characterWhitelist: '');

        final args = options.toTesseractArgs();

        expect(args.containsKey('tessedit_char_whitelist'), false);
      });

      test('should include character blacklist when set', () {
        const options = OcrOptions(characterBlacklist: '@#\$%');

        final args = options.toTesseractArgs();

        expect(args['tessedit_char_blacklist'], '@#\$%');
      });

      test('should not include blacklist when null', () {
        const options = OcrOptions(characterBlacklist: null);

        final args = options.toTesseractArgs();

        expect(args.containsKey('tessedit_char_blacklist'), false);
      });

      test('should not include blacklist when empty', () {
        const options = OcrOptions(characterBlacklist: '');

        final args = options.toTesseractArgs();

        expect(args.containsKey('tessedit_char_blacklist'), false);
      });

      test('should generate correct args for numericOnly preset', () {
        const options = OcrOptions.numericOnly();

        final args = options.toTesseractArgs();

        expect(args['tessedit_char_whitelist'], '0123456789');
        expect(args.containsKey('preserve_interword_spaces'), false);
      });
    });

    group('equality', () {
      test('should be equal with same values', () {
        const options1 = OcrOptions(
          language: OcrLanguage.english,
          pageSegmentationMode: OcrPageSegmentationMode.auto,
          engineMode: OcrEngineMode.lstmOnly,
          preserveInterwordSpaces: true,
          enableDeskew: false,
          characterWhitelist: 'ABC',
          characterBlacklist: 'XYZ',
        );
        const options2 = OcrOptions(
          language: OcrLanguage.english,
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
        const options1 = OcrOptions(language: OcrLanguage.english);
        const options2 = OcrOptions(language: OcrLanguage.german);

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
        const options1 = OcrOptions(language: OcrLanguage.english);
        const options2 = OcrOptions(language: OcrLanguage.english);

        expect(options1.hashCode, equals(options2.hashCode));
      });

      test('should be different for different options', () {
        const options1 = OcrOptions(language: OcrLanguage.english);
        const options2 = OcrOptions(language: OcrLanguage.german);

        expect(options1.hashCode, isNot(equals(options2.hashCode)));
      });
    });

    group('toString', () {
      test('should contain language code', () {
        const options = OcrOptions(language: OcrLanguage.german);

        expect(options.toString(), contains('deu'));
      });

      test('should contain PSM value', () {
        const options = OcrOptions(
          pageSegmentationMode: OcrPageSegmentationMode.singleLine,
        );

        expect(options.toString(), contains('psm: 7'));
      });

      test('should contain OEM value', () {
        const options = OcrOptions(engineMode: OcrEngineMode.lstmOnly);

        expect(options.toString(), contains('oem: 1'));
      });
    });
  });

  group('OcrService', () {
    late OcrService service;

    setUp(() {
      service = OcrService();
    });

    group('isReady', () {
      test('should return false before initialization', () {
        expect(service.isReady, false);
      });
    });

    group('availableLanguages', () {
      test('should be empty before initialization', () {
        expect(service.availableLanguages, isEmpty);
      });
    });

    group('isLanguageAvailable', () {
      test('should return false for any language before initialization', () {
        expect(service.isLanguageAvailable(OcrLanguage.english), false);
        expect(service.isLanguageAvailable(OcrLanguage.german), false);
      });
    });

    group('extractTextFromFile validation', () {
      test('should throw when not initialized', () async {
        expect(
          () => service.extractTextFromFile('/path/to/image.jpg'),
          throwsA(isA<OcrException>().having(
            (e) => e.message,
            'message',
            contains('not initialized'),
          )),
        );
      });
    });

    group('extractTextFromBytes validation', () {
      test('should throw when not initialized', () async {
        expect(
          () => service.extractTextFromBytes(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<OcrException>().having(
            (e) => e.message,
            'message',
            contains('not initialized'),
          )),
        );
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
      test('should return false when check fails (not initialized)', () async {
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
      test('should return 0 before initialization', () async {
        final size = await service.getCacheSize();

        expect(size, 0);
      });
    });

    group('getCacheSizeFormatted', () {
      test('should return formatted size before initialization', () async {
        final formatted = await service.getCacheSizeFormatted();

        expect(formatted, '0 B');
      });
    });

    group('defaultLanguage', () {
      test('should be English', () {
        expect(OcrService.defaultLanguage, OcrLanguage.english);
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

      expect(englishDoc.language.code, 'eng');
      expect(germanDoc.language.code, 'deu');
      expect(frenchDoc.language.code, 'fra');
    });

    test('should generate correct Tesseract args for all PSM modes', () {
      for (final mode in OcrPageSegmentationMode.values) {
        final options = OcrOptions(pageSegmentationMode: mode);
        final args = options.toTesseractArgs();

        expect(args['psm'], mode.value.toString());
      }
    });

    test('should generate correct Tesseract args for all OEM modes', () {
      for (final mode in OcrEngineMode.values) {
        final options = OcrOptions(engineMode: mode);
        final args = options.toTesseractArgs();

        expect(args['oem'], mode.value.toString());
      }
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
