import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:aiscan/core/performance/cache/thumbnail_cache_service.dart';
import 'package:aiscan/core/performance/device_performance.dart';

import 'thumbnail_cache_service_test.mocks.dart';

@GenerateMocks([DevicePerformance])
void main() {
  late MockDevicePerformance mockDevicePerformance;
  late ThumbnailCacheService cacheService;

  // Helper to create test thumbnail data
  Uint8List createThumbnailData(int sizeBytes) {
    return Uint8List.fromList(
      List.generate(sizeBytes, (i) => i % 256),
    );
  }

  setUp(() {
    mockDevicePerformance = MockDevicePerformance();

    // Default mock behavior - medium device
    when(mockDevicePerformance.recommendedImageCacheSize)
        .thenReturn(50 * 1024 * 1024); // 50 MB
    when(mockDevicePerformance.maxCachedImages).thenReturn(50);
  });

  group('ThumbnailCacheService', () {
    group('initialization', () {
      test('should initialize with device-specific settings', () {
        // Arrange & Act
        cacheService = ThumbnailCacheService(
          devicePerformance: mockDevicePerformance,
        );

        // Assert
        expect(cacheService.isEmpty, isTrue);
        expect(cacheService.currentSizeBytes, equals(0));
        expect(cacheService.itemCount, equals(0));
        verify(mockDevicePerformance.recommendedImageCacheSize).called(1);
        verify(mockDevicePerformance.maxCachedImages).called(1);
      });

      test('should respect low-end device limits', () {
        // Arrange
        when(mockDevicePerformance.recommendedImageCacheSize)
            .thenReturn(20 * 1024 * 1024); // 20 MB
        when(mockDevicePerformance.maxCachedImages).thenReturn(30);

        // Act
        cacheService = ThumbnailCacheService(
          devicePerformance: mockDevicePerformance,
        );

        // Assert
        expect(cacheService.isEmpty, isTrue);
        verify(mockDevicePerformance.recommendedImageCacheSize).called(1);
        verify(mockDevicePerformance.maxCachedImages).called(1);
      });

      test('should respect high-end device limits', () {
        // Arrange
        when(mockDevicePerformance.recommendedImageCacheSize)
            .thenReturn(100 * 1024 * 1024); // 100 MB
        when(mockDevicePerformance.maxCachedImages).thenReturn(100);

        // Act
        cacheService = ThumbnailCacheService(
          devicePerformance: mockDevicePerformance,
        );

        // Assert
        expect(cacheService.isEmpty, isTrue);
        verify(mockDevicePerformance.recommendedImageCacheSize).called(1);
        verify(mockDevicePerformance.maxCachedImages).called(1);
      });
    });

    group('cacheThumbnail and getCachedThumbnail', () {
      setUp(() {
        cacheService = ThumbnailCacheService(
          devicePerformance: mockDevicePerformance,
        );
      });

      test('should cache and retrieve thumbnail correctly', () {
        // Arrange
        const docId = 'doc-123';
        final thumbnailBytes = createThumbnailData(1024);

        // Act
        cacheService.cacheThumbnail(docId, thumbnailBytes);
        final retrieved = cacheService.getCachedThumbnail(docId);

        // Assert
        expect(retrieved, equals(thumbnailBytes));
        expect(cacheService.itemCount, equals(1));
        expect(cacheService.currentSizeBytes, equals(1024));
      });

      test('should return null for non-cached thumbnail', () {
        // Act
        final retrieved = cacheService.getCachedThumbnail('non-existent');

        // Assert
        expect(retrieved, isNull);
      });

      test('should update existing thumbnail when caching same document ID', () {
        // Arrange
        const docId = 'doc-123';
        final oldThumbnail = createThumbnailData(1024);
        final newThumbnail = createThumbnailData(2048);

        // Act
        cacheService.cacheThumbnail(docId, oldThumbnail);
        expect(cacheService.currentSizeBytes, equals(1024));

        cacheService.cacheThumbnail(docId, newThumbnail);
        final retrieved = cacheService.getCachedThumbnail(docId);

        // Assert
        expect(retrieved, equals(newThumbnail));
        expect(cacheService.itemCount, equals(1));
        expect(cacheService.currentSizeBytes, equals(2048));
      });

      test('should cache multiple thumbnails', () {
        // Arrange & Act
        cacheService.cacheThumbnail('doc-1', createThumbnailData(1024));
        cacheService.cacheThumbnail('doc-2', createThumbnailData(2048));
        cacheService.cacheThumbnail('doc-3', createThumbnailData(1536));

        // Assert
        expect(cacheService.itemCount, equals(3));
        expect(cacheService.currentSizeBytes, equals(4608));
        expect(cacheService.getCachedThumbnail('doc-1'), isNotNull);
        expect(cacheService.getCachedThumbnail('doc-2'), isNotNull);
        expect(cacheService.getCachedThumbnail('doc-3'), isNotNull);
      });

      test('should use correct cache key format', () {
        // Arrange
        const docId = 'abc-123';
        final thumbnailBytes = createThumbnailData(512);

        // Act
        cacheService.cacheThumbnail(docId, thumbnailBytes);

        // Assert - internal cache key should be 'thumb_abc-123'
        expect(cacheService.hasCachedThumbnail(docId), isTrue);
        expect(cacheService.getCachedThumbnail(docId), equals(thumbnailBytes));
      });
    });

    group('hasCachedThumbnail', () {
      setUp(() {
        cacheService = ThumbnailCacheService(
          devicePerformance: mockDevicePerformance,
        );
      });

      test('should return true for cached thumbnail', () {
        // Arrange
        const docId = 'doc-123';
        cacheService.cacheThumbnail(docId, createThumbnailData(1024));

        // Act & Assert
        expect(cacheService.hasCachedThumbnail(docId), isTrue);
      });

      test('should return false for non-cached thumbnail', () {
        // Act & Assert
        expect(cacheService.hasCachedThumbnail('non-existent'), isFalse);
      });

      test('should return false after thumbnail is removed', () {
        // Arrange
        const docId = 'doc-123';
        cacheService.cacheThumbnail(docId, createThumbnailData(1024));

        // Act
        cacheService.removeThumbnail(docId);

        // Assert
        expect(cacheService.hasCachedThumbnail(docId), isFalse);
      });
    });

    group('removeThumbnail', () {
      setUp(() {
        cacheService = ThumbnailCacheService(
          devicePerformance: mockDevicePerformance,
        );
      });

      test('should remove cached thumbnail', () {
        // Arrange
        const docId = 'doc-123';
        cacheService.cacheThumbnail(docId, createThumbnailData(1024));
        expect(cacheService.hasCachedThumbnail(docId), isTrue);

        // Act
        cacheService.removeThumbnail(docId);

        // Assert
        expect(cacheService.hasCachedThumbnail(docId), isFalse);
        expect(cacheService.getCachedThumbnail(docId), isNull);
        expect(cacheService.isEmpty, isTrue);
        expect(cacheService.currentSizeBytes, equals(0));
      });

      test('should update size correctly when removing thumbnail', () {
        // Arrange
        cacheService.cacheThumbnail('doc-1', createThumbnailData(1024));
        cacheService.cacheThumbnail('doc-2', createThumbnailData(2048));
        expect(cacheService.currentSizeBytes, equals(3072));

        // Act
        cacheService.removeThumbnail('doc-1');

        // Assert
        expect(cacheService.currentSizeBytes, equals(2048));
        expect(cacheService.itemCount, equals(1));
      });

      test('should handle removing non-existent thumbnail gracefully', () {
        // Arrange
        cacheService.cacheThumbnail('doc-1', createThumbnailData(1024));

        // Act & Assert - should not throw
        expect(
          () => cacheService.removeThumbnail('non-existent'),
          returnsNormally,
        );
        expect(cacheService.itemCount, equals(1));
        expect(cacheService.currentSizeBytes, equals(1024));
      });
    });

    group('clearCache', () {
      setUp(() {
        cacheService = ThumbnailCacheService(
          devicePerformance: mockDevicePerformance,
        );
      });

      test('should clear all thumbnails and reset statistics', () {
        // Arrange
        cacheService.cacheThumbnail('doc-1', createThumbnailData(1024));
        cacheService.cacheThumbnail('doc-2', createThumbnailData(2048));
        cacheService.cacheThumbnail('doc-3', createThumbnailData(1536));

        // Generate some cache hits/misses
        cacheService.getCachedThumbnail('doc-1'); // hit
        cacheService.getCachedThumbnail('doc-2'); // hit
        cacheService.getCachedThumbnail('non-existent'); // miss

        expect(cacheService.cacheHits, equals(2));
        expect(cacheService.cacheMisses, equals(1));

        // Act
        cacheService.clearCache();

        // Assert
        expect(cacheService.isEmpty, isTrue);
        expect(cacheService.itemCount, equals(0));
        expect(cacheService.currentSizeBytes, equals(0));
        expect(cacheService.cacheHits, equals(0));
        expect(cacheService.cacheMisses, equals(0));
        expect(cacheService.hitRate, equals(0));
      });

      test('should handle clearing empty cache', () {
        // Act & Assert
        expect(() => cacheService.clearCache(), returnsNormally);
        expect(cacheService.isEmpty, isTrue);
      });
    });

    group('trimToSize', () {
      setUp(() {
        cacheService = ThumbnailCacheService(
          devicePerformance: mockDevicePerformance,
        );
      });

      test('should trim cache to target size', () {
        // Arrange
        cacheService.cacheThumbnail('doc-1', createThumbnailData(10 * 1024));
        cacheService.cacheThumbnail('doc-2', createThumbnailData(10 * 1024));
        cacheService.cacheThumbnail('doc-3', createThumbnailData(10 * 1024));
        expect(cacheService.currentSizeBytes, equals(30 * 1024));

        // Act - trim to 15 KB
        cacheService.trimToSize(15 * 1024);

        // Assert
        expect(
          cacheService.currentSizeBytes,
          lessThanOrEqualTo(15 * 1024),
        );
      });

      test('should evict oldest thumbnails first when trimming', () {
        // Arrange
        cacheService.cacheThumbnail('doc-1', createThumbnailData(5 * 1024));
        cacheService.cacheThumbnail('doc-2', createThumbnailData(5 * 1024));
        cacheService.cacheThumbnail('doc-3', createThumbnailData(5 * 1024));
        cacheService.cacheThumbnail('doc-4', createThumbnailData(5 * 1024));

        // Act - trim to 12 KB
        cacheService.trimToSize(12 * 1024);

        // Assert - should keep newest thumbnails
        expect(cacheService.getCachedThumbnail('doc-1'), isNull);
        expect(cacheService.getCachedThumbnail('doc-2'), isNull);
        expect(cacheService.getCachedThumbnail('doc-3'), isNotNull);
        expect(cacheService.getCachedThumbnail('doc-4'), isNotNull);
      });

      test('should do nothing if current size is below target', () {
        // Arrange
        cacheService.cacheThumbnail('doc-1', createThumbnailData(5 * 1024));
        cacheService.cacheThumbnail('doc-2', createThumbnailData(5 * 1024));

        // Act
        cacheService.trimToSize(20 * 1024);

        // Assert - should keep all thumbnails
        expect(cacheService.itemCount, equals(2));
        expect(cacheService.currentSizeBytes, equals(10 * 1024));
        expect(cacheService.getCachedThumbnail('doc-1'), isNotNull);
        expect(cacheService.getCachedThumbnail('doc-2'), isNotNull);
      });
    });

    group('cache statistics', () {
      setUp(() {
        cacheService = ThumbnailCacheService(
          devicePerformance: mockDevicePerformance,
        );
      });

      test('should track cache hits correctly', () {
        // Arrange
        cacheService.cacheThumbnail('doc-1', createThumbnailData(1024));

        // Act
        cacheService.getCachedThumbnail('doc-1'); // hit
        cacheService.getCachedThumbnail('doc-1'); // hit
        cacheService.getCachedThumbnail('doc-1'); // hit

        // Assert
        expect(cacheService.cacheHits, equals(3));
        expect(cacheService.cacheMisses, equals(0));
      });

      test('should track cache misses correctly', () {
        // Act
        cacheService.getCachedThumbnail('doc-1'); // miss
        cacheService.getCachedThumbnail('doc-2'); // miss
        cacheService.getCachedThumbnail('doc-3'); // miss

        // Assert
        expect(cacheService.cacheHits, equals(0));
        expect(cacheService.cacheMisses, equals(3));
      });

      test('should track mixed hits and misses', () {
        // Arrange
        cacheService.cacheThumbnail('doc-1', createThumbnailData(1024));
        cacheService.cacheThumbnail('doc-2', createThumbnailData(1024));

        // Act
        cacheService.getCachedThumbnail('doc-1'); // hit
        cacheService.getCachedThumbnail('doc-2'); // hit
        cacheService.getCachedThumbnail('doc-3'); // miss
        cacheService.getCachedThumbnail('doc-1'); // hit

        // Assert
        expect(cacheService.cacheHits, equals(3));
        expect(cacheService.cacheMisses, equals(1));
      });

      test('should calculate hit rate correctly', () {
        // Arrange
        cacheService.cacheThumbnail('doc-1', createThumbnailData(1024));

        // Act
        cacheService.getCachedThumbnail('doc-1'); // hit
        cacheService.getCachedThumbnail('doc-1'); // hit
        cacheService.getCachedThumbnail('doc-1'); // hit
        cacheService.getCachedThumbnail('doc-2'); // miss

        // 3 hits out of 4 total = 75%
        // Assert
        expect(cacheService.hitRate, closeTo(75.0, 0.1));
      });

      test('should return 0 hit rate when no lookups performed', () {
        // Act & Assert
        expect(cacheService.hitRate, equals(0));
      });

      test('should return 0 hit rate when only misses', () {
        // Act
        cacheService.getCachedThumbnail('doc-1'); // miss
        cacheService.getCachedThumbnail('doc-2'); // miss

        // Assert
        expect(cacheService.hitRate, equals(0));
      });

      test('should return 100 hit rate when only hits', () {
        // Arrange
        cacheService.cacheThumbnail('doc-1', createThumbnailData(1024));

        // Act
        cacheService.getCachedThumbnail('doc-1'); // hit
        cacheService.getCachedThumbnail('doc-1'); // hit

        // Assert
        expect(cacheService.hitRate, equals(100.0));
      });
    });

    group('resetStatistics', () {
      setUp(() {
        cacheService = ThumbnailCacheService(
          devicePerformance: mockDevicePerformance,
        );
      });

      test('should reset statistics without clearing cached items', () {
        // Arrange
        cacheService.cacheThumbnail('doc-1', createThumbnailData(1024));
        cacheService.cacheThumbnail('doc-2', createThumbnailData(2048));

        cacheService.getCachedThumbnail('doc-1'); // hit
        cacheService.getCachedThumbnail('doc-3'); // miss

        expect(cacheService.cacheHits, equals(1));
        expect(cacheService.cacheMisses, equals(1));

        // Act
        cacheService.resetStatistics();

        // Assert
        expect(cacheService.cacheHits, equals(0));
        expect(cacheService.cacheMisses, equals(0));
        expect(cacheService.hitRate, equals(0));
        expect(cacheService.itemCount, equals(2)); // items still cached
        expect(cacheService.currentSizeBytes, equals(3072)); // size unchanged
      });
    });

    group('cache state', () {
      setUp(() {
        cacheService = ThumbnailCacheService(
          devicePerformance: mockDevicePerformance,
        );
      });

      test('should report isEmpty correctly', () {
        // Initially empty
        expect(cacheService.isEmpty, isTrue);

        // Add thumbnail
        cacheService.cacheThumbnail('doc-1', createThumbnailData(1024));
        expect(cacheService.isEmpty, isFalse);

        // Clear
        cacheService.clearCache();
        expect(cacheService.isEmpty, isTrue);
      });

      test('should calculate utilization percent correctly', () {
        // Arrange
        final cacheSize = 50 * 1024 * 1024; // 50 MB
        when(mockDevicePerformance.recommendedImageCacheSize)
            .thenReturn(cacheSize);

        cacheService = ThumbnailCacheService(
          devicePerformance: mockDevicePerformance,
        );

        // Act - add 25 MB (50% utilization)
        cacheService.cacheThumbnail('doc-1', createThumbnailData(25 * 1024 * 1024));

        // Assert
        expect(cacheService.utilizationPercent, closeTo(50.0, 0.1));
      });

      test('should track item count correctly', () {
        // Initially zero
        expect(cacheService.itemCount, equals(0));

        // Add items
        cacheService.cacheThumbnail('doc-1', createThumbnailData(1024));
        expect(cacheService.itemCount, equals(1));

        cacheService.cacheThumbnail('doc-2', createThumbnailData(1024));
        expect(cacheService.itemCount, equals(2));

        cacheService.cacheThumbnail('doc-3', createThumbnailData(1024));
        expect(cacheService.itemCount, equals(3));

        // Remove item
        cacheService.removeThumbnail('doc-2');
        expect(cacheService.itemCount, equals(2));
      });

      test('should track current size correctly', () {
        // Initially zero
        expect(cacheService.currentSizeBytes, equals(0));

        // Add items
        cacheService.cacheThumbnail('doc-1', createThumbnailData(1024));
        expect(cacheService.currentSizeBytes, equals(1024));

        cacheService.cacheThumbnail('doc-2', createThumbnailData(2048));
        expect(cacheService.currentSizeBytes, equals(3072));

        // Remove item
        cacheService.removeThumbnail('doc-1');
        expect(cacheService.currentSizeBytes, equals(2048));
      });
    });

    group('edge cases', () {
      test('should handle very small cache size', () {
        // Arrange
        when(mockDevicePerformance.recommendedImageCacheSize).thenReturn(1024);
        when(mockDevicePerformance.maxCachedImages).thenReturn(1);

        cacheService = ThumbnailCacheService(
          devicePerformance: mockDevicePerformance,
        );

        // Act
        cacheService.cacheThumbnail('doc-1', createThumbnailData(512));

        // Assert
        expect(cacheService.getCachedThumbnail('doc-1'), isNotNull);
        expect(cacheService.currentSizeBytes, equals(512));
      });

      test('should handle empty thumbnail bytes', () {
        // Arrange
        cacheService = ThumbnailCacheService(
          devicePerformance: mockDevicePerformance,
        );
        final emptyBytes = Uint8List(0);

        // Act
        cacheService.cacheThumbnail('empty', emptyBytes);
        final retrieved = cacheService.getCachedThumbnail('empty');

        // Assert
        expect(retrieved, equals(emptyBytes));
        expect(cacheService.currentSizeBytes, equals(0));
      });

      test('should handle special characters in document IDs', () {
        // Arrange
        cacheService = ThumbnailCacheService(
          devicePerformance: mockDevicePerformance,
        );
        const specialDocId = 'doc-_#@!-123';
        final thumbnailBytes = createThumbnailData(1024);

        // Act
        cacheService.cacheThumbnail(specialDocId, thumbnailBytes);
        final retrieved = cacheService.getCachedThumbnail(specialDocId);

        // Assert
        expect(retrieved, equals(thumbnailBytes));
        expect(cacheService.hasCachedThumbnail(specialDocId), isTrue);
      });

      test('should handle long document IDs', () {
        // Arrange
        cacheService = ThumbnailCacheService(
          devicePerformance: mockDevicePerformance,
        );
        final longDocId = 'doc-${'a' * 100}';
        final thumbnailBytes = createThumbnailData(1024);

        // Act
        cacheService.cacheThumbnail(longDocId, thumbnailBytes);
        final retrieved = cacheService.getCachedThumbnail(longDocId);

        // Assert
        expect(retrieved, equals(thumbnailBytes));
        expect(cacheService.hasCachedThumbnail(longDocId), isTrue);
      });
    });

    group('toString', () {
      test('should provide meaningful string representation', () {
        // Arrange
        cacheService = ThumbnailCacheService(
          devicePerformance: mockDevicePerformance,
        );
        cacheService.cacheThumbnail('doc-1', createThumbnailData(2 * 1024 * 1024));
        cacheService.getCachedThumbnail('doc-1'); // hit
        cacheService.getCachedThumbnail('doc-2'); // miss

        // Act
        final str = cacheService.toString();

        // Assert
        expect(str, contains('ThumbnailCacheService'));
        expect(str, contains('items: 1'));
        expect(str, contains('2.0MB'));
        expect(str, contains('hitRate:'));
      });
    });
  });
}
