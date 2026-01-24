import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

import 'package:aiscan/core/permissions/camera_permission_service.dart';
import 'package:aiscan/core/permissions/permission_dialog.dart';

/// Fake implementation of PermissionHandlerPlatform for testing.
///
/// This mock intercepts all permission checks and requests, allowing us to
/// control the behavior without needing actual platform channels.
class FakePermissionHandlerPlatform extends PermissionHandlerPlatform {
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  bool _shouldShowRationale = false;
  PermissionStatus? _requestResult;

  /// Sets the camera permission status for testing.
  void setCameraStatus(PermissionStatus status) {
    _cameraStatus = status;
  }

  /// Sets whether shouldShowRequestRationale returns true.
  void setShouldShowRationale(bool value) {
    _shouldShowRationale = value;
  }

  /// Sets the result returned by requestPermissions (if different from status).
  void setRequestResult(PermissionStatus? result) {
    _requestResult = result;
  }

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async {
    return _cameraStatus;
  }

  @override
  Future<bool> shouldShowRequestPermissionRationale(
      Permission permission) async {
    return _shouldShowRationale;
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    final resultStatus = _requestResult ?? _cameraStatus;
    return {
      for (final permission in permissions) permission: resultStatus,
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

/// A testable version of the permission flow logic from ScannerScreen.
///
/// This class extracts the permission checking logic to make it testable
/// without needing to render the full widget.
class TestablePermissionFlow {
  TestablePermissionFlow({
    required this.permissionService,
    required this.onShowSettingsDialog,
    required this.onOpenSettings,
  });

  final CameraPermissionService permissionService;
  final Future<bool> Function() onShowSettingsDialog;
  final Future<void> Function() onOpenSettings;

  /// Flag to prevent multiple permission dialogs from appearing.
  bool isPermissionDialogShowing = false;

  /// Flag to track if we directed the user to settings.
  bool waitingForSettingsReturn = false;

  /// Checks camera permission and requests if needed.
  ///
  /// Implements the new permission flow:
  /// 1. If permission is already granted or sessionOnly -> return true
  /// 2. If this is a first-time request -> show native Android dialog
  /// 3. If permission is blocked -> show Yes/No dialog to redirect to settings
  ///
  /// Returns `true` if permission is granted and camera can be used,
  /// `false` otherwise.
  Future<bool> checkAndRequestPermission() async {
    // Prevent multiple dialogs from appearing
    if (isPermissionDialogShowing) {
      return false;
    }

    // Check current permission state
    final state = await permissionService.checkPermission();

    // If already granted, proceed
    if (state == CameraPermissionState.granted ||
        state == CameraPermissionState.sessionOnly) {
      return true;
    }

    // Check if this is a first-time request (native dialog should be shown)
    final isFirstTime = await permissionService.isFirstTimeRequest();

    if (isFirstTime) {
      // Show native Android permission dialog
      final result = await permissionService.requestSystemPermission();

      return result == CameraPermissionState.granted ||
          result == CameraPermissionState.sessionOnly;
    }

    // Permission is blocked - show Yes/No dialog to redirect to settings
    if (await permissionService.isPermissionBlocked()) {
      isPermissionDialogShowing = true;
      try {
        final shouldOpenSettings = await onShowSettingsDialog();

        if (shouldOpenSettings) {
          // Set flag to re-check permission when app resumes
          waitingForSettingsReturn = true;

          // Open settings
          await onOpenSettings();

          // Return false for now - user will need to tap scan again after settings
          return false;
        }
      } finally {
        isPermissionDialogShowing = false;
      }

      return false;
    }

    // Unknown state - try requesting permission
    final result = await permissionService.requestSystemPermission();
    return result == CameraPermissionState.granted ||
        result == CameraPermissionState.sessionOnly;
  }

  /// Simulates app resume from settings.
  Future<void> handleAppResume() async {
    if (waitingForSettingsReturn) {
      waitingForSettingsReturn = false;
      permissionService.clearCache();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePermissionHandlerPlatform fakePermissionHandler;
  late CameraPermissionService permissionService;
  late TestablePermissionFlow permissionFlow;
  late bool settingsDialogShown;
  late bool settingsOpened;
  late bool settingsDialogResult;

  setUp(() {
    fakePermissionHandler = FakePermissionHandlerPlatform();
    PermissionHandlerPlatform.instance = fakePermissionHandler;
    permissionService = CameraPermissionService();
    settingsDialogShown = false;
    settingsOpened = false;
    settingsDialogResult = false;

    permissionFlow = TestablePermissionFlow(
      permissionService: permissionService,
      onShowSettingsDialog: () async {
        settingsDialogShown = true;
        return settingsDialogResult;
      },
      onOpenSettings: () async {
        settingsOpened = true;
      },
    );
  });

  tearDown(() {
    // Reset state between tests
    permissionService.clearAllPermissions();
  });

  group('Permission Flow Integration', () {
    group('Permission already granted scenarios', () {
      test('should return true immediately when permission is granted',
          () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);

        final result = await permissionFlow.checkAndRequestPermission();

        expect(result, isTrue);
        expect(settingsDialogShown, isFalse);
        expect(settingsOpened, isFalse);
      });

      test(
          'should return true immediately when sessionOnly permission is active',
          () async {
        // First grant permission via request (sets session flag)
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);
        await permissionService.requestSystemPermission();

        // Clear cache so next check returns sessionOnly
        permissionService.clearCache();

        final result = await permissionFlow.checkAndRequestPermission();

        expect(result, isTrue);
        expect(settingsDialogShown, isFalse);
        expect(settingsOpened, isFalse);
      });
    });

    group('First-time permission request scenarios', () {
      test('should request system permission on first-time request', () async {
        // First-time request: denied status, no rationale shown
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);
        fakePermissionHandler.setShouldShowRationale(false);

        // When requested, grant permission
        fakePermissionHandler.setRequestResult(PermissionStatus.granted);

        final result = await permissionFlow.checkAndRequestPermission();

        expect(result, isTrue);
        expect(settingsDialogShown, isFalse);
        expect(settingsOpened, isFalse);
      });

      test('should return false when user denies first-time request', () async {
        // First-time request: denied status, no rationale shown
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);
        fakePermissionHandler.setShouldShowRationale(false);

        // When requested, deny permission
        fakePermissionHandler.setRequestResult(PermissionStatus.denied);

        final result = await permissionFlow.checkAndRequestPermission();

        // Result depends on whether it's blocked after denial
        // After denial, rationale would be true on next check, so this returns false
        expect(result, isFalse);
        expect(settingsDialogShown, isFalse);
      });
    });

    group('Blocked permission scenarios', () {
      test('should show settings dialog when permission was previously denied',
          () async {
        // Previously denied: denied status with rationale shown
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);
        fakePermissionHandler.setShouldShowRationale(true);

        final result = await permissionFlow.checkAndRequestPermission();

        expect(result, isFalse);
        expect(settingsDialogShown, isTrue);
        expect(settingsOpened, isFalse);
      });

      test('should show settings dialog when permission is permanently denied',
          () async {
        fakePermissionHandler
            .setCameraStatus(PermissionStatus.permanentlyDenied);

        final result = await permissionFlow.checkAndRequestPermission();

        expect(result, isFalse);
        expect(settingsDialogShown, isTrue);
        expect(settingsOpened, isFalse);
      });

      test('should show settings dialog when permission is restricted',
          () async {
        fakePermissionHandler.setCameraStatus(PermissionStatus.restricted);

        final result = await permissionFlow.checkAndRequestPermission();

        expect(result, isFalse);
        expect(settingsDialogShown, isTrue);
        expect(settingsOpened, isFalse);
      });

      test('should open settings when user confirms dialog', () async {
        fakePermissionHandler
            .setCameraStatus(PermissionStatus.permanentlyDenied);
        settingsDialogResult = true;

        final result = await permissionFlow.checkAndRequestPermission();

        expect(
            result, isFalse); // Returns false since permission not yet granted
        expect(settingsDialogShown, isTrue);
        expect(settingsOpened, isTrue);
        expect(permissionFlow.waitingForSettingsReturn, isTrue);
      });

      test('should not open settings when user cancels dialog', () async {
        fakePermissionHandler
            .setCameraStatus(PermissionStatus.permanentlyDenied);
        settingsDialogResult = false;

        final result = await permissionFlow.checkAndRequestPermission();

        expect(result, isFalse);
        expect(settingsDialogShown, isTrue);
        expect(settingsOpened, isFalse);
        expect(permissionFlow.waitingForSettingsReturn, isFalse);
      });
    });

    group('Settings return handling', () {
      test('should clear cache when returning from settings', () async {
        fakePermissionHandler
            .setCameraStatus(PermissionStatus.permanentlyDenied);
        settingsDialogResult = true;

        await permissionFlow.checkAndRequestPermission();
        expect(permissionFlow.waitingForSettingsReturn, isTrue);

        // Simulate user granting permission in settings
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);

        await permissionFlow.handleAppResume();

        expect(permissionFlow.waitingForSettingsReturn, isFalse);

        // Now permission check should return granted
        final result = await permissionFlow.checkAndRequestPermission();
        expect(result, isTrue);
      });

      test('should stay blocked if user did not grant permission in settings',
          () async {
        fakePermissionHandler
            .setCameraStatus(PermissionStatus.permanentlyDenied);
        settingsDialogResult = true;

        await permissionFlow.checkAndRequestPermission();
        await permissionFlow.handleAppResume();

        // Permission still denied
        fakePermissionHandler
            .setCameraStatus(PermissionStatus.permanentlyDenied);

        final result = await permissionFlow.checkAndRequestPermission();
        expect(result, isFalse);
        expect(settingsDialogShown, isTrue);
      });
    });

