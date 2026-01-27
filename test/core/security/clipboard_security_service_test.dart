
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:aiscan/core/security/clipboard_security_service.dart';
import 'package:aiscan/core/security/secure_storage_service.dart';
import 'package:aiscan/core/security/sensitive_data_detector.dart';

import 'clipboard_security_service_test.mocks.dart';

@GenerateMocks([SecureStorageService, SensitiveDataDetector])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSecureStorageService mockSecureStorage;
  late MockSensitiveDataDetector mockSensitiveDetector;
  late ClipboardSecurityService clipboardService;

  setUp(() {
    mockSecureStorage = MockSecureStorageService();
    mockSensitiveDetector = MockSensitiveDataDetector();
    clipboardService = ClipboardSecurityService(
      secureStorage: mockSecureStorage,
      sensitiveDataDetector: mockSensitiveDetector,
    );

    // Set up mock clipboard
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform,
            (MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        return null;
      }
      return null;
    });

    // Default mock behavior - security and detection disabled by default
    when(mockSecureStorage.getUserData('clipboard_security_enabled'))
        .thenAnswer((_) async => null);
    when(mockSecureStorage.getUserData('clipboard_auto_clear_timeout'))
        .thenAnswer((_) async => null);
    when(mockSecureStorage.getUserData(
            'clipboard_sensitive_detection_enabled'))
        .thenAnswer((_) async => null);
  });

  tearDown(() {
    clipboardService.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('ClipboardSecurityService', () {
    group('copyToClipboard', () {
      test('should copy text to clipboard when no sensitive data', () async {
        // Arrange
        const text = 'This is normal text';
        when(mockSecureStorage.getUserData(
                'clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => 'true');
        when(mockSensitiveDetector.detectSensitiveData(text))
            .thenReturn(SensitiveDataDetectionResult.noSensitiveData());

        // Act
        final result = await clipboardService.copyToClipboard(text);

        // Assert
        expect(result.success, isTrue);
        expect(result.hasSensitiveData, isFalse);
        expect(result.detectionResult, isNotNull);
        expect(result.willAutoClear, isFalse);
      });

      test('should detect sensitive data when detection enabled', () async {
        // Arrange
        const text = 'My SSN is 123-45-6789';
        final detectionResult = const SensitiveDataDetectionResult(
          hasSensitiveData: true,
          detectedTypes: {SensitiveDataType.ssn},
          confidenceScore: 0.8,
          detectionCount: 1,
        );

        when(mockSecureStorage.getUserData(
                'clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => 'true');
        when(mockSensitiveDetector.detectSensitiveData(text))
            .thenReturn(detectionResult);

        // Act
        final result = await clipboardService.copyToClipboard(text);

        // Assert
        expect(result.success, isTrue);
        expect(result.hasSensitiveData, isTrue);
        expect(result.detectionResult, equals(detectionResult));
      });

      test('should skip detection when detection disabled', () async {
        // Arrange
        const text = 'My SSN is 123-45-6789';
        when(mockSecureStorage.getUserData(
                'clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => 'false');

        // Act
        final result = await clipboardService.copyToClipboard(text);

        // Assert
        expect(result.success, isTrue);
        expect(result.hasSensitiveData, isFalse);
        expect(result.detectionResult, isNull);
        verifyNever(mockSensitiveDetector.detectSensitiveData(any));
      });

      test('should call callback when sensitive data detected', () async {
        // Arrange
        const text = 'My SSN is 123-45-6789';
        final detectionResult = const SensitiveDataDetectionResult(
          hasSensitiveData: true,
          detectedTypes: {SensitiveDataType.ssn},
          confidenceScore: 0.8,
          detectionCount: 1,
        );

        when(mockSecureStorage.getUserData(
                'clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => 'true');
        when(mockSensitiveDetector.detectSensitiveData(text))
            .thenReturn(detectionResult);

        var callbackInvoked = false;
        SensitiveDataDetectionResult? callbackResult;

        // Act
        final result = await clipboardService.copyToClipboard(
          text,
          onSensitiveDataDetected: (detection) async {
            callbackInvoked = true;
            callbackResult = detection;
            return true; // Proceed with copy
          },
        );

        // Assert
        expect(callbackInvoked, isTrue);
        expect(callbackResult, equals(detectionResult));
        expect(result.success, isTrue);
        expect(result.hasSensitiveData, isTrue);
      });

      test('should cancel copy when callback returns false', () async {
        // Arrange
        const text = 'My SSN is 123-45-6789';
        final detectionResult = const SensitiveDataDetectionResult(
          hasSensitiveData: true,
          detectedTypes: {SensitiveDataType.ssn},
          confidenceScore: 0.8,
          detectionCount: 1,
        );

        when(mockSecureStorage.getUserData(
                'clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => 'true');
        when(mockSensitiveDetector.detectSensitiveData(text))
            .thenReturn(detectionResult);

        // Act
        final result = await clipboardService.copyToClipboard(
          text,
          onSensitiveDataDetected: (detection) async => false, // Cancel
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.hasSensitiveData, isTrue);
        expect(result.errorMessage, contains('User cancelled'));
      });

      test('should schedule auto-clear when security enabled', () async {
        // Arrange
        const text = 'Test text';
        when(mockSecureStorage.getUserData(
                'clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => 'false');
        when(mockSecureStorage.getUserData('clipboard_security_enabled'))
            .thenAnswer((_) async => 'true');
        when(mockSecureStorage.getUserData('clipboard_auto_clear_timeout'))
            .thenAnswer((_) async => '30');
        when(mockSensitiveDetector.detectSensitiveData(text))
            .thenReturn(SensitiveDataDetectionResult.noSensitiveData());

        // Act
        final result = await clipboardService.copyToClipboard(text);

        // Assert
        expect(result.success, isTrue);
        expect(result.willAutoClear, isTrue);
        expect(result.autoClearDuration, equals(const Duration(seconds: 30)));
      });

      test('should not schedule auto-clear when security disabled', () async {
        // Arrange
        const text = 'Test text';
        when(mockSecureStorage.getUserData(
                'clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => 'false');
        when(mockSecureStorage.getUserData('clipboard_security_enabled'))
            .thenAnswer((_) async => 'false');

        // Act
        final result = await clipboardService.copyToClipboard(text);

        // Assert
        expect(result.success, isTrue);
        expect(result.willAutoClear, isFalse);
        expect(result.autoClearDuration, isNull);
      });

      test('should cancel existing timer before scheduling new one', () async {
        // Arrange
        const text1 = 'First text';
        const text2 = 'Second text';
        when(mockSecureStorage.getUserData(
                'clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => 'false');
        when(mockSecureStorage.getUserData('clipboard_security_enabled'))
            .thenAnswer((_) async => 'true');
        when(mockSecureStorage.getUserData('clipboard_auto_clear_timeout'))
            .thenAnswer((_) async => '30');

        // Act - copy twice
        await clipboardService.copyToClipboard(text1);
        await clipboardService.copyToClipboard(text2);

        // Assert - should not throw, timer should be replaced
        expect(true, isTrue);
      });

      test('should throw ClipboardSecurityException on failure', () async {
        // Arrange
        const text = 'Test text';
        when(mockSecureStorage.getUserData(
                'clipboard_sensitive_detection_enabled'))
            .thenThrow(SecureStorageException('Storage error'));

        // Act & Assert
        expect(
          () => clipboardService.copyToClipboard(text),
          throwsA(isA<ClipboardSecurityException>()),
        );
      });

      test('should handle both sensitive detection and auto-clear', () async {
        // Arrange
        const text = 'My SSN is 123-45-6789';
        final detectionResult = const SensitiveDataDetectionResult(
          hasSensitiveData: true,
          detectedTypes: {SensitiveDataType.ssn},
          confidenceScore: 0.8,
          detectionCount: 1,
        );

        when(mockSecureStorage.getUserData(
                'clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => 'true');
        when(mockSecureStorage.getUserData('clipboard_security_enabled'))
            .thenAnswer((_) async => 'true');
        when(mockSecureStorage.getUserData('clipboard_auto_clear_timeout'))
            .thenAnswer((_) async => '60');
        when(mockSensitiveDetector.detectSensitiveData(text))
            .thenReturn(detectionResult);

        // Act
        final result = await clipboardService.copyToClipboard(
          text,
          onSensitiveDataDetected: (detection) async => true,
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.hasSensitiveData, isTrue);
        expect(result.willAutoClear, isTrue);
        expect(result.autoClearDuration, equals(const Duration(seconds: 60)));
      });
    });

    group('clearClipboard', () {
      test('should clear clipboard successfully', () async {
        // Act
        await clipboardService.clearClipboard();

        // Assert - should not throw
        expect(true, isTrue);
      });

      test('should cancel pending auto-clear timer', () async {
        // Arrange - set up auto-clear
        const text = 'Test text';
        when(mockSecureStorage.getUserData(
                'clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => 'false');
        when(mockSecureStorage.getUserData('clipboard_security_enabled'))
            .thenAnswer((_) async => 'true');
        when(mockSecureStorage.getUserData('clipboard_auto_clear_timeout'))
            .thenAnswer((_) async => '30');

        await clipboardService.copyToClipboard(text);

        // Act - manually clear
        await clipboardService.clearClipboard();

        // Assert - should not throw
        expect(true, isTrue);
      });

      test('should handle clipboard failure gracefully (best-effort)',
          () async {
        // Arrange - simulate clipboard failure
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform,
                (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            throw PlatformException(code: 'ERROR');
          }
          return null;
        });

        // Act - clearClipboard is best-effort and should not throw
        await clipboardService.clearClipboard();

        // Assert - should complete without throwing
        expect(true, isTrue);
      });
    });

    group('cancelAutoClear', () {
      test('should cancel pending auto-clear timer', () async {
        // Arrange - set up auto-clear
        const text = 'Test text';
        when(mockSecureStorage.getUserData(
                'clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => 'false');
        when(mockSecureStorage.getUserData('clipboard_security_enabled'))
            .thenAnswer((_) async => 'true');
        when(mockSecureStorage.getUserData('clipboard_auto_clear_timeout'))
            .thenAnswer((_) async => '30');

        await clipboardService.copyToClipboard(text);

        // Act
        clipboardService.cancelAutoClear();

        // Assert - should not throw
        expect(true, isTrue);
      });

      test('should be safe to call when no timer is active', () {
        // Act & Assert
        expect(() => clipboardService.cancelAutoClear(), returnsNormally);
      });

      test('should be safe to call multiple times', () {
        // Act & Assert
        clipboardService.cancelAutoClear();
        expect(() => clipboardService.cancelAutoClear(), returnsNormally);
      });
    });

    group('isSecurityEnabled', () {
      test('should return true when security is enabled', () async {
        // Arrange
        when(mockSecureStorage.getUserData('clipboard_security_enabled'))
            .thenAnswer((_) async => 'true');

        // Act
        final result = await clipboardService.isSecurityEnabled();

        // Assert
        expect(result, isTrue);
      });

      test('should return false when security is disabled', () async {
        // Arrange
        when(mockSecureStorage.getUserData('clipboard_security_enabled'))
            .thenAnswer((_) async => 'false');

        // Act
        final result = await clipboardService.isSecurityEnabled();

        // Assert
        expect(result, isFalse);
      });

      test('should return false when setting not configured', () async {
        // Arrange
        when(mockSecureStorage.getUserData('clipboard_security_enabled'))
            .thenAnswer((_) async => null);

        // Act
        final result = await clipboardService.isSecurityEnabled();

        // Assert
        expect(result, isFalse);
      });

      test('should throw ClipboardSecurityException on storage error',
          () async {
        // Arrange
        when(mockSecureStorage.getUserData('clipboard_security_enabled'))
            .thenThrow(SecureStorageException('Storage error'));

        // Act & Assert
        expect(
          () => clipboardService.isSecurityEnabled(),
          throwsA(isA<ClipboardSecurityException>()),
        );
      });
    });

    group('setSecurityEnabled', () {
      test('should enable security', () async {
        // Arrange
        when(mockSecureStorage.storeUserData(
                'clipboard_security_enabled', 'true'))
            .thenAnswer((_) async => {});

        // Act
        await clipboardService.setSecurityEnabled(true);

        // Assert
        verify(mockSecureStorage.storeUserData(
                'clipboard_security_enabled', 'true'))
            .called(1);
      });

      test('should disable security', () async {
        // Arrange
        when(mockSecureStorage.storeUserData(
                'clipboard_security_enabled', 'false'))
            .thenAnswer((_) async => {});

        // Act
        await clipboardService.setSecurityEnabled(false);

        // Assert
        verify(mockSecureStorage.storeUserData(
                'clipboard_security_enabled', 'false'))
            .called(1);
      });

      test('should cancel timer when disabling security', () async {
        // Arrange - set up auto-clear first
        const text = 'Test text';
        when(mockSecureStorage.getUserData(
                'clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => 'false');
        when(mockSecureStorage.getUserData('clipboard_security_enabled'))
            .thenAnswer((_) async => 'true');
        when(mockSecureStorage.getUserData('clipboard_auto_clear_timeout'))
            .thenAnswer((_) async => '30');
        when(mockSecureStorage.storeUserData(
                'clipboard_security_enabled', 'false'))
            .thenAnswer((_) async => {});

        await clipboardService.copyToClipboard(text);

        // Act - disable security
        await clipboardService.setSecurityEnabled(false);

        // Assert - should not throw
        expect(true, isTrue);
      });

      test('should throw ClipboardSecurityException on storage error',
          () async {
        // Arrange
        when(mockSecureStorage.storeUserData(
                'clipboard_security_enabled', 'true'))
            .thenThrow(SecureStorageException('Storage error'));

        // Act & Assert
        expect(
          () => clipboardService.setSecurityEnabled(true),
          throwsA(isA<ClipboardSecurityException>()),
        );
      });
    });

    group('getAutoClearTimeout', () {
      test('should return configured timeout', () async {
        // Arrange
        when(mockSecureStorage.getUserData('clipboard_auto_clear_timeout'))
            .thenAnswer((_) async => '60');

        // Act
        final result = await clipboardService.getAutoClearTimeout();

        // Assert
        expect(result, equals(const Duration(seconds: 60)));
      });

      test('should return default timeout when not configured', () async {
        // Arrange
        when(mockSecureStorage.getUserData('clipboard_auto_clear_timeout'))
            .thenAnswer((_) async => null);

        // Act
        final result = await clipboardService.getAutoClearTimeout();

        // Assert
        expect(result,
            equals(ClipboardSecurityService.defaultAutoClearTimeout));
      });

      test('should return default timeout for invalid value', () async {
        // Arrange
        when(mockSecureStorage.getUserData('clipboard_auto_clear_timeout'))
            .thenAnswer((_) async => 'invalid');

        // Act
        final result = await clipboardService.getAutoClearTimeout();

        // Assert
        expect(result,
            equals(ClipboardSecurityService.defaultAutoClearTimeout));
      });

      test('should throw ClipboardSecurityException on storage error',
          () async {
        // Arrange
        when(mockSecureStorage.getUserData('clipboard_auto_clear_timeout'))
            .thenThrow(SecureStorageException('Storage error'));

        // Act & Assert
        expect(
          () => clipboardService.getAutoClearTimeout(),
          throwsA(isA<ClipboardSecurityException>()),
        );
      });
    });

    group('setAutoClearTimeout', () {
      test('should set timeout successfully', () async {
        // Arrange
        const timeout = Duration(seconds: 60);
        when(mockSecureStorage.storeUserData(
                'clipboard_auto_clear_timeout', '60'))
            .thenAnswer((_) async => {});

        // Act
        await clipboardService.setAutoClearTimeout(timeout);

        // Assert
        verify(mockSecureStorage.storeUserData(
                'clipboard_auto_clear_timeout', '60'))
            .called(1);
      });

      test('should handle various timeout durations', () async {
        // Arrange
        final timeouts = [
          const Duration(seconds: 15),
          const Duration(seconds: 30),
          const Duration(seconds: 120),
          const Duration(minutes: 5),
        ];

        for (final timeout in timeouts) {
          when(mockSecureStorage.storeUserData(
                  'clipboard_auto_clear_timeout', timeout.inSeconds.toString()))
              .thenAnswer((_) async => {});

          // Act
          await clipboardService.setAutoClearTimeout(timeout);

          // Assert
          verify(mockSecureStorage.storeUserData('clipboard_auto_clear_timeout',
                  timeout.inSeconds.toString()))
              .called(1);
        }
      });

      test('should throw ArgumentError for zero timeout', () async {
        // Act & Assert
        expect(
          () => clipboardService.setAutoClearTimeout(Duration.zero),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for negative timeout', () async {
        // Act & Assert
        expect(
          () =>
              clipboardService.setAutoClearTimeout(const Duration(seconds: -1)),
          throwsArgumentError,
        );
      });

      test('should throw ClipboardSecurityException on storage error',
          () async {
        // Arrange
        when(mockSecureStorage.storeUserData(
                'clipboard_auto_clear_timeout', '60'))
            .thenThrow(SecureStorageException('Storage error'));

        // Act & Assert
        expect(
          () =>
              clipboardService.setAutoClearTimeout(const Duration(seconds: 60)),
          throwsA(isA<ClipboardSecurityException>()),
        );
      });
    });

    group('isSensitiveDetectionEnabled', () {
      test('should return true when detection is enabled', () async {
        // Arrange
        when(mockSecureStorage
                .getUserData('clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => 'true');

        // Act
        final result = await clipboardService.isSensitiveDetectionEnabled();

        // Assert
        expect(result, isTrue);
      });

      test('should return false when detection is disabled', () async {
        // Arrange
        when(mockSecureStorage
                .getUserData('clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => 'false');

        // Act
        final result = await clipboardService.isSensitiveDetectionEnabled();

        // Assert
        expect(result, isFalse);
      });

      test('should return true when setting not configured (default)',
          () async {
        // Arrange
        when(mockSecureStorage
                .getUserData('clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => null);

        // Act
        final result = await clipboardService.isSensitiveDetectionEnabled();

        // Assert
        expect(result, isTrue); // Default is enabled
      });

      test('should throw ClipboardSecurityException on storage error',
          () async {
        // Arrange
        when(mockSecureStorage
                .getUserData('clipboard_sensitive_detection_enabled'))
            .thenThrow(SecureStorageException('Storage error'));

        // Act & Assert
        expect(
          () => clipboardService.isSensitiveDetectionEnabled(),
          throwsA(isA<ClipboardSecurityException>()),
        );
      });
    });

    group('setSensitiveDetectionEnabled', () {
      test('should enable detection', () async {
        // Arrange
        when(mockSecureStorage.storeUserData(
                'clipboard_sensitive_detection_enabled', 'true'))
            .thenAnswer((_) async => {});

        // Act
        await clipboardService.setSensitiveDetectionEnabled(true);

        // Assert
        verify(mockSecureStorage.storeUserData(
                'clipboard_sensitive_detection_enabled', 'true'))
            .called(1);
      });

      test('should disable detection', () async {
        // Arrange
        when(mockSecureStorage.storeUserData(
                'clipboard_sensitive_detection_enabled', 'false'))
            .thenAnswer((_) async => {});

        // Act
        await clipboardService.setSensitiveDetectionEnabled(false);

        // Assert
        verify(mockSecureStorage.storeUserData(
                'clipboard_sensitive_detection_enabled', 'false'))
            .called(1);
      });

      test('should throw ClipboardSecurityException on storage error',
          () async {
        // Arrange
        when(mockSecureStorage.storeUserData(
                'clipboard_sensitive_detection_enabled', 'true'))
            .thenThrow(SecureStorageException('Storage error'));

        // Act & Assert
        expect(
          () => clipboardService.setSensitiveDetectionEnabled(true),
          throwsA(isA<ClipboardSecurityException>()),
        );
      });
    });

    group('getSettings', () {
      test('should return all settings', () async {
        // Arrange
        when(mockSecureStorage.getUserData('clipboard_security_enabled'))
            .thenAnswer((_) async => 'true');
        when(mockSecureStorage.getUserData('clipboard_auto_clear_timeout'))
            .thenAnswer((_) async => '60');
        when(mockSecureStorage
                .getUserData('clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => 'false');

        // Act
        final settings = await clipboardService.getSettings();

        // Assert
        expect(settings['securityEnabled'], isTrue);
        expect(settings['autoClearTimeout'], equals(60));
        expect(settings['sensitiveDetectionEnabled'], isFalse);
      });

      test('should return default values when not configured', () async {
        // Arrange
        when(mockSecureStorage.getUserData('clipboard_security_enabled'))
            .thenAnswer((_) async => null);
        when(mockSecureStorage.getUserData('clipboard_auto_clear_timeout'))
            .thenAnswer((_) async => null);
        when(mockSecureStorage
                .getUserData('clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => null);

        // Act
        final settings = await clipboardService.getSettings();

        // Assert
        expect(settings['securityEnabled'], isFalse);
        expect(settings['autoClearTimeout'], equals(30)); // Default
        expect(settings['sensitiveDetectionEnabled'], isTrue); // Default
      });

      test('should throw ClipboardSecurityException on storage error',
          () async {
        // Arrange
        when(mockSecureStorage.getUserData('clipboard_security_enabled'))
            .thenThrow(SecureStorageException('Storage error'));

        // Act & Assert
        expect(
          () => clipboardService.getSettings(),
          throwsA(isA<ClipboardSecurityException>()),
        );
      });
    });

    group('resetSettings', () {
      test('should reset all settings to defaults', () async {
        // Arrange
        when(mockSecureStorage.storeUserData(
                'clipboard_security_enabled', 'false'))
            .thenAnswer((_) async => {});
        when(mockSecureStorage.storeUserData(
                'clipboard_auto_clear_timeout', '30'))
            .thenAnswer((_) async => {});
        when(mockSecureStorage.storeUserData(
                'clipboard_sensitive_detection_enabled', 'true'))
            .thenAnswer((_) async => {});

        // Act
        await clipboardService.resetSettings();

        // Assert
        verify(mockSecureStorage.storeUserData(
                'clipboard_security_enabled', 'false'))
            .called(1);
        verify(mockSecureStorage.storeUserData(
                'clipboard_auto_clear_timeout', '30'))
            .called(1);
        verify(mockSecureStorage.storeUserData(
                'clipboard_sensitive_detection_enabled', 'true'))
            .called(1);
      });

      test('should cancel any active timers', () async {
        // Arrange - set up auto-clear first
        const text = 'Test text';
        when(mockSecureStorage.getUserData(
                'clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => 'false');
        when(mockSecureStorage.getUserData('clipboard_security_enabled'))
            .thenAnswer((_) async => 'true');
        when(mockSecureStorage.getUserData('clipboard_auto_clear_timeout'))
            .thenAnswer((_) async => '30');
        when(mockSecureStorage.storeUserData(
                'clipboard_security_enabled', 'false'))
            .thenAnswer((_) async => {});
        when(mockSecureStorage.storeUserData(
                'clipboard_auto_clear_timeout', '30'))
            .thenAnswer((_) async => {});
        when(mockSecureStorage.storeUserData(
                'clipboard_sensitive_detection_enabled', 'true'))
            .thenAnswer((_) async => {});

        await clipboardService.copyToClipboard(text);

        // Act
        await clipboardService.resetSettings();

        // Assert - should not throw
        expect(true, isTrue);
      });

      test('should throw ClipboardSecurityException on storage error',
          () async {
        // Arrange
        when(mockSecureStorage.storeUserData(
                'clipboard_security_enabled', 'false'))
            .thenThrow(SecureStorageException('Storage error'));

        // Act & Assert
        expect(
          () => clipboardService.resetSettings(),
          throwsA(isA<ClipboardSecurityException>()),
        );
      });
    });

    group('dispose', () {
      test('should cancel active timers', () async {
        // Arrange - set up auto-clear
        const text = 'Test text';
        when(mockSecureStorage.getUserData(
                'clipboard_sensitive_detection_enabled'))
            .thenAnswer((_) async => 'false');
        when(mockSecureStorage.getUserData('clipboard_security_enabled'))
            .thenAnswer((_) async => 'true');
        when(mockSecureStorage.getUserData('clipboard_auto_clear_timeout'))
            .thenAnswer((_) async => '30');

        await clipboardService.copyToClipboard(text);

        // Act
        clipboardService.dispose();

        // Assert - should not throw
        expect(true, isTrue);
      });

      test('should be safe to call multiple times', () {
        // Act & Assert
        clipboardService.dispose();
        expect(() => clipboardService.dispose(), returnsNormally);
      });
    });
  });

  group('ClipboardSecurityException', () {
    test('should format message without cause', () {
      // Arrange
      const exception = ClipboardSecurityException('Test error');

      // Act
      final message = exception.toString();

      // Assert
      expect(message, equals('ClipboardSecurityException: Test error'));
    });

    test('should format message with cause', () {
      // Arrange
      final cause = Exception('Root cause');
      final exception = ClipboardSecurityException('Test error', cause: cause);

      // Act
      final message = exception.toString();

      // Assert
      expect(
        message,
        equals(
          'ClipboardSecurityException: Test error (caused by: Exception: Root cause)',
        ),
      );
    });

    test('should store message and cause', () {
      // Arrange
      final cause = Exception('Root cause');
      const errorMessage = 'Test error';
      final exception = ClipboardSecurityException(errorMessage, cause: cause);

      // Assert
      expect(exception.message, equals(errorMessage));
      expect(exception.cause, equals(cause));
    });
  });

  group('ClipboardCopyResult', () {
    test('should create result with all parameters', () {
      // Arrange
      final detectionResult = const SensitiveDataDetectionResult(
        hasSensitiveData: true,
        detectedTypes: {SensitiveDataType.ssn},
        confidenceScore: 0.8,
        detectionCount: 1,
      );

      // Act
      final result = ClipboardCopyResult(
        success: true,
        hasSensitiveData: true,
        detectionResult: detectionResult,
        willAutoClear: true,
        autoClearDuration: const Duration(seconds: 30),
      );

      // Assert
      expect(result.success, isTrue);
      expect(result.hasSensitiveData, isTrue);
      expect(result.detectionResult, equals(detectionResult));
      expect(result.errorMessage, isNull);
      expect(result.willAutoClear, isTrue);
      expect(result.autoClearDuration, equals(const Duration(seconds: 30)));
    });

    test('should format toString correctly', () {
      // Arrange
      const result = ClipboardCopyResult(
        success: true,
        hasSensitiveData: false,
        willAutoClear: true,
        autoClearDuration: Duration(seconds: 30),
      );

      // Act
      final str = result.toString();

      // Assert
      expect(str, contains('success: true'));
      expect(str, contains('hasSensitiveData: false'));
      expect(str, contains('willAutoClear: true'));
      expect(str, contains('autoClearDuration: 0:00:30'));
    });
  });

  group('clipboardSecurityServiceProvider', () {
    test(
        'should provide ClipboardSecurityService with dependencies', () {
      // Arrange
      final container = ProviderContainer();

      // Act
      final service = container.read(clipboardSecurityServiceProvider);

      // Assert
      expect(service, isA<ClipboardSecurityService>());

      container.dispose();
    });
  });
}
