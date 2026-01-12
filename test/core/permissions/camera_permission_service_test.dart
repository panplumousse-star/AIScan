import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:aiscan/core/permissions/camera_permission_service.dart';

import 'camera_permission_service_test.mocks.dart';

@GenerateMocks([FlutterSecureStorage])
void main() {
  late MockFlutterSecureStorage mockStorage;
  late CameraPermissionService permissionService;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    permissionService = CameraPermissionService(storage: mockStorage);

    // Default mock behavior - no stored permission
    when(mockStorage.read(key: anyNamed('key')))
        .thenAnswer((_) async => null);
    when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
        .thenAnswer((_) async {});
    when(mockStorage.delete(key: anyNamed('key')))
        .thenAnswer((_) async {});
  });

  group('CameraPermissionState', () {
    test('should have all expected enum values', () {
      expect(CameraPermissionState.values, hasLength(6));
      expect(CameraPermissionState.values, contains(CameraPermissionState.unknown));
      expect(CameraPermissionState.values, contains(CameraPermissionState.granted));
      expect(CameraPermissionState.values, contains(CameraPermissionState.sessionOnly));
      expect(CameraPermissionState.values, contains(CameraPermissionState.denied));
      expect(CameraPermissionState.values, contains(CameraPermissionState.restricted));
      expect(CameraPermissionState.values, contains(CameraPermissionState.permanentlyDenied));
    });
  });

  group('CameraPermissionException', () {
    test('should format message without cause', () {
      // Arrange
      const exception = CameraPermissionException('Permission denied');

      // Act
      final message = exception.toString();

      // Assert
      expect(message, equals('CameraPermissionException: Permission denied'));
    });

    test('should format message with cause', () {
      // Arrange
      final cause = Exception('Storage error');
      final exception = CameraPermissionException('Failed to store', cause: cause);

      // Act
      final message = exception.toString();

      // Assert
      expect(
        message,
        equals(
          'CameraPermissionException: Failed to store (caused by: Exception: Storage error)',
        ),
      );
    });

    test('should store message and cause', () {
      // Arrange
      final cause = Exception('Root cause');
      const errorMessage = 'Permission error';
      final exception = CameraPermissionException(errorMessage, cause: cause);

      // Assert
      expect(exception.message, equals(errorMessage));
      expect(exception.cause, equals(cause));
    });
  });

  group('CameraPermissionService', () {
    group('initialization', () {
      test('should create service with default storage', () {
        // Act
        final service = CameraPermissionService();

        // Assert
        expect(service, isNotNull);
        expect(service.currentState, isNull);
      });

      test('should create service with custom storage', () {
        // Act
        final service = CameraPermissionService(storage: mockStorage);

        // Assert
        expect(service, isNotNull);
      });

      test('should initialize with null cached state', () {
        // Assert
        expect(permissionService.currentState, isNull);
        expect(permissionService.needsPermission, isTrue);
      });
    });

    group('grantSessionPermission', () {
      test('should set session permission flag', () {
        // Act
        permissionService.grantSessionPermission();

        // Assert
        expect(permissionService.currentState, equals(CameraPermissionState.sessionOnly));
      });

      test('should update cached state to sessionOnly', () {
        // Act
        permissionService.grantSessionPermission();

        // Assert
        expect(permissionService.isAccessAllowed, isTrue);
        expect(permissionService.needsPermission, isFalse);
      });
    });

    group('grantPermanentPermission', () {
      test('should store granted value in secure storage', () async {
        // Act
        await permissionService.grantPermanentPermission();

        // Assert
        verify(mockStorage.write(
          key: 'aiscan_camera_permission',
          value: 'granted',
        )).called(1);
      });

      test('should update cached state to granted', () async {
        // Act
        await permissionService.grantPermanentPermission();

        // Assert
        expect(permissionService.currentState, equals(CameraPermissionState.granted));
        expect(permissionService.isAccessAllowed, isTrue);
      });

      test('should clear session permission when granting permanent', () async {
        // Arrange
        permissionService.grantSessionPermission();
        expect(permissionService.currentState, equals(CameraPermissionState.sessionOnly));

        // Act
        await permissionService.grantPermanentPermission();

        // Assert
        expect(permissionService.currentState, equals(CameraPermissionState.granted));
      });

      test('should throw CameraPermissionException on storage error', () async {
        // Arrange
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenThrow(Exception('Storage write error'));

        // Act & Assert
        expect(
          () => permissionService.grantPermanentPermission(),
          throwsA(isA<CameraPermissionException>()),
        );
      });
    });

    group('denyPermission', () {
      test('should store denied value in secure storage', () async {
        // Act
        await permissionService.denyPermission();

        // Assert
        verify(mockStorage.write(
          key: 'aiscan_camera_permission',
          value: 'denied',
        )).called(1);
      });

      test('should update cached state to denied', () async {
        // Act
        await permissionService.denyPermission();

        // Assert
        expect(permissionService.currentState, equals(CameraPermissionState.denied));
        expect(permissionService.isAccessAllowed, isFalse);
      });

      test('should clear session permission when denying', () async {
        // Arrange
        permissionService.grantSessionPermission();

        // Act
        await permissionService.denyPermission();

        // Assert
        expect(permissionService.currentState, equals(CameraPermissionState.denied));
      });

      test('should throw CameraPermissionException on storage error', () async {
        // Arrange
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenThrow(Exception('Storage write error'));

        // Act & Assert
        expect(
          () => permissionService.denyPermission(),
          throwsA(isA<CameraPermissionException>()),
        );
      });
    });

    group('clearSessionPermission', () {
      test('should clear session permission flag', () {
        // Arrange
        permissionService.grantSessionPermission();
        expect(permissionService.currentState, equals(CameraPermissionState.sessionOnly));

        // Act
        permissionService.clearSessionPermission();

        // Assert
        expect(permissionService.currentState, isNull);
        expect(permissionService.needsPermission, isTrue);
      });

      test('should invalidate cached state', () {
        // Arrange
        permissionService.grantSessionPermission();

        // Act
        permissionService.clearSessionPermission();

        // Assert
        expect(permissionService.currentState, isNull);
      });

      test('should not affect permanent permissions in storage', () async {
        // Arrange
        await permissionService.grantPermanentPermission();

        // Act
        permissionService.clearSessionPermission();

        // Assert - storage delete should NOT be called
        verifyNever(mockStorage.delete(key: anyNamed('key')));
      });
    });

    group('clearAllPermissions', () {
      test('should delete permission from storage', () async {
        // Act
        await permissionService.clearAllPermissions();

        // Assert
        verify(mockStorage.delete(key: 'aiscan_camera_permission')).called(1);
      });

      test('should reset cached state to unknown', () async {
        // Arrange
        await permissionService.grantPermanentPermission();

        // Act
        await permissionService.clearAllPermissions();

        // Assert
        expect(permissionService.currentState, equals(CameraPermissionState.unknown));
      });

      test('should clear session permission flag', () async {
        // Arrange
        permissionService.grantSessionPermission();

        // Act
        await permissionService.clearAllPermissions();

        // Assert
        expect(permissionService.currentState, equals(CameraPermissionState.unknown));
      });

      test('should throw CameraPermissionException on storage error', () async {
        // Arrange
        when(mockStorage.delete(key: anyNamed('key')))
            .thenThrow(Exception('Storage delete error'));

        // Act & Assert
        expect(
          () => permissionService.clearAllPermissions(),
          throwsA(isA<CameraPermissionException>()),
        );
      });
    });

    group('isAccessAllowed', () {
      test('should return true when state is granted', () async {
        // Arrange
        await permissionService.grantPermanentPermission();

        // Assert
        expect(permissionService.isAccessAllowed, isTrue);
      });

      test('should return true when state is sessionOnly', () {
        // Arrange
        permissionService.grantSessionPermission();

        // Assert
        expect(permissionService.isAccessAllowed, isTrue);
      });

      test('should return false when state is denied', () async {
        // Arrange
        await permissionService.denyPermission();

        // Assert
        expect(permissionService.isAccessAllowed, isFalse);
      });

      test('should return false when state is unknown', () async {
        // Arrange
        await permissionService.clearAllPermissions();

        // Assert
        expect(permissionService.isAccessAllowed, isFalse);
      });

      test('should return false when state is null', () {
        // Assert - initial state
        expect(permissionService.isAccessAllowed, isFalse);
      });
    });

    group('needsPermission', () {
      test('should return true when state is null', () {
        // Assert
        expect(permissionService.needsPermission, isTrue);
      });

      test('should return true when state is unknown', () async {
        // Arrange
        await permissionService.clearAllPermissions();

        // Assert
        expect(permissionService.needsPermission, isTrue);
      });

      test('should return false when state is granted', () async {
        // Arrange
        await permissionService.grantPermanentPermission();

        // Assert
        expect(permissionService.needsPermission, isFalse);
      });

      test('should return false when state is sessionOnly', () {
        // Arrange
        permissionService.grantSessionPermission();

        // Assert
        expect(permissionService.needsPermission, isFalse);
      });

      test('should return false when state is denied', () async {
        // Arrange
        await permissionService.denyPermission();

        // Assert
        expect(permissionService.needsPermission, isFalse);
      });
    });

    group('requiresSettingsChange', () {
      test('should return false when state is null', () {
        // Assert
        expect(permissionService.requiresSettingsChange, isFalse);
      });

      test('should return false when state is granted', () async {
        // Arrange
        await permissionService.grantPermanentPermission();

        // Assert
        expect(permissionService.requiresSettingsChange, isFalse);
      });

      test('should return false when state is sessionOnly', () {
        // Arrange
        permissionService.grantSessionPermission();

        // Assert
        expect(permissionService.requiresSettingsChange, isFalse);
      });

      test('should return false when state is denied', () async {
        // Arrange
        await permissionService.denyPermission();

        // Assert
        expect(permissionService.requiresSettingsChange, isFalse);
      });

      test('should return false when state is unknown', () async {
        // Arrange
        await permissionService.clearAllPermissions();

        // Assert
        expect(permissionService.requiresSettingsChange, isFalse);
      });
    });

    group('currentState', () {
      test('should return null initially', () {
        // Assert
        expect(permissionService.currentState, isNull);
      });

      test('should return granted after grantPermanentPermission', () async {
        // Act
        await permissionService.grantPermanentPermission();

        // Assert
        expect(permissionService.currentState, equals(CameraPermissionState.granted));
      });

      test('should return sessionOnly after grantSessionPermission', () {
        // Act
        permissionService.grantSessionPermission();

        // Assert
        expect(permissionService.currentState, equals(CameraPermissionState.sessionOnly));
      });

      test('should return denied after denyPermission', () async {
        // Act
        await permissionService.denyPermission();

        // Assert
        expect(permissionService.currentState, equals(CameraPermissionState.denied));
      });

      test('should return unknown after clearAllPermissions', () async {
        // Arrange
        await permissionService.grantPermanentPermission();

        // Act
        await permissionService.clearAllPermissions();

        // Assert
        expect(permissionService.currentState, equals(CameraPermissionState.unknown));
      });
    });

    group('state transitions', () {
      test('should transition from unknown to granted', () async {
        // Arrange
        await permissionService.clearAllPermissions();
        expect(permissionService.currentState, equals(CameraPermissionState.unknown));

        // Act
        await permissionService.grantPermanentPermission();

        // Assert
        expect(permissionService.currentState, equals(CameraPermissionState.granted));
      });

      test('should transition from unknown to sessionOnly', () async {
        // Arrange
        await permissionService.clearAllPermissions();

        // Act
        permissionService.grantSessionPermission();

        // Assert
        expect(permissionService.currentState, equals(CameraPermissionState.sessionOnly));
      });

      test('should transition from unknown to denied', () async {
        // Arrange
        await permissionService.clearAllPermissions();

        // Act
        await permissionService.denyPermission();

        // Assert
        expect(permissionService.currentState, equals(CameraPermissionState.denied));
      });

      test('should transition from sessionOnly to granted', () async {
        // Arrange
        permissionService.grantSessionPermission();

        // Act
        await permissionService.grantPermanentPermission();

        // Assert
        expect(permissionService.currentState, equals(CameraPermissionState.granted));
      });

      test('should transition from sessionOnly to denied', () async {
        // Arrange
        permissionService.grantSessionPermission();

        // Act
        await permissionService.denyPermission();

        // Assert
        expect(permissionService.currentState, equals(CameraPermissionState.denied));
      });

      test('should transition from granted to unknown on clearAll', () async {
        // Arrange
        await permissionService.grantPermanentPermission();

        // Act
        await permissionService.clearAllPermissions();

        // Assert
        expect(permissionService.currentState, equals(CameraPermissionState.unknown));
      });

      test('should transition from denied to granted', () async {
        // Arrange
        await permissionService.denyPermission();

        // Act
        await permissionService.grantPermanentPermission();

        // Assert
        expect(permissionService.currentState, equals(CameraPermissionState.granted));
      });
    });

    group('session permission behavior', () {
      test('session permission should not persist to storage', () {
        // Act
        permissionService.grantSessionPermission();

        // Assert - no storage write for session permission
        verifyNever(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')));
      });

      test('clearSessionPermission should not affect storage', () async {
        // Arrange
        permissionService.grantSessionPermission();

        // Act
        permissionService.clearSessionPermission();

        // Assert
        verifyNever(mockStorage.delete(key: anyNamed('key')));
      });

      test('multiple session grants should not accumulate storage calls', () {
        // Act
        permissionService.grantSessionPermission();
        permissionService.grantSessionPermission();
        permissionService.grantSessionPermission();

        // Assert
        verifyNever(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')));
      });
    });

    group('permanent permission behavior', () {
      test('permanent permission should persist to storage', () async {
        // Act
        await permissionService.grantPermanentPermission();

        // Assert
        verify(mockStorage.write(
          key: 'aiscan_camera_permission',
          value: 'granted',
        )).called(1);
      });

      test('denial should persist to storage', () async {
        // Act
        await permissionService.denyPermission();

        // Assert
        verify(mockStorage.write(
          key: 'aiscan_camera_permission',
          value: 'denied',
        )).called(1);
      });

      test('multiple permanent grants should make multiple storage calls', () async {
        // Act
        await permissionService.grantPermanentPermission();
        await permissionService.grantPermanentPermission();

        // Assert
        verify(mockStorage.write(
          key: 'aiscan_camera_permission',
          value: 'granted',
        )).called(2);
      });
    });

    group('error handling', () {
      test('should throw CameraPermissionException with cause on permanent grant error', () async {
        // Arrange
        final storageError = Exception('Encryption failed');
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenThrow(storageError);

        // Act & Assert
        expect(
          () => permissionService.grantPermanentPermission(),
          throwsA(
            isA<CameraPermissionException>().having(
              (e) => e.message,
              'message',
              contains('Failed to store permanent permission grant'),
            ),
          ),
        );
      });

      test('should throw CameraPermissionException with cause on deny error', () async {
        // Arrange
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenThrow(Exception('Write failed'));

        // Act & Assert
        expect(
          () => permissionService.denyPermission(),
          throwsA(
            isA<CameraPermissionException>().having(
              (e) => e.message,
              'message',
              contains('Failed to store permission denial'),
            ),
          ),
        );
      });

      test('should throw CameraPermissionException with cause on clear error', () async {
        // Arrange
        when(mockStorage.delete(key: anyNamed('key')))
            .thenThrow(Exception('Delete failed'));

        // Act & Assert
        expect(
          () => permissionService.clearAllPermissions(),
          throwsA(
            isA<CameraPermissionException>().having(
              (e) => e.message,
              'message',
              contains('Failed to clear permission state'),
            ),
          ),
        );
      });
    });
  });

  group('cameraPermissionServiceProvider', () {
    test('should provide CameraPermissionService', () {
      // Arrange
      final container = ProviderContainer();

      // Act
      final service = container.read(cameraPermissionServiceProvider);

      // Assert
      expect(service, isA<CameraPermissionService>());

      container.dispose();
    });

    test('should return same instance on multiple reads', () {
      // Arrange
      final container = ProviderContainer();

      // Act
      final service1 = container.read(cameraPermissionServiceProvider);
      final service2 = container.read(cameraPermissionServiceProvider);

      // Assert
      expect(identical(service1, service2), isTrue);

      container.dispose();
    });
  });
}
