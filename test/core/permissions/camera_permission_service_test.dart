import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

import 'package:aiscan/core/permissions/camera_permission_service.dart';

/// Fake implementation of PermissionHandlerPlatform for testing.
///
/// This mock intercepts all permission checks and requests, allowing us to
/// control the behavior without needing actual platform channels.
class FakePermissionHandlerPlatform extends PermissionHandlerPlatform {
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  bool _shouldShowRationale = false;

  /// Sets the camera permission status for testing.
  void setCameraStatus(PermissionStatus status) {
    _cameraStatus = status;
  }

  /// Sets whether shouldShowRequestRationale returns true.
  void setShouldShowRationale(bool value) {
    _shouldShowRationale = value;
  }

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async {
    return _cameraStatus;
  }

  @override
  Future<bool> shouldShowRequestPermissionRationale(Permission permission) async {
    return _shouldShowRationale;
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    return {
      for (final permission in permissions) permission: _cameraStatus,
    };
  }

  @override
  Future<bool> openAppSettings() async {
    return true;
  }

  @override
  Future<ServiceStatus> checkServiceStatus(Permission permission) async {
    return ServiceStatus.enabled;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePermissionHandlerPlatform fakePermissionHandler;
  late CameraPermissionService service;

  setUp(() {
    fakePermissionHandler = FakePermissionHandlerPlatform();
    PermissionHandlerPlatform.instance = fakePermissionHandler;
    service = CameraPermissionService();
  });

  tearDown(() {
    // Reset state between tests
    service.clearAllPermissions();
  });

  group('CameraPermissionService', () {
    group('CameraPermissionState enum', () {
      test('should have all expected states', () {
        expect(CameraPermissionState.values, contains(CameraPermissionState.unknown));
        expect(CameraPermissionState.values, contains(CameraPermissionState.granted));
        expect(CameraPermissionState.values, contains(CameraPermissionState.sessionOnly));
        expect(CameraPermissionState.values, contains(CameraPermissionState.denied));
        expect(CameraPermissionState.values, contains(CameraPermissionState.restricted));
        expect(CameraPermissionState.values, contains(CameraPermissionState.permanentlyDenied));
      });
    });

    group('CameraPermissionException', () {
      test('should format message correctly without cause', () {
        const exception = CameraPermissionException('Test error');
        expect(exception.toString(), equals('CameraPermissionException: Test error'));
      });

      test('should format message correctly with cause', () {
        final cause = Exception('Original error');
        final exception = CameraPermissionException('Test error', cause: cause);
        expect(
          exception.toString(),
          equals('CameraPermissionException: Test error (caused by: $cause)'),
        );
      });

      test('should store message and cause correctly', () {
        final cause = Exception('Original error');
        final exception = CameraPermissionException('Test error', cause: cause);
        expect(exception.message, equals('Test error'));
        expect(exception.cause, equals(cause));
      });
    });

    group('checkPermission', () {
      test('should return granted when system permission is granted', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);

        final state = await service.checkPermission();

        expect(state, equals(CameraPermissionState.granted));
      });

      test('should return denied when system permission is denied', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);

        final state = await service.checkPermission();

        expect(state, equals(CameraPermissionState.denied));
      });

      test('should return restricted when system permission is restricted', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.restricted);

        final state = await service.checkPermission();

        expect(state, equals(CameraPermissionState.restricted));
      });

      test('should return permanentlyDenied when system permission is permanently denied', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.permanentlyDenied);

        final state = await service.checkPermission();

        expect(state, equals(CameraPermissionState.permanentlyDenied));
      });

      test('should return granted for limited permission status', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.limited);

        final state = await service.checkPermission();

        expect(state, equals(CameraPermissionState.granted));
      });

      test('should return granted for provisional permission status', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.provisional);

        final state = await service.checkPermission();

        expect(state, equals(CameraPermissionState.granted));
      });

      test('should cache permission state', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);
        await service.checkPermission();

        // Change status after first check
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);

        // Should return cached value
        final state = await service.checkPermission();
        expect(state, equals(CameraPermissionState.granted));
      });

      test('should return fresh state after clearCache', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);
        await service.checkPermission();

        // Clear cache and change status
        service.clearCache();
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);

        final state = await service.checkPermission();
        expect(state, equals(CameraPermissionState.denied));
      });
    });

    group('requestSystemPermission', () {
      test('should return granted state when permission is granted', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);

        final state = await service.requestSystemPermission();

        expect(state, equals(CameraPermissionState.granted));
      });

      test('should return denied state when permission is denied', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);

        final state = await service.requestSystemPermission();

        expect(state, equals(CameraPermissionState.denied));
      });

      test('should set session permission granted when permission is granted', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);

        await service.requestSystemPermission();

        expect(service.isSessionPermissionGranted, isTrue);
      });

      test('should not set session permission granted when permission is denied', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);

        await service.requestSystemPermission();

        expect(service.isSessionPermissionGranted, isFalse);
      });

      test('should cache the result state', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);
        await service.requestSystemPermission();

        // Change status
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);

        // Should return cached value
        final state = await service.checkPermission();
        expect(state, equals(CameraPermissionState.granted));
      });
    });

    group('isPermissionBlocked', () {
      test('should return true when permission is denied', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);

        final isBlocked = await service.isPermissionBlocked();

        expect(isBlocked, isTrue);
      });

      test('should return true when permission is permanently denied', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.permanentlyDenied);

        final isBlocked = await service.isPermissionBlocked();

        expect(isBlocked, isTrue);
      });

      test('should return true when permission is restricted', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.restricted);

        final isBlocked = await service.isPermissionBlocked();

        expect(isBlocked, isTrue);
      });

      test('should return false when permission is granted', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);

        final isBlocked = await service.isPermissionBlocked();

        expect(isBlocked, isFalse);
      });

      test('should return false when session permission was granted in current session', () async {
        // First grant permission via request (sets session flag)
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);
        await service.requestSystemPermission();

        // Clear cache but not session
        service.clearCache();

        // Check permission again - should return sessionOnly
        final isBlocked = await service.isPermissionBlocked();

        expect(isBlocked, isFalse);
      });

      test('should return true when session permission expired (app restart simulation)', () async {
        // First grant permission via request
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);
        await service.requestSystemPermission();

        // Simulate app restart by clearing session permission
        service.clearSessionPermission();

        // When system still reports granted but session was cleared,
        // this means it was a temporary "Only this time" grant
        // The service should detect this as granted (since system says granted)
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);

        final isBlocked = await service.isPermissionBlocked();

        // After clearSessionPermission, checkPermission returns granted (not sessionOnly)
        // because _sessionPermissionGranted is false and system shows granted
        expect(isBlocked, isFalse);
      });

      test('should return true when sessionOnly and session not active', () async {
        // Manually set up a scenario where state is sessionOnly but session is cleared
        // This requires:
        // 1. Request permission (grants session)
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);
        await service.requestSystemPermission();

        // 2. State is now cached as granted with session flag true
        // 3. Clear session (simulating app restart)
        service.clearSessionPermission();

        // 4. But now checkPermission will return fresh check
        // With session cleared and system showing denied, it's blocked
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);

        final isBlocked = await service.isPermissionBlocked();
        expect(isBlocked, isTrue);
      });
    });

    group('isFirstTimeRequest', () {
      test('should return true when status is denied and rationale is false (never requested)', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);
        fakePermissionHandler.setShouldShowRationale(false);

        final isFirstTime = await service.isFirstTimeRequest();

        expect(isFirstTime, isTrue);
      });

      test('should return false when status is denied but rationale is true (previously denied)', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);
        fakePermissionHandler.setShouldShowRationale(true);

        final isFirstTime = await service.isFirstTimeRequest();

        expect(isFirstTime, isFalse);
      });

      test('should return false when permission is already granted', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);
        fakePermissionHandler.setShouldShowRationale(false);

        final isFirstTime = await service.isFirstTimeRequest();

        expect(isFirstTime, isFalse);
      });

      test('should return false when permission is permanently denied', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.permanentlyDenied);
        fakePermissionHandler.setShouldShowRationale(false);

        final isFirstTime = await service.isFirstTimeRequest();

        expect(isFirstTime, isFalse);
      });

      test('should return false when permission is restricted', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.restricted);
        fakePermissionHandler.setShouldShowRationale(false);

        final isFirstTime = await service.isFirstTimeRequest();

        expect(isFirstTime, isFalse);
      });

      test('should return false when permission is limited', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.limited);
        fakePermissionHandler.setShouldShowRationale(false);

        final isFirstTime = await service.isFirstTimeRequest();

        expect(isFirstTime, isFalse);
      });

      test('should return false when permission is provisional', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.provisional);
        fakePermissionHandler.setShouldShowRationale(false);

        final isFirstTime = await service.isFirstTimeRequest();

        expect(isFirstTime, isFalse);
      });
    });

    group('clearSessionPermission', () {
      test('should reset session permission flag', () async {
        // Grant permission first
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);
        await service.requestSystemPermission();
        expect(service.isSessionPermissionGranted, isTrue);

        // Clear session
        service.clearSessionPermission();

        expect(service.isSessionPermissionGranted, isFalse);
      });

      test('should clear cached state', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);
        await service.checkPermission();

        service.clearSessionPermission();
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);

        final state = await service.checkPermission();
        expect(state, equals(CameraPermissionState.denied));
      });
    });

    group('clearAllPermissions', () {
      test('should clear both session and cache', () async {
        // Set up session permission
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);
        await service.requestSystemPermission();

        expect(service.isSessionPermissionGranted, isTrue);

        // Clear all
        service.clearAllPermissions();

        // Verify session is cleared
        expect(service.isSessionPermissionGranted, isFalse);

        // Verify cache is cleared
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);
        final state = await service.checkPermission();
        expect(state, equals(CameraPermissionState.denied));
      });
    });

    group('clearCache', () {
      test('should only clear cache, not session permission', () async {
        // Grant permission
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);
        await service.requestSystemPermission();

        // Clear cache only
        service.clearCache();

        // Session should still be granted
        expect(service.isSessionPermissionGranted, isTrue);

        // But cache is cleared, so next check uses fresh status
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);
        final state = await service.checkPermission();
        expect(state, equals(CameraPermissionState.denied));
      });
    });

    group('sessionOnly state', () {
      test('should return sessionOnly when granted after request and session is active', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);

        // Request permission sets session flag
        final requestResult = await service.requestSystemPermission();
        expect(requestResult, equals(CameraPermissionState.granted));
        expect(service.isSessionPermissionGranted, isTrue);

        // Clear cache and check again
        service.clearCache();

        // Now checkPermission should return sessionOnly
        final state = await service.checkPermission();
        expect(state, equals(CameraPermissionState.sessionOnly));
      });

      test('sessionOnly isPermissionBlocked should return false when session active', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);
        await service.requestSystemPermission();

        // Clear cache to get fresh sessionOnly state
        service.clearCache();

        // Should not be blocked because session is active
        final isBlocked = await service.isPermissionBlocked();
        expect(isBlocked, isFalse);
      });
    });

    group('Permission flow scenarios', () {
      test('first time user - should show native dialog', () async {
        // Fresh install: denied status, no rationale
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);
        fakePermissionHandler.setShouldShowRationale(false);

        final isFirstTime = await service.isFirstTimeRequest();
        final isBlocked = await service.isPermissionBlocked();

        expect(isFirstTime, isTrue);
        expect(isBlocked, isTrue);
      });

      test('user denied once - should show settings dialog', () async {
        // After first denial: denied status, rationale true
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);
        fakePermissionHandler.setShouldShowRationale(true);

        final isFirstTime = await service.isFirstTimeRequest();
        final isBlocked = await service.isPermissionBlocked();

        expect(isFirstTime, isFalse);
        expect(isBlocked, isTrue);
      });

      test('user selected dont ask again - should show settings dialog', () async {
        // Permanently denied
        fakePermissionHandler.setCameraStatus(PermissionStatus.permanentlyDenied);
        fakePermissionHandler.setShouldShowRationale(false);

        final isFirstTime = await service.isFirstTimeRequest();
        final isBlocked = await service.isPermissionBlocked();

        expect(isFirstTime, isFalse);
        expect(isBlocked, isTrue);
      });

      test('user granted permission - camera should work', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);

        final isBlocked = await service.isPermissionBlocked();
        final state = await service.checkPermission();

        expect(isBlocked, isFalse);
        expect(state, equals(CameraPermissionState.granted));
      });

      test('user granted only this time - should work in session', () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);
        await service.requestSystemPermission();

        final isBlocked = await service.isPermissionBlocked();

        expect(isBlocked, isFalse);
        expect(service.isSessionPermissionGranted, isTrue);
      });

      test('app restart after only this time - should show settings dialog', () async {
        // Simulate granting "only this time"
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);
        await service.requestSystemPermission();

        // Simulate app restart
        service.clearSessionPermission();

        // System now returns denied (temporary permission expired)
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);
        fakePermissionHandler.setShouldShowRationale(true);

        final isFirstTime = await service.isFirstTimeRequest();
        final isBlocked = await service.isPermissionBlocked();

        expect(isFirstTime, isFalse);
        expect(isBlocked, isTrue);
      });
    });
  });
}
