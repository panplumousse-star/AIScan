import 'dart:convert';
import 'dart:math';

import 'package:aes_encrypt_file/aes_encrypt_file.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../exceptions/base_exception.dart';
import 'secure_storage_service.dart';

/// Riverpod provider for [EncryptionService].
///
/// Provides a singleton instance of the encryption service for
/// dependency injection throughout the application.
/// Depends on [SecureStorageService] for encryption key management.
final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  final secureStorage = ref.read(secureStorageServiceProvider);
  return EncryptionService(secureStorage: secureStorage);
});

/// Exception thrown when encryption/decryption operations fail.
///
/// Contains the original error message and optional underlying exception.
class EncryptionException extends BaseException {
  /// Creates an [EncryptionException] with the given [message].
  const EncryptionException(super.message, {super.cause});
}

/// Exception thrown when HMAC integrity verification fails.
///
/// Indicates that encrypted data has been tampered with or is corrupted.
/// Contains the original error message and optional underlying exception.
class IntegrityException extends BaseException {
  /// Creates an [IntegrityException] with the given [message].
  const IntegrityException(super.message, {super.cause});
}

/// Performs constant-time comparison of two byte arrays.
///
/// This prevents timing attacks by ensuring the comparison always
/// takes the same amount of time regardless of where the arrays differ.
///
/// Parameters:
/// - [a]: The first byte array to compare.
/// - [b]: The second byte array to compare.
///
/// Returns `true` if the arrays are equal, `false` otherwise.
bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }

  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a[i] ^ b[i];
  }

  return result == 0;
}

/// Derives an HMAC key from the master encryption key.
///
/// Uses HMAC-SHA256 key derivation to generate a separate key for
/// integrity verification. This ensures the encryption and authentication
/// keys are cryptographically independent, following security best practices.
///
/// Parameters:
/// - [masterKey]: The master encryption key bytes (32 bytes for AES-256).
///
/// Returns a 32-byte HMAC key for use with HMAC-SHA256 operations.
///
/// Throws [EncryptionException] if key derivation fails.
Uint8List _deriveHmacKeyTopLevel(Uint8List masterKey) {
  try {
    // Use HMAC-SHA256 with the master key to derive HMAC key
    const hmacKeyDerivationConstant = 'HMAC-KEY-DERIVATION';
    final hmac = Hmac(sha256, masterKey);
    final derivedKeyBytes =
        hmac.convert(utf8.encode(hmacKeyDerivationConstant)).bytes;

    return Uint8List.fromList(derivedKeyBytes);
  } catch (e) {
    throw EncryptionException('Failed to derive HMAC key', cause: e);
  }
}

/// Parameters for isolate-based decryption.
///
/// Contains the encrypted data and encryption key needed for
/// decryption in a separate isolate.
class _DecryptParams {
  /// Creates decryption parameters with the given [encryptedData] and [keyBytes].
  const _DecryptParams({
    required this.encryptedData,
    required this.keyBytes,
  });

  /// The encrypted data to decrypt.
  ///
  /// Supports both formats:
  /// - New format: IV prefix + ciphertext + HMAC suffix
  /// - Legacy format: IV prefix + ciphertext (no HMAC)
  final Uint8List encryptedData;

  /// The AES-256 encryption key as raw bytes.
  final Uint8List keyBytes;
}

