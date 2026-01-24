import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:aiscan/core/security/biometric_auth_service.dart';

import 'biometric_auth_service_test.mocks.dart';

@GenerateMocks([LocalAuthentication])
void main() {
  late MockLocalAuthentication mockLocalAuth;
  late BiometricAuthService service;

  setUp(() {
    mockLocalAuth = MockLocalAuthentication();
    service = BiometricAuthService(localAuth: mockLocalAuth);
  });

  group('BiometricAuthService', () {
    group('checkBiometricCapability', () {
      test('returns available when device has enrolled biometrics', () async {
        // Arrange
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockLocalAuth.getAvailableBiometrics())
            .thenAnswer((_) async => [BiometricType.fingerprint]);

        // Act
        final result = await service.checkBiometricCapability();

        // Assert
        expect(result, BiometricCapability.available);
      });

      test('returns notEnrolled when device has hardware but no enrollment',
          () async {
        // Arrange
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockLocalAuth.getAvailableBiometrics())
            .thenAnswer((_) async => []);

        // Act
        final result = await service.checkBiometricCapability();

        // Assert
        expect(result, BiometricCapability.notEnrolled);
      });

      test('returns notAvailable when device lacks hardware', () async {
        // Arrange
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => false);

        // Act
        final result = await service.checkBiometricCapability();

        // Assert
        expect(result, BiometricCapability.notAvailable);
      });

      test('returns notSupported when platform not supported', () async {
        // Arrange
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => false);

        // Act
        final result = await service.checkBiometricCapability();

        // Assert
        expect(result, BiometricCapability.notSupported);
      });

      test('caches capability result', () async {
        // Arrange
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockLocalAuth.getAvailableBiometrics())
            .thenAnswer((_) async => [BiometricType.face]);

        // Act
        await service.checkBiometricCapability();
        await service.checkBiometricCapability();

        // Assert - should only call once due to caching
        verify(mockLocalAuth.canCheckBiometrics).called(1);
        verify(mockLocalAuth.isDeviceSupported()).called(1);
        verify(mockLocalAuth.getAvailableBiometrics()).called(1);
      });

      test('throws BiometricAuthException on error', () async {
        // Arrange
        when(mockLocalAuth.canCheckBiometrics)
            .thenThrow(Exception('Platform error'));

        // Act & Assert
        expect(
          () => service.checkBiometricCapability(),
          throwsA(isA<BiometricAuthException>()),
        );
      });
    });

    group('authenticate', () {
      test('returns true on successful authentication', () async {
        // Arrange
        when(mockLocalAuth.authenticate(
          localizedReason: anyNamed('localizedReason'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => true);

        // Act
        final result = await service.authenticate(
          reason: 'Test authentication',
        );

        // Assert
        expect(result, isTrue);
      });

      test('returns false on user cancellation', () async {
        // Arrange
        when(mockLocalAuth.authenticate(
          localizedReason: anyNamed('localizedReason'),
          options: anyNamed('options'),
        )).thenThrow(Exception('User cancelled authentication'));

        // Act
        final result = await service.authenticate(
          reason: 'Test authentication',
        );

        // Assert
        expect(result, isFalse);
      });

      test('returns false on authentication failure', () async {
        // Arrange
        when(mockLocalAuth.authenticate(
          localizedReason: anyNamed('localizedReason'),
          options: anyNamed('options'),
        )).thenThrow(Exception('Authentication failed'));

        // Act
        final result = await service.authenticate(
          reason: 'Test authentication',
        );

        // Assert
        expect(result, isFalse);
      });

      test('throws BiometricAuthException on system error', () async {
        // Arrange
        when(mockLocalAuth.authenticate(
          localizedReason: anyNamed('localizedReason'),
          options: anyNamed('options'),
        )).thenThrow(Exception('System error occurred'));

        // Act & Assert
        expect(
          () => service.authenticate(reason: 'Test authentication'),
          throwsA(isA<BiometricAuthException>()),
        );
      });

      test('passes correct parameters to LocalAuthentication', () async {
        // Arrange
        when(mockLocalAuth.authenticate(
          localizedReason: anyNamed('localizedReason'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => true);

        // Act
        await service.authenticate(
          reason: 'Test reason',
          useErrorDialogs: false,
          stickyAuth: true,
          biometricOnly: true,
        );

        // Assert
        verify(mockLocalAuth.authenticate(
          localizedReason: 'Test reason',
          options: anyNamed('options'),
        )).called(1);
      });
    });

    group('getAvailableBiometrics', () {
      test('returns list of available biometric types', () async {
        // Arrange
        when(mockLocalAuth.getAvailableBiometrics()).thenAnswer(
          (_) async => [BiometricType.fingerprint, BiometricType.face],
        );

        // Act
        final result = await service.getAvailableBiometrics();

        // Assert
        expect(result, hasLength(2));
        expect(result, contains(BiometricAuthType.fingerprint));
        expect(result, contains(BiometricAuthType.face));
      });

      test('returns empty list when no biometrics', () async {
        // Arrange
        when(mockLocalAuth.getAvailableBiometrics())
            .thenAnswer((_) async => []);

        // Act
        final result = await service.getAvailableBiometrics();

        // Assert
        expect(result, isEmpty);
      });

      test('caches biometrics result', () async {
        // Arrange
        when(mockLocalAuth.getAvailableBiometrics())
            .thenAnswer((_) async => [BiometricType.fingerprint]);

        // Act
        await service.getAvailableBiometrics();
        await service.getAvailableBiometrics();

        // Assert - should only call once due to caching
        verify(mockLocalAuth.getAvailableBiometrics()).called(1);
      });

      test('maps BiometricType correctly', () async {
        // Arrange
        when(mockLocalAuth.getAvailableBiometrics()).thenAnswer(
          (_) async => [
            BiometricType.fingerprint,
            BiometricType.face,
            BiometricType.iris,
            BiometricType.weak,
            BiometricType.strong,
          ],
        );

        // Act
        final result = await service.getAvailableBiometrics();

        // Assert
        expect(result[0], BiometricAuthType.fingerprint);
        expect(result[1], BiometricAuthType.face);
        expect(result[2], BiometricAuthType.iris);
        expect(result[3], BiometricAuthType.weak);
        expect(result[4], BiometricAuthType.strong);
      });

      test('throws BiometricAuthException on error', () async {
        // Arrange
        when(mockLocalAuth.getAvailableBiometrics())
            .thenThrow(Exception('Platform error'));

        // Act & Assert
        expect(
          () => service.getAvailableBiometrics(),
          throwsA(isA<BiometricAuthException>()),
        );
      });
    });

    group('clearCache', () {
      test('clears cached capability and biometrics', () async {
        // Arrange
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockLocalAuth.getAvailableBiometrics())
            .thenAnswer((_) async => [BiometricType.fingerprint]);

        // First calls - should fetch from platform
        await service.checkBiometricCapability();
        await service.getAvailableBiometrics();

        // Verify initial calls (checkBiometricCapability also calls getAvailableBiometrics internally)
        verify(mockLocalAuth.canCheckBiometrics).called(1);
        verify(mockLocalAuth.getAvailableBiometrics()).called(
            2); // Called twice: once by checkBiometricCapability, once by getAvailableBiometrics

        // Reset mock to track new calls
        reset(mockLocalAuth);
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockLocalAuth.getAvailableBiometrics())
            .thenAnswer((_) async => [BiometricType.fingerprint]);

        // Second calls - should use cache (no new platform calls)
        await service.checkBiometricCapability();
        await service.getAvailableBiometrics();
        verifyNever(mockLocalAuth.canCheckBiometrics);
        verifyNever(mockLocalAuth.getAvailableBiometrics());

        // Act - clear cache
        service.clearCache();

        // Third calls - should fetch from platform again after cache clear
        await service.checkBiometricCapability();
        await service.getAvailableBiometrics();

        // Assert - verify platform was called again after clear
        verify(mockLocalAuth.canCheckBiometrics).called(1);
        verify(mockLocalAuth.getAvailableBiometrics())
            .called(2); // Called twice again after cache clear
      });
    });

    group('isBiometricAvailable', () {
      test('returns true when capability is available', () async {
        // Arrange
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockLocalAuth.getAvailableBiometrics())
            .thenAnswer((_) async => [BiometricType.fingerprint]);

        // Act
        final result = await service.isBiometricAvailable();

        // Assert
        expect(result, isTrue);
      });

      test('returns false when capability is not available', () async {
        // Arrange
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => false);

        // Act
        final result = await service.isBiometricAvailable();

        // Assert
        expect(result, isFalse);
      });
    });

    group('needsEnrollment', () {
      test('returns true when biometrics not enrolled', () async {
        // Arrange
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockLocalAuth.getAvailableBiometrics())
            .thenAnswer((_) async => []);

        // Act
        final result = await service.needsEnrollment();

        // Assert
        expect(result, isTrue);
      });

      test('returns false when biometrics are enrolled', () async {
        // Arrange
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockLocalAuth.getAvailableBiometrics())
            .thenAnswer((_) async => [BiometricType.fingerprint]);

        // Act
        final result = await service.needsEnrollment();

        // Assert
        expect(result, isFalse);
      });
    });

    group('stopAuthentication', () {
      test('stops ongoing authentication', () async {
        // Arrange
        when(mockLocalAuth.stopAuthentication()).thenAnswer((_) async => true);

        // Act
        await service.stopAuthentication();

        // Assert
        verify(mockLocalAuth.stopAuthentication()).called(1);
      });

      test('throws BiometricAuthException on error', () async {
        // Arrange
        when(mockLocalAuth.stopAuthentication())
            .thenThrow(Exception('Platform error'));

        // Act & Assert
        expect(
          () => service.stopAuthentication(),
          throwsA(isA<BiometricAuthException>()),
        );
      });
    });
  });

  group('BiometricAuthException', () {
    test('formats message without cause', () {
      // Arrange
      const exception = BiometricAuthException('Test error');

      // Act
      final message = exception.toString();

      // Assert
      expect(message, equals('BiometricAuthException: Test error'));
    });

    test('formats message with cause', () {
      // Arrange
      final cause = Exception('Root cause');
      final exception = BiometricAuthException('Test error', cause: cause);

      // Act
      final message = exception.toString();

      // Assert
      expect(
        message,
        equals(
          'BiometricAuthException: Test error (caused by: Exception: Root cause)',
        ),
      );
    });

    test('stores message and cause', () {
      // Arrange
      final cause = Exception('Root cause');
      const errorMessage = 'Test error';
      final exception = BiometricAuthException(errorMessage, cause: cause);

      // Assert
      expect(exception.message, equals(errorMessage));
      expect(exception.cause, equals(cause));
    });
  });

  group('Helper methods', () {
    test('getTypeDescription returns correct descriptions', () {
      expect(
        BiometricAuthService.getTypeDescription(BiometricAuthType.fingerprint),
        equals('Fingerprint'),
      );
      expect(
        BiometricAuthService.getTypeDescription(BiometricAuthType.face),
        equals('Face Recognition'),
      );
      expect(
        BiometricAuthService.getTypeDescription(BiometricAuthType.iris),
        equals('Iris Scanner'),
      );
      expect(
        BiometricAuthService.getTypeDescription(BiometricAuthType.weak),
        equals('Biometric (Weak)'),
      );
      expect(
        BiometricAuthService.getTypeDescription(BiometricAuthType.strong),
        equals('Biometric (Strong)'),
      );
    });

    test('getCapabilityDescription returns correct descriptions', () {
      expect(
        BiometricAuthService.getCapabilityDescription(
            BiometricCapability.unknown),
        equals('Unknown'),
      );
      expect(
        BiometricAuthService.getCapabilityDescription(
            BiometricCapability.available),
        equals('Biometric authentication is available'),
      );
      expect(
        BiometricAuthService.getCapabilityDescription(
            BiometricCapability.notEnrolled),
        contains('No biometrics enrolled'),
      );
      expect(
        BiometricAuthService.getCapabilityDescription(
            BiometricCapability.notAvailable),
        contains('does not support biometric authentication'),
      );
      expect(
        BiometricAuthService.getCapabilityDescription(
            BiometricCapability.notSupported),
        contains('not supported on this platform'),
      );
    });
  });
}
