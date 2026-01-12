import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:aes_encrypt_file/aes_encrypt_file.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
class EncryptionException implements Exception {
  /// Creates an [EncryptionException] with the given [message].
  const EncryptionException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'EncryptionException: $message (caused by: $cause)';
    }
    return 'EncryptionException: $message';
  }
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

  /// Maximum recommended size for in-memory encryption (1 MB).
  /// Files larger than this should use [encryptFile] instead.
  static const int maxInMemorySize = 1024 * 1024;

  /// Cached encryption key for performance.
  String? _cachedKey;

  /// Encrypts data in memory using AES-256-CBC.
  ///
  /// Suitable for small data like metadata, settings, and document info.
  /// For large files, use [encryptFile] instead.
  ///
  /// The returned encrypted data has the following structure:
  /// `[16-byte IV][encrypted data]`
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
        enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'),
      );

      final encrypted = encrypter.encryptBytes(data.toList(), iv: iv);

      // Prepend IV to encrypted data for decryption
      final result = Uint8List(_ivSizeBytes + encrypted.bytes.length);
      result.setRange(0, _ivSizeBytes, ivBytes);
      result.setRange(_ivSizeBytes, result.length, encrypted.bytes);

      return result;
    } on EncryptionException {
      rethrow;
    } catch (e) {
      throw EncryptionException('Failed to encrypt data', cause: e);
    }
  }

  /// Decrypts data that was encrypted with [encrypt].
  ///
  /// Expects the encrypted data to have the structure:
  /// `[16-byte IV][encrypted data]`
  ///
  /// Returns the decrypted data as [Uint8List].
  ///
  /// Throws [EncryptionException] if decryption fails.
  Future<Uint8List> decrypt(Uint8List encryptedData) async {
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
      final key = enc.Key(keyBytes);

      // Extract IV from the beginning of encrypted data
      final ivBytes = encryptedData.sublist(0, _ivSizeBytes);
      final iv = enc.IV(ivBytes);

      // Extract actual encrypted data
      final cipherBytes = encryptedData.sublist(_ivSizeBytes);

      final encrypter = enc.Encrypter(
        enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'),
      );

      final encrypted = enc.Encrypted(cipherBytes);
      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);

      return Uint8List.fromList(decrypted);
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
  /// Returns the decrypted plaintext string.
  ///
  /// Throws [EncryptionException] if decryption fails.
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
  /// Returns `true` if the file appears to be encrypted, `false` otherwise.
  ///
  /// Note: This is a heuristic check and may not be 100% accurate.
  /// Always handle decryption errors gracefully.
  bool isLikelyEncrypted(Uint8List data) {
    if (data.isEmpty) {
      return false;
    }

    // Encrypted data should be at least as long as the IV
    if (data.length <= _ivSizeBytes) {
      return false;
    }

    // Encrypted data length should be a multiple of the block size
    // (after subtracting the IV)
    final encryptedLength = data.length - _ivSizeBytes;
    return encryptedLength % _blockSizeBytes == 0;
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