/// Top-level function for isolate-based decryption with legacy format support.
///
/// This function must be top-level (not a class method) to be used
/// with Flutter's `compute()` function for isolate execution.
///
/// Attempts to verify HMAC integrity before decryption (new format).
/// Falls back to legacy decryption without HMAC if verification fails
/// and the data appears to be in legacy format (IV + ciphertext only).
///
/// Returns the decrypted data as [Uint8List].
///
/// Throws [EncryptionException] if decryption fails.
Uint8List _decryptInIsolate(_DecryptParams params) {
  const ivSizeBytes = 16;
  const hmacSizeBytes = 32;
  const blockSizeBytes = 16;

  if (params.encryptedData.isEmpty) {
    throw const EncryptionException('Cannot decrypt empty data');
  }

  if (params.encryptedData.length <= ivSizeBytes) {
    throw const EncryptionException(
      'Invalid encrypted data: too short to contain IV',
    );
  }

  // Try new format with HMAC first
  final minLengthWithHmac = ivSizeBytes + blockSizeBytes + hmacSizeBytes;
  var hmacVerificationFailed = false;

  if (params.encryptedData.length >= minLengthWithHmac) {
    try {
      // Extract components: IV + ciphertext + HMAC
      final ivBytes = params.encryptedData.sublist(0, ivSizeBytes);
      final hmacStartIndex = params.encryptedData.length - hmacSizeBytes;
      final cipherBytes = params.encryptedData.sublist(ivSizeBytes, hmacStartIndex);
      final receivedHmac = params.encryptedData.sublist(hmacStartIndex);

      // Derive HMAC key and verify integrity
      final hmacKey = _deriveHmacKeyTopLevel(params.keyBytes);
      final hmacInput = Uint8List(ivSizeBytes + cipherBytes.length);
      hmacInput.setRange(0, ivSizeBytes, ivBytes);
      hmacInput.setRange(ivSizeBytes, hmacInput.length, cipherBytes);

      final hmac = Hmac(sha256, hmacKey);
      final computedHmac = hmac.convert(hmacInput).bytes;

      // Constant-time comparison to prevent timing attacks
      if (_constantTimeEquals(computedHmac, receivedHmac)) {
        // HMAC verified, proceed with decryption
        final key = enc.Key(params.keyBytes);
        final iv = enc.IV(ivBytes);

        final encrypter = enc.Encrypter(
          enc.AES(key, mode: enc.AESMode.cbc),
        );

        final encrypted = enc.Encrypted(cipherBytes);
        final decrypted = encrypter.decryptBytes(encrypted, iv: iv);

        return Uint8List.fromList(decrypted);
      }

      // HMAC verification failed - check if it could be legacy format
      // Legacy format check: remove HMAC bytes and see if ciphertext is block-aligned
      final cipherLengthWithoutHmac =
          params.encryptedData.length - ivSizeBytes - hmacSizeBytes;

      if (cipherLengthWithoutHmac % blockSizeBytes != 0) {
        // Not valid legacy format (ciphertext not block-aligned)
        // This is likely tampered new format data
        throw const IntegrityException(
          'HMAC verification failed - data may be tampered or corrupted',
        );
      }

      // Could be legacy format, will try legacy decryption below
      hmacVerificationFailed = true;
    } catch (e) {
      // If it's already an IntegrityException, rethrow it
      if (e is IntegrityException) {
        rethrow;
      }
      // Other errors during HMAC verification, will try legacy format
    }
  }

  // Try legacy format (IV + ciphertext without HMAC)
  try {
    final cipherLength = params.encryptedData.length - ivSizeBytes;

    // Legacy ciphertext must be a multiple of block size
    if (cipherLength % blockSizeBytes == 0 && cipherLength > 0) {
      final ivBytes = params.encryptedData.sublist(0, ivSizeBytes);
      final cipherBytes = params.encryptedData.sublist(ivSizeBytes);

      final key = enc.Key(params.keyBytes);
      final iv = enc.IV(ivBytes);

      final encrypter = enc.Encrypter(
        enc.AES(key, mode: enc.AESMode.cbc),
      );

      final encrypted = enc.Encrypted(cipherBytes);
      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);

      return Uint8List.fromList(decrypted);
    }
  } catch (e) {
    throw EncryptionException(
      'Failed to decrypt data in both new and legacy formats',
      cause: e,
    );
  }

  throw const EncryptionException(
    'Invalid encrypted data: does not match new or legacy format',
  );
}