    group('Session permission expiration', () {
      test('should return true when session permission is active', () async {
        // Grant permission in this session
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);
        await permissionService.requestSystemPermission();

        // Clear cache to simulate fresh check
        permissionService.clearCache();

        final result = await permissionFlow.checkAndRequestPermission();
        expect(result, isTrue);
      });

      test('should show dialog after session expires (app restart)', () async {
        // Grant permission in this session
        fakePermissionHandler.setCameraStatus(PermissionStatus.granted);
        await permissionService.requestSystemPermission();

        // Simulate app restart
        permissionService.clearSessionPermission();

        // System now returns denied (temporary permission expired)
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);
        fakePermissionHandler.setShouldShowRationale(true);

        final result = await permissionFlow.checkAndRequestPermission();
        expect(result, isFalse);
        expect(settingsDialogShown, isTrue);
      });
    });

    group('Multiple dialog prevention', () {
      test('should prevent showing multiple dialogs simultaneously', () async {
        fakePermissionHandler
            .setCameraStatus(PermissionStatus.permanentlyDenied);

        // Simulate dialog being shown
        permissionFlow.isPermissionDialogShowing = true;

        final result = await permissionFlow.checkAndRequestPermission();

        expect(result, isFalse);
        // Dialog should not have been shown again
        expect(settingsDialogShown, isFalse);
      });

      test('should reset dialog flag after dialog closes', () async {
        fakePermissionHandler
            .setCameraStatus(PermissionStatus.permanentlyDenied);
        settingsDialogResult = false;

        await permissionFlow.checkAndRequestPermission();

        expect(permissionFlow.isPermissionDialogShowing, isFalse);
      });
    });

    group('Complete user journey scenarios', () {
      test('fresh install user flow', () async {
        // Step 1: Fresh install - first time request
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);
        fakePermissionHandler.setShouldShowRationale(false);
        fakePermissionHandler.setRequestResult(PermissionStatus.granted);

        final result = await permissionFlow.checkAndRequestPermission();

        expect(result, isTrue);
        expect(settingsDialogShown, isFalse);
      });

      test('user who denied once flow', () async {
        // User denied permission once before
        fakePermissionHandler.setCameraStatus(PermissionStatus.denied);
        fakePermissionHandler.setShouldShowRationale(true);

        final result = await permissionFlow.checkAndRequestPermission();

        expect(result, isFalse);
        expect(settingsDialogShown, isTrue);
      });

      test('user with dont ask again selected', () async {
        fakePermissionHandler
            .setCameraStatus(PermissionStatus.permanentlyDenied);

        final result = await permissionFlow.checkAndRequestPermission();

        expect(result, isFalse);
        expect(settingsDialogShown, isTrue);
      });
    });
  });

  group('Camera Settings Dialog Widget Tests', () {
    testWidgets('should show correct title and content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showCameraSettingsDialog(context),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Camera Access Required'), findsOneWidget);
      expect(
        find.textContaining('Would you like to open Settings'),
        findsOneWidget,
      );
    });

    testWidgets('should have Not Now and Open Settings buttons',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showCameraSettingsDialog(context),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Not Now'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('should return false when Not Now is tapped', (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  dialogResult = await showCameraSettingsDialog(context);
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(dialogResult, isFalse);
    });

    testWidgets('should return true when Open Settings is tapped',
        (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  dialogResult = await showCameraSettingsDialog(context);
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(dialogResult, isTrue);
    });

    testWidgets('should have settings icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showCameraSettingsDialog(context),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });
  });

  group('Permission Service with Flow Integration', () {
    test('isFirstTimeRequest and isPermissionBlocked work together correctly',
        () async {
      // Scenario 1: Fresh install (denied, no rationale)
      fakePermissionHandler.setCameraStatus(PermissionStatus.denied);
      fakePermissionHandler.setShouldShowRationale(false);

      var isFirstTime = await permissionService.isFirstTimeRequest();
      var isBlocked = await permissionService.isPermissionBlocked();

      expect(isFirstTime, isTrue);
      expect(isBlocked, isTrue);

      // Clear cache for next scenario
      permissionService.clearCache();

      // Scenario 2: After denial (denied, rationale shown)
      fakePermissionHandler.setShouldShowRationale(true);

      isFirstTime = await permissionService.isFirstTimeRequest();
      permissionService.clearCache();
      isBlocked = await permissionService.isPermissionBlocked();

      expect(isFirstTime, isFalse);
      expect(isBlocked, isTrue);

      // Clear cache for next scenario
      permissionService.clearCache();

      // Scenario 3: Permanently denied
      fakePermissionHandler.setCameraStatus(PermissionStatus.permanentlyDenied);

      isFirstTime = await permissionService.isFirstTimeRequest();
      permissionService.clearCache();
      isBlocked = await permissionService.isPermissionBlocked();

      expect(isFirstTime, isFalse);
      expect(isBlocked, isTrue);

      // Clear cache for next scenario
      permissionService.clearCache();

      // Scenario 4: Granted
      fakePermissionHandler.setCameraStatus(PermissionStatus.granted);

      isFirstTime = await permissionService.isFirstTimeRequest();
      permissionService.clearCache();
      isBlocked = await permissionService.isPermissionBlocked();

      expect(isFirstTime, isFalse);
      expect(isBlocked, isFalse);
    });

    test('session permission tracking works correctly', () async {
      // Request permission and get granted
      fakePermissionHandler.setCameraStatus(PermissionStatus.granted);
      final result = await permissionService.requestSystemPermission();

      expect(result, CameraPermissionState.granted);
      expect(permissionService.isSessionPermissionGranted, isTrue);

      // Clear cache and check - should be sessionOnly
      permissionService.clearCache();
      final state = await permissionService.checkPermission();

      expect(state, CameraPermissionState.sessionOnly);
      expect(await permissionService.isPermissionBlocked(), isFalse);

      // Clear session (simulate app restart)
      permissionService.clearSessionPermission();

      // System still shows granted, but session is cleared
      // This would typically mean permission is still valid (not just session-only)
      permissionService.clearCache();
      final afterRestartState = await permissionService.checkPermission();

      // Without session flag, granted status maps to granted (not sessionOnly)
      expect(afterRestartState, CameraPermissionState.granted);
    });
  });
}
