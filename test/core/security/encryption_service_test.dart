import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:aiscan/core/security/encryption_service.dart';
import 'package:aiscan/core/security/secure_storage_service.dart';

import 'encryption_service_test.mocks.dart';

@GenerateMocks([SecureStorageService])
void main() {
  late MockSecureStorageService mockSecureStorage;
  late EncryptionService encryptionService;

  // Valid AES-256 key (32 bytes encoded as base64)
  final testKeyBytes = Uint8List.fromList(
    List.generate(32, (i) => i),
  );
  final testKey = base64Encode(testKeyBytes);

  setUp(() {
    mockSecureStorage = MockSecureStorageService();
    encryptionService = EncryptionService(secureStorage: mockSecureStorage);

    // Default mock behavior
    when(mockSecureStorage.getOrCreateEncryptionKey())
        .thenAnswer((_) async => testKey);
    when(mockSecureStorage.hasEncryptionKey()).thenAnswer((_) async => true);
  });

  group('EncryptionService', () {
    group('encrypt/decrypt', () {
      test('should encrypt and decrypt data correctly (round-trip)', () async {
        // Arrange
        final originalData = Uint8List.fromList(
          utf8.encode('Hello, this is sensitive data!'),
        );

        // Act
        final encrypted = await encryptionService.encrypt(originalData);
        final decrypted = await encryptionService.decrypt(encrypted);

        // Assert
        expect(decrypted, equals(originalData));
      });

      test('should produce different ciphertext for same plaintext (unique IV)',
          () async {
        // Arrange
        final data = Uint8List.fromList(utf8.encode('Same data'));

        // Act
        final encrypted1 = await encryptionService.encrypt(data);
        final encrypted2 = await encryptionService.encrypt(data);

        // Assert - encrypted outputs should be different due to unique IVs
        expect(encrypted1, isNot(equals(encrypted2)));

        // But both should decrypt to the same original data
        final decrypted1 = await encryptionService.decrypt(encrypted1);
        final decrypted2 = await encryptionService.decrypt(encrypted2);
        expect(decrypted1, equals(data));
        expect(decrypted2, equals(data));
      });

      test('should handle binary data correctly', () async {
        // Arrange - binary data including null bytes
        final binaryData = Uint8List.fromList([
          0x00,
          0x01,
          0x02,
          0xFF,
          0xFE,
          0x00,
          0x10,
          0x20,
        ]);

        // Act
        final encrypted = await encryptionService.encrypt(binaryData);
        final decrypted = await encryptionService.decrypt(encrypted);

        // Assert
        expect(decrypted, equals(binaryData));
      });

      test('should handle large data', () async {
        // Arrange - 100KB of data
        final largeData = Uint8List.fromList(
          List.generate(100 * 1024, (i) => i % 256),
        );

        // Act
        final encrypted = await encryptionService.encrypt(largeData);
        final decrypted = await encryptionService.decrypt(encrypted);

        // Assert
        expect(decrypted, equals(largeData));
      });

      test('should prepend IV and append HMAC to encrypted data', () async {
        // Arrange
        final data = Uint8List.fromList(utf8.encode('Test'));

        // Act
        final encrypted = await encryptionService.encrypt(data);

        // Assert - encrypted data should be at least 48 bytes (16 IV + data + 32 HMAC)
        expect(encrypted.length, greaterThanOrEqualTo(48));
      });

      test('should throw EncryptionException for empty data', () async {
        // Arrange
        final emptyData = Uint8List(0);

        // Act & Assert
        expect(
          () => encryptionService.encrypt(emptyData),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('should throw EncryptionException for empty encrypted data',
          () async {
        // Arrange
        final emptyData = Uint8List(0);

        // Act & Assert
        expect(
          () => encryptionService.decrypt(emptyData),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('should throw EncryptionException for data too short to contain IV',
          () async {
        // Arrange - less than 16 bytes (IV size)
        final shortData = Uint8List.fromList([1, 2, 3, 4, 5]);

        // Act & Assert
        expect(
          () => encryptionService.decrypt(shortData),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('should throw exception for corrupted data (HMAC verification)',
          () async {
        // Arrange
        final data = Uint8List.fromList(utf8.encode('Test'));
        final encrypted = await encryptionService.encrypt(data);

        // Corrupt the encrypted data (modify a byte in ciphertext)
        encrypted[20] = (encrypted[20] + 1) % 256;

        // Act & Assert - HMAC verification should fail
        // Note: Implementation may fall back to legacy format, so accept either exception
        expect(
          () => encryptionService.decrypt(encrypted),
          throwsA(
            anyOf(
              isA<IntegrityException>(),
              isA<EncryptionException>(),
            ),
          ),
        );
      });
    });

    group('encryptString/decryptString', () {
      test('should encrypt and decrypt string correctly', () async {
        // Arrange
        const originalString = 'Document Title: Important Report';

        // Act
        final encrypted = await encryptionService.encryptString(originalString);
        final decrypted = await encryptionService.decryptString(encrypted);

        // Assert
        expect(decrypted, equals(originalString));
      });

      test('should handle unicode characters', () async {
        // Arrange
        const unicodeString = 'Hello \u{1F600} World \u{1F30D} Test';

        // Act
        final encrypted = await encryptionService.encryptString(unicodeString);
        final decrypted = await encryptionService.decryptString(encrypted);

        // Assert
        expect(decrypted, equals(unicodeString));
      });

      test('should handle multi-line strings', () async {
        // Arrange
        const multilineString = 'Line 1\nLine 2\r\nLine 3\tTabbed';

        // Act
        final encrypted =
            await encryptionService.encryptString(multilineString);
        final decrypted = await encryptionService.decryptString(encrypted);

        // Assert
        expect(decrypted, equals(multilineString));
      });

      test('should throw EncryptionException for empty string', () async {
        // Act & Assert
        expect(
          () => encryptionService.encryptString(''),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('should throw EncryptionException for empty encrypted string',
          () async {
        // Act & Assert
        expect(
          () => encryptionService.decryptString(''),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('should throw EncryptionException for invalid base64', () async {
        // Arrange - invalid base64 string
        const invalidBase64 = 'not-valid-base64!@#\$%';

        // Act & Assert
        expect(
          () => encryptionService.decryptString(invalidBase64),
          throwsA(isA<EncryptionException>()),
        );
      });
    });

    group('isLikelyEncrypted', () {
      test('should return true for encrypted data', () async {
        // Arrange
        final data = Uint8List.fromList(utf8.encode('Test data'));
        final encrypted = await encryptionService.encrypt(data);

        // Act
        final result = encryptionService.isLikelyEncrypted(encrypted);

        // Assert
        expect(result, isTrue);
      });

      test('should return false for empty data', () {
        // Arrange
        final emptyData = Uint8List(0);

        // Act
        final result = encryptionService.isLikelyEncrypted(emptyData);

        // Assert
        expect(result, isFalse);
      });

      test('should return false for data shorter than IV', () {
        // Arrange - less than 16 bytes
        final shortData = Uint8List.fromList([1, 2, 3, 4, 5]);

        // Act
        final result = encryptionService.isLikelyEncrypted(shortData);

        // Assert
        expect(result, isFalse);
      });

      test('should return false for data exactly equal to IV length', () {
        // Arrange - exactly 16 bytes
        final ivLengthData = Uint8List(16);

        // Act
        final result = encryptionService.isLikelyEncrypted(ivLengthData);

        // Assert
        expect(result, isFalse);
      });
    });

    group('ensureKeyInitialized', () {
      test('should return true when key is created', () async {
        // Arrange
        when(mockSecureStorage.hasEncryptionKey())
            .thenAnswer((_) async => false);

        // Act
        final result = await encryptionService.ensureKeyInitialized();

        // Assert
        expect(result, isTrue);
        verify(mockSecureStorage.getOrCreateEncryptionKey()).called(1);
      });

      test('should return false when key already exists', () async {
        // Arrange
        when(mockSecureStorage.hasEncryptionKey())
            .thenAnswer((_) async => true);

        // Act
        final result = await encryptionService.ensureKeyInitialized();

        // Assert
        expect(result, isFalse);
      });
    });

    group('isReady', () {
      test('should return true when encryption key exists', () async {
        // Arrange
        when(mockSecureStorage.hasEncryptionKey())
            .thenAnswer((_) async => true);

        // Act
        final result = await encryptionService.isReady();

        // Assert
        expect(result, isTrue);
      });

      test('should return false when encryption key does not exist', () async {
        // Arrange
        when(mockSecureStorage.hasEncryptionKey())
            .thenAnswer((_) async => false);

        // Act
        final result = await encryptionService.isReady();

        // Assert
        expect(result, isFalse);
      });
    });

    group('clearCache', () {
      test('should clear cached key and require re-fetch', () async {
        // Arrange
        final data = Uint8List.fromList(utf8.encode('Test'));

        // First encryption - fetches key
        await encryptionService.encrypt(data);
        verify(mockSecureStorage.getOrCreateEncryptionKey()).called(1);

        // Second encryption - uses cache
        await encryptionService.encrypt(data);
        verifyNever(mockSecureStorage.getOrCreateEncryptionKey());

        // Act - clear cache
        encryptionService.clearCache();

        // Third encryption - should fetch key again
        await encryptionService.encrypt(data);

        // Assert
        verify(mockSecureStorage.getOrCreateEncryptionKey()).called(1);
      });
    });

    group('error handling', () {
      test('should throw EncryptionException when key retrieval fails',
          () async {
        // Arrange
        when(mockSecureStorage.getOrCreateEncryptionKey())
            .thenThrow(Exception('Storage error'));

        // Clear cache to force key fetch
        encryptionService.clearCache();

        // Act & Assert
        expect(
          () => encryptionService.encrypt(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('should throw EncryptionException for invalid key size', () async {
        // Arrange - invalid key size (not 32 bytes)
        final invalidKey = base64Encode(Uint8List.fromList([1, 2, 3]));
        when(mockSecureStorage.getOrCreateEncryptionKey())
            .thenAnswer((_) async => invalidKey);

        // Clear cache to force key fetch
        encryptionService.clearCache();

        // Act & Assert
        expect(
          () => encryptionService.encrypt(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<EncryptionException>()),
        );
      });
    });

    group('file encryption path validation', () {
      test('should throw EncryptionException for empty input path', () async {
        // Act & Assert
        expect(
          () => encryptionService.encryptFile('', '/output/path'),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('should throw EncryptionException for empty output path', () async {
        // Act & Assert
        expect(
          () => encryptionService.encryptFile('/input/path', ''),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('should throw EncryptionException when paths are the same',
          () async {
        // Arrange
        const samePath = '/path/to/file.dat';

        // Act & Assert
        expect(
          () => encryptionService.encryptFile(samePath, samePath),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('decryptFile should throw EncryptionException for empty input path',
          () async {
        // Act & Assert
        expect(
          () => encryptionService.decryptFile('', '/output/path'),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('decryptFile should throw EncryptionException for empty output path',
          () async {
        // Act & Assert
        expect(
          () => encryptionService.decryptFile('/input/path', ''),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('decryptFile should throw EncryptionException when paths are same',
          () async {
        // Arrange
        const samePath = '/path/to/file.dat';

        // Act & Assert
        expect(
          () => encryptionService.decryptFile(samePath, samePath),
          throwsA(isA<EncryptionException>()),
        );
      });
    });
  });

  group('EncryptionException', () {
    test('should format message without cause', () {
      // Arrange
      const exception = EncryptionException('Test error');

      // Act
      final message = exception.toString();

      // Assert
      expect(message, equals('EncryptionException: Test error'));
    });

    test('should format message with cause', () {
      // Arrange
      final cause = Exception('Root cause');
      final exception = EncryptionException('Test error', cause: cause);

      // Act
      final message = exception.toString();

      // Assert
      expect(
        message,
        equals(
          'EncryptionException: Test error (caused by: Exception: Root cause)',
        ),
      );
    });

    test('should store message and cause', () {
      // Arrange
      final cause = Exception('Root cause');
      const errorMessage = 'Test error';
      final exception = EncryptionException(errorMessage, cause: cause);

      // Assert
      expect(exception.message, equals(errorMessage));
      expect(exception.cause, equals(cause));
    });
  });

  group('IntegrityException', () {
    test('should format message without cause', () {
      // Arrange
      const exception = IntegrityException('Integrity check failed');

      // Act
      final message = exception.toString();

      // Assert
      expect(message, equals('IntegrityException: Integrity check failed'));
    });

    test('should format message with cause', () {
      // Arrange
      final cause = Exception('HMAC mismatch');
      final exception =
          IntegrityException('Integrity check failed', cause: cause);

      // Act
      final message = exception.toString();

      // Assert
      expect(
        message,
        equals(
          'IntegrityException: Integrity check failed (caused by: Exception: HMAC mismatch)',
        ),
      );
    });

    test('should store message and cause', () {
      // Arrange
      final cause = Exception('Data tampering detected');
      const errorMessage = 'Integrity verification failed';
      final exception = IntegrityException(errorMessage, cause: cause);

      // Assert
      expect(exception.message, equals(errorMessage));
      expect(exception.cause, equals(cause));
    });
  });

  group('encryptionServiceProvider', () {
    test('should provide EncryptionService with SecureStorageService', () {
      // Arrange
      final container = ProviderContainer();

      // Act
      final service = container.read(encryptionServiceProvider);

      // Assert
      expect(service, isA<EncryptionService>());

      container.dispose();
    });
  });
}