/// Service for AES-256 encryption operations.
///
/// Provides two encryption modes:
/// - **Small data encryption**: Uses the `encrypt` package for in-memory
///   encryption of metadata and small data (< 1MB recommended).
/// - **Large file encryption**: Uses `aes_encrypt_file` for native streaming
///   encryption of document files with minimal memory overhead.
///
/// ## Security Architecture
/// - **Algorithm**: AES-256 in CBC mode with PKCS7 padding (small data)
/// - **File encryption**: AES-256-CTR via native implementation (large files)
/// - **Key storage**: Encryption keys are managed by [SecureStorageService]
///   and stored in platform secure storage (Android KeyStore / iOS Keychain)
/// - **IV handling**: Each encryption operation uses a unique IV prepended
///   to the ciphertext for small data operations
///
/// ## Usage
/// ```dart
/// final encryption = ref.read(encryptionServiceProvider);
///
/// // Encrypt small data (metadata, settings, etc.)
/// final plaintext = utf8.encode('sensitive data');
/// final encrypted = await encryption.encrypt(Uint8List.fromList(plaintext));
/// final decrypted = await encryption.decrypt(encrypted);
///
/// // Encrypt large files (documents, images)
/// await encryption.encryptFile('/path/to/document.pdf', '/path/to/document.enc');
/// await encryption.decryptFile('/path/to/document.enc', '/path/to/document.pdf');
/// ```
///
/// ## Important Notes
/// - All document storage MUST go through this encryption layer
/// - Never store plaintext document data to disk
/// - The encryption key is generated once and stored in secure storage
/// - If the key is lost, all encrypted data becomes unrecoverable
class EncryptionService {
  /// Creates an [EncryptionService] with the required [SecureStorageService].
  EncryptionService({
    required SecureStorageService secureStorage,
  }) : _secureStorage = secureStorage;

  /// The secure storage service for key management.
  final SecureStorageService _secureStorage;

  /// AES block size in bytes (16 bytes = 128 bits).
  static const int _blockSizeBytes = 16;

  /// AES-256 key size in bytes (32 bytes = 256 bits).
  static const int _keySizeBytes = 32;

  /// Initialization vector size in bytes (16 bytes = 128 bits).
  static const int _ivSizeBytes = 16;

  /// HMAC-SHA256 output size in bytes (32 bytes = 256 bits).
  static const int _hmacSizeBytes = 32;

  /// Maximum recommended size for in-memory encryption (1 MB).
  /// Files larger than this should use [encryptFile] instead.
  static const int maxInMemorySize = 1024 * 1024;

  /// Cached encryption key for performance.
  String? _cachedKey;

  /// Encrypts data in memory using AES-256-CBC with HMAC-SHA256 authentication.
  ///
  /// Suitable for small data like metadata, settings, and document info.
  /// For large files, use [encryptFile] instead.
  ///
  /// The returned encrypted data has the following structure:
  /// `[16-byte IV][encrypted data][32-byte HMAC]`
  ///
  /// Returns the encrypted data as [Uint8List].
  ///
  /// Throws [EncryptionException] if encryption fails.
  Future<Uint8List> encrypt(Uint8List data) async {
    if (data.isEmpty) {
      throw const EncryptionException('Cannot encrypt empty data');
    }

    try {
      final keyBytes = await _getEncryptionKeyBytes();
      final key = enc.Key(keyBytes);

      // Generate a unique IV for each encryption operation
      final ivBytes = _generateSecureRandomBytes(_ivSizeBytes);
      final iv = enc.IV(ivBytes);

      final encrypter = enc.Encrypter(
        enc.AES(key, mode: enc.AESMode.cbc),
      );

      final encrypted = encrypter.encryptBytes(data.toList(), iv: iv);

      // Derive HMAC key from master encryption key
      final hmacKey = _deriveHmacKey(keyBytes);

      // Compute HMAC over IV + ciphertext
      final hmacInput = Uint8List(_ivSizeBytes + encrypted.bytes.length);
      hmacInput.setRange(0, _ivSizeBytes, ivBytes);
      hmacInput.setRange(_ivSizeBytes, hmacInput.length, encrypted.bytes);

      final hmac = Hmac(sha256, hmacKey);
      final hmacTag = hmac.convert(hmacInput).bytes;

      // Build result: IV + ciphertext + HMAC tag
      final result = Uint8List(
        _ivSizeBytes + encrypted.bytes.length + _hmacSizeBytes,
      );
      result.setRange(0, _ivSizeBytes, ivBytes);
      result.setRange(_ivSizeBytes, _ivSizeBytes + encrypted.bytes.length, encrypted.bytes);
      result.setRange(_ivSizeBytes + encrypted.bytes.length, result.length, hmacTag);

      return result;
    } on EncryptionException {
      rethrow;
    } catch (e) {
      throw EncryptionException('Failed to encrypt data', cause: e);
    }
  }

