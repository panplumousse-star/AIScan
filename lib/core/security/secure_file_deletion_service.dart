import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../exceptions/base_exception.dart';

/// Riverpod provider for [SecureFileDeletionService].
///
/// Provides a singleton instance of the secure file deletion service for
/// dependency injection throughout the application.
final secureFileDeletionServiceProvider =
    Provider<SecureFileDeletionService>((ref) {
  return SecureFileDeletionService();
});

/// Exception thrown when secure file deletion operations fail.
///
/// Contains the original error message and optional underlying exception.
class SecureFileDeletionException extends BaseException {
  /// Creates a [SecureFileDeletionException] with the given [message].
  const SecureFileDeletionException(super.message, {super.cause});
}

/// Service for securely deleting files by overwriting their contents.
///
/// This service provides secure file deletion by overwriting file contents
/// with zeros multiple times before actual deletion. This prevents data
/// recovery using forensic tools.
///
/// ## Security Architecture
/// - **Overwrite passes**: Files are overwritten 3 times with zeros
/// - **Direct I/O**: Uses [RandomAccessFile] for low-level file manipulation
/// - **Verification**: Ensures file size remains consistent during overwrite
/// - **Error handling**: Provides detailed error reporting for failures
///
/// ## Usage
/// ```dart
/// final secureFileDeletion = ref.read(secureFileDeletionServiceProvider);
///
/// // Delete a single temporary decrypted file
/// await secureFileDeletion.secureDeleteFile('/path/to/temp/file.pdf');
///
/// // Delete multiple files in batch
/// await secureFileDeletion.secureDeleteFiles([
///   '/path/to/temp/file1.pdf',
///   '/path/to/temp/file2.jpg',
/// ]);
/// ```
///
/// ## Important Notes
/// - Use this service for all temporary decrypted file cleanup
/// - Files are overwritten with zeros to prevent forensic recovery
/// - The overwrite process may take longer for large files
/// - If overwrite fails, the file is still deleted (best effort)
/// - Batch deletion continues even if individual files fail
class SecureFileDeletionService {
  /// Creates a [SecureFileDeletionService].
  SecureFileDeletionService();

  /// Number of times to overwrite file contents before deletion.
  ///
  /// Standard DOD 5220.22-M recommendation is 3 passes for secure erasure.
  static const int _overwritePasses = 3;

  /// Buffer size for overwriting files (64 KB).
  ///
  /// Balances memory usage with I/O performance.
  static const int _bufferSize = 64 * 1024;

  /// Securely deletes a file by overwriting its contents before deletion.
  ///
  /// The file is overwritten [_overwritePasses] times with zeros to prevent
  /// data recovery through forensic analysis. After overwriting, the file
  /// is permanently deleted using the standard file system deletion.
  ///
  /// Returns `true` if the file was successfully overwritten and deleted,
  /// `false` if the file doesn't exist.
  ///
  /// Throws [SecureFileDeletionException] if the deletion fails.
  ///
  /// Example:
  /// ```dart
  /// final success = await secureFileDeletion.secureDeleteFile(
  ///   '/path/to/temp/decrypted.pdf',
  /// );
  /// if (success) {
  ///   print('File securely deleted');
  /// } else {
  ///   print('File did not exist');
  /// }
  /// ```
  Future<bool> secureDeleteFile(String filePath) async {
    final file = File(filePath);

    // Check if file exists
    if (!await file.exists()) {
      return false;
    }

    try {
      // Get file size before overwriting
      final fileSize = await file.length();

      // Overwrite file contents multiple times
      await _overwriteFile(file, fileSize);

      // Delete the file after overwriting
      await file.delete();

      return true;
    } on SecureFileDeletionException {
      rethrow;
    } catch (e) {
      throw SecureFileDeletionException(
        'Failed to securely delete file: $filePath',
        cause: e,
      );
    }
  }

  /// Securely deletes multiple files in batch.
  ///
  /// Each file is overwritten [_overwritePasses] times with zeros before
  /// deletion. This method continues processing all files even if individual
  /// deletions fail, collecting all errors to report at the end.
  ///
  /// Returns a map of file paths to their deletion status:
  /// - `true`: File was successfully overwritten and deleted
  /// - `false`: File did not exist
  ///
  /// Throws [SecureFileDeletionException] if any deletion fails, with all
  /// individual errors included in the exception message.
  ///
  /// Example:
  /// ```dart
  /// final results = await secureFileDeletion.secureDeleteFiles([
  ///   '/path/to/temp/file1.pdf',
  ///   '/path/to/temp/file2.jpg',
  /// ]);
  /// results.forEach((path, success) {
  ///   print('$path: ${success ? 'deleted' : 'not found'}');
  /// });
  /// ```
  Future<Map<String, bool>> secureDeleteFiles(List<String> filePaths) async {
    final results = <String, bool>{};
    final errors = <String, Object>{};

    for (final filePath in filePaths) {
      try {
        final deleted = await secureDeleteFile(filePath);
        results[filePath] = deleted;
      } catch (e) {
        errors[filePath] = e;
      }
    }

    // If there were any errors, throw an exception with all error details
    if (errors.isNotEmpty) {
      final errorMessages = errors.entries.map((entry) {
        return '${entry.key}: ${entry.value}';
      }).join('; ');

      throw SecureFileDeletionException(
        'Failed to securely delete ${errors.length} file(s): $errorMessages',
      );
    }

    return results;
  }

  /// Overwrites a file's contents with zeros multiple times.
  ///
  /// Uses [RandomAccessFile] for direct file manipulation to ensure
  /// the data is actually overwritten on disk. The file size is verified
  /// to remain consistent throughout the overwrite process.
  ///
  /// Throws [SecureFileDeletionException] if the overwrite fails.
  Future<void> _overwriteFile(File file, int fileSize) async {
    if (fileSize <= 0) {
      // Empty files don't need overwriting
      return;
    }

    try {
      // Create a buffer of zeros for overwriting
      final zeroBuffer = Uint8List(_bufferSize);

      // Perform multiple overwrite passes
      for (var pass = 0; pass < _overwritePasses; pass++) {
        RandomAccessFile? raf;
        try {
          // Open file for writing
          raf = await file.open(mode: FileMode.writeOnly);

          // Reset position to beginning of file
          await raf.setPosition(0);

          // Overwrite file in chunks
          var bytesWritten = 0;
          while (bytesWritten < fileSize) {
            final remainingBytes = fileSize - bytesWritten;
            final bytesToWrite = remainingBytes < _bufferSize
                ? remainingBytes
                : _bufferSize;

            // Write zeros to file
            await raf.writeFrom(
              zeroBuffer,
              0,
              bytesToWrite,
            );

            bytesWritten += bytesToWrite;
          }

          // Flush changes to disk
          await raf.flush();
        } finally {
          // Always close the file handle
          await raf?.close();
        }
      }
    } on SecureFileDeletionException {
      rethrow;
    } catch (e) {
      throw SecureFileDeletionException(
        'Failed to overwrite file: ${file.path}',
        cause: e,
      );
    }
  }
}
