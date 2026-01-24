import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:aiscan/core/performance/cache/image_cache_manager.dart';

void main() {
  late ImageCacheManager cache;

  // Helper to create test data of specific size
  Uint8List createTestData(int sizeBytes) {
    return Uint8List.fromList(
      List.generate(sizeBytes, (i) => i % 256),
    );
  }

  group('ImageCacheManager', () {
    group('initialization', () {
      test('should initialize with correct limits', () {
        // Arrange & Act
        final cache = ImageCacheManager(
          maxSizeBytes: 1024 * 1024,
          maxItems: 10,
        );

        // Assert
        expect(cache.maxSizeBytes, equals(1024 * 1024));
        expect(cache.maxItems, equals(10));
        expect(cache.isEmpty, isTrue);
        expect(cache.currentSizeBytes, equals(0));
        expect(cache.itemCount, equals(0));
      });

      test('should start empty', () {
        // Arrange & Act
        final cache = ImageCacheManager(
          maxSizeBytes: 1024,
          maxItems: 5,
        );

        // Assert
        expect(cache.isEmpty, isTrue);
        expect(cache.isFull, isFalse);
        expect(cache.currentSizeBytes, equals(0));
        expect(cache.itemCount, equals(0));
      });
    });

    group('put and get', () {
      setUp(() {
        cache = ImageCacheManager(
          maxSizeBytes: 1024,
          maxItems: 10,
        );
      });

      test('should store and retrieve image correctly', () {
        // Arrange
        const key = 'test-image';
        final bytes = createTestData(100);

        // Act
        cache.put(key, bytes);
        final retrieved = cache.get(key);

        // Assert
        expect(retrieved, equals(bytes));
        expect(cache.itemCount, equals(1));
        expect(cache.currentSizeBytes, equals(100));
      });

      test('should return null for non-existent key', () {
        // Act
        final retrieved = cache.get('non-existent');

        // Assert
        expect(retrieved, isNull);
      });

      test('should update existing entry when key already exists', () {
        // Arrange
        const key = 'test-image';
        final oldBytes = createTestData(100);
        final newBytes = createTestData(200);

        // Act
        cache.put(key, oldBytes);
        expect(cache.currentSizeBytes, equals(100));

        cache.put(key, newBytes);
        final retrieved = cache.get(key);

        // Assert
        expect(retrieved, equals(newBytes));
        expect(cache.itemCount, equals(1));
        expect(cache.currentSizeBytes, equals(200));
      });

      test('should handle multiple entries', () {
        // Arrange & Act
        cache.put('image1', createTestData(100));
        cache.put('image2', createTestData(150));
        cache.put('image3', createTestData(200));

        // Assert
        expect(cache.itemCount, equals(3));
        expect(cache.currentSizeBytes, equals(450));
        expect(cache.get('image1'), isNotNull);
        expect(cache.get('image2'), isNotNull);
        expect(cache.get('image3'), isNotNull);
      });

      test('should handle binary data correctly', () {
        // Arrange
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
        cache.put('binary', binaryData);
        final retrieved = cache.get('binary');

        // Assert
        expect(retrieved, equals(binaryData));
      });
    });

    group('LRU eviction', () {
      setUp(() {
        cache = ImageCacheManager(
          maxSizeBytes: 500,
          maxItems: 3,
        );
      });

      test('should evict oldest entry when size limit exceeded', () {
        // Arrange
        cache.put('image1', createTestData(200));
        cache.put('image2', createTestData(200));

        // Act - this should evict image1
        cache.put('image3', createTestData(200));

        // Assert
        expect(cache.itemCount, equals(2));
        expect(cache.get('image1'), isNull);
        expect(cache.get('image2'), isNotNull);
        expect(cache.get('image3'), isNotNull);
      });

      test('should evict oldest entry when item count limit exceeded', () {
        // Arrange
        cache.put('image1', createTestData(100));
        cache.put('image2', createTestData(100));
        cache.put('image3', createTestData(100));

        // Act - this should evict image1
        cache.put('image4', createTestData(100));

        // Assert
        expect(cache.itemCount, equals(3));
        expect(cache.get('image1'), isNull);
        expect(cache.get('image2'), isNotNull);
        expect(cache.get('image3'), isNotNull);
        expect(cache.get('image4'), isNotNull);
      });

      test('should update LRU order on access', () {
        // Arrange
        cache.put('image1', createTestData(100));
        cache.put('image2', createTestData(100));
        cache.put('image3', createTestData(100));

        // Act - access image1 to make it most recently used
        cache.get('image1');

        // Add new item - should evict image2 (oldest)
        cache.put('image4', createTestData(100));

        // Assert
        expect(cache.get('image1'), isNotNull);
        expect(cache.get('image2'), isNull);
        expect(cache.get('image3'), isNotNull);
        expect(cache.get('image4'), isNotNull);
      });

      test('should evict multiple entries if needed', () {
        // Arrange
        cache.put('image1', createTestData(100));
        cache.put('image2', createTestData(100));
        cache.put('image3', createTestData(100));

        // Act - add large item that requires evicting multiple entries
        cache.put('large', createTestData(400));

        // Assert - should evict image1 and image2, keeping image3 and large
        expect(cache.itemCount, equals(2));
        expect(cache.get('image1'), isNull);
        expect(cache.get('image2'), isNull);
        expect(cache.get('image3'), isNotNull);
        expect(cache.get('large'), isNotNull);
      });

      test('should handle item larger than max cache size', () {
        // Arrange
        cache.put('image1', createTestData(100));

        // Act - try to add item larger than max cache size
        cache.put('oversized', createTestData(600));

        // Assert - evicts all items, then adds the oversized item anyway
        // (exceeding the limit is allowed, LRU just prevents adding more)
        expect(cache.itemCount, equals(1));
        expect(cache.get('image1'), isNull);
        expect(cache.get('oversized'), isNotNull);
        expect(cache.currentSizeBytes, equals(600));
      });
    });

    group('containsKey', () {
      setUp(() {
        cache = ImageCacheManager(
          maxSizeBytes: 1024,
          maxItems: 10,
        );
      });

      test('should return true for existing key', () {
        // Arrange
        cache.put('test', createTestData(100));

        // Act & Assert
        expect(cache.containsKey('test'), isTrue);
      });

      test('should return false for non-existent key', () {
        // Act & Assert
        expect(cache.containsKey('non-existent'), isFalse);
      });

      test('should return false after item is evicted', () {
        // Arrange
        final smallCache = ImageCacheManager(
          maxSizeBytes: 100,
          maxItems: 1,
        );
        smallCache.put('image1', createTestData(50));

        // Act - add another item to evict image1
        smallCache.put('image2', createTestData(50));

        // Assert
        expect(smallCache.containsKey('image1'), isFalse);
        expect(smallCache.containsKey('image2'), isTrue);
      });
    });

    group('remove', () {
      setUp(() {
        cache = ImageCacheManager(
          maxSizeBytes: 1024,
          maxItems: 10,
        );
      });

      test('should remove existing entry', () {
        // Arrange
        cache.put('test', createTestData(100));
        expect(cache.containsKey('test'), isTrue);

        // Act
        cache.remove('test');

        // Assert
        expect(cache.containsKey('test'), isFalse);
        expect(cache.get('test'), isNull);
        expect(cache.isEmpty, isTrue);
        expect(cache.currentSizeBytes, equals(0));
      });

      test('should update size correctly when removing entry', () {
        // Arrange
        cache.put('image1', createTestData(100));
        cache.put('image2', createTestData(200));
        expect(cache.currentSizeBytes, equals(300));

        // Act
        cache.remove('image1');

        // Assert
        expect(cache.currentSizeBytes, equals(200));
        expect(cache.itemCount, equals(1));
      });

      test('should handle removing non-existent key gracefully', () {
        // Arrange
        cache.put('test', createTestData(100));

        // Act & Assert - should not throw
        expect(() => cache.remove('non-existent'), returnsNormally);
        expect(cache.itemCount, equals(1));
        expect(cache.currentSizeBytes, equals(100));
      });
    });

    group('clear', () {
      setUp(() {
        cache = ImageCacheManager(
          maxSizeBytes: 1024,
          maxItems: 10,
        );
      });

      test('should clear all entries', () {
        // Arrange
        cache.put('image1', createTestData(100));
        cache.put('image2', createTestData(200));
        cache.put('image3', createTestData(150));
        expect(cache.itemCount, equals(3));

        // Act
        cache.clear();

        // Assert
        expect(cache.isEmpty, isTrue);
        expect(cache.itemCount, equals(0));
        expect(cache.currentSizeBytes, equals(0));
        expect(cache.get('image1'), isNull);
        expect(cache.get('image2'), isNull);
        expect(cache.get('image3'), isNull);
      });

      test('should handle clearing empty cache', () {
        // Act & Assert
        expect(() => cache.clear(), returnsNormally);
        expect(cache.isEmpty, isTrue);
      });
    });

    group('trimToSize', () {
      setUp(() {
        cache = ImageCacheManager(
          maxSizeBytes: 1024,
          maxItems: 10,
        );
      });

      test('should trim cache to target size', () {
        // Arrange
        cache.put('image1', createTestData(200));
        cache.put('image2', createTestData(200));
        cache.put('image3', createTestData(200));
        expect(cache.currentSizeBytes, equals(600));

        // Act - trim to 300 bytes
        cache.trimToSize(300);

        // Assert
        expect(cache.currentSizeBytes, lessThanOrEqualTo(300));
        expect(cache.get('image1'), isNull);
        expect(cache.get('image2'), isNull);
        expect(cache.get('image3'), isNotNull);
      });

      test('should evict oldest entries first when trimming', () {
        // Arrange
        cache.put('image1', createTestData(100));
        cache.put('image2', createTestData(100));
        cache.put('image3', createTestData(100));
        cache.put('image4', createTestData(100));

        // Act - trim to 250 bytes
        cache.trimToSize(250);

        // Assert - should keep newest entries
        expect(cache.get('image1'), isNull);
        expect(cache.get('image2'), isNull);
        expect(cache.get('image3'), isNotNull);
        expect(cache.get('image4'), isNotNull);
      });

      test('should handle trimming to zero', () {
        // Arrange
        cache.put('image1', createTestData(100));
        cache.put('image2', createTestData(200));

        // Act
        cache.trimToSize(0);

        // Assert
        expect(cache.isEmpty, isTrue);
        expect(cache.currentSizeBytes, equals(0));
      });

      test('should do nothing if current size is below target', () {
        // Arrange
        cache.put('image1', createTestData(100));
        cache.put('image2', createTestData(100));

        // Act
        cache.trimToSize(500);

        // Assert - should keep all entries
        expect(cache.itemCount, equals(2));
        expect(cache.currentSizeBytes, equals(200));
        expect(cache.get('image1'), isNotNull);
        expect(cache.get('image2'), isNotNull);
      });
    });

    group('cache state', () {
      setUp(() {
        cache = ImageCacheManager(
          maxSizeBytes: 500,
          maxItems: 3,
        );
      });

      test('should report isFull when size limit reached', () {
        // Arrange & Act
        cache.put('image1', createTestData(500));

        // Assert
        expect(cache.isFull, isTrue);
      });

      test('should report isFull when item limit reached', () {
        // Arrange & Act
        cache.put('image1', createTestData(100));
        cache.put('image2', createTestData(100));
        cache.put('image3', createTestData(100));

        // Assert
        expect(cache.isFull, isTrue);
      });

      test('should report isEmpty correctly', () {
        // Initially empty
        expect(cache.isEmpty, isTrue);

        // Add item
        cache.put('test', createTestData(100));
        expect(cache.isEmpty, isFalse);

        // Clear
        cache.clear();
        expect(cache.isEmpty, isTrue);
      });

      test('should calculate utilization percent correctly', () {
        // Arrange
        cache.put('image1', createTestData(250)); // 50% of 500

        // Act & Assert
        expect(cache.utilizationPercent, closeTo(50.0, 0.1));

        cache.put('image2', createTestData(125)); // 75% of 500
        expect(cache.utilizationPercent, closeTo(75.0, 0.1));
      });
    });

    group('edge cases', () {
      setUp(() {
        cache = ImageCacheManager(
          maxSizeBytes: 1024,
          maxItems: 10,
        );
      });

      test('should handle very small cache size', () {
        // Arrange
        cache = ImageCacheManager(
          maxSizeBytes: 10,
          maxItems: 1,
        );

        // Act
        cache.put('small', createTestData(5));

        // Assert
        expect(cache.get('small'), isNotNull);
        expect(cache.currentSizeBytes, equals(5));
      });

      test('should handle cache with maxItems = 1', () {
        // Arrange
        cache = ImageCacheManager(
          maxSizeBytes: 1024,
          maxItems: 1,
        );

        // Act
        cache.put('first', createTestData(100));
        cache.put('second', createTestData(100));

        // Assert
        expect(cache.itemCount, equals(1));
        expect(cache.get('first'), isNull);
        expect(cache.get('second'), isNotNull);
      });

      test('should handle empty bytes', () {
        // Arrange
        final emptyBytes = Uint8List(0);

        // Act
        cache.put('empty', emptyBytes);
        final retrieved = cache.get('empty');

        // Assert
        expect(retrieved, equals(emptyBytes));
        expect(cache.currentSizeBytes, equals(0));
      });
    });

    group('toString', () {
      setUp(() {
        cache = ImageCacheManager(
          maxSizeBytes: 10 * 1024 * 1024, // 10 MB
          maxItems: 5,
        );
      });

      test('should provide meaningful string representation', () {
        // Arrange
        cache.put('test', createTestData(2 * 1024 * 1024)); // 2 MB

        // Act
        final str = cache.toString();

        // Assert
        expect(str, contains('ImageCacheManager'));
        expect(str, contains('items: 1'));
        expect(str, contains('2.0MB'));
        expect(str, contains('10.0MB'));
      });
    });
  });
}