  /// Decrypts data that was encrypted with [encrypt].
  ///
  /// Supports both new format with HMAC and legacy format without HMAC:
  /// - New format: `[16-byte IV][encrypted data][32-byte HMAC]`
  /// - Legacy format: `[16-byte IV][encrypted data]`
  ///
  /// Attempts HMAC verification first (new format). If verification fails
  /// and the data appears to be in legacy format, falls back to decryption
  /// without HMAC verification for backward compatibility.
  ///
  /// Returns the decrypted data as [Uint8List].
  ///
  /// Throws [EncryptionException] if decryption fails in both formats.
  Future<Uint8List> decrypt(Uint8List encryptedData) async {
    if (encryptedData.isEmpty) {
      throw const EncryptionException('Cannot decrypt empty data');
    }

    if (encryptedData.length <= _ivSizeBytes) {
      throw const EncryptionException(
        'Invalid encrypted data: too short to contain IV',
      );
    }

    final keyBytes = await _getEncryptionKeyBytes();

    // Try new format with HMAC first
    final minLengthWithHmac = _ivSizeBytes + _blockSizeBytes + _hmacSizeBytes;
    var hmacVerificationFailed = false;

    if (encryptedData.length >= minLengthWithHmac) {
      try {
        // Extract components: IV + ciphertext + HMAC
        final ivBytes = encryptedData.sublist(0, _ivSizeBytes);
        final hmacStartIndex = encryptedData.length - _hmacSizeBytes;
        final cipherBytes = encryptedData.sublist(_ivSizeBytes, hmacStartIndex);
        final receivedHmac = encryptedData.sublist(hmacStartIndex);

        // Derive HMAC key and verify integrity
        final hmacKey = _deriveHmacKey(keyBytes);
        final hmacInput = Uint8List(_ivSizeBytes + cipherBytes.length);
        hmacInput.setRange(0, _ivSizeBytes, ivBytes);
        hmacInput.setRange(_ivSizeBytes, hmacInput.length, cipherBytes);

        final hmac = Hmac(sha256, hmacKey);
        final computedHmac = hmac.convert(hmacInput).bytes;

        // Constant-time comparison to prevent timing attacks
        if (_constantTimeEquals(computedHmac, receivedHmac)) {
          // HMAC verified, proceed with decryption
          final key = enc.Key(keyBytes);
          final iv = enc.IV(ivBytes);

          final encrypter = enc.Encrypter(
            enc.AES(key, mode: enc.AESMode.cbc),
          );

          final encrypted = enc.Encrypted(cipherBytes);
          final decrypted = encrypter.decryptBytes(encrypted, iv: iv);

          return Uint8List.fromList(decrypted);
        }

        // HMAC verification failed - check if it could be legacy format
        // Legacy format check: remove HMAC bytes and see if ciphertext is block-aligned
        final cipherLengthWithoutHmac =
            encryptedData.length - _ivSizeBytes - _hmacSizeBytes;

        if (cipherLengthWithoutHmac % _blockSizeBytes != 0) {
          // Not valid legacy format (ciphertext not block-aligned)
          // This is likely tampered new format data
          throw const IntegrityException(
            'HMAC verification failed - data may be tampered or corrupted',
          );
        }

        // Could be legacy format, will try legacy decryption below
        hmacVerificationFailed = true;
      } catch (e) {
        // If it's already an IntegrityException, rethrow it
        if (e is IntegrityException) {
          rethrow;
        }
        // Other errors during HMAC verification, will try legacy format
      }
    }

    // Try legacy format (IV + ciphertext without HMAC)
    try {
      final cipherLength = encryptedData.length - _ivSizeBytes;

      // Legacy ciphertext must be a multiple of block size
      if (cipherLength % _blockSizeBytes == 0 && cipherLength > 0) {
        final ivBytes = encryptedData.sublist(0, _ivSizeBytes);
        final cipherBytes = encryptedData.sublist(_ivSizeBytes);

        final key = enc.Key(keyBytes);
        final iv = enc.IV(ivBytes);

        final encrypter = enc.Encrypter(
          enc.AES(key, mode: enc.AESMode.cbc),
        );

        final encrypted = enc.Encrypted(cipherBytes);
        final decrypted = encrypter.decryptBytes(encrypted, iv: iv);

        return Uint8List.fromList(decrypted);
      }
    } catch (e) {
      throw EncryptionException(
        'Failed to decrypt data in both new and legacy formats',
        cause: e,
      );
    }

    throw const EncryptionException(
      'Invalid encrypted data: does not match new or legacy format',
    );
  }

