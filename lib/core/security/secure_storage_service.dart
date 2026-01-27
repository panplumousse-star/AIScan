import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../exceptions/base_exception.dart';

/// Riverpod provider for [SecureStorageService].
///
/// Provides a singleton instance of the secure storage service for
/// dependency injection throughout the application.
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Exception thrown when secure storage operations fail.
///
/// Contains the original error message and optional underlying exception.
class SecureStorageException extends BaseException {
  /// Creates a [SecureStorageException] with the given [message].
  const SecureStorageException(super.message, {super.cause});
}

/// Service for secure storage operations using platform keystore.
///
/// Uses [FlutterSecureStorage] to store sensitive data in:
/// - **Android**: KeyStore with AES encryption (hardware-backed when available)
/// - **iOS**: Keychain with Secure Enclave support
///
/// This service is the foundation of the security layer and must be used
/// for storing encryption keys and other sensitive application secrets.
///
/// ## Usage
/// ```dart
/// final storage = ref.read(secureStorageServiceProvider);
///
/// // Store the encryption key
/// await storage.storeEncryptionKey(encryptionKey);
///
/// // Retrieve the encryption key
/// final key = await storage.getEncryptionKey();
/// ```
///
/// ## Security Considerations
/// - Never store unencrypted sensitive data outside this service
/// - The encryption key is generated once and stored permanently
/// - If the key is lost, encrypted documents cannot be recovered
class SecureStorageService {
  /// Creates a [SecureStorageService] with platform-optimized storage options.
  SecureStorageService({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? _createSecureStorage();

  /// The underlying secure storage instance.
  final FlutterSecureStorage _storage;

  /// Cached encryption key to prevent race conditions.
  String? _cachedEncryptionKey;

  /// Completer to prevent concurrent key generation.
  Completer<String>? _keyGenerationCompleter;

  /// Key used to store the main encryption key in secure storage.
  static const String _encryptionKeyStorageKey = 'aiscan_encryption_key';

  /// Key used to store the initialization vector in secure storage.
  static const String _initializationVectorStorageKey = 'aiscan_iv';

  /// Key used to store the salt for key derivation.
  static const String _saltStorageKey = 'aiscan_salt';

  /// Key prefix for user-specific data.
  static const String _userDataPrefix = 'aiscan_user_';

  /// Standard key length for AES-256 encryption (32 bytes).
  static const int _keyLengthBytes = 32;

  /// Standard IV length for AES encryption (16 bytes).
  static const int _ivLengthBytes = 16;

  /// Standard salt length for key derivation (32 bytes).
  static const int _saltLengthBytes = 32;

  /// Creates a [FlutterSecureStorage] instance with platform-optimized options.
  static FlutterSecureStorage _createSecureStorage() {
    const androidOptions = AndroidOptions(
      // Use encrypted shared preferences for additional security
      encryptedSharedPreferences: true,
      // Require device to be unlocked to access data
      sharedPreferencesName: 'aiscan_secure_prefs',
      preferencesKeyPrefix: 'aiscan_',
    );

    const iOSOptions = IOSOptions(
      // Use kSecAttrAccessibleWhenUnlockedThisDeviceOnly for maximum security
      accessibility: KeychainAccessibility.unlocked_this_device,
      // Store in app-specific keychain group
      accountName: 'Scanaï',
    );

    const linuxOptions = LinuxOptions();

    const webOptions = WebOptions();

    const macOsOptions = MacOsOptions();

    const windowsOptions = WindowsOptions();

    return const FlutterSecureStorage(
      aOptions: androidOptions,
      iOptions: iOSOptions,
    );
  }

  /// Retrieves the encryption key from secure storage.
  ///
  /// Returns the stored encryption key as a base64-encoded string,
  /// or `null` if no key has been stored yet.
  ///
  /// Throws [SecureStorageException] if the read operation fails.
  Future<String?> getEncryptionKey() async {
    try {
      return await _storage.read(key: _encryptionKeyStorageKey);
    } on Exception catch (e) {
      throw SecureStorageException(
        'Failed to retrieve encryption key',
        cause: e,
      );
    }
  }

  /// Stores the encryption key in secure storage.
  ///
  /// The [key] should be a base64-encoded AES-256 key (32 bytes).
  ///
  /// Throws [SecureStorageException] if the write operation fails.
  Future<void> storeEncryptionKey(String key) async {
    try {
      await _storage.write(
        key: _encryptionKeyStorageKey,
        value: key,
      );
    } on Exception catch (e) {
      throw SecureStorageException(
        'Failed to store encryption key',
        cause: e,
      );
    }
  }

  /// Retrieves the initialization vector (IV) from secure storage.
  ///
  /// Returns the stored IV as a base64-encoded string,
  /// or `null` if no IV has been stored yet.
  ///
  /// Throws [SecureStorageException] if the read operation fails.
  Future<String?> getInitializationVector() async {
    try {
      return await _storage.read(key: _initializationVectorStorageKey);
    } on Exception catch (e) {
      throw SecureStorageException(
        'Failed to retrieve initialization vector',
        cause: e,
      );
    }
  }

  /// Stores the initialization vector (IV) in secure storage.
  ///
  /// The [iv] should be a base64-encoded 16-byte value.
  ///
  /// Throws [SecureStorageException] if the write operation fails.
  Future<void> storeInitializationVector(String iv) async {
    try {
      await _storage.write(
        key: _initializationVectorStorageKey,
        value: iv,
      );
    } on Exception catch (e) {
      throw SecureStorageException(
        'Failed to store initialization vector',
        cause: e,
      );
    }
  }

  /// Retrieves the salt used for key derivation from secure storage.
  ///
  /// Returns the stored salt as a base64-encoded string,
  /// or `null` if no salt has been stored yet.
  ///
  /// Throws [SecureStorageException] if the read operation fails.
  Future<String?> getSalt() async {
    try {
      return await _storage.read(key: _saltStorageKey);
    } on Exception catch (e) {
      throw SecureStorageException(
        'Failed to retrieve salt',
        cause: e,
      );
    }
  }

  /// Stores the salt used for key derivation in secure storage.
  ///
  /// The [salt] should be a base64-encoded value (typically 32 bytes).
  ///
  /// Throws [SecureStorageException] if the write operation fails.
  Future<void> storeSalt(String salt) async {
    try {
      await _storage.write(
        key: _saltStorageKey,
        value: salt,
      );
    } on Exception catch (e) {
      throw SecureStorageException(
        'Failed to store salt',
        cause: e,
      );
    }
  }

  /// Generates and stores a new encryption key if one doesn't exist.
  ///
  /// Returns the existing key if already stored, or generates a new
  /// cryptographically secure random key and stores it.
  ///
  /// Returns the encryption key as a base64-encoded string.
  ///
  /// Throws [SecureStorageException] if the operation fails.
  Future<String> getOrCreateEncryptionKey() async {
    // Return cached key if available (prevents race conditions)
    if (_cachedEncryptionKey != null) {
      return _cachedEncryptionKey!;
    }

    // If another call is already generating the key, wait for it
    if (_keyGenerationCompleter != null) {
      debugPrint('SecureStorage: Waiting for ongoing key generation...');
      return _keyGenerationCompleter!.future;
    }

    // Start key generation with lock
    _keyGenerationCompleter = Completer<String>();

    try {
      final existingKey = await getEncryptionKey();
      if (existingKey != null) {
        _cachedEncryptionKey = existingKey;
        _keyGenerationCompleter!.complete(existingKey);
        return existingKey;
      }

      debugPrint('SecureStorage: No existing key found, generating NEW key');
      final newKey = _generateSecureRandomBytes(_keyLengthBytes);
      final encodedKey = base64Encode(newKey);
      await storeEncryptionKey(encodedKey);
      _cachedEncryptionKey = encodedKey;
      _keyGenerationCompleter!.complete(encodedKey);
      return encodedKey;
    } on Object catch (e) {
      _keyGenerationCompleter!.completeError(e);
      rethrow;
    } finally {
      _keyGenerationCompleter = null;
    }
  }

  /// Generates and stores a new initialization vector if one doesn't exist.
  ///
  /// Returns the existing IV if already stored, or generates a new
  /// cryptographically secure random IV and stores it.
  ///
  /// Returns the IV as a base64-encoded string.
  ///
  /// Throws [SecureStorageException] if the operation fails.
  Future<String> getOrCreateInitializationVector() async {
    final existingIv = await getInitializationVector();
    if (existingIv != null) {
      return existingIv;
    }

    final newIv = _generateSecureRandomBytes(_ivLengthBytes);
    final encodedIv = base64Encode(newIv);
    await storeInitializationVector(encodedIv);
    return encodedIv;
  }

  /// Generates and stores a new salt if one doesn't exist.
  ///
  /// Returns the existing salt if already stored, or generates a new
  /// cryptographically secure random salt and stores it.
  ///
  /// Returns the salt as a base64-encoded string.
  ///
  /// Throws [SecureStorageException] if the operation fails.
  Future<String> getOrCreateSalt() async {
    final existingSalt = await getSalt();
    if (existingSalt != null) {
      return existingSalt;
    }

    final newSalt = _generateSecureRandomBytes(_saltLengthBytes);
    final encodedSalt = base64Encode(newSalt);
    await storeSalt(encodedSalt);
    return encodedSalt;
  }

  /// Stores a user-specific value in secure storage.
  ///
  /// The [key] is prefixed with the user data prefix to namespace user data.
  /// The [value] is stored as a string.
  ///
  /// Throws [SecureStorageException] if the write operation fails.
  Future<void> storeUserData(String key, String value) async {
    try {
      await _storage.write(
        key: '$_userDataPrefix$key',
        value: value,
      );
    } on Exception catch (e) {
      throw SecureStorageException(
        'Failed to store user data for key: $key',
        cause: e,
      );
    }
  }

  /// Retrieves a user-specific value from secure storage.
  ///
  /// The [key] is prefixed with the user data prefix to namespace user data.
  /// Returns `null` if the key doesn't exist.
  ///
  /// Throws [SecureStorageException] if the read operation fails.
  Future<String?> getUserData(String key) async {
    try {
      return await _storage.read(key: '$_userDataPrefix$key');
    } on Exception catch (e) {
      throw SecureStorageException(
        'Failed to retrieve user data for key: $key',
        cause: e,
      );
    }
  }

  /// Deletes a user-specific value from secure storage.
  ///
  /// The [key] is prefixed with the user data prefix to namespace user data.
  ///
  /// Throws [SecureStorageException] if the delete operation fails.
  Future<void> deleteUserData(String key) async {
    try {
      await _storage.delete(key: '$_userDataPrefix$key');
    } on Exception catch (e) {
      throw SecureStorageException(
        'Failed to delete user data for key: $key',
        cause: e,
      );
    }
  }

  /// Checks if secure storage is available on this device.
  ///
  /// Returns `true` if the platform supports secure storage,
  /// `false` otherwise.
  Future<bool> isAvailable() async {
    try {
      // Try to read a non-existent key to check if storage is accessible
      await _storage.read(key: '_aiscan_test_key');
      return true;
    } on Object catch (_) {
      return false;
    }
  }

  /// Checks if the encryption key has been initialized.
  ///
  /// Returns `true` if an encryption key exists in secure storage,
  /// `false` otherwise.
  Future<bool> hasEncryptionKey() async {
    final key = await getEncryptionKey();
    return key != null;
  }

  /// Deletes the encryption key from secure storage.
  ///
  /// **WARNING**: This will make all encrypted documents unrecoverable.
  /// Only use this for testing or when the user explicitly requests
  /// a complete data wipe.
  ///
  /// Throws [SecureStorageException] if the delete operation fails.
  Future<void> deleteEncryptionKey() async {
    try {
      await _storage.delete(key: _encryptionKeyStorageKey);
    } on Exception catch (e) {
      throw SecureStorageException(
        'Failed to delete encryption key',
        cause: e,
      );
    }
  }

  /// Deletes all stored data from secure storage.
  ///
  /// **WARNING**: This will delete the encryption key and make all
  /// encrypted documents unrecoverable. Only use this for testing
  /// or when the user explicitly requests a complete data wipe.
  ///
  /// Throws [SecureStorageException] if the delete operation fails.
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } on Exception catch (e) {
      throw SecureStorageException(
        'Failed to delete all secure storage data',
        cause: e,
      );
    }
  }

  /// Generates cryptographically secure random bytes.
  ///
  /// Uses [Random.secure] to generate [length] random bytes.
  /// This is suitable for generating encryption keys and IVs.
  Uint8List _generateSecureRandomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  /// Decodes a base64-encoded key to raw bytes.
  ///
  /// Useful when the encryption key needs to be passed to
  /// encryption libraries that expect raw bytes.
  Uint8List decodeKey(String base64Key) {
    return base64Decode(base64Key);
  }

  /// Encodes raw bytes to a base64 string.
  ///
  /// Useful when raw bytes need to be stored as a string.
  String encodeBytes(Uint8List bytes) {
    return base64Encode(bytes);
  }
}
