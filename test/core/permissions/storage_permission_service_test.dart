import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:aiscan/core/permissions/storage_permission_service.dart';

/// A fake permission implementation for testing.
///
/// Uses direct status values to avoid complex mocking.
class FakePermission implements Permission {
  FakePermission({
    PermissionStatus initialStatus = PermissionStatus.denied,
    bool shouldShowRationale = false,
  })  : _status = initialStatus,
        _shouldShowRationale = shouldShowRationale;

  PermissionStatus _status;
  bool _shouldShowRationale;

  /// Set the status that will be returned by [status] and [request].
  void setStatus(PermissionStatus status) => _status = status;

  /// Set the rationale flag.
  void setShouldShowRationale(bool value) => _shouldShowRationale = value;

  @override
  Future<PermissionStatus> get status async => _status;

  @override
  Future<PermissionStatus> request() async => _status;

  @override
  Future<bool> get shouldShowRequestRationale async => _shouldShowRationale;

  // Required Permission interface methods (unused in tests)
  @override
  int get value => 0;

  @override
  Future<bool> get isGranted async => _status == PermissionStatus.granted;

  @override
  Future<bool> get isDenied async => _status == PermissionStatus.denied;

  @override
  Future<bool> get isPermanentlyDenied async =>
      _status == PermissionStatus.permanentlyDenied;

  @override
  Future<bool> get isRestricted async => _status == PermissionStatus.restricted;

  @override
  Future<bool> get isLimited async => _status == PermissionStatus.limited;

  @override
  Future<bool> get isProvisional async =>
      _status == PermissionStatus.provisional;

  @override
  Future<PermissionStatus> onDeniedCallback() async => _status;

  @override
  Future<PermissionStatus> onGrantedCallback() async => _status;

  @override
  Future<PermissionStatus> onPermanentlyDeniedCallback() async => _status;

  @override
  Future<PermissionStatus> onRestrictedCallback() async => _status;

  @override
  Future<PermissionStatus> onLimitedCallback() async => _status;

  @override
  Future<PermissionStatus> onProvisionalCallback() async => _status;