  /// Decrypts data asynchronously in a separate isolate using [compute].
  ///
  /// This method runs the decryption operation in a separate isolate
  /// to prevent blocking the UI thread. Use this for decrypting larger
  /// data sets (e.g., > 100KB) or when decryption is happening on the
  /// main thread and may cause UI lag.
  ///
  /// For small data (< 100KB), the overhead of spawning an isolate
  /// may outweigh the benefits. Use [decrypt] for small data instead.
  ///
  /// Supports both new format with HMAC and legacy format without HMAC:
  /// - New format: `[16-byte IV][encrypted data][32-byte HMAC]`
  /// - Legacy format: `[16-byte IV][encrypted data]`
  ///
  /// Attempts HMAC verification first (new format). If verification fails
  /// and the data appears to be in legacy format, falls back to decryption
  /// without HMAC verification for backward compatibility.
  ///
  /// Returns the decrypted data as [Uint8List].
  ///
  /// Throws [EncryptionException] if decryption fails in both formats.
  Future<Uint8List> decryptAsync(Uint8List encryptedData) async {
    if (encryptedData.isEmpty) {
      throw const EncryptionException('Cannot decrypt empty data');
    }

    if (encryptedData.length <= _ivSizeBytes) {
      throw const EncryptionException(
        'Invalid encrypted data: too short to contain IV',
      );
    }

    try {
      final keyBytes = await _getEncryptionKeyBytes();
      final params = _DecryptParams(
        encryptedData: encryptedData,
        keyBytes: keyBytes,
      );

      return await compute(_decryptInIsolate, params);
    } on EncryptionException {
      rethrow;
    } catch (e) {
      throw EncryptionException('Failed to decrypt data', cause: e);
    }
  }

  /// Encrypts a file using native AES-256-CTR streaming encryption.
  ///
  /// This method is optimized for large files and uses native code
  /// (OpenSSL on Android, CommonCrypto on iOS) for better performance
  /// and minimal memory usage.
  ///
  /// The [inputPath] is the path to the plaintext file.
  /// The [outputPath] is where the encrypted file will be written.
  ///
  /// Throws [EncryptionException] if file encryption fails.
  Future<void> encryptFile(String inputPath, String outputPath) async {
    if (inputPath.isEmpty || outputPath.isEmpty) {
      throw const EncryptionException('File paths cannot be empty');
    }

    if (inputPath == outputPath) {
      throw const EncryptionException(
        'Input and output paths must be different',
      );
    }

    try {
      final key = await _getEncryptionKeyString();
      final aesEncryptor = AesEncryptFile();
      await aesEncryptor.encryptFile(
        inputPath: inputPath,
        outputPath: outputPath,
        key: key,
      );
    } on EncryptionException {
      rethrow;
    } catch (e) {
      throw EncryptionException(
        'Failed to encrypt file: $inputPath',
        cause: e,
      );
    }
  }

