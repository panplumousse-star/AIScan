import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:aiscan/core/security/biometric_auth_service.dart';
import 'package:aiscan/core/security/secure_storage_service.dart';
import 'package:aiscan/features/app_lock/domain/app_lock_service.dart';

import 'app_lock_service_test.mocks.dart';

@GenerateMocks([SecureStorageService, BiometricAuthService])
void main() {
  late MockSecureStorageService mockSecureStorage;
  late MockBiometricAuthService mockBiometricAuth;
  late AppLockService service;

  setUp(() {
    mockSecureStorage = MockSecureStorageService();
    mockBiometricAuth = MockBiometricAuthService();
    service = AppLockService(
      secureStorage: mockSecureStorage,
      biometricAuth: mockBiometricAuth,
    );
  });

  group('AppLockService', () {
    group('initialize', () {
      test('loads enabled state from secure storage', () async {
        // Arrange
        when(mockSecureStorage.getUserData('aiscan_app_lock_enabled'))
            .thenAnswer((_) async => 'true');
        when(mockSecureStorage.getUserData('aiscan_app_lock_timeout_seconds'))
            .thenAnswer((_) async => '60');

        // Act
        await service.initialize();

        // Assert
        expect(service.isEnabled(), isTrue);
        expect(service.getTimeout(), AppLockTimeout.oneMinute);
      });

      test('loads timeout setting from secure storage', () async {
        // Arrange
        when(mockSecureStorage.getUserData('aiscan_app_lock_enabled'))
            .thenAnswer((_) async => 'false');
        when(mockSecureStorage.getUserData('aiscan_app_lock_timeout_seconds'))
            .thenAnswer((_) async => '300');

        // Act
        await service.initialize();

        // Assert
        expect(service.getTimeout(), AppLockTimeout.fiveMinutes);
      });

      test('defaults to disabled and immediate timeout', () async {
        // Arrange
        when(mockSecureStorage.getUserData(any)).thenAnswer((_) async => null);

        // Act
        await service.initialize();

        // Assert
        expect(service.isEnabled(), isFalse);
        expect(service.getTimeout(), AppLockTimeout.immediate);
      });

      test('throws AppLockException on storage error', () async {
        // Arrange
        when(mockSecureStorage.getUserData(any))
            .thenThrow(SecureStorageException('Storage error'));

        // Act & Assert
        expect(
          () => service.initialize(),
          throwsA(isA<AppLockException>()),
        );
      });

      test('does not reinitialize if already initialized', () async {
        // Arrange
        when(mockSecureStorage.getUserData(any)).thenAnswer((_) async => null);

        // Act
        await service.initialize();
        await service.initialize();

        // Assert - should only call storage once
        verify(mockSecureStorage.getUserData('aiscan_app_lock_enabled'))
            .called(1);
      });
    });

    group('setEnabled', () {
      setUp(() async {
        when(mockSecureStorage.getUserData(any)).thenAnswer((_) async => null);
        when(mockSecureStorage.storeUserData(any, any))
            .thenAnswer((_) async => {});
        await service.initialize();
      });

      test('enables lock when biometrics available', () async {
        // Arrange
        when(mockBiometricAuth.isBiometricAvailable())
            .thenAnswer((_) async => true);

        // Act
        await service.setEnabled(true);

        // Assert
        expect(service.isEnabled(), isTrue);
        verify(mockSecureStorage.storeUserData(
          'aiscan_app_lock_enabled',
          'true',
        )).called(1);
      });

      test('throws exception when enabling without biometrics', () async {
        // Arrange
        when(mockBiometricAuth.isBiometricAvailable())
            .thenAnswer((_) async => false);

        // Act & Assert
        expect(
          () => service.setEnabled(true),
          throwsA(isA<AppLockException>()),
        );
      });

      test('disables lock and clears auth state', () async {
        // Arrange
        when(mockBiometricAuth.isBiometricAvailable())
            .thenAnswer((_) async => true);
        await service.setEnabled(true);
        service.recordSuccessfulAuth();

        // Act
        await service.setEnabled(false);

        // Assert
        expect(service.isEnabled(), isFalse);
        expect(
          await service.shouldShowLockScreen(),
          isFalse,
        ); // Auth state cleared
      });

      test('persists enabled state to secure storage', () async {
        // Arrange
        when(mockBiometricAuth.isBiometricAvailable())
            .thenAnswer((_) async => true);

        // Act
        await service.setEnabled(true);

        // Assert
        verify(mockSecureStorage.storeUserData(
          'aiscan_app_lock_enabled',
          'true',
        )).called(1);
      });

      test('throws AppLockException if not initialized', () {
        // Arrange
        final uninitializedService = AppLockService(
          secureStorage: mockSecureStorage,
          biometricAuth: mockBiometricAuth,
        );

        // Act & Assert
        expect(
          () => uninitializedService.setEnabled(true),
          throwsA(isA<AppLockException>()),
        );
      });

      test('throws AppLockException on storage error', () async {
        // Arrange
        when(mockBiometricAuth.isBiometricAvailable())
            .thenAnswer((_) async => true);
        when(mockSecureStorage.storeUserData(any, any))
            .thenThrow(SecureStorageException('Storage error'));

        // Act & Assert
        expect(
          () => service.setEnabled(true),
          throwsA(isA<AppLockException>()),
        );
      });
    });

    group('setTimeout', () {
      setUp(() async {
        when(mockSecureStorage.getUserData(any)).thenAnswer((_) async => null);
        when(mockSecureStorage.storeUserData(any, any))
            .thenAnswer((_) async => {});
        await service.initialize();
      });

      test('updates timeout setting', () async {
        // Act
        await service.setTimeout(AppLockTimeout.fiveMinutes);

        // Assert
        expect(service.getTimeout(), AppLockTimeout.fiveMinutes);
      });

      test('persists timeout to secure storage', () async {
        // Act
        await service.setTimeout(AppLockTimeout.thirtyMinutes);

        // Assert
        verify(mockSecureStorage.storeUserData(
          'aiscan_app_lock_timeout_seconds',
          '1800',
        )).called(1);
      });

      test('throws AppLockException if not initialized', () {
        // Arrange
        final uninitializedService = AppLockService(
          secureStorage: mockSecureStorage,
          biometricAuth: mockBiometricAuth,
        );

        // Act & Assert
        expect(
          () => uninitializedService.setTimeout(AppLockTimeout.oneMinute),
          throwsA(isA<AppLockException>()),
        );
      });

      test('throws AppLockException on storage error', () async {
        // Arrange
        when(mockSecureStorage.storeUserData(any, any))
            .thenThrow(SecureStorageException('Storage error'));

        // Act & Assert
        expect(
          () => service.setTimeout(AppLockTimeout.oneMinute),
          throwsA(isA<AppLockException>()),
        );
      });
    });

    group('shouldShowLockScreen', () {
      setUp(() async {
        when(mockSecureStorage.getUserData(any)).thenAnswer((_) async => null);
        when(mockSecureStorage.storeUserData(any, any))
            .thenAnswer((_) async => {});
        when(mockBiometricAuth.isBiometricAvailable())
            .thenAnswer((_) async => true);
        await service.initialize();
      });

      test('returns false when lock disabled', () async {
        // Arrange
        await service.setEnabled(false);

        // Act
        final result = await service.shouldShowLockScreen();

        // Assert
        expect(result, isFalse);
      });

      test('returns true when never authenticated', () async {
        // Arrange
        await service.setEnabled(true);

        // Act
        final result = await service.shouldShowLockScreen();

        // Assert
        expect(result, isTrue);
      });

      test('returns false when within timeout window', () async {
        // Arrange
        await service.setEnabled(true);
        await service.setTimeout(AppLockTimeout.fiveMinutes);
        service.recordSuccessfulAuth();

        // Act - immediately after auth
        final result = await service.shouldShowLockScreen();

        // Assert
        expect(result, isFalse);
      });

      test('returns true when timeout elapsed', () async {
        // Arrange
        await service.setEnabled(true);
        await service.setTimeout(AppLockTimeout.immediate);
        service.recordSuccessfulAuth();

        // Wait a bit to ensure timeout elapsed
        await Future.delayed(const Duration(milliseconds: 10));

        // Act
        final result = await service.shouldShowLockScreen();

        // Assert
        expect(result, isTrue);
      });

      test('correctly calculates immediate timeout', () async {
        // Arrange
        await service.setEnabled(true);
        await service.setTimeout(AppLockTimeout.immediate);
        service.recordSuccessfulAuth();

        // Act - even immediately, should require reauth
        final result = await service.shouldShowLockScreen();

        // Assert
        expect(result, isTrue);
      });

      test('correctly calculates 1 minute timeout', () async {
        // Arrange
        await service.setEnabled(true);
        await service.setTimeout(AppLockTimeout.oneMinute);
        service.recordSuccessfulAuth();

        // Act - within 1 minute
        final result = await service.shouldShowLockScreen();

        // Assert
        expect(result, isFalse);
      });

      test('correctly calculates 5 minute timeout', () async {
        // Arrange
        await service.setEnabled(true);
        await service.setTimeout(AppLockTimeout.fiveMinutes);
        service.recordSuccessfulAuth();

        // Act - within 5 minutes
        final result = await service.shouldShowLockScreen();

        // Assert
        expect(result, isFalse);
      });

      test('correctly calculates 30 minute timeout', () async {
        // Arrange
        await service.setEnabled(true);
        await service.setTimeout(AppLockTimeout.thirtyMinutes);
        service.recordSuccessfulAuth();

        // Act - within 30 minutes
        final result = await service.shouldShowLockScreen();

        // Assert
        expect(result, isFalse);
      });
    });

    group('recordSuccessfulAuth', () {
      setUp(() async {
        when(mockSecureStorage.getUserData(any)).thenAnswer((_) async => null);
        when(mockSecureStorage.storeUserData(any, any))
            .thenAnswer((_) async => {});
        when(mockBiometricAuth.isBiometricAvailable())
            .thenAnswer((_) async => true);
        await service.initialize();
        await service.setEnabled(true);
      });

      test('updates last auth timestamp', () async {
        // Arrange
        await service.setTimeout(AppLockTimeout.immediate);
        expect(await service.shouldShowLockScreen(), isTrue);

        // Act
        service.recordSuccessfulAuth();

        // Assert - immediate timeout should trigger even after recording auth
        expect(await service.shouldShowLockScreen(), isTrue);
      });

      test('affects shouldShowLockScreen result', () async {
        // Arrange
        await service.setTimeout(AppLockTimeout.fiveMinutes);
        expect(await service.shouldShowLockScreen(), isTrue);

        // Act
        service.recordSuccessfulAuth();

        // Assert
        expect(await service.shouldShowLockScreen(), isFalse);
      });

      test('throws AppLockException if not initialized', () {
        // Arrange
        final uninitializedService = AppLockService(
          secureStorage: mockSecureStorage,
          biometricAuth: mockBiometricAuth,
        );

        // Act & Assert
        expect(
          () => uninitializedService.recordSuccessfulAuth(),
          throwsA(isA<AppLockException>()),
        );
      });
    });

    group('clearAuthState', () {
      setUp(() async {
        when(mockSecureStorage.getUserData(any)).thenAnswer((_) async => null);
        when(mockSecureStorage.storeUserData(any, any))
            .thenAnswer((_) async => {});
        when(mockBiometricAuth.isBiometricAvailable())
            .thenAnswer((_) async => true);
        await service.initialize();
        await service.setEnabled(true);
      });

      test('clears last auth timestamp', () {
        // Arrange
        service.recordSuccessfulAuth();

        // Act
        service.clearAuthState();

        // Assert - should require lock screen
        expect(service.shouldShowLockScreen(), completion(isTrue));
      });

      test('forces lock screen on next check', () async {
        // Arrange
        await service.setTimeout(AppLockTimeout.thirtyMinutes);
        service.recordSuccessfulAuth();
        expect(await service.shouldShowLockScreen(), isFalse);

        // Act
        service.clearAuthState();

        // Assert
        expect(await service.shouldShowLockScreen(), isTrue);
      });
    });

    group('isBiometricAvailable', () {
      test('delegates to BiometricAuthService', () async {
        // Arrange
        when(mockBiometricAuth.isBiometricAvailable())
            .thenAnswer((_) async => true);

        // Act
        final result = await service.isBiometricAvailable();

        // Assert
        expect(result, isTrue);
        verify(mockBiometricAuth.isBiometricAvailable()).called(1);
      });
    });

    group('getBiometricCapability', () {
      test('delegates to BiometricAuthService', () async {
        // Arrange
        when(mockBiometricAuth.checkBiometricCapability())
            .thenAnswer((_) async => BiometricCapability.available);

        // Act
        final result = await service.getBiometricCapability();

        // Assert
        expect(result, BiometricCapability.available);
        verify(mockBiometricAuth.checkBiometricCapability()).called(1);
      });
    });

    group('authenticateUser', () {
      test('delegates to BiometricAuthService with app-specific reason',
          () async {
        // Arrange
        when(mockBiometricAuth.authenticate(reason: anyNamed('reason')))
            .thenAnswer((_) async => true);

        // Act
        final result = await service.authenticateUser();

        // Assert
        expect(result, isTrue);
        verify(mockBiometricAuth.authenticate(
          reason: 'Verify your identity to access Scanaï',
        )).called(1);
      });
    });

    group('reset', () {
      test('resets service to initial state', () async {
        // Arrange
        when(mockSecureStorage.getUserData(any)).thenAnswer((_) async => null);
        when(mockSecureStorage.storeUserData(any, any))
            .thenAnswer((_) async => {});
        when(mockBiometricAuth.isBiometricAvailable())
            .thenAnswer((_) async => true);

        await service.initialize();
        await service.setEnabled(true);
        await service.setTimeout(AppLockTimeout.fiveMinutes);
        service.recordSuccessfulAuth();

        // Act
        service.reset();

        // Assert - should throw because not initialized
        expect(
          () => service.isEnabled(),
          throwsA(isA<AppLockException>()),
        );
      });
    });
  });

  group('AppLockException', () {
    test('formats message without cause', () {
      // Arrange
      const exception = AppLockException('Test error');

      // Act
      final message = exception.toString();

      // Assert
      expect(message, equals('AppLockException: Test error'));
    });

    test('formats message with cause', () {
      // Arrange
      final cause = Exception('Root cause');
      final exception = AppLockException('Test error', cause: cause);

      // Act
      final message = exception.toString();

      // Assert
      expect(
        message,
        equals('AppLockException: Test error (caused by: Exception: Root cause)'),
      );
    });

    test('stores message and cause', () {
      // Arrange
      final cause = Exception('Root cause');
      const errorMessage = 'Test error';
      final exception = AppLockException(errorMessage, cause: cause);

      // Assert
      expect(exception.message, equals(errorMessage));
      expect(exception.cause, equals(cause));
    });
  });

  group('AppLockTimeout', () {
    test('returns correct seconds', () {
      expect(AppLockTimeout.immediate.seconds, equals(0));
      expect(AppLockTimeout.oneMinute.seconds, equals(60));
      expect(AppLockTimeout.fiveMinutes.seconds, equals(300));
      expect(AppLockTimeout.thirtyMinutes.seconds, equals(1800));
    });

    test('returns correct labels', () {
      expect(AppLockTimeout.immediate.label, equals('Immediate'));
      expect(AppLockTimeout.oneMinute.label, equals('1 minute'));
      expect(AppLockTimeout.fiveMinutes.label, equals('5 minutes'));
      expect(AppLockTimeout.thirtyMinutes.label, equals('30 minutes'));
    });

    test('fromSeconds returns correct timeout', () {
      expect(AppLockTimeout.fromSeconds(0), AppLockTimeout.immediate);
      expect(AppLockTimeout.fromSeconds(-10), AppLockTimeout.immediate);
      expect(AppLockTimeout.fromSeconds(30), AppLockTimeout.oneMinute);
      expect(AppLockTimeout.fromSeconds(60), AppLockTimeout.oneMinute);
      expect(AppLockTimeout.fromSeconds(120), AppLockTimeout.fiveMinutes);
      expect(AppLockTimeout.fromSeconds(300), AppLockTimeout.fiveMinutes);
      expect(AppLockTimeout.fromSeconds(600), AppLockTimeout.thirtyMinutes);
      expect(AppLockTimeout.fromSeconds(1800), AppLockTimeout.thirtyMinutes);
      expect(AppLockTimeout.fromSeconds(3600), AppLockTimeout.thirtyMinutes);
    });
  });
}
