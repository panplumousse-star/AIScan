import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:aiscan/features/app_lock/domain/app_lock_service.dart';
import 'package:aiscan/features/app_lock/presentation/lock_screen.dart';

import 'lock_screen_test.mocks.dart';

@GenerateMocks([AppLockService])
void main() {
  late MockAppLockService mockAppLockService;

  setUp(() {
    mockAppLockService = MockAppLockService();
  });

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        appLockServiceProvider.overrideWithValue(mockAppLockService),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('LockScreen widget tests', () {
    testWidgets('displays app icon and name', (tester) async {
      // Act
      await tester.pumpWidget(createTestWidget(const LockScreen()));

      // Assert
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Scanaï'), findsOneWidget);
    });

    testWidgets('displays unlock button when not authenticating',
        (tester) async {
      // Act
      await tester.pumpWidget(createTestWidget(const LockScreen()));

      // Assert
      expect(find.text('Unlock with Biometric'), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint), findsOneWidget);
    });

    testWidgets('displays loading indicator during authentication',
        (tester) async {
      // Arrange
      when(mockAppLockService.authenticateUser())
          .thenAnswer((_) => Future.delayed(
                const Duration(milliseconds: 100),
                () => true,
              ));
      when(mockAppLockService.recordSuccessfulAuth()).thenReturn(null);

      // Act
      await tester.pumpWidget(createTestWidget(const LockScreen()));
      await tester.tap(find.text('Unlock with Biometric'));
      await tester.pump();

      // Assert - during authentication
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Unlock with Biometric'), findsNothing);

      // Complete the authentication
      await tester.pumpAndSettle();
    });

    testWidgets('hides unlock button during authentication', (tester) async {
      // Arrange
      when(mockAppLockService.authenticateUser())
          .thenAnswer((_) => Future.delayed(
                const Duration(milliseconds: 100),
                () => true,
              ));
      when(mockAppLockService.recordSuccessfulAuth()).thenReturn(null);

      // Act
      await tester.pumpWidget(createTestWidget(const LockScreen()));
      await tester.tap(find.text('Unlock with Biometric'));
      await tester.pump();

      // Assert
      expect(find.text('Unlock with Biometric'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the authentication
      await tester.pumpAndSettle();
    });

    testWidgets('displays error message in error container when auth fails',
        (tester) async {
      // Arrange
      when(mockAppLockService.authenticateUser())
          .thenAnswer((_) async => false);

      // Act
      await tester.pumpWidget(createTestWidget(const LockScreen()));
      await tester.tap(find.text('Unlock with Biometric'));
      await tester.pumpAndSettle();

      // Assert
      expect(
        find.text('Authentication failed. Please try again.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('error message can be dismissed via close button',
        (tester) async {
      // Arrange
      when(mockAppLockService.authenticateUser())
          .thenAnswer((_) async => false);

      // Act
      await tester.pumpWidget(createTestWidget(const LockScreen()));
      await tester.tap(find.text('Unlock with Biometric'));
      await tester.pumpAndSettle();

      // Assert - error is visible
      expect(
        find.text('Authentication failed. Please try again.'),
        findsOneWidget,
      );

      // Dismiss error
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Assert - error is dismissed
      expect(
        find.text('Authentication failed. Please try again.'),
        findsNothing,
      );
    });

    testWidgets('tapping unlock button triggers authentication',
        (tester) async {
      // Arrange
      when(mockAppLockService.authenticateUser()).thenAnswer((_) async => true);

      // Act
      await tester.pumpWidget(createTestWidget(const LockScreen()));
      await tester.tap(find.text('Unlock with Biometric'));
      await tester.pumpAndSettle();

      // Assert
      verify(mockAppLockService.authenticateUser()).called(1);
    });

    testWidgets('successful authentication triggers navigation callback',
        (tester) async {
      // Arrange
      when(mockAppLockService.authenticateUser()).thenAnswer((_) async => true);
      when(mockAppLockService.recordSuccessfulAuth()).thenReturn(null);

      // Create a navigator to track pops
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLockServiceProvider.overrideWithValue(mockAppLockService),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LockScreen()),
                ),
                child: const Text('Open Lock Screen'),
              ),
            ),
          ),
        ),
      );

      // Open lock screen
      await tester.tap(find.text('Open Lock Screen'));
      await tester.pumpAndSettle();

      // Assert lock screen is visible
      expect(find.text('Scanaï'), findsOneWidget);

      // Act - authenticate
      await tester.tap(find.text('Unlock with Biometric'));
      await tester.pumpAndSettle();

      // Assert - lock screen was popped
      expect(find.text('Scanaï'), findsNothing);
      expect(find.text('Open Lock Screen'), findsOneWidget);
      verify(mockAppLockService.recordSuccessfulAuth()).called(1);
    });
  });

  group('LockScreenNotifier tests', () {
    test('initial state has isAuthenticating false and no error', () {
      // Arrange
      final notifier = LockScreenNotifier(mockAppLockService);

      // Assert
      expect(notifier.state.isAuthenticating, isFalse);
      expect(notifier.state.error, isNull);
    });

    test('authenticate sets isAuthenticating true while authenticating',
        () async {
      // Arrange
      final notifier = LockScreenNotifier(mockAppLockService);
      when(mockAppLockService.authenticateUser())
          .thenAnswer((_) => Future.delayed(
                const Duration(milliseconds: 50),
                () => true,
              ));

      // Act
      final authFuture = notifier.authenticate();

      // Assert - during authentication
      expect(notifier.state.isAuthenticating, isTrue);

      // Wait for completion
      await authFuture;
    });

    test('successful auth records timestamp and calls success callback',
        () async {
      // Arrange
      final notifier = LockScreenNotifier(mockAppLockService);
      when(mockAppLockService.authenticateUser()).thenAnswer((_) async => true);
      when(mockAppLockService.recordSuccessfulAuth()).thenReturn(null);

      var callbackCalled = false;
      notifier.onAuthenticationSuccess = () {
        callbackCalled = true;
      };

      // Act
      final result = await notifier.authenticate();

      // Assert
      expect(result, isTrue);
      expect(notifier.state.isAuthenticating, isFalse);
      expect(notifier.state.error, isNull);
      expect(callbackCalled, isTrue);
      verify(mockAppLockService.recordSuccessfulAuth()).called(1);
    });

    test('failed auth sets error message and isAuthenticating false', () async {
      // Arrange
      final notifier = LockScreenNotifier(mockAppLockService);
      when(mockAppLockService.authenticateUser())
          .thenAnswer((_) async => false);

      // Act
      final result = await notifier.authenticate();

      // Assert
      expect(result, isFalse);
      expect(notifier.state.isAuthenticating, isFalse);
      expect(
        notifier.state.error,
        'Authentication failed. Please try again.',
      );
    });

    test('exception during auth sets error message with exception details',
        () async {
      // Arrange
      final notifier = LockScreenNotifier(mockAppLockService);
      when(mockAppLockService.authenticateUser())
          .thenThrow(Exception('System error'));

      // Act
      final result = await notifier.authenticate();

      // Assert
      expect(result, isFalse);
      expect(notifier.state.isAuthenticating, isFalse);
      expect(notifier.state.error, contains('unexpected error'));
      expect(notifier.state.error, contains('System error'));
    });

    test('clearError removes error message from state', () async {
      // Arrange
      final notifier = LockScreenNotifier(mockAppLockService);
      when(mockAppLockService.authenticateUser())
          .thenAnswer((_) async => false);

      // Set up error state
      await notifier.authenticate();
      expect(notifier.state.error, isNotNull);

      // Act
      notifier.clearError();

      // Assert
      expect(notifier.state.error, isNull);
    });
  });

  group('LockScreenState', () {
    test('copyWith updates isAuthenticating', () {
      // Arrange
      const state = LockScreenState();

      // Act
      final newState = state.copyWith(isAuthenticating: true);

      // Assert
      expect(newState.isAuthenticating, isTrue);
      expect(newState.error, isNull);
    });

    test('copyWith updates error', () {
      // Arrange
      const state = LockScreenState();

      // Act
      final newState = state.copyWith(error: 'Test error');

      // Assert
      expect(newState.isAuthenticating, isFalse);
      expect(newState.error, 'Test error');
    });

    test('copyWith clears error when error is set to null', () {
      // Arrange
      const state = LockScreenState(error: 'Old error');

      // Act
      final newState = state.copyWith(error: null);

      // Assert
      expect(newState.error, isNull);
    });

    test('equality works correctly', () {
      // Arrange
      const state1 = LockScreenState(isAuthenticating: true, error: 'Error');
      const state2 = LockScreenState(isAuthenticating: true, error: 'Error');
      const state3 = LockScreenState(error: 'Error');

      // Assert
      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('hashCode is consistent', () {
      // Arrange
      const state1 = LockScreenState(isAuthenticating: true, error: 'Error');
      const state2 = LockScreenState(isAuthenticating: true, error: 'Error');

      // Assert
      expect(state1.hashCode, equals(state2.hashCode));
    });
  });
}
