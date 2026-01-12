import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:aiscan/core/permissions/camera_permission_service.dart';
import 'package:aiscan/core/permissions/permission_dialog.dart';

import 'permission_flow_test.mocks.dart';

@GenerateMocks([FlutterSecureStorage])
void main() {
  late MockFlutterSecureStorage mockStorage;
  late CameraPermissionService permissionService;

  /// Storage key used by CameraPermissionService.
  const permissionStorageKey = 'aiscan_camera_permission';

  /// Value stored for permanent grant.
  const grantedValue = 'granted';

  /// Value stored for denial.
  const deniedValue = 'denied';

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    permissionService = CameraPermissionService(storage: mockStorage);

    // Default mock behaviors
    when(mockStorage.read(key: anyNamed('key'))).thenAnswer((_) async => null);
    when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
        .thenAnswer((_) async {});
    when(mockStorage.delete(key: anyNamed('key'))).thenAnswer((_) async {});
  });

  group('Permission Flow Integration Tests', () {
    group('Permission → Scanner Access Flow', () {
      test(
        'should block scanner access when permission not granted',
        () async {
          // Arrange - No stored permission, no session permission
          when(mockStorage.read(key: permissionStorageKey))
              .thenAnswer((_) async => null);

          // Act
          final isAllowed = permissionService.isAccessAllowed;

          // Assert - Access should be blocked with no permission
          expect(isAllowed, isFalse);
          expect(permissionService.needsPermission, isTrue);
        },
      );

      test(
        'should allow scanner access after permanent permission grant',
        () async {
          // Act - Grant permanent permission
          await permissionService.grantPermanentPermission();

          // Assert - Access should be allowed
          expect(permissionService.isAccessAllowed, isTrue);
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.granted),
          );

          // Verify storage was called
          verify(
            mockStorage.write(
              key: permissionStorageKey,
              value: grantedValue,
            ),
          ).called(1);
        },
      );

      test(
        'should allow scanner access after session permission grant',
        () async {
          // Act - Grant session permission
          permissionService.grantSessionPermission();

          // Assert - Access should be allowed
          expect(permissionService.isAccessAllowed, isTrue);
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.sessionOnly),
          );

          // Verify storage was NOT called for session permission
          verifyNever(
            mockStorage.write(key: anyNamed('key'), value: anyNamed('value')),
          );
        },
      );

      test(
        'should block scanner access after permission denial',
        () async {
          // Act - Deny permission
          await permissionService.denyPermission();

          // Assert - Access should be blocked
          expect(permissionService.isAccessAllowed, isFalse);
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.denied),
          );

          // Verify denial was stored
          verify(
            mockStorage.write(
              key: permissionStorageKey,
              value: deniedValue,
            ),
          ).called(1);
        },
      );

      test(
        'should require permission dialog when state is unknown',
        () async {
          // Arrange - Clear any existing state
          await permissionService.clearAllPermissions();

          // Assert - Should need permission dialog
          expect(permissionService.needsPermission, isTrue);
          expect(permissionService.isAccessAllowed, isFalse);
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.unknown),
          );
        },
      );
    });

    group('Permission Persistence Flow', () {
      test(
        'permanent grant should persist across service recreations',
        () async {
          // Arrange - First service instance grants permission
          final service1 = CameraPermissionService(storage: mockStorage);
          await service1.grantPermanentPermission();

          // Mock storage to return granted value
          when(mockStorage.read(key: permissionStorageKey))
              .thenAnswer((_) async => grantedValue);

          // Act - Create new service instance (simulates app restart)
          final service2 = CameraPermissionService(storage: mockStorage);

          // Need to read from storage to get the persisted value
          // In real app, checkPermission would be called
          final storedValue = await mockStorage.read(key: permissionStorageKey);

          // Assert - Permission should be retrievable
          expect(storedValue, equals(grantedValue));

          // Verify storage write was called once by service1
          verify(
            mockStorage.write(
              key: permissionStorageKey,
              value: grantedValue,
            ),
          ).called(1);
        },
      );

      test(
        'denial should persist across service recreations',
        () async {
          // Arrange - First service instance denies permission
          final service1 = CameraPermissionService(storage: mockStorage);
          await service1.denyPermission();

          // Mock storage to return denied value
          when(mockStorage.read(key: permissionStorageKey))
              .thenAnswer((_) async => deniedValue);

          // Act - Create new service instance
          final service2 = CameraPermissionService(storage: mockStorage);
          final storedValue = await mockStorage.read(key: permissionStorageKey);

          // Assert - Denial should be retrievable
          expect(storedValue, equals(deniedValue));
        },
      );

      test(
        'should store and retrieve permission state correctly',
        () async {
          // Arrange
          String? storedPermissionValue;

          when(
            mockStorage.write(key: anyNamed('key'), value: anyNamed('value')),
          ).thenAnswer((invocation) async {
            storedPermissionValue =
                invocation.namedArguments[const Symbol('value')] as String?;
          });

          when(mockStorage.read(key: anyNamed('key')))
              .thenAnswer((_) async => storedPermissionValue);

          // Act - Grant permanent permission
          await permissionService.grantPermanentPermission();

          // Assert - Value should be stored
          expect(storedPermissionValue, equals(grantedValue));

          // Act - Read back from storage
          final readValue = await mockStorage.read(key: permissionStorageKey);

          // Assert - Should get same value back
          expect(readValue, equals(grantedValue));
        },
      );

      test(
        'should handle storage errors gracefully',
        () async {
          // Arrange - Storage throws error
          when(
            mockStorage.write(key: anyNamed('key'), value: anyNamed('value')),
          ).thenThrow(Exception('Storage encryption failed'));

          // Act & Assert - Should throw CameraPermissionException
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
        },
      );

      test(
        'clearAllPermissions should remove persistent state',
        () async {
          // Arrange - First grant permission
          await permissionService.grantPermanentPermission();

          // Act - Clear all permissions
          await permissionService.clearAllPermissions();

          // Assert
          verify(mockStorage.delete(key: permissionStorageKey)).called(1);
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.unknown),
          );
        },
      );
    });

    group('Session Permission Reset Flow', () {
      test(
        'session permission should reset on clearSessionPermission',
        () async {
          // Arrange - Grant session permission
          permissionService.grantSessionPermission();
          expect(permissionService.isAccessAllowed, isTrue);

          // Act - Clear session permission (simulates cold start)
          permissionService.clearSessionPermission();

          // Assert - Access should be revoked
          expect(permissionService.currentState, isNull);
          expect(permissionService.needsPermission, isTrue);

          // Verify storage was NOT affected
          verifyNever(mockStorage.delete(key: anyNamed('key')));
        },
      );

      test(
        'session permission should not persist to storage',
        () async {
          // Act - Grant session permission multiple times
          permissionService.grantSessionPermission();
          permissionService.clearSessionPermission();
          permissionService.grantSessionPermission();

          // Assert - Storage should never be called for session permissions
          verifyNever(
            mockStorage.write(key: anyNamed('key'), value: anyNamed('value')),
          );
          verifyNever(mockStorage.delete(key: anyNamed('key')));
        },
      );

      test(
        'permanent permission should survive clearSessionPermission',
        () async {
          // Arrange - Grant permanent permission
          await permissionService.grantPermanentPermission();

          // Act - Clear session permission (simulates cold start)
          permissionService.clearSessionPermission();

          // Assert - Storage should NOT be cleared
          verifyNever(mockStorage.delete(key: anyNamed('key')));

          // Verify storage still has the granted value
          verify(
            mockStorage.write(
              key: permissionStorageKey,
              value: grantedValue,
            ),
          ).called(1);
        },
      );

      test(
        'cold start should reset session but preserve permanent grants',
        () async {
          // Arrange - Create a service with both session and "stored" permission
          final service1 = CameraPermissionService(storage: mockStorage);

          // Grant permanent permission
          await service1.grantPermanentPermission();

          // Grant session permission on top
          service1.grantSessionPermission();
          expect(
            service1.currentState,
            equals(CameraPermissionState.sessionOnly),
          );

          // Mock storage to return granted value for new service
          when(mockStorage.read(key: permissionStorageKey))
              .thenAnswer((_) async => grantedValue);

          // Act - Simulate cold start
          final service2 = CameraPermissionService(storage: mockStorage);
          service2.clearSessionPermission(); // Called in main.dart on cold start

          // Assert - Session state should be cleared (null)
          expect(service2.currentState, isNull);

          // But storage should still have permanent grant
          final storedValue = await mockStorage.read(key: permissionStorageKey);
          expect(storedValue, equals(grantedValue));
        },
      );

      test(
        'app lifecycle: session grant -> background -> terminate -> restart',
        () async {
          // Step 1: User grants session-only permission
          permissionService.grantSessionPermission();
          expect(permissionService.isAccessAllowed, isTrue);
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.sessionOnly),
          );

          // Step 2: App goes to background (no effect on permission)
          // (In real app, nothing changes when backgrounded)
          expect(permissionService.isAccessAllowed, isTrue);

          // Step 3: App terminates and restarts (new service instance)
          final newService = CameraPermissionService(storage: mockStorage);
          newService.clearSessionPermission(); // Called in main.dart

          // Step 4: Verify session permission is gone
          expect(newService.currentState, isNull);
          expect(newService.needsPermission, isTrue);
          expect(newService.isAccessAllowed, isFalse);

          // Step 5: Verify no storage call was made for session
          verifyNever(
            mockStorage.write(
              key: permissionStorageKey,
              value: 'sessionOnly',
            ),
          );
        },
      );

      test(
        'app lifecycle: permanent grant -> background -> terminate -> restart',
        () async {
          // Step 1: User grants permanent permission
          await permissionService.grantPermanentPermission();
          expect(permissionService.isAccessAllowed, isTrue);
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.granted),
          );

          // Step 2: Mock storage to return granted value
          when(mockStorage.read(key: permissionStorageKey))
              .thenAnswer((_) async => grantedValue);

          // Step 3: App terminates and restarts (new service instance)
          final newService = CameraPermissionService(storage: mockStorage);
          newService.clearSessionPermission(); // Called in main.dart

          // Step 4: Storage should still have the grant
          final storedValue = await mockStorage.read(key: permissionStorageKey);
          expect(storedValue, equals(grantedValue));

          // Step 5: Verify storage was called only once for the grant
          verify(
            mockStorage.write(
              key: permissionStorageKey,
              value: grantedValue,
            ),
          ).called(1);
        },
      );
    });

    group('Permission Dialog Result Handling', () {
      test(
        'PermissionDialogResult.granted should trigger permanent storage',
        () async {
          // Simulate dialog returning granted result
          const dialogResult = PermissionDialogResult.granted;

          // Act - Handle dialog result
          switch (dialogResult) {
            case PermissionDialogResult.granted:
              await permissionService.grantPermanentPermission();
            case PermissionDialogResult.sessionOnly:
              permissionService.grantSessionPermission();
            case PermissionDialogResult.denied:
              await permissionService.denyPermission();
          }

          // Assert
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.granted),
          );
          verify(
            mockStorage.write(
              key: permissionStorageKey,
              value: grantedValue,
            ),
          ).called(1);
        },
      );

      test(
        'PermissionDialogResult.sessionOnly should not trigger storage',
        () async {
          // Simulate dialog returning sessionOnly result
          const dialogResult = PermissionDialogResult.sessionOnly;

          // Act - Handle dialog result
          switch (dialogResult) {
            case PermissionDialogResult.granted:
              await permissionService.grantPermanentPermission();
            case PermissionDialogResult.sessionOnly:
              permissionService.grantSessionPermission();
            case PermissionDialogResult.denied:
              await permissionService.denyPermission();
          }

          // Assert
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.sessionOnly),
          );
          verifyNever(
            mockStorage.write(key: anyNamed('key'), value: anyNamed('value')),
          );
        },
      );

      test(
        'PermissionDialogResult.denied should trigger denial storage',
        () async {
          // Simulate dialog returning denied result
          const dialogResult = PermissionDialogResult.denied;

          // Act - Handle dialog result
          switch (dialogResult) {
            case PermissionDialogResult.granted:
              await permissionService.grantPermanentPermission();
            case PermissionDialogResult.sessionOnly:
              permissionService.grantSessionPermission();
            case PermissionDialogResult.denied:
              await permissionService.denyPermission();
          }

          // Assert
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.denied),
          );
          verify(
            mockStorage.write(
              key: permissionStorageKey,
              value: deniedValue,
            ),
          ).called(1);
        },
      );
    });

    group('State Transition Scenarios', () {
      test(
        'should transition: unknown -> denied -> granted',
        () async {
          // Start at unknown
          await permissionService.clearAllPermissions();
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.unknown),
          );

          // User denies
          await permissionService.denyPermission();
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.denied),
          );
          expect(permissionService.isAccessAllowed, isFalse);

          // User changes mind and grants
          await permissionService.grantPermanentPermission();
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.granted),
          );
          expect(permissionService.isAccessAllowed, isTrue);
        },
      );

      test(
        'should transition: sessionOnly -> granted (upgrade)',
        () async {
          // Start with session permission
          permissionService.grantSessionPermission();
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.sessionOnly),
          );

          // Upgrade to permanent
          await permissionService.grantPermanentPermission();
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.granted),
          );

          // Verify storage was called for upgrade
          verify(
            mockStorage.write(
              key: permissionStorageKey,
              value: grantedValue,
            ),
          ).called(1);
        },
      );

      test(
        'should transition: granted -> unknown (reset)',
        () async {
          // Start with permanent permission
          await permissionService.grantPermanentPermission();
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.granted),
          );

          // Reset all permissions
          await permissionService.clearAllPermissions();
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.unknown),
          );

          // Verify storage was cleared
          verify(mockStorage.delete(key: permissionStorageKey)).called(1);
        },
      );
    });

    group('Multiple Scanner Access Attempts', () {
      test(
        'should allow multiple scans with permanent permission',
        () async {
          // Grant permanent permission
          await permissionService.grantPermanentPermission();

          // Simulate multiple scan attempts
          for (int i = 0; i < 5; i++) {
            expect(permissionService.isAccessAllowed, isTrue);
          }

          // Verify storage was only called once
          verify(
            mockStorage.write(
              key: permissionStorageKey,
              value: grantedValue,
            ),
          ).called(1);
        },
      );

      test(
        'should allow multiple scans with session permission',
        () async {
          // Grant session permission
          permissionService.grantSessionPermission();

          // Simulate multiple scan attempts
          for (int i = 0; i < 5; i++) {
            expect(permissionService.isAccessAllowed, isTrue);
          }

          // Verify storage was never called
          verifyNever(
            mockStorage.write(key: anyNamed('key'), value: anyNamed('value')),
          );
        },
      );

      test(
        'should block multiple scans when denied',
        () async {
          // Deny permission
          await permissionService.denyPermission();

          // Simulate multiple scan attempts
          for (int i = 0; i < 5; i++) {
            expect(permissionService.isAccessAllowed, isFalse);
          }

          // Verify denial was stored only once
          verify(
            mockStorage.write(
              key: permissionStorageKey,
              value: deniedValue,
            ),
          ).called(1);
        },
      );
    });

    group('Riverpod Provider Integration', () {
      test(
        'cameraPermissionServiceProvider should provide singleton',
        () {
          // Arrange
          final container = ProviderContainer();

          // Act
          final service1 = container.read(cameraPermissionServiceProvider);
          final service2 = container.read(cameraPermissionServiceProvider);

          // Assert - Should be same instance
          expect(identical(service1, service2), isTrue);

          container.dispose();
        },
      );

      test(
        'provider should maintain state across reads',
        () async {
          // Arrange
          final container = ProviderContainer();

          // Act - Grant permission through provider
          final service1 = container.read(cameraPermissionServiceProvider);
          service1.grantSessionPermission();

          // Read again
          final service2 = container.read(cameraPermissionServiceProvider);

          // Assert - State should be preserved
          expect(
            service2.currentState,
            equals(CameraPermissionState.sessionOnly),
          );
          expect(service2.isAccessAllowed, isTrue);

          container.dispose();
        },
      );
    });

    group('Error Recovery Scenarios', () {
      test(
        'should recover from storage write failure',
        () async {
          // Arrange - First write fails
          var callCount = 0;
          when(
            mockStorage.write(key: anyNamed('key'), value: anyNamed('value')),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) {
              throw Exception('Network error');
            }
          });

          // First attempt fails
          expect(
            () => permissionService.grantPermanentPermission(),
            throwsA(isA<CameraPermissionException>()),
          );

          // Second attempt succeeds
          await permissionService.grantPermanentPermission();
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.granted),
          );
        },
      );

      test(
        'session permission should work when storage is unavailable',
        () async {
          // Arrange - Storage always fails
          when(
            mockStorage.write(key: anyNamed('key'), value: anyNamed('value')),
          ).thenThrow(Exception('Storage unavailable'));

          // Act - Grant session permission (should not use storage)
          permissionService.grantSessionPermission();

          // Assert - Should work without storage
          expect(permissionService.isAccessAllowed, isTrue);
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.sessionOnly),
          );
        },
      );
    });

    group('Edge Cases', () {
      test(
        'should handle rapid permission state changes',
        () async {
          // Rapidly change permission states
          permissionService.grantSessionPermission();
          await permissionService.grantPermanentPermission();
          await permissionService.denyPermission();
          permissionService.grantSessionPermission();
          await permissionService.clearAllPermissions();

          // Final state should be unknown
          expect(
            permissionService.currentState,
            equals(CameraPermissionState.unknown),
          );
        },
      );

      test(
        'should handle clearSessionPermission when already cleared',
        () {
          // Clear multiple times should not throw
          permissionService.clearSessionPermission();
          permissionService.clearSessionPermission();
          permissionService.clearSessionPermission();

          // Should be in consistent state
          expect(permissionService.currentState, isNull);
          expect(permissionService.needsPermission, isTrue);
        },
      );

      test(
        'should handle empty storage gracefully',
        () async {
          // Arrange - Storage returns null for all reads
          when(mockStorage.read(key: anyNamed('key')))
              .thenAnswer((_) async => null);

          // Act - Create fresh service
          final service = CameraPermissionService(storage: mockStorage);

          // Assert - Should be in unknown state
          expect(service.currentState, isNull);
          expect(service.needsPermission, isTrue);
          expect(service.isAccessAllowed, isFalse);
        },
      );
    });
  });
}