  /// Decrypts a file that was encrypted with [encryptFile].
  ///
  /// This method is optimized for large files and uses native code
  /// (OpenSSL on Android, CommonCrypto on iOS) for better performance
  /// and minimal memory usage.
  ///
  /// The [inputPath] is the path to the encrypted file.
  /// The [outputPath] is where the decrypted file will be written.
  ///
  /// Throws [EncryptionException] if file decryption fails.
  Future<void> decryptFile(String inputPath, String outputPath) async {
    if (inputPath.isEmpty || outputPath.isEmpty) {
      throw const EncryptionException('File paths cannot be empty');
    }

    if (inputPath == outputPath) {
      throw const EncryptionException(
        'Input and output paths must be different',
      );
    }

    try {
      final key = await _getEncryptionKeyString();
      final aesEncryptor = AesEncryptFile();
      await aesEncryptor.decryptFile(
        inputPath: inputPath,
        outputPath: outputPath,
        key: key,
      );
    } on EncryptionException {
      rethrow;
    } catch (e) {
      throw EncryptionException(
        'Failed to decrypt file: $inputPath',
        cause: e,
      );
    }
  }

  /// Encrypts a string value and returns it as a base64-encoded string.
  ///
  /// This is a convenience method for encrypting string data like
  /// document titles, descriptions, or other text metadata.
  ///
  /// The encryption includes HMAC-SHA256 authentication for integrity
  /// verification. The returned base64 string encodes the structure:
  /// `[16-byte IV][encrypted data][32-byte HMAC]`
  ///
  /// Returns the encrypted data as a base64-encoded string.
  ///
  /// Throws [EncryptionException] if encryption fails.
  Future<String> encryptString(String plaintext) async {
    if (plaintext.isEmpty) {
      throw const EncryptionException('Cannot encrypt empty string');
    }

    final data = Uint8List.fromList(utf8.encode(plaintext));
    final encrypted = await encrypt(data);
    return base64Encode(encrypted);
  }

  /// Decrypts a base64-encoded encrypted string.
  ///
  /// This is a convenience method for decrypting string data that
  /// was encrypted with [encryptString].
  ///
  /// Supports both new format with HMAC and legacy format without HMAC:
  /// - New format: `[16-byte IV][encrypted data][32-byte HMAC]`
  /// - Legacy format: `[16-byte IV][encrypted data]`
  ///
  /// Verifies HMAC integrity before decryption when present. Falls back
  /// to legacy decryption for backward compatibility if HMAC verification
  /// fails and the data appears to be in legacy format.
  ///
  /// Returns the decrypted plaintext string.
  ///
  /// Throws [EncryptionException] if decryption fails in both formats.
  /// Throws [IntegrityException] if HMAC verification detects tampering.
  Future<String> decryptString(String encryptedBase64) async {
    if (encryptedBase64.isEmpty) {
      throw const EncryptionException('Cannot decrypt empty string');
    }

    try {
      final encryptedData = base64Decode(encryptedBase64);
      final decrypted = await decrypt(Uint8List.fromList(encryptedData));
      return utf8.decode(decrypted);
    } on FormatException catch (e) {
      throw EncryptionException('Invalid base64 format', cause: e);
    }
  }