  @override
  Future<ServiceStatus> get serviceStatus async => ServiceStatus.enabled;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StoragePermissionState', () {
    test('should have all expected values', () {
      expect(StoragePermissionState.values, hasLength(6));
      expect(StoragePermissionState.values,
          contains(StoragePermissionState.unknown));
      expect(StoragePermissionState.values,
          contains(StoragePermissionState.granted));
      expect(StoragePermissionState.values,
          contains(StoragePermissionState.sessionOnly));
      expect(StoragePermissionState.values,
          contains(StoragePermissionState.denied));
      expect(StoragePermissionState.values,
          contains(StoragePermissionState.restricted));
      expect(StoragePermissionState.values,
          contains(StoragePermissionState.permanentlyDenied));
    });
  });

  group('StoragePermissionException', () {
    test('should format message without cause', () {
      // Arrange
      const exception = StoragePermissionException('Permission denied');

      // Act
      final message = exception.toString();

      // Assert
      expect(message, equals('PermissionException: Permission denied'));
    });

    test('should format message with cause', () {
      // Arrange
      final cause = Exception('Platform error');
      final exception =
          StoragePermissionException('Permission failed', cause: cause);

      // Act
      final message = exception.toString();

      // Assert
      expect(
        message,
        equals(
          'PermissionException: Permission failed (caused by: Exception: Platform error)',
        ),
      );
    });

    test('should store message and cause', () {
      // Arrange
      final cause = Exception('Root cause');
      const errorMessage = 'Storage permission error';
      final exception = StoragePermissionException(errorMessage, cause: cause);

      // Assert
      expect(exception.message, equals(errorMessage));
      expect(exception.cause, equals(cause));
    });

    test('should handle null cause', () {
      // Arrange
      const exception = StoragePermissionException('Simple error');

      // Assert
      expect(exception.cause, isNull);
      expect(exception.toString(), equals('PermissionException: Simple error'));
    });
  });

  group('StoragePermissionService', () {
    late FakePermission fakePermission;
    late StoragePermissionService service;

    setUp(() {
      fakePermission = FakePermission();
      service = StoragePermissionService(permission: fakePermission);
    });

    group('checkPermission', () {
      test('should return granted when system permission is granted', () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.granted);

        // Act
        final result = await service.checkPermission();

        // Assert
        expect(result, equals(StoragePermissionState.granted));
      });

      test('should return denied when system permission is denied', () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.denied);

        // Act
        final result = await service.checkPermission();

        // Assert
        expect(result, equals(StoragePermissionState.denied));
      });

      test('should return restricted when system permission is restricted',
          () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.restricted);

        // Act
        final result = await service.checkPermission();

        // Assert
        expect(result, equals(StoragePermissionState.restricted));
      });

      test(
          'should return permanentlyDenied when system permission is permanentlyDenied',
          () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.permanentlyDenied);

        // Act
        final result = await service.checkPermission();

        // Assert
        expect(result, equals(StoragePermissionState.permanentlyDenied));
      });

      test('should return granted when system permission is limited', () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.limited);

        // Act
        final result = await service.checkPermission();

        // Assert - limited is treated as granted for storage
        expect(result, equals(StoragePermissionState.granted));
      });

      test('should return granted when system permission is provisional',
          () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.provisional);

        // Act
        final result = await service.checkPermission();

        // Assert - provisional is iOS-specific, treated as granted
        expect(result, equals(StoragePermissionState.granted));
      });

      test('should cache permission state', () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.granted);

        // Act
        final result1 = await service.checkPermission();

        // Change status - should be ignored due to cache
        fakePermission.setStatus(PermissionStatus.denied);
        final result2 = await service.checkPermission();

        // Assert
        expect(result1, equals(StoragePermissionState.granted));
        expect(result2, equals(StoragePermissionState.granted)); // Still cached
      });
    });

    group('requestSystemPermission', () {
      test('should return granted when permission is granted', () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.granted);

        // Act
        final result = await service.requestSystemPermission();

        // Assert
        expect(result, equals(StoragePermissionState.granted));
      });

      test('should return denied when permission is denied', () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.denied);

        // Act
        final result = await service.requestSystemPermission();

        // Assert
        expect(result, equals(StoragePermissionState.denied));
      });

      test('should return permanentlyDenied when system denies permanently',
          () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.permanentlyDenied);

        // Act
        final result = await service.requestSystemPermission();

        // Assert
        expect(result, equals(StoragePermissionState.permanentlyDenied));
      });

      test('should set session permission flag when granted', () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.granted);

        // Act
        await service.requestSystemPermission();

        // Assert
        expect(service.isSessionPermissionGranted, isTrue);
      });

      test('should not set session permission flag when denied', () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.denied);

        // Act
        await service.requestSystemPermission();

        // Assert
        expect(service.isSessionPermissionGranted, isFalse);
      });

      test('should update cached state', () async {
        // Arrange - First check denied
        fakePermission.setStatus(PermissionStatus.denied);
        await service.checkPermission();

        // Act - Request and get granted
        fakePermission.setStatus(PermissionStatus.granted);
        await service.requestSystemPermission();

        // Assert - Subsequent check returns new cached value
        final result = await service.checkPermission();
        expect(result, equals(StoragePermissionState.granted));
      });
    });

    group('sessionOnly state', () {
      test('should return sessionOnly when granted after request', () async {
        // Arrange - Start with denied, then grant via request
        fakePermission.setStatus(PermissionStatus.denied);
        await service.checkPermission();

        // Act - Request permission and it gets granted
        fakePermission.setStatus(PermissionStatus.granted);
        final requestResult = await service.requestSystemPermission();

        // Assert - First result after request should track session
        expect(requestResult, equals(StoragePermissionState.granted));
        expect(service.isSessionPermissionGranted, isTrue);

        // When we clear cache and re-check, it should show sessionOnly
        service.clearCache();
        fakePermission.setStatus(PermissionStatus.granted);
        final checkResult = await service.checkPermission();
        expect(checkResult, equals(StoragePermissionState.sessionOnly));
      });
    });

    group('isPermissionBlocked', () {
      test('should return true when permission is denied', () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.denied);

        // Act
        final result = await service.isPermissionBlocked();

        // Assert
        expect(result, isTrue);
      });

      test('should return true when permission is permanentlyDenied', () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.permanentlyDenied);

        // Act
        final result = await service.isPermissionBlocked();

        // Assert
        expect(result, isTrue);
      });

      test('should return true when permission is restricted', () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.restricted);

        // Act
        final result = await service.isPermissionBlocked();

        // Assert
        expect(result, isTrue);
      });

      test('should return false when permission is granted', () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.granted);

        // Act
        final result = await service.isPermissionBlocked();

        // Assert
        expect(result, isFalse);
      });

      test('should return false for sessionOnly when session is active',
          () async {
        // Arrange - Grant permission via request to set session flag
        fakePermission.setStatus(PermissionStatus.granted);
        await service.requestSystemPermission();
        service.clearCache();

        // Act
        final result = await service.isPermissionBlocked();

        // Assert - Session is still active, so not blocked
        expect(result, isFalse);
      });

      test('should return true for sessionOnly when session is cleared',
          () async {
        // Arrange - Grant permission via request
        fakePermission.setStatus(PermissionStatus.granted);
        await service.requestSystemPermission();

        // Clear session (simulates app restart)
        service.clearSessionPermission();

        // Act
        final result = await service.isPermissionBlocked();

        // Assert - Session cleared, needs re-grant
        expect(result, isFalse); // Granted but not sessionOnly after clear
      });
    });

    group('isFirstTimeRequest', () {
      test('should return true when status is denied and rationale is false',
          () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.denied);
        fakePermission.setShouldShowRationale(false);

        // Act
        final result = await service.isFirstTimeRequest();

        // Assert
        expect(result, isTrue);
      });

      test('should return false when status is denied but rationale is true',
          () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.denied);
        fakePermission.setShouldShowRationale(true);

        // Act
        final result = await service.isFirstTimeRequest();

        // Assert
        expect(result, isFalse);
      });

      test('should return false when permission is granted', () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.granted);

        // Act
        final result = await service.isFirstTimeRequest();

        // Assert
        expect(result, isFalse);
      });

      test('should return false when permission is permanentlyDenied',
          () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.permanentlyDenied);

        // Act
        final result = await service.isFirstTimeRequest();

        // Assert
        expect(result, isFalse);
      });

      test('should return false when permission is restricted', () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.restricted);

        // Act
        final result = await service.isFirstTimeRequest();

        // Assert
        expect(result, isFalse);
      });

      test('should return false when permission is limited', () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.limited);

        // Act
        final result = await service.isFirstTimeRequest();

        // Assert
        expect(result, isFalse);
      });

      test('should return false when permission is provisional', () async {
        // Arrange
        fakePermission.setStatus(PermissionStatus.provisional);

        // Act
        final result = await service.isFirstTimeRequest();

        // Assert
        expect(result, isFalse);
      });
    });

    group('clearSessionPermission', () {
      test('should clear session permission flag', () async {
        // Arrange - Grant permission to set session flag
        fakePermission.setStatus(PermissionStatus.granted);
        await service.requestSystemPermission();
        expect(service.isSessionPermissionGranted, isTrue);

        // Act
        service.clearSessionPermission();

        // Assert
        expect(service.isSessionPermissionGranted, isFalse);
      });

      test('should clear cached state', () async {
        // Arrange - Check permission to cache state
        fakePermission.setStatus(PermissionStatus.granted);
        await service.checkPermission();

        // Act
        service.clearSessionPermission();

        // Assert - Cache is cleared, next check will query system
        fakePermission.setStatus(PermissionStatus.denied);
        final result = await service.checkPermission();
        expect(result, equals(StoragePermissionState.denied));
      });
    });

    group('clearCache', () {
      test('should clear cached permission state', () async {
        // Arrange - Check permission to cache state
        fakePermission.setStatus(PermissionStatus.granted);
        await service.checkPermission();

        // Act
        service.clearCache();

        // Assert - Cache is cleared, next check will query system
        fakePermission.setStatus(PermissionStatus.denied);
        final result = await service.checkPermission();
        expect(result, equals(StoragePermissionState.denied));
      });

      test('should not affect session permission flag', () async {
        // Arrange - Grant permission to set session flag
        fakePermission.setStatus(PermissionStatus.granted);
        await service.requestSystemPermission();

        // Act
        service.clearCache();

        // Assert - Session flag is still set
        expect(service.isSessionPermissionGranted, isTrue);
      });
    });

    group('clearAllPermissions', () {
      test('should clear both session and cache', () async {
        // Arrange - Grant permission and check to set both
        fakePermission.setStatus(PermissionStatus.granted);
        await service.requestSystemPermission();
        await service.checkPermission();

        // Act
        service.clearAllPermissions();

        // Assert
        expect(service.isSessionPermissionGranted, isFalse);

        // Cache is cleared
        fakePermission.setStatus(PermissionStatus.denied);
        final result = await service.checkPermission();
        expect(result, equals(StoragePermissionState.denied));
      });
    });
  });

  group('StoragePermissionService default constructor', () {
    test('should create service with default storage permission', () {
      // Act
      final service = StoragePermissionService();

      // Assert
      expect(service, isNotNull);
      expect(service.isSessionPermissionGranted, isFalse);
    });
  });

  group('storagePermissionServiceProvider', () {
    test('should provide StoragePermissionService', () {
      // Arrange
      final container = ProviderContainer();

      // Act
      final service = container.read(storagePermissionServiceProvider);

      // Assert
      expect(service, isA<StoragePermissionService>());

      container.dispose();
    });

    test('should provide same instance across multiple reads', () {
      // Arrange
      final container = ProviderContainer();

      // Act
      final service1 = container.read(storagePermissionServiceProvider);
      final service2 = container.read(storagePermissionServiceProvider);

      // Assert
      expect(identical(service1, service2), isTrue);

      container.dispose();
    });
  });

  group('Permission state flow scenarios', () {
    late FakePermission fakePermission;
    late StoragePermissionService service;

    setUp(() {
      fakePermission = FakePermission();
      service = StoragePermissionService(permission: fakePermission);
    });

    test('fresh app install flow: unknown -> first time request -> granted',
        () async {
      // Arrange - Fresh install state
      fakePermission.setStatus(PermissionStatus.denied);
      fakePermission.setShouldShowRationale(false);

      // Act - Check if first time
      final isFirstTime = await service.isFirstTimeRequest();
      expect(isFirstTime, isTrue);

      // Request permission
      fakePermission.setStatus(PermissionStatus.granted);
      final result = await service.requestSystemPermission();

      // Assert
      expect(result, equals(StoragePermissionState.granted));
      expect(service.isSessionPermissionGranted, isTrue);
    });

    test('previously denied flow: should show rationale', () async {
      // Arrange - Previously denied state
      fakePermission.setStatus(PermissionStatus.denied);
      fakePermission.setShouldShowRationale(true);

      // Act - Check if first time
      final isFirstTime = await service.isFirstTimeRequest();

      // Assert - Should show rationale dialog instead
      expect(isFirstTime, isFalse);
    });

    test('permanently denied flow: needs settings redirect', () async {
      // Arrange - User selected "Don\'t ask again"
      fakePermission.setStatus(PermissionStatus.permanentlyDenied);

      // Act
      final state = await service.checkPermission();
      final isBlocked = await service.isPermissionBlocked();
      final isFirstTime = await service.isFirstTimeRequest();

      // Assert
      expect(state, equals(StoragePermissionState.permanentlyDenied));
      expect(isBlocked, isTrue);
      expect(isFirstTime, isFalse);
    });

    test('app restart flow: session permission should be cleared', () async {
      // Arrange - User granted "Only this time" in previous session
      fakePermission.setStatus(PermissionStatus.granted);
      await service.requestSystemPermission();

      // Simulate app restart
      service.clearSessionPermission();

      // Act - Check permission state
      final state = await service.checkPermission();

      // Assert - Should be granted (system still says granted)
      // but session flag is cleared
      expect(state, equals(StoragePermissionState.granted));
      expect(service.isSessionPermissionGranted, isFalse);
    });

    test('returning from settings flow: cache should be cleared', () async {
      // Arrange - Permission was denied
      fakePermission.setStatus(PermissionStatus.denied);
      await service.checkPermission();

      // User went to settings and granted permission
      service.clearCache();
      fakePermission.setStatus(PermissionStatus.granted);

      // Act - Check permission after returning from settings
      final state = await service.checkPermission();

      // Assert
      expect(state, equals(StoragePermissionState.granted));
    });

    test('restricted device flow: should be blocked', () async {
      // Arrange - Enterprise/MDM restricted
      fakePermission.setStatus(PermissionStatus.restricted);

      // Act
      final state = await service.checkPermission();
      final isBlocked = await service.isPermissionBlocked();

      // Assert
      expect(state, equals(StoragePermissionState.restricted));
      expect(isBlocked, isTrue);
    });
  });

  group('Edge cases', () {
    late FakePermission fakePermission;
    late StoragePermissionService service;

    setUp(() {
      fakePermission = FakePermission();
      service = StoragePermissionService(permission: fakePermission);
    });

    test('multiple consecutive requests should update state correctly',
        () async {
      // First request - denied
      fakePermission.setStatus(PermissionStatus.denied);
      final result1 = await service.requestSystemPermission();
      expect(result1, equals(StoragePermissionState.denied));

      // Second request - granted
      fakePermission.setStatus(PermissionStatus.granted);
      final result2 = await service.requestSystemPermission();
      expect(result2, equals(StoragePermissionState.granted));

      // Verify final state
      service.clearCache();
      final finalState = await service.checkPermission();
      expect(finalState, equals(StoragePermissionState.sessionOnly));
    });

    test('clearAllPermissions should reset to clean state', () async {
      // Setup - grant permission
      fakePermission.setStatus(PermissionStatus.granted);
      await service.requestSystemPermission();
      await service.checkPermission();

      // Act
      service.clearAllPermissions();

      // Assert
      expect(service.isSessionPermissionGranted, isFalse);

      // New check should query system fresh
      fakePermission.setStatus(PermissionStatus.permanentlyDenied);
      final state = await service.checkPermission();
      expect(state, equals(StoragePermissionState.permanentlyDenied));
    });

    test('should handle rapid permission changes', () async {
      // Rapid changes
      fakePermission.setStatus(PermissionStatus.denied);
      await service.checkPermission();
      service.clearCache();

      fakePermission.setStatus(PermissionStatus.granted);
      await service.checkPermission();
      service.clearCache();

      fakePermission.setStatus(PermissionStatus.denied);
      final result = await service.checkPermission();

      expect(result, equals(StoragePermissionState.denied));
    });
  });
}
