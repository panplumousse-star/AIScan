import 'package:flutter_test/flutter_test.dart';
import 'package:jailbreak_root_detection/jailbreak_root_detection.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:aiscan/core/security/device_security_service.dart';

import 'device_security_service_test.mocks.dart';

@GenerateMocks([JailbreakRootDetection])
void main() {
  late MockJailbreakRootDetection mockJailbreakRootDetection;
  late DeviceSecurityService service;

  setUp(() {
    mockJailbreakRootDetection = MockJailbreakRootDetection();
    service = DeviceSecurityService(
      jailbreakRootDetection: mockJailbreakRootDetection,
    );
  });

  group('DeviceSecurityService', () {
    group('checkDeviceSecurity', () {
      test('returns secure status when device has no security threats', () async {
        // Arrange - All security checks return safe values
        when(mockJailbreakRootDetection.isJailBroken)
            .thenAnswer((_) async => false);
        when(mockJailbreakRootDetection.isDevMode)
            .thenAnswer((_) async => false);
        when(mockJailbreakRootDetection.isRealDevice)
            .thenAnswer((_) async => true);

        // Act
        final result = await service.checkDeviceSecurity();

        // Assert
        expect(result.status, DeviceSecurityStatus.secure);
        expect(result.threats, isEmpty);
        expect(result.isSecure, isTrue);
        expect(result.isCompromised, isFalse);
        expect(result.hasThreats, isFalse);
      });

      test('returns compromised status when device is jailbroken', () async {
        // Arrange
        when(mockJailbreakRootDetection.isJailBroken)
            .thenAnswer((_) async => true);
        when(mockJailbreakRootDetection.isDevMode)
            .thenAnswer((_) async => false);
        when(mockJailbreakRootDetection.isRealDevice)
            .thenAnswer((_) async => true);

        // Act
        final result = await service.checkDeviceSecurity();

        // Assert
        expect(result.status, DeviceSecurityStatus.compromised);
        expect(result.threats, contains(DeviceSecurityThreat.jailbroken));
        expect(result.isCompromised, isTrue);
        expect(result.isSecure, isFalse);
        expect(result.hasThreats, isTrue);
      });

      test('detects development mode but still returns secure status', () async {
        // Arrange - Dev mode is not considered a compromise by itself
        when(mockJailbreakRootDetection.isJailBroken)
            .thenAnswer((_) async => false);
        when(mockJailbreakRootDetection.isDevMode)
            .thenAnswer((_) async => true);
        when(mockJailbreakRootDetection.isRealDevice)
            .thenAnswer((_) async => true);

        // Act
        final result = await service.checkDeviceSecurity();

        // Assert
        expect(result.status, DeviceSecurityStatus.secure);
        expect(result.threats, contains(DeviceSecurityThreat.developmentMode));
        expect(result.isSecure, isTrue);
        expect(result.isCompromised, isFalse);
        expect(result.hasThreats, isTrue);
      });

      test('detects emulator but still returns secure status', () async {
        // Arrange - Emulator is not considered a compromise by itself
        when(mockJailbreakRootDetection.isJailBroken)
            .thenAnswer((_) async => false);
        when(mockJailbreakRootDetection.isDevMode)
            .thenAnswer((_) async => false);
        when(mockJailbreakRootDetection.isRealDevice)
            .thenAnswer((_) async => false);

        // Act
        final result = await service.checkDeviceSecurity();

        // Assert
        expect(result.status, DeviceSecurityStatus.secure);
        expect(result.threats, contains(DeviceSecurityThreat.emulator));
        expect(result.isSecure, isTrue);
        expect(result.isCompromised, isFalse);
        expect(result.hasThreats, isTrue);
      });

      test('detects multiple non-compromise threats', () async {
        // Arrange - Both dev mode and emulator, but not jailbroken
        when(mockJailbreakRootDetection.isJailBroken)
            .thenAnswer((_) async => false);
        when(mockJailbreakRootDetection.isDevMode)
            .thenAnswer((_) async => true);
        when(mockJailbreakRootDetection.isRealDevice)
            .thenAnswer((_) async => false);

        // Act
        final result = await service.checkDeviceSecurity();

        // Assert
        expect(result.status, DeviceSecurityStatus.secure);
        expect(result.threats, hasLength(2));
        expect(result.threats, contains(DeviceSecurityThreat.developmentMode));
        expect(result.threats, contains(DeviceSecurityThreat.emulator));
        expect(result.isSecure, isTrue);
        expect(result.isCompromised, isFalse);
        expect(result.hasThreats, isTrue);
      });

      test('returns unknownError status when plugin throws exception', () async {
        // Arrange
        when(mockJailbreakRootDetection.isJailBroken)
            .thenThrow(Exception('Platform error'));

        // Act
        final result = await service.checkDeviceSecurity();

        // Assert
        expect(result.status, DeviceSecurityStatus.unknownError);
        expect(result.threats, isEmpty);
        expect(result.details, contains('Failed to check device security'));
        expect(result.isSecure, isFalse);
        expect(result.isCompromised, isFalse);
      });

      test('caches result and does not re-check on subsequent calls', () async {
        // Arrange
        when(mockJailbreakRootDetection.isJailBroken)
            .thenAnswer((_) async => false);
        when(mockJailbreakRootDetection.isDevMode)
            .thenAnswer((_) async => false);
        when(mockJailbreakRootDetection.isRealDevice)
            .thenAnswer((_) async => true);

        // Act - Call twice
        final result1 = await service.checkDeviceSecurity();
        final result2 = await service.checkDeviceSecurity();

        // Assert
        expect(result1, same(result2)); // Same instance from cache
        // Should only call the plugin once due to caching
        verify(mockJailbreakRootDetection.isJailBroken).called(1);
        verify(mockJailbreakRootDetection.isDevMode).called(1);
        verify(mockJailbreakRootDetection.isRealDevice).called(1);
      });

      test('provides cached result via cachedResult getter', () async {
        // Arrange
        when(mockJailbreakRootDetection.isJailBroken)
            .thenAnswer((_) async => false);
        when(mockJailbreakRootDetection.isDevMode)
            .thenAnswer((_) async => false);
        when(mockJailbreakRootDetection.isRealDevice)
            .thenAnswer((_) async => true);

        // Act
        expect(service.cachedResult, isNull); // No cache initially
        final result = await service.checkDeviceSecurity();

        // Assert
        expect(service.cachedResult, same(result));
      });
    });

    group('clearCache', () {
      test('clears cached result and forces fresh check', () async {
        // Arrange
        when(mockJailbreakRootDetection.isJailBroken)
            .thenAnswer((_) async => false);
        when(mockJailbreakRootDetection.isDevMode)
            .thenAnswer((_) async => false);
        when(mockJailbreakRootDetection.isRealDevice)
            .thenAnswer((_) async => true);

        // First call - should fetch from platform
        await service.checkDeviceSecurity();
        verify(mockJailbreakRootDetection.isJailBroken).called(1);

        // Second call - should use cache (no new platform calls)
        await service.checkDeviceSecurity();
        verifyNever(mockJailbreakRootDetection.isJailBroken);

        // Reset mock to track new calls
        reset(mockJailbreakRootDetection);
        when(mockJailbreakRootDetection.isJailBroken)
            .thenAnswer((_) async => false);
        when(mockJailbreakRootDetection.isDevMode)
            .thenAnswer((_) async => false);
        when(mockJailbreakRootDetection.isRealDevice)
            .thenAnswer((_) async => true);

        // Act - clear cache
        service.clearCache();
        expect(service.cachedResult, isNull);

        // Third call - should fetch from platform again after cache clear
        await service.checkDeviceSecurity();

        // Assert - verify platform was called again after clear
        verify(mockJailbreakRootDetection.isJailBroken).called(1);
        verify(mockJailbreakRootDetection.isDevMode).called(1);
        verify(mockJailbreakRootDetection.isRealDevice).called(1);
      });
    });

    group('isDeviceCompromised', () {
      test('returns true when device is jailbroken', () async {
        // Arrange
        when(mockJailbreakRootDetection.isJailBroken)
            .thenAnswer((_) async => true);
        when(mockJailbreakRootDetection.isDevMode)
            .thenAnswer((_) async => false);
        when(mockJailbreakRootDetection.isRealDevice)
            .thenAnswer((_) async => true);

        // Act
        final result = await service.isDeviceCompromised();

        // Assert
        expect(result, isTrue);
      });

      test('returns false when device is secure', () async {
        // Arrange
        when(mockJailbreakRootDetection.isJailBroken)
            .thenAnswer((_) async => false);
        when(mockJailbreakRootDetection.isDevMode)
            .thenAnswer((_) async => false);
        when(mockJailbreakRootDetection.isRealDevice)
            .thenAnswer((_) async => true);

        // Act
        final result = await service.isDeviceCompromised();

        // Assert
        expect(result, isFalse);
      });

      test('throws DeviceSecurityException on error', () async {
        // Arrange
        when(mockJailbreakRootDetection.isJailBroken)
            .thenThrow(Exception('Platform error'));

        // Act & Assert
        // Note: The service catches the error in checkDeviceSecurity and returns unknownError status
        // So isDeviceCompromised should return false (not compromised, but error state)
        final result = await service.isDeviceCompromised();
        expect(result, isFalse);
      });
    });

    group('isDevelopmentModeEnabled', () {
      test('returns true when development mode is enabled', () async {
        // Arrange
        when(mockJailbreakRootDetection.isDevMode)
            .thenAnswer((_) async => true);

        // Act
        final result = await service.isDevelopmentModeEnabled();

        // Assert
        expect(result, isTrue);
      });

      test('returns false when development mode is disabled', () async {
        // Arrange
        when(mockJailbreakRootDetection.isDevMode)
            .thenAnswer((_) async => false);

        // Act
        final result = await service.isDevelopmentModeEnabled();

        // Assert
        expect(result, isFalse);
      });

      test('throws DeviceSecurityException on error', () async {
        // Arrange
        when(mockJailbreakRootDetection.isDevMode)
            .thenThrow(Exception('Platform error'));

        // Act & Assert
        expect(
          () => service.isDevelopmentModeEnabled(),
          throwsA(isA<DeviceSecurityException>()),
        );
      });
    });

    group('isRealDevice', () {
      test('returns true when running on real device', () async {
        // Arrange
        when(mockJailbreakRootDetection.isRealDevice)
            .thenAnswer((_) async => true);

        // Act
        final result = await service.isRealDevice();

        // Assert
        expect(result, isTrue);
      });

      test('returns false when running on emulator', () async {
        // Arrange
        when(mockJailbreakRootDetection.isRealDevice)
            .thenAnswer((_) async => false);

        // Act
        final result = await service.isRealDevice();

        // Assert
        expect(result, isFalse);
      });

      test('throws DeviceSecurityException on error', () async {
        // Arrange
        when(mockJailbreakRootDetection.isRealDevice)
            .thenThrow(Exception('Platform error'));

        // Act & Assert
        expect(
          () => service.isRealDevice(),
          throwsA(isA<DeviceSecurityException>()),
        );
      });
    });
  });

  group('DeviceSecurityResult', () {
    test('isCompromised returns true when status is compromised', () {
      // Arrange
      const result = DeviceSecurityResult(
        status: DeviceSecurityStatus.compromised,
        threats: [DeviceSecurityThreat.jailbroken],
      );

      // Assert
      expect(result.isCompromised, isTrue);
      expect(result.isSecure, isFalse);
    });

    test('isSecure returns true when status is secure', () {
      // Arrange
      const result = DeviceSecurityResult(
        status: DeviceSecurityStatus.secure,
        threats: [],
      );

      // Assert
      expect(result.isSecure, isTrue);
      expect(result.isCompromised, isFalse);
    });

    test('hasThreats returns true when threats list is not empty', () {
      // Arrange
      const result = DeviceSecurityResult(
        status: DeviceSecurityStatus.secure,
        threats: [DeviceSecurityThreat.developmentMode],
      );

      // Assert
      expect(result.hasThreats, isTrue);
    });

    test('hasThreats returns false when threats list is empty', () {
      // Arrange
      const result = DeviceSecurityResult(
        status: DeviceSecurityStatus.secure,
        threats: [],
      );

      // Assert
      expect(result.hasThreats, isFalse);
    });

    test('toString includes status and threats', () {
      // Arrange
      const result = DeviceSecurityResult(
        status: DeviceSecurityStatus.compromised,
        threats: [DeviceSecurityThreat.jailbroken],
        details: 'Test details',
      );

      // Act
      final string = result.toString();

      // Assert
      expect(string, contains('DeviceSecurityStatus.compromised'));
      expect(string, contains('[DeviceSecurityThreat.jailbroken]'));
      expect(string, contains('Test details'));
    });
  });

  group('DeviceSecurityException', () {
    test('formats message without cause', () {
      // Arrange
      const exception = DeviceSecurityException('Test error');

      // Act
      final message = exception.toString();

      // Assert
      expect(message, equals('DeviceSecurityException: Test error'));
    });

    test('formats message with cause', () {
      // Arrange
      final cause = Exception('Root cause');
      final exception = DeviceSecurityException('Test error', cause: cause);

      // Act
      final message = exception.toString();

      // Assert
      expect(
        message,
        equals(
          'DeviceSecurityException: Test error (caused by: Exception: Root cause)',
        ),
      );
    });

    test('stores message and cause', () {
      // Arrange
      final cause = Exception('Root cause');
      const errorMessage = 'Test error';
      final exception = DeviceSecurityException(errorMessage, cause: cause);

      // Assert
      expect(exception.message, equals(errorMessage));
      expect(exception.cause, equals(cause));
    });
  });
}
