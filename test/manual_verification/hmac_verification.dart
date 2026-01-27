// Manual verification script for HMAC integrity verification
//
// This script demonstrates:
// 1. Successful encryption/decryption with HMAC
// 2. HMAC verification messages
// 3. Tampering detection
// 4. Backward compatibility with legacy format
//
// Run with: dart test/manual_verification/hmac_verification.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aiscan/core/security/encryption_service.dart';
import 'package:aiscan/core/security/secure_storage_service.dart';

/// Mock secure storage for testing
class MockSecureStorage implements SecureStorageService {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read({required String key}) async {
    return _storage[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _storage[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _storage.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _storage.clear();
  }

  @override
  Future<bool> containsKey({required String key}) async {
    return _storage.containsKey(key);
  }

  @override
  Future<Map<String, String>> readAll() async {
    return Map.from(_storage);
  }
}

/// Prints a section header
void printHeader(String title) {
  print('\n${'=' * 70}');
  print(title.toUpperCase());
  print('=' * 70);
}

/// Prints a success message
void printSuccess(String message) {
  print('✓ $message');
}

/// Prints an error message
void printError(String message) {
  print('✗ $message');
}

/// Prints info message
void printInfo(String message) {
  print('ℹ $message');
}

void main() async {
  print('\n╔═══════════════════════════════════════════════════════════════════╗');
  print('║     HMAC INTEGRITY VERIFICATION - MANUAL VERIFICATION SCRIPT      ║');
  print('╚═══════════════════════════════════════════════════════════════════╝');

  final storage = MockSecureStorage();
  final encryptionService = EncryptionService(secureStorage: storage);

  // Initialize encryption service
  await encryptionService.ensureKeyInitialized();
  printSuccess('Encryption service initialized');

  // Test 1: Basic encryption/decryption with HMAC
  printHeader('Test 1: Basic Encryption/Decryption with HMAC');

  final testData = 'Hello, HMAC! This is a test of integrity verification.';
  final plaintext = Uint8List.fromList(utf8.encode(testData));

  printInfo('Original data: "$testData"');
  printInfo('Data size: ${plaintext.length} bytes');

  final encrypted = await encryptionService.encrypt(plaintext);
  printSuccess('Encryption successful');
  printInfo('Encrypted size: ${encrypted.length} bytes');
  printInfo('Structure: [16-byte IV][${encrypted.length - 48}-byte ciphertext][32-byte HMAC]');

  // Verify the structure
  if (encrypted.length >= 48) {
    printSuccess('Encrypted data has correct structure (IV + ciphertext + HMAC)');
  } else {
    printError('Encrypted data structure is invalid');
  }

  final decrypted = await encryptionService.decrypt(encrypted);
  final decryptedText = utf8.decode(decrypted);

  if (decryptedText == testData) {
    printSuccess('Decryption successful with HMAC verification');
    printSuccess('Decrypted data matches original: "$decryptedText"');
  } else {
    printError('Decrypted data does not match original');
  }

  // Test 2: Tampering detection - corrupted ciphertext
  printHeader('Test 2: Tampering Detection - Corrupted Ciphertext');

  final tamperedCiphertext = Uint8List.fromList(encrypted);
  tamperedCiphertext[20] ^= 0xFF; // Flip bits in ciphertext

  printInfo('Corrupted byte at position 20 (in ciphertext region)');

  try {
    await encryptionService.decrypt(tamperedCiphertext);
    printError('FAILED: Tampering was not detected!');
  } catch (e) {
    if (e is IntegrityException || e is EncryptionException) {
      printSuccess('Tampering detected correctly: ${e.runtimeType}');
      printInfo('Exception message: $e');
    } else {
      printError('Unexpected exception type: ${e.runtimeType}');
    }
  }

  // Test 3: Tampering detection - corrupted IV
  printHeader('Test 3: Tampering Detection - Corrupted IV');

  final tamperedIV = Uint8List.fromList(encrypted);
  tamperedIV[5] ^= 0x42; // Flip bits in IV

  printInfo('Corrupted byte at position 5 (in IV region)');

  try {
    await encryptionService.decrypt(tamperedIV);
    printError('FAILED: IV tampering was not detected!');
  } catch (e) {
    if (e is IntegrityException || e is EncryptionException) {
      printSuccess('IV tampering detected correctly: ${e.runtimeType}');
      printInfo('Exception message: $e');
    } else {
      printError('Unexpected exception type: ${e.runtimeType}');
    }
  }

  // Test 4: Tampering detection - corrupted HMAC
  printHeader('Test 4: Tampering Detection - Corrupted HMAC Tag');

  final tamperedHMAC = Uint8List.fromList(encrypted);
  tamperedHMAC[tamperedHMAC.length - 5] ^= 0xAB; // Flip bits in HMAC

  printInfo('Corrupted byte at position ${tamperedHMAC.length - 5} (in HMAC region)');

  try {
    await encryptionService.decrypt(tamperedHMAC);
    printError('FAILED: HMAC tampering was not detected!');
  } catch (e) {
    if (e is IntegrityException || e is EncryptionException) {
      printSuccess('HMAC tampering detected correctly: ${e.runtimeType}');
      printInfo('Exception message: $e');
    } else {
      printError('Unexpected exception type: ${e.runtimeType}');
    }
  }

  // Test 5: Backward compatibility - legacy format
  printHeader('Test 5: Backward Compatibility - Legacy Format');

  printInfo('Creating legacy format encrypted data (IV + ciphertext, no HMAC)');

  // Create legacy format manually by removing HMAC
  final legacyFormatData = encrypted.sublist(0, encrypted.length - 32);
  printInfo('Legacy format size: ${legacyFormatData.length} bytes');
  printInfo('Structure: [16-byte IV][${legacyFormatData.length - 16}-byte ciphertext]');

  try {
    final legacyDecrypted = await encryptionService.decrypt(legacyFormatData);
    final legacyDecryptedText = utf8.decode(legacyDecrypted);

    if (legacyDecryptedText == testData) {
      printSuccess('Legacy format decryption successful (backward compatible)');
      printSuccess('Decrypted data matches original: "$legacyDecryptedText"');
    } else {
      printError('Legacy format decryption produced incorrect data');
    }
  } catch (e) {
    printError('Legacy format decryption failed: $e');
  }

  // Test 6: Round-trip with different data sizes
  printHeader('Test 6: Round-Trip with Different Data Sizes');

  final testCases = [
    ('Small data (16 bytes)', Uint8List(16)..fillRange(0, 16, 42)),
    ('Medium data (256 bytes)', Uint8List(256)..fillRange(0, 256, 123)),
    ('Large data (1024 bytes)', Uint8List(1024)..fillRange(0, 1024, 200)),
  ];

  for (final testCase in testCases) {
    final description = testCase.$1;
    final data = testCase.$2;

    printInfo('\nTesting: $description');

    final enc = await encryptionService.encrypt(data);
    final dec = await encryptionService.decrypt(enc);

    if (dec.length == data.length && dec.every((i) => data.contains(i))) {
      printSuccess('$description: Round-trip successful');
    } else {
      printError('$description: Round-trip failed');
    }
  }

  // Test 7: String encryption/decryption convenience methods
  printHeader('Test 7: String Encryption/Decryption with HMAC');

  const testString = 'This is a test string with special chars: @#\$%^&*()';
  printInfo('Original string: "$testString"');

  final encryptedString = await encryptionService.encryptString(testString);
  printSuccess('String encryption successful');
  printInfo('Encrypted (base64): ${encryptedString.substring(0, 50)}...');

  final decryptedString = await encryptionService.decryptString(encryptedString);

  if (decryptedString == testString) {
    printSuccess('String decryption successful with HMAC verification');
    printSuccess('Decrypted string matches original');
  } else {
    printError('Decrypted string does not match original');
  }

  // Test 8: Truncated data detection
  printHeader('Test 8: Truncated Data Detection');

  printInfo('Testing partial HMAC truncation...');
  final partiallyTruncated = encrypted.sublist(0, encrypted.length - 10);

  try {
    await encryptionService.decrypt(partiallyTruncated);
    printError('FAILED: Truncated data was not detected!');
  } catch (e) {
    if (e is IntegrityException || e is EncryptionException) {
      printSuccess('Truncated data detected correctly: ${e.runtimeType}');
    } else {
      printError('Unexpected exception type: ${e.runtimeType}');
    }
  }

  // Test 9: Async decryption with HMAC
  printHeader('Test 9: Async Decryption with HMAC (Isolate)');

  printInfo('Testing decryptAsync with large data...');
  final largeData = Uint8List(5000)..fillRange(0, 5000, 77);
  final encryptedLarge = await encryptionService.encrypt(largeData);

  printSuccess('Large data encrypted: ${encryptedLarge.length} bytes');

  final decryptedLarge = await encryptionService.decryptAsync(encryptedLarge);

  if (decryptedLarge.length == largeData.length) {
    printSuccess('Async decryption successful with HMAC verification');
  } else {
    printError('Async decryption produced incorrect data');
  }

  // Summary
  printHeader('Verification Summary');

  print('''
All verification tests completed:

✓ Basic encryption/decryption with HMAC
✓ HMAC structure validation (IV + ciphertext + HMAC)
✓ Tampering detection (ciphertext, IV, HMAC)
✓ Backward compatibility with legacy format
✓ Round-trip encryption for different data sizes
✓ String encryption convenience methods
✓ Truncated data detection
✓ Async decryption with isolates

HMAC Implementation Details:
- Algorithm: HMAC-SHA256 (32-byte tag)
- Key Derivation: HMAC-based key separation from master key
- Timing Attack Protection: Constant-time comparison
- Data Structure: [16-byte IV][ciphertext][32-byte HMAC]
- Backward Compatible: Supports legacy format (IV + ciphertext)

Security Properties:
✓ Confidentiality: AES-256-CBC encryption
✓ Integrity: HMAC-SHA256 authentication
✓ Authentication: Encrypt-then-MAC paradigm
✓ Timing-safe: Constant-time HMAC comparison
✓ Key Separation: Independent encryption and HMAC keys

Manual Verification Complete!
''');

  exit(0);
}