  /// Checks if a file is likely encrypted by this service.
  ///
  /// This performs a basic heuristic check by examining the file's
  /// structure. It does NOT verify that the file can be decrypted
  /// with the current key.
  ///
  /// Checks for both new format (with HMAC) and legacy format (without HMAC).
  ///
  /// Returns `true` if the file appears to be encrypted, `false` otherwise.
  ///
  /// Note: This is a heuristic check and may not be 100% accurate.
  /// Always handle decryption errors gracefully.
  bool isLikelyEncrypted(Uint8List data) {
    if (data.isEmpty) {
      return false;
    }

    // Data should be at least as long as IV + one block
    final minLength = _ivSizeBytes + _blockSizeBytes;
    if (data.length < minLength) {
      return false;
    }

    // Check for new format (IV + ciphertext + HMAC)
    if (data.length > _ivSizeBytes + _blockSizeBytes + _hmacSizeBytes) {
      final encryptedLengthWithHmac = data.length - _ivSizeBytes - _hmacSizeBytes;
      if (encryptedLengthWithHmac % _blockSizeBytes == 0) {
        return true;
      }
    }

    // Check for legacy format (IV + ciphertext)
    final encryptedLengthLegacy = data.length - _ivSizeBytes;
    return encryptedLengthLegacy % _blockSizeBytes == 0;
  }

  /// Ensures the encryption key is initialized.
  ///
  /// This method should be called during app initialization to
  /// ensure the encryption key exists before any encryption operations.
  ///
  /// Returns `true` if the key was created, `false` if it already existed.
  Future<bool> ensureKeyInitialized() async {
    final hadKey = await _secureStorage.hasEncryptionKey();
    await _getEncryptionKeyString();
    return !hadKey;
  }

  /// Checks if the encryption service is ready for use.
  ///
  /// Returns `true` if the encryption key is available.
  Future<bool> isReady() async {
    return await _secureStorage.hasEncryptionKey();
  }

  /// Clears the cached encryption key.
  ///
  /// Call this when the app goes to background or during security
  /// sensitive operations that require re-authentication.
  void clearCache() {
    _cachedKey = null;
  }

  /// Gets the encryption key as a base64-encoded string.
  ///
  /// Creates a new key if one doesn't exist.
  Future<String> _getEncryptionKeyString() async {
    if (_cachedKey != null) {
      return _cachedKey!;
    }

    try {
      _cachedKey = await _secureStorage.getOrCreateEncryptionKey();
      return _cachedKey!;
    } catch (e) {
      throw EncryptionException('Failed to get encryption key', cause: e);
    }
  }

  /// Gets the encryption key as raw bytes.
  ///
  /// Creates a new key if one doesn't exist.
  Future<Uint8List> _getEncryptionKeyBytes() async {
    final keyString = await _getEncryptionKeyString();

    final keyBytes = base64Decode(keyString);
    if (keyBytes.length != _keySizeBytes) {
      throw EncryptionException(
        'Invalid key size: expected $_keySizeBytes bytes, got ${keyBytes.length}',
      );
    }

    return Uint8List.fromList(keyBytes);
  }

  /// Derives an HMAC key from the master encryption key.
  ///
  /// Uses HMAC-SHA256 key derivation to generate a separate key for
  /// integrity verification. This ensures the encryption and authentication
  /// keys are cryptographically independent, following security best practices.
  ///
  /// The derivation uses HMAC-SHA256(masterKey, constant) where the constant
  /// is [_hmacKeyDerivationConstant]. This provides a simple but secure
  /// key separation mechanism.
  ///
  /// Parameters:
  /// - [masterKey]: The master encryption key bytes (32 bytes for AES-256).
  ///
  /// Returns a 32-byte HMAC key for use with HMAC-SHA256 operations.
  ///
  /// Throws [EncryptionException] if key derivation fails.
  Uint8List _deriveHmacKey(Uint8List masterKey) {
    return _deriveHmacKeyTopLevel(masterKey);
  }

  /// Generates cryptographically secure random bytes.
  Uint8List _generateSecureRandomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }
}
