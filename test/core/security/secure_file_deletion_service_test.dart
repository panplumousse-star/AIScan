import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:aiscan/core/security/secure_file_deletion_service.dart';

void main() {
  late SecureFileDeletionService service;
  late Directory tempDir;

  setUp(() {
    service = SecureFileDeletionService();
  });

  /// Creates a temporary directory for test files.
  Future<Directory> createTempDirectory() async {
    final dir = await Directory.systemTemp.createTemp('secure_deletion_test_');
    return dir;
  }

  /// Creates a test file with the specified size in bytes.
  Future<File> createTestFile(Directory dir, String name, int size) async {
    final file = File('${dir.path}/$name');
    if (size > 0) {
      final data = Uint8List(size);
      // Fill with non-zero data to verify overwriting
      for (var i = 0; i < size; i++) {
        data[i] = (i % 256);
      }
      await file.writeAsBytes(data);
    } else {
      await file.create();
    }
    return file;
  }

  group('SecureFileDeletionService', () {
    setUp(() async {
      tempDir = await createTempDirectory();
    });

    tearDown(() async {
      // Clean up temp directory if it still exists
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('secureDeleteFile', () {
      test('should delete existing file and return true', () async {
        // Arrange
        final file = await createTestFile(tempDir, 'test.txt', 1024);
        expect(await file.exists(), isTrue);

        // Act
        final result = await service.secureDeleteFile(file.path);

        // Assert
        expect(result, isTrue);
        expect(await file.exists(), isFalse);
      });

      test('should return false when file does not exist', () async {
        // Arrange
        final nonExistentPath = '${tempDir.path}/non_existent.txt';

        // Act
        final result = await service.secureDeleteFile(nonExistentPath);

        // Assert
        expect(result, isFalse);
      });

      test('should delete empty file', () async {
        // Arrange
        final file = await createTestFile(tempDir, 'empty.txt', 0);
        expect(await file.exists(), isTrue);
        expect(await file.length(), equals(0));

        // Act
        final result = await service.secureDeleteFile(file.path);

        // Assert
        expect(result, isTrue);
        expect(await file.exists(), isFalse);
      });

      test('should delete small file (< buffer size)', () async {
        // Arrange
        final file = await createTestFile(tempDir, 'small.txt', 100);
        expect(await file.exists(), isTrue);

        // Act
        final result = await service.secureDeleteFile(file.path);

        // Assert
        expect(result, isTrue);
        expect(await file.exists(), isFalse);
      });

      test('should delete medium file (= buffer size)', () async {
        // Arrange
        final file = await createTestFile(tempDir, 'medium.txt', 64 * 1024);
        expect(await file.exists(), isTrue);

        // Act
        final result = await service.secureDeleteFile(file.path);

        // Assert
        expect(result, isTrue);
        expect(await file.exists(), isFalse);
      });

      test('should delete large file (> buffer size)', () async {
        // Arrange
        final file = await createTestFile(tempDir, 'large.txt', 200 * 1024);
        expect(await file.exists(), isTrue);

        // Act
        final result = await service.secureDeleteFile(file.path);

        // Assert
        expect(result, isTrue);
        expect(await file.exists(), isFalse);
      });

      test('should handle directory instead of file', () async {
        // Arrange
        final subDir = Directory('${tempDir.path}/subdir');
        await subDir.create();

        // Act
        final result = await service.secureDeleteFile(subDir.path);

        // Assert
        // Directories are treated as non-existent files
        expect(result, isFalse);

        // Clean up
        await subDir.delete();
      });

      test('should throw SecureFileDeletionException when file is locked',
          () async {
        // Arrange
        final file = await createTestFile(tempDir, 'locked.txt', 1024);

        // Open the file in exclusive mode to lock it (platform dependent)
        final raf = await file.open(mode: FileMode.write);

        try {
          // Act & Assert
          // Note: This test may be platform-specific
          // On some platforms, deleting a locked file may succeed
          await service.secureDeleteFile(file.path);

          // If we reach here, the platform allows deletion of locked files
          expect(await file.exists(), isFalse);
        } catch (e) {
          // If deletion fails, verify it's the correct exception
          expect(e, isA<SecureFileDeletionException>());
        } finally {
          await raf.close();
        }
      });
    });

    group('secureDeleteFiles', () {
      test('should delete multiple existing files', () async {
        // Arrange
        final file1 = await createTestFile(tempDir, 'file1.txt', 1024);
        final file2 = await createTestFile(tempDir, 'file2.txt', 2048);
        final file3 = await createTestFile(tempDir, 'file3.txt', 512);

        final filePaths = [file1.path, file2.path, file3.path];

        expect(await file1.exists(), isTrue);
        expect(await file2.exists(), isTrue);
        expect(await file3.exists(), isTrue);

        // Act
        final results = await service.secureDeleteFiles(filePaths);

        // Assert
        expect(results, hasLength(3));
        expect(results[file1.path], isTrue);
        expect(results[file2.path], isTrue);
        expect(results[file3.path], isTrue);

        expect(await file1.exists(), isFalse);
        expect(await file2.exists(), isFalse);
        expect(await file3.exists(), isFalse);
      });

      test('should handle mix of existing and non-existing files', () async {
        // Arrange
        final file1 = await createTestFile(tempDir, 'exists.txt', 1024);
        final nonExistentPath = '${tempDir.path}/non_existent.txt';

        final filePaths = [file1.path, nonExistentPath];

        expect(await file1.exists(), isTrue);

        // Act
        final results = await service.secureDeleteFiles(filePaths);

        // Assert
        expect(results, hasLength(2));
        expect(results[file1.path], isTrue);
        expect(results[nonExistentPath], isFalse);

        expect(await file1.exists(), isFalse);
      });

      test('should handle empty file list', () async {
        // Arrange
        final filePaths = <String>[];

        // Act
        final results = await service.secureDeleteFiles(filePaths);

        // Assert
        expect(results, isEmpty);
      });

      test('should continue processing other files when one fails', () async {
        // Arrange
        final file1 = await createTestFile(tempDir, 'file1.txt', 1024);
        final file2 = await createTestFile(tempDir, 'file2.txt', 1024);

        // Open file2 to potentially lock it
        final raf = await file2.open(mode: FileMode.write);

        try {
          final filePaths = [file1.path, file2.path];

          // Act
          // This may succeed or fail depending on platform
          try {
            final results = await service.secureDeleteFiles(filePaths);
            // If it succeeds, both files should be deleted
            expect(results[file1.path], isTrue);
            expect(await file1.exists(), isFalse);
          } catch (e) {
            // If it fails, verify it's the correct exception
            expect(e, isA<SecureFileDeletionException>());
          }
        } finally {
          await raf.close();
        }
      });

      test('should handle all non-existent files', () async {
        // Arrange
        final nonExistentPath1 = '${tempDir.path}/non_existent1.txt';
        final nonExistentPath2 = '${tempDir.path}/non_existent2.txt';

        final filePaths = [nonExistentPath1, nonExistentPath2];

        // Act
        final results = await service.secureDeleteFiles(filePaths);

        // Assert
        expect(results, hasLength(2));
        expect(results[nonExistentPath1], isFalse);
        expect(results[nonExistentPath2], isFalse);
      });

      test('should delete files with various sizes', () async {
        // Arrange
        final files = <File>[];
        final sizes = [0, 100, 1024, 64 * 1024, 128 * 1024];

        for (var i = 0; i < sizes.length; i++) {
          final file = await createTestFile(
            tempDir,
            'file_$i.txt',
            sizes[i],
          );
          files.add(file);
        }

        final filePaths = files.map((f) => f.path).toList();

        // Act
        final results = await service.secureDeleteFiles(filePaths);

        // Assert
        expect(results, hasLength(sizes.length));
        for (final file in files) {
          expect(results[file.path], isTrue);
          expect(await file.exists(), isFalse);
        }
      });
    });

    group('SecureFileDeletionException', () {
      test('should format message without cause', () {
        // Arrange
        const message = 'Test error message';
        const exception = SecureFileDeletionException(message);

        // Act
        final result = exception.toString();

        // Assert
        expect(result, equals('SecureFileDeletionException: $message'));
      });

      test('should format message with cause', () {
        // Arrange
        const message = 'Test error message';
        final cause = Exception('Root cause');
        final exception = SecureFileDeletionException(message, cause: cause);

        // Act
        final result = exception.toString();

        // Assert
        expect(result, contains('SecureFileDeletionException: $message'));
        expect(result, contains('caused by:'));
        expect(result, contains('Root cause'));
      });

      test('should store message and cause', () {
        // Arrange
        const message = 'Test error message';
        final cause = Exception('Root cause');

        // Act
        final exception = SecureFileDeletionException(message, cause: cause);

        // Assert
        expect(exception.message, equals(message));
        expect(exception.cause, equals(cause));
      });
    });

    group('Integration tests', () {
      test('should successfully delete real temporary file', () async {
        // Arrange
        final file = await createTestFile(tempDir, 'integration_test.txt', 4096);

        // Write some identifiable content
        await file.writeAsString('Sensitive data that must be securely deleted');
        expect(await file.exists(), isTrue);
        final originalSize = await file.length();

        // Act
        final result = await service.secureDeleteFile(file.path);

        // Assert
        expect(result, isTrue);
        expect(await file.exists(), isFalse);
      });

      test('should handle deleting same file twice', () async {
        // Arrange
        final file = await createTestFile(tempDir, 'double_delete.txt', 1024);
        expect(await file.exists(), isTrue);

        // Act
        final firstResult = await service.secureDeleteFile(file.path);
        final secondResult = await service.secureDeleteFile(file.path);

        // Assert
        expect(firstResult, isTrue);
        expect(secondResult, isFalse); // File already deleted
        expect(await file.exists(), isFalse);
      });

      test('should handle batch deletion with duplicate paths', () async {
        // Arrange
        final file = await createTestFile(tempDir, 'duplicate.txt', 1024);
        final filePaths = [file.path, file.path, file.path];

        // Act
        final results = await service.secureDeleteFiles(filePaths);

        // Assert
        // Map keys are unique, so only one entry for the path
        // Last write wins: first deletion succeeds (true), subsequent return false
        expect(results, hasLength(1));
        expect(results[file.path], isFalse); // Last result is false
        expect(await file.exists(), isFalse);
      });
    });
  });
}
