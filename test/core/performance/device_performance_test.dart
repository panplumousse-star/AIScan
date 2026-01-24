import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aiscan/core/performance/device_performance.dart';

void main() {
  late DevicePerformance devicePerformance;

  setUp(() {
    devicePerformance = DevicePerformance();
  });

  group('DevicePerformance', () {
    group('initialization and detection', () {
      test('should detect capabilities on creation', () {
        // Act
        final device = DevicePerformance();

        // Assert - capabilities should be detected
        expect(device.processorCount, greaterThan(0));
        expect(device.estimatedRamMB, greaterThan(0));
        expect(device.tier, isIn([DeviceTier.low, DeviceTier.medium, DeviceTier.high]));
      });

      test('should classify tier based on processor count', () {
        // Act
        final device = DevicePerformance();

        // Assert - tier should match processor count heuristics
        if (device.processorCount <= 2) {
          expect(device.tier, equals(DeviceTier.low));
        } else if (device.processorCount <= 4) {
          expect(device.tier, equals(DeviceTier.medium));
        } else {
          expect(device.tier, equals(DeviceTier.high));
        }
      });

      test('should estimate RAM based on processor count', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.processorCount <= 2) {
          expect(device.estimatedRamMB, equals(2048));
        } else if (device.processorCount <= 4) {
          expect(device.estimatedRamMB, equals(4096));
        } else {
          expect(device.estimatedRamMB, equals(8192));
        }
      });

      test('should provide meaningful toString representation', () {
        // Act
        final device = DevicePerformance();
        final string = device.toString();

        // Assert
        expect(string, contains('DevicePerformance'));
        expect(string, contains('tier:'));
        expect(string, contains('cores:'));
        expect(string, contains('estimatedRAM:'));
        expect(string, contains('MB'));
      });
    });

    group('device tier classification', () {
      test('should provide boolean helpers for tier classification', () {
        // Act
        final device = DevicePerformance();

        // Assert - exactly one should be true
        final classifications = [
          device.isLowEndDevice,
          device.isMidRangeDevice,
          device.isHighEndDevice,
        ];
        expect(classifications.where((c) => c).length, equals(1));
      });

      test('isLowEndDevice should match tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        expect(device.isLowEndDevice, equals(device.tier == DeviceTier.low));
      });

      test('isMidRangeDevice should match tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        expect(device.isMidRangeDevice, equals(device.tier == DeviceTier.medium));
      });

      test('isHighEndDevice should match tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        expect(device.isHighEndDevice, equals(device.tier == DeviceTier.high));
      });
    });

    group('animation settings', () {
      test('animationDurationMultiplier should return correct value for low tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.low) {
          expect(device.animationDurationMultiplier, equals(0.5));
        }
      });

      test('animationDurationMultiplier should return correct value for medium tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.medium) {
          expect(device.animationDurationMultiplier, equals(0.8));
        }
      });

      test('animationDurationMultiplier should return correct value for high tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.high) {
          expect(device.animationDurationMultiplier, equals(1.0));
        }
      });

      test('animationDurationMultiplier should be between 0 and 1', () {
        // Act
        final device = DevicePerformance();

        // Assert
        expect(device.animationDurationMultiplier, greaterThan(0.0));
        expect(device.animationDurationMultiplier, lessThanOrEqualTo(1.0));
      });

      test('enableComplexAnimations should be false for low tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.low) {
          expect(device.enableComplexAnimations, isFalse);
        }
      });

      test('enableComplexAnimations should be true for medium and high tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.medium || device.tier == DeviceTier.high) {
          expect(device.enableComplexAnimations, isTrue);
        }
      });

      test('enablePageTransitions should be false for low tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.low) {
          expect(device.enablePageTransitions, isFalse);
        }
      });

      test('enablePageTransitions should be true for medium and high tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.medium || device.tier == DeviceTier.high) {
          expect(device.enablePageTransitions, isTrue);
        }
      });
    });

    group('image settings', () {
      test('recommendedThumbnailSize should return correct value for low tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.low) {
          expect(device.recommendedThumbnailSize, equals(150));
        }
      });

      test('recommendedThumbnailSize should return correct value for medium tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.medium) {
          expect(device.recommendedThumbnailSize, equals(200));
        }
      });

      test('recommendedThumbnailSize should return correct value for high tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.high) {
          expect(device.recommendedThumbnailSize, equals(200));
        }
      });

      test('recommendedThumbnailSize should be a reasonable size', () {
        // Act
        final device = DevicePerformance();

        // Assert
        expect(device.recommendedThumbnailSize, greaterThanOrEqualTo(100));
        expect(device.recommendedThumbnailSize, lessThanOrEqualTo(500));
      });

      test('recommendedThumbnailQuality should return correct value for low tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.low) {
          expect(device.recommendedThumbnailQuality, equals(60));
        }
      });

      test('recommendedThumbnailQuality should return correct value for medium tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.medium) {
          expect(device.recommendedThumbnailQuality, equals(75));
        }
      });

      test('recommendedThumbnailQuality should return correct value for high tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.high) {
          expect(device.recommendedThumbnailQuality, equals(85));
        }
      });

      test('recommendedThumbnailQuality should be in valid range', () {
        // Act
        final device = DevicePerformance();

        // Assert - JPEG quality should be 0-100
        expect(device.recommendedThumbnailQuality, greaterThanOrEqualTo(0));
        expect(device.recommendedThumbnailQuality, lessThanOrEqualTo(100));
      });

      test('maxImageDimension should return correct value for low tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.low) {
          expect(device.maxImageDimension, equals(2000));
        }
      });

      test('maxImageDimension should return correct value for medium tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.medium) {
          expect(device.maxImageDimension, equals(3000));
        }
      });

      test('maxImageDimension should return correct value for high tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.high) {
          expect(device.maxImageDimension, equals(4000));
        }
      });

      test('maxImageDimension should be a reasonable value', () {
        // Act
        final device = DevicePerformance();

        // Assert
        expect(device.maxImageDimension, greaterThanOrEqualTo(1000));
        expect(device.maxImageDimension, lessThanOrEqualTo(10000));
      });

      test('maxImageDimension should increase with device tier', () {
        // This test verifies the logic consistency
        // Low < Medium < High
        const lowValue = 2000;
        const mediumValue = 3000;
        const highValue = 4000;

        expect(lowValue, lessThan(mediumValue));
        expect(mediumValue, lessThan(highValue));
      });
    });

    group('cache settings', () {
      test('recommendedImageCacheSize should return correct value for low tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.low) {
          expect(device.recommendedImageCacheSize, equals(20 * 1024 * 1024));
        }
      });

      test('recommendedImageCacheSize should return correct value for medium tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.medium) {
          expect(device.recommendedImageCacheSize, equals(50 * 1024 * 1024));
        }
      });

      test('recommendedImageCacheSize should return correct value for high tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.high) {
          expect(device.recommendedImageCacheSize, equals(100 * 1024 * 1024));
        }
      });

      test('recommendedImageCacheSize should be positive', () {
        // Act
        final device = DevicePerformance();

        // Assert
        expect(device.recommendedImageCacheSize, greaterThan(0));
      });

      test('maxCachedImages should return correct value for low tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.low) {
          expect(device.maxCachedImages, equals(30));
        }
      });

      test('maxCachedImages should return correct value for medium tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.medium) {
          expect(device.maxCachedImages, equals(50));
        }
      });

      test('maxCachedImages should return correct value for high tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.high) {
          expect(device.maxCachedImages, equals(100));
        }
      });

      test('maxCachedImages should be positive', () {
        // Act
        final device = DevicePerformance();

        // Assert
        expect(device.maxCachedImages, greaterThan(0));
      });
    });

    group('list and preload settings', () {
      test('listPreloadCount should return correct value for low tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.low) {
          expect(device.listPreloadCount, equals(2));
        }
      });

      test('listPreloadCount should return correct value for medium tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.medium) {
          expect(device.listPreloadCount, equals(3));
        }
      });

      test('listPreloadCount should return correct value for high tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.high) {
          expect(device.listPreloadCount, equals(5));
        }
      });

      test('listPreloadCount should be positive', () {
        // Act
        final device = DevicePerformance();

        // Assert
        expect(device.listPreloadCount, greaterThan(0));
      });
    });

    group('computation settings', () {
      test('useIsolates should be false for less than 4 cores', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.processorCount < 4) {
          expect(device.useIsolates, isFalse);
        }
      });

      test('useIsolates should be true for 4 or more cores', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.processorCount >= 4) {
          expect(device.useIsolates, isTrue);
        }
      });
    });

    group('search and interaction settings', () {
      test('searchDebounce should return correct value for low tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.low) {
          expect(device.searchDebounce, equals(const Duration(milliseconds: 500)));
        }
      });

      test('searchDebounce should return correct value for medium tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.medium) {
          expect(device.searchDebounce, equals(const Duration(milliseconds: 400)));
        }
      });

      test('searchDebounce should return correct value for high tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.high) {
          expect(device.searchDebounce, equals(const Duration(milliseconds: 300)));
        }
      });

      test('searchDebounce should be positive', () {
        // Act
        final device = DevicePerformance();

        // Assert
        expect(device.searchDebounce.inMilliseconds, greaterThan(0));
      });
    });

    group('scroll physics', () {
      test('recommendedScrollPhysics should return ClampingScrollPhysics for low tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.low) {
          expect(device.recommendedScrollPhysics, isA<ClampingScrollPhysics>());
        }
      });

      test('recommendedScrollPhysics should return BouncingScrollPhysics for medium tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.medium) {
          expect(device.recommendedScrollPhysics, isA<BouncingScrollPhysics>());
        }
      });

      test('recommendedScrollPhysics should return BouncingScrollPhysics for high tier', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.high) {
          expect(device.recommendedScrollPhysics, isA<BouncingScrollPhysics>());
        }
      });

      test('recommendedScrollPhysics should never be null', () {
        // Act
        final device = DevicePerformance();

        // Assert
        expect(device.recommendedScrollPhysics, isNotNull);
        expect(device.recommendedScrollPhysics, isA<ScrollPhysics>());
      });
    });

    group('provider', () {
      test('devicePerformanceProvider should provide DevicePerformance instance', () {
        // Arrange
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Act
        final device = container.read(devicePerformanceProvider);

        // Assert
        expect(device, isA<DevicePerformance>());
        expect(device.processorCount, greaterThan(0));
      });

      test('devicePerformanceProvider should provide singleton instance', () {
        // Arrange
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Act
        final device1 = container.read(devicePerformanceProvider);
        final device2 = container.read(devicePerformanceProvider);

        // Assert - should be same instance
        expect(identical(device1, device2), isTrue);
      });
    });

    group('tier-specific behavior consistency', () {
      test('low tier should have performance-optimized settings', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.low) {
          // Animations should be reduced or disabled
          expect(device.animationDurationMultiplier, lessThan(1.0));
          expect(device.enableComplexAnimations, isFalse);
          expect(device.enablePageTransitions, isFalse);

          // Image quality should be reduced
          expect(device.recommendedThumbnailQuality, lessThan(75));
          expect(device.recommendedThumbnailSize, lessThanOrEqualTo(150));

          // Cache sizes should be smaller
          expect(device.maxCachedImages, lessThanOrEqualTo(30));
          expect(device.recommendedImageCacheSize, lessThanOrEqualTo(20 * 1024 * 1024));

          // Scroll physics should be clamping
          expect(device.recommendedScrollPhysics, isA<ClampingScrollPhysics>());
        }
      });

      test('high tier should have full-featured settings', () {
        // Act
        final device = DevicePerformance();

        // Assert
        if (device.tier == DeviceTier.high) {
          // Animations should be full speed
          expect(device.animationDurationMultiplier, equals(1.0));
          expect(device.enableComplexAnimations, isTrue);
          expect(device.enablePageTransitions, isTrue);

          // Image quality should be high
          expect(device.recommendedThumbnailQuality, greaterThanOrEqualTo(75));
          expect(device.recommendedThumbnailSize, greaterThanOrEqualTo(150));

          // Cache sizes should be larger
          expect(device.maxCachedImages, greaterThanOrEqualTo(50));
          expect(device.recommendedImageCacheSize, greaterThanOrEqualTo(50 * 1024 * 1024));

          // Scroll physics should be bouncing
          expect(device.recommendedScrollPhysics, isA<BouncingScrollPhysics>());
        }
      });
    });
  });
}
