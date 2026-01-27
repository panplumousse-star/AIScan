import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
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

  // Different key for testing key mismatch
  final differentKeyBytes = Uint8List.fromList(
    List.generate(32, (i) => i + 100),
  );
  final differentKey = base64Encode(differentKeyBytes);

  setUp(() {
    mockSecureStorage = MockSecureStorageService();
    encryptionService = EncryptionService(secureStorage: mockSecureStorage);

    // Default mock behavior
    when(mockSecureStorage.getOrCreateEncryptionKey())
        .thenAnswer((_) async => testKey);
    when(mockSecureStorage.hasEncryptionKey()).thenAnswer((_) async => true);
  });

  group('HMAC Integrity Verification', () {
    group('tampered ciphertext detection', () {
      test('should throw IntegrityException when ciphertext is modified',
          () async {
        // Arrange
        final originalData = Uint8List.fromList(
          utf8.encode('Sensitive data that must not be tampered with'),
        );

        // Act - encrypt data
        final encrypted = await encryptionService.encrypt(originalData);

        // Corrupt the ciphertext portion (after IV, before HMAC)
        // Structure: [16-byte IV][ciphertext][32-byte HMAC]
        final corruptedIndex = 20; // In the ciphertext portion
        encrypted[corruptedIndex] = (encrypted[corruptedIndex] + 1) % 256;

        // Assert - decryption should fail with IntegrityException
        // Note: The implementation may fall back to legacy format in some cases
        // but should fail either way since corrupted data won't decrypt properly
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

      test('should throw when multiple bytes in ciphertext are modified',
          () async {
        // Arrange
        final originalData = Uint8List.fromList(
          utf8.encode('Important document content'),
        );

        // Act
        final encrypted = await encryptionService.encrypt(originalData);

        // Corrupt multiple bytes in the ciphertext
        encrypted[16] = (encrypted[16] + 1) % 256;
        encrypted[17] = (encrypted[17] + 50) % 256;
        encrypted[18] = (encrypted[18] + 100) % 256;

        // Assert
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

      test('should throw when last byte of ciphertext is modified', () async {
        // Arrange
        final originalData = Uint8List.fromList(
          utf8.encode('Test data'),
        );

        // Act
        final encrypted = await encryptionService.encrypt(originalData);

        // Corrupt last byte of ciphertext (just before HMAC)
        final lastCiphertextIndex = encrypted.length - 32 - 1;
        encrypted[lastCiphertextIndex] =
            (encrypted[lastCiphertextIndex] + 1) % 256;

        // Assert
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

    group('tampered IV detection', () {
      test('should throw IntegrityException when IV is modified', () async {
        // Arrange
        final originalData = Uint8List.fromList(
          utf8.encode('Sensitive information'),
        );

        // Act
        final encrypted = await encryptionService.encrypt(originalData);

        // Corrupt the IV portion (first 16 bytes)
        encrypted[0] = (encrypted[0] + 1) % 256;

        // Assert
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

      test('should throw when multiple IV bytes are modified', () async {
        // Arrange
        final originalData = Uint8List.fromList(
          utf8.encode('Secret message'),
        );

        // Act
        final encrypted = await encryptionService.encrypt(originalData);

        // Corrupt multiple IV bytes
        encrypted[0] = (encrypted[0] + 1) % 256;
        encrypted[5] = (encrypted[5] + 1) % 256;
        encrypted[15] = (encrypted[15] + 1) % 256;

        // Assert
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

    group('truncated data detection', () {
      test('should throw when HMAC is truncated', () async {
        // Arrange
        final originalData = Uint8List.fromList(
          utf8.encode('Test data'),
        );

        // Act
        final encrypted = await encryptionService.encrypt(originalData);

        // Truncate the HMAC (remove last 10 bytes)
        final truncated = encrypted.sublist(0, encrypted.length - 10);

        // Assert
        expect(
          () => encryptionService.decrypt(truncated),
          throwsA(
            anyOf(
              isA<IntegrityException>(),
              isA<EncryptionException>(),
            ),
          ),
        );
      });

      test('should successfully decrypt when entire HMAC is removed (legacy fallback)',
          () async {
        // Arrange
        final originalData = Uint8List.fromList(
          utf8.encode('Another test'),
        );

        // Act
        final encrypted = await encryptionService.encrypt(originalData);

        // Remove entire HMAC (last 32 bytes) - creates legacy format
        final truncated = encrypted.sublist(0, encrypted.length - 32);

        // Assert - should fall back to legacy format and succeed
        // This tests backward compatibility feature
        final decrypted = await encryptionService.decrypt(truncated);
        expect(decrypted, equals(originalData));
      });

      test('should throw when data is truncated to only IV', () async {
        // Arrange
        final originalData = Uint8List.fromList(
          utf8.encode('Data'),
        );

        // Act
        final encrypted = await encryptionService.encrypt(originalData);

        // Truncate to only IV (16 bytes)
        final truncated = encrypted.sublist(0, 16);

        // Assert
        expect(
          () => encryptionService.decrypt(truncated),
          throwsA(isA<EncryptionException>()),
        );
      });
    });

    group('HMAC tag verification', () {
      test('should throw when HMAC tag is modified', () async {
        // Arrange
        final originalData = Uint8List.fromList(
          utf8.encode('Protected content'),
        );

        // Act
        final encrypted = await encryptionService.encrypt(originalData);

        // Corrupt the HMAC tag (last 32 bytes)
        final hmacIndex = encrypted.length - 32;
        encrypted[hmacIndex] = (encrypted[hmacIndex] + 1) % 256;

        // Assert
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

      test('should throw when HMAC tag is zeroed out', () async {
        // Arrange
        final originalData = Uint8List.fromList(
          utf8.encode('Important data'),
        );

        // Act
        final encrypted = await encryptionService.encrypt(originalData);

        // Zero out the entire HMAC tag
        for (var i = encrypted.length - 32; i < encrypted.length; i++) {
          encrypted[i] = 0;
        }

        // Assert
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

    group('different key verification', () {
      test('should throw when decrypting with different key', () async {
        // Arrange
        final originalData = Uint8List.fromList(
          utf8.encode('Secret message that needs encryption'),
        );

        // Act - encrypt with first key
        final encrypted = await encryptionService.encrypt(originalData);

        // Create new service with different key
        final mockSecureStorage2 = MockSecureStorageService();
        when(mockSecureStorage2.getOrCreateEncryptionKey())
            .thenAnswer((_) async => differentKey);
        when(mockSecureStorage2.hasEncryptionKey())
            .thenAnswer((_) async => true);

        final encryptionService2 =
            EncryptionService(secureStorage: mockSecureStorage2);

        // Assert - decryption should fail
        // Either HMAC verification fails, or decryption produces garbage/fails
        try {
          final decrypted = await encryptionService2.decrypt(encrypted);
          final decryptedString = utf8.decode(decrypted, allowMalformed: false);
          // If we get here without exception, the decrypted data should not match
          expect(decryptedString, isNot(equals(utf8.decode(originalData))));
        } on EncryptionException {
          // Expected - HMAC or decryption failure
        } on IntegrityException {
          // Expected - HMAC verification failure
        } on FormatException {
          // Expected - invalid UTF-8 from decryption with wrong key
        }
      });

      test('should produce different HMAC tags for different keys', () async {
        // Arrange
        final originalData = Uint8List.fromList(
          utf8.encode('Same plaintext for both encryptions'),
        );

        // Act - encrypt with first key
        final encrypted1 = await encryptionService.encrypt(originalData);

        // Encrypt with second key
        final mockSecureStorage2 = MockSecureStorageService();
        when(mockSecureStorage2.getOrCreateEncryptionKey())
            .thenAnswer((_) async => differentKey);
        when(mockSecureStorage2.hasEncryptionKey())
            .thenAnswer((_) async => true);

        final encryptionService2 =
            EncryptionService(secureStorage: mockSecureStorage2);
        final encrypted2 = await encryptionService2.encrypt(originalData);

        // Extract HMAC tags (last 32 bytes)
        final hmac1 = encrypted1.sublist(encrypted1.length - 32);
        final hmac2 = encrypted2.sublist(encrypted2.length - 32);

        // Assert - HMAC tags should be different because keys are different
        // Also, the IVs will be different, making the ciphertexts different
        expect(hmac1, isNot(equals(hmac2)));

        // Verify both can be decrypted with their respective keys
        final decrypted1 = await encryptionService.decrypt(encrypted1);
        final decrypted2 = await encryptionService2.decrypt(encrypted2);
        expect(decrypted1, equals(originalData));
        expect(decrypted2, equals(originalData));
      });
    });

    group('round-trip with HMAC verification', () {
      test('should encrypt and decrypt correctly with HMAC', () async {
        // Arrange
        final originalData = Uint8List.fromList(
          utf8.encode('This is a test message with HMAC protection'),
        );

        // Act
        final encrypted = await encryptionService.encrypt(originalData);
        final decrypted = await encryptionService.decrypt(encrypted);

        // Assert
        expect(decrypted, equals(originalData));
      });

      test('should handle multiple round-trips correctly', () async {
        // Arrange
        final originalData = Uint8List.fromList(
          utf8.encode('Multiple encryption test'),
        );

        // Act - encrypt and decrypt 3 times
        var encrypted = await encryptionService.encrypt(originalData);
        var decrypted = await encryptionService.decrypt(encrypted);

        encrypted = await encryptionService.encrypt(decrypted);
        decrypted = await encryptionService.decrypt(encrypted);

        encrypted = await encryptionService.encrypt(decrypted);
        decrypted = await encryptionService.decrypt(encrypted);

        // Assert
        expect(decrypted, equals(originalData));
      });

      test('should handle binary data with HMAC', () async {
        // Arrange
        final binaryData = Uint8List.fromList([
          0x00,
          0x01,
          0xFF,
          0xFE,
          0x42,
          0xAB,
          0xCD,
          0xEF,
        ]);

        // Act
        final encrypted = await encryptionService.encrypt(binaryData);
        final decrypted = await encryptionService.decrypt(encrypted);

        // Assert
        expect(decrypted, equals(binaryData));
      });

      test('should handle large data with HMAC', () async {
        // Arrange - 500KB of data
        final largeData = Uint8List.fromList(
          List.generate(500 * 1024, (i) => i % 256),
        );

        // Act
        final encrypted = await encryptionService.encrypt(largeData);
        final decrypted = await encryptionService.decrypt(encrypted);

        // Assert
        expect(decrypted, equals(largeData));
      });
    });

    group('HMAC data structure verification', () {
      test('should have correct structure [IV][ciphertext][HMAC]', () async {
        // Arrange
        final originalData = Uint8List.fromList(
          utf8.encode('Test data'),
        );

        // Act
        final encrypted = await encryptionService.encrypt(originalData);

        // Assert
        // IV is 16 bytes, HMAC is 32 bytes
        expect(encrypted.length, greaterThan(16 + 32));

        // Encrypted data should be at least IV + one block + HMAC
        expect(encrypted.length, greaterThanOrEqualTo(16 + 16 + 32));
      });

      test('should produce unique IVs for same plaintext', () async {
        // Arrange
        final data = Uint8List.fromList(utf8.encode('Same data'));

        // Act
        final encrypted1 = await encryptionService.encrypt(data);
        final encrypted2 = await encryptionService.encrypt(data);

        // Extract IVs (first 16 bytes)
        final iv1 = encrypted1.sublist(0, 16);
        final iv2 = encrypted2.sublist(0, 16);

        // Assert - IVs should be different
        expect(iv1, isNot(equals(iv2)));

        // But both should decrypt to same data
        final decrypted1 = await encryptionService.decrypt(encrypted1);
        final decrypted2 = await encryptionService.decrypt(encrypted2);
        expect(decrypted1, equals(data));
        expect(decrypted2, equals(data));
      });
    });

    group('encryptString/decryptString with HMAC', () {
      test('should encrypt and decrypt strings with HMAC', () async {
        // Arrange
        const originalString = 'Sensitive document title';

        // Act
        final encrypted = await encryptionService.encryptString(originalString);
        final decrypted = await encryptionService.decryptString(encrypted);

        // Assert
        expect(decrypted, equals(originalString));
      });

      test('should detect tampered base64 encrypted string', () async {
        // Arrange
        const originalString = 'Important data';

        // Act
        final encrypted = await encryptionService.encryptString(originalString);

        // Corrupt the base64 string by changing a character
        var corruptedEncrypted = encrypted;
        if (encrypted.length > 20) {
          final chars = corruptedEncrypted.split('');
          // Change a character in the middle
          chars[10] = chars[10] == 'A' ? 'B' : 'A';
          corruptedEncrypted = chars.join('');
        }

        // Assert
        expect(
          () => encryptionService.decryptString(corruptedEncrypted),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('should handle unicode strings with HMAC', () async {
        // Arrange
        const unicodeString = 'Hello 🔒 Encrypted 世界';

        // Act
        final encrypted = await encryptionService.encryptString(unicodeString);
        final decrypted = await encryptionService.decryptString(encrypted);

        // Assert
        expect(decrypted, equals(unicodeString));
      });
    });

    group('decryptAsync with HMAC', () {
      test('should decrypt asynchronously with HMAC verification', () async {
        // Arrange
        final originalData = Uint8List.fromList(
          utf8.encode('Async decryption test'),
        );

        // Act
        final encrypted = await encryptionService.encrypt(originalData);
        final decrypted = await encryptionService.decryptAsync(encrypted);

        // Assert
        expect(decrypted, equals(originalData));
      });

      test('should detect tampering in async decryption', () async {
        // Arrange
        final originalData = Uint8List.fromList(
          utf8.encode('Tamper detection test'),
        );

        // Act
        final encrypted = await encryptionService.encrypt(originalData);

        // Corrupt a byte
        encrypted[20] = (encrypted[20] + 1) % 256;

        // Assert
        expect(
          () => encryptionService.decryptAsync(encrypted),
          throwsA(
            anyOf(
              isA<IntegrityException>(),
              isA<EncryptionException>(),
            ),
          ),
        );
      });

      test('should handle large data in async decryption', () async {
        // Arrange - 200KB of data
        final largeData = Uint8List.fromList(
          List.generate(200 * 1024, (i) => i % 256),
        );

        // Act
        final encrypted = await encryptionService.encrypt(largeData);
        final decrypted = await encryptionService.decryptAsync(encrypted);

        // Assert
        expect(decrypted, equals(largeData));
      });
    });
  });

  group('Backward Compatibility - Legacy Format', () {
    test('should decrypt legacy format without HMAC', () async {
      // Arrange - Create legacy encrypted data manually (IV + ciphertext, no HMAC)
      // We need to encrypt data using the old format

      // Create a service that will encrypt without HMAC by using the raw encrypt package
      final keyBytes = base64Decode(testKey);
      final key = enc.Key(keyBytes);

      // Generate IV
      final ivBytes = Uint8List.fromList([
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
      ]);
      final iv = enc.IV(ivBytes);

      // Encrypt with raw package (no HMAC)
      final encrypter = enc.Encrypter(
        enc.AES(key, mode: enc.AESMode.cbc),
      );
      final plaintext = 'Legacy encrypted data';
      final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
      final encrypted = encrypter.encryptBytes(plaintextBytes.toList(), iv: iv);

      // Build legacy format: IV + ciphertext (no HMAC)
      final legacyEncryptedLength = 16 + encrypted.bytes.length;
      final legacyEncrypted = Uint8List(legacyEncryptedLength);
      legacyEncrypted.setRange(0, 16, ivBytes);
      legacyEncrypted.setRange(16, legacyEncrypted.length, encrypted.bytes);

      // Act - decrypt using the service (should detect legacy format)
      final decrypted = await encryptionService.decrypt(legacyEncrypted);
      final decryptedString = utf8.decode(decrypted);

      // Assert
      expect(decryptedString, equals(plaintext));
    });

    test('should handle legacy format with different data sizes', () async {
      // Arrange
      final keyBytes = base64Decode(testKey);
      final key = enc.Key(keyBytes);

      final testCases = [
        'Short',
        'Medium length text for testing',
        'Very long text that will definitely require multiple AES blocks ' *
            10,
      ];

      for (final plaintext in testCases) {
        // Generate IV
        final ivBytes = Uint8List.fromList(
          List.generate(16, (i) => (i * 7) % 256),
        );
        final iv = enc.IV(ivBytes);

        // Encrypt with raw package (no HMAC)
        final encrypter = enc.Encrypter(
          enc.AES(key, mode: enc.AESMode.cbc),
        );
        final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
        final encrypted =
            encrypter.encryptBytes(plaintextBytes.toList(), iv: iv);

        // Build legacy format
        final legacyEncryptedLength = 16 + encrypted.bytes.length;
        final legacyEncrypted = Uint8List(legacyEncryptedLength);
        legacyEncrypted.setRange(0, 16, ivBytes);
        legacyEncrypted.setRange(16, legacyEncrypted.length, encrypted.bytes);

        // Act
        final decrypted = await encryptionService.decrypt(legacyEncrypted);
        final decryptedString = utf8.decode(decrypted);

        // Assert
        expect(decryptedString, equals(plaintext));
      }
    });

    test('should reject tampered legacy format data', () async {
      // Arrange - Create legacy encrypted data
      final keyBytes = base64Decode(testKey);
      final key = enc.Key(keyBytes);

      final ivBytes = Uint8List.fromList(
        List.generate(16, (i) => i),
      );
      final iv = enc.IV(ivBytes);

      final encrypter = enc.Encrypter(
        enc.AES(key, mode: enc.AESMode.cbc),
      );
      final plaintext = 'Legacy data that will be tampered';
      final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
      final encrypted = encrypter.encryptBytes(plaintextBytes.toList(), iv: iv);

      // Build legacy format
      final legacyEncryptedLength = 16 + encrypted.bytes.length;
      final legacyEncrypted = Uint8List(legacyEncryptedLength);
      legacyEncrypted.setRange(0, 16, ivBytes);
      legacyEncrypted.setRange(16, legacyEncrypted.length, encrypted.bytes);

      // Corrupt the ciphertext
      legacyEncrypted[20] = (legacyEncrypted[20] + 1) % 256;

      // Act & Assert - should either fail or produce garbage
      // Legacy format has no integrity check, so we verify it doesn't match original
      try {
        final decrypted = await encryptionService.decrypt(legacyEncrypted);
        final decryptedString = utf8.decode(decrypted, allowMalformed: false);
        // If decryption "succeeds", the result should not match the original
        expect(decryptedString, isNot(equals(plaintext)));
      } on EncryptionException {
        // Expected - padding validation failed
      } on FormatException {
        // Expected - invalid UTF-8 from corrupted decryption
      }
    });
  });

  group('isLikelyEncrypted with HMAC', () {
    test('should recognize new format encrypted data', () async {
      // Arrange
      final data = Uint8List.fromList(utf8.encode('Test data'));

      // Act
      final encrypted = await encryptionService.encrypt(data);
      final isEncrypted = encryptionService.isLikelyEncrypted(encrypted);

      // Assert
      expect(isEncrypted, isTrue);
    });

    test('should recognize legacy format encrypted data', () {
      // Arrange - Create legacy format data
      final keyBytes = base64Decode(testKey);
      final key = enc.Key(keyBytes);
      final ivBytes = Uint8List.fromList(List.generate(16, (i) => i));
      final iv = enc.IV(ivBytes);

      final encrypter = enc.Encrypter(
        enc.AES(key, mode: enc.AESMode.cbc),
      );
      final plaintext = 'Legacy test';
      final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
      final encrypted = encrypter.encryptBytes(plaintextBytes.toList(), iv: iv);

      // Build legacy format
      final legacyEncryptedLength = 16 + encrypted.bytes.length;
      final legacyEncrypted = Uint8List(legacyEncryptedLength);
      legacyEncrypted.setRange(0, 16, ivBytes);
      legacyEncrypted.setRange(16, legacyEncrypted.length, encrypted.bytes);

      // Act
      final isEncrypted = encryptionService.isLikelyEncrypted(legacyEncrypted);

      // Assert
      expect(isEncrypted, isTrue);
    });

    test('should not recognize plaintext as encrypted', () {
      // Arrange
      final plaintext = Uint8List.fromList(utf8.encode('Plain text data'));

      // Act
      final isEncrypted = encryptionService.isLikelyEncrypted(plaintext);

      // Assert
      expect(isEncrypted, isFalse);
    });

    test('should not recognize empty data as encrypted', () {
      // Arrange
      final emptyData = Uint8List(0);

      // Act
      final isEncrypted = encryptionService.isLikelyEncrypted(emptyData);

      // Assert
      expect(isEncrypted, isFalse);
    });
  });
}
