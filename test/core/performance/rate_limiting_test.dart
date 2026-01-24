import 'package:flutter_test/flutter_test.dart';

import 'package:aiscan/core/performance/rate_limiting.dart';

void main() {
  group('Debouncer', () {
    group('run', () {
      test('should execute action after debounce duration', () async {
        // Arrange
        final debouncer = Debouncer(duration: Duration(milliseconds: 100));
        var callCount = 0;

        // Act
        debouncer.run(() => callCount++);

        // Assert - should not execute immediately
        expect(callCount, equals(0));
        expect(debouncer.isPending, isTrue);

        // Wait for debounce duration
        await Future.delayed(Duration(milliseconds: 150));
        expect(callCount, equals(1));
        expect(debouncer.isPending, isFalse);

        // Cleanup
        debouncer.dispose();
      });

      test('should cancel previous action when called multiple times', () async {
        // Arrange
        final debouncer = Debouncer(duration: Duration(milliseconds: 100));
        var callCount = 0;

        // Act - call multiple times rapidly
        debouncer.run(() => callCount++);
        await Future.delayed(Duration(milliseconds: 50));
        debouncer.run(() => callCount++);
        await Future.delayed(Duration(milliseconds: 50));
        debouncer.run(() => callCount++);

        // Assert - only last action should execute
        expect(callCount, equals(0));
        expect(debouncer.isPending, isTrue);

        // Wait for debounce duration
        await Future.delayed(Duration(milliseconds: 150));
        expect(callCount, equals(1));

        // Cleanup
        debouncer.dispose();
      });

      test('should handle rapid successive calls correctly', () async {
        // Arrange
        final debouncer = Debouncer(duration: Duration(milliseconds: 100));
        var lastValue = 0;

        // Act - simulate typing in search field
        for (var i = 1; i <= 5; i++) {
          debouncer.run(() => lastValue = i);
          await Future.delayed(Duration(milliseconds: 20));
        }

        // Assert - only last value should be set
        expect(lastValue, equals(0));
        expect(debouncer.isPending, isTrue);

        // Wait for debounce duration
        await Future.delayed(Duration(milliseconds: 150));
        expect(lastValue, equals(5));

        // Cleanup
        debouncer.dispose();
      });

      test('should allow multiple executions if time between calls exceeds duration',
          () async {
        // Arrange
        final debouncer = Debouncer(duration: Duration(milliseconds: 50));
        var callCount = 0;

        // Act
        debouncer.run(() => callCount++);
        await Future.delayed(Duration(milliseconds: 100));

        debouncer.run(() => callCount++);
        await Future.delayed(Duration(milliseconds: 100));

        // Assert
        expect(callCount, equals(2));

        // Cleanup
        debouncer.dispose();
      });

      test('should update isPending status correctly', () async {
        // Arrange
        final debouncer = Debouncer(duration: Duration(milliseconds: 50));

        // Act & Assert - initially not pending
        expect(debouncer.isPending, isFalse);

        // Schedule action
        debouncer.run(() {});
        expect(debouncer.isPending, isTrue);

        // Wait for execution
        await Future.delayed(Duration(milliseconds: 100));
        expect(debouncer.isPending, isFalse);

        // Cleanup
        debouncer.dispose();
      });
    });

    group('runImmediate', () {
      test('should execute action immediately on first call', () async {
        // Arrange
        final debouncer = Debouncer(duration: Duration(milliseconds: 100));
        var callCount = 0;

        // Act
        debouncer.runImmediate(() => callCount++);

        // Assert - should execute immediately
        expect(callCount, equals(1));
        expect(debouncer.isPending, isTrue);

        // Cleanup
        debouncer.dispose();
      });

      test('should prevent further calls during debounce period', () async {
        // Arrange
        final debouncer = Debouncer(duration: Duration(milliseconds: 100));
        var callCount = 0;

        // Act
        debouncer.runImmediate(() => callCount++);
        debouncer.runImmediate(() => callCount++);
        debouncer.runImmediate(() => callCount++);

        // Assert - only first call should execute
        expect(callCount, equals(1));

        // Wait for debounce period to end
        await Future.delayed(Duration(milliseconds: 150));

        // Try again after period
        debouncer.runImmediate(() => callCount++);
        expect(callCount, equals(2));

        // Cleanup
        debouncer.dispose();
      });

      test('should allow execution after debounce period expires', () async {
        // Arrange
        final debouncer = Debouncer(duration: Duration(milliseconds: 50));
        var callCount = 0;

        // Act
        debouncer.runImmediate(() => callCount++);
        expect(callCount, equals(1));

        // Wait for debounce period
        await Future.delayed(Duration(milliseconds: 100));

        // Should allow new execution
        debouncer.runImmediate(() => callCount++);
        expect(callCount, equals(2));

        // Cleanup
        debouncer.dispose();
      });
    });

    group('cancel', () {
      test('should cancel pending action', () async {
        // Arrange
        final debouncer = Debouncer(duration: Duration(milliseconds: 100));
        var callCount = 0;

        // Act
        debouncer.run(() => callCount++);
        expect(debouncer.isPending, isTrue);

        debouncer.cancel();

        // Assert
        expect(debouncer.isPending, isFalse);

        // Wait to ensure action doesn't execute
        await Future.delayed(Duration(milliseconds: 150));
        expect(callCount, equals(0));

        // Cleanup
        debouncer.dispose();
      });

      test('should handle cancel when no action is pending', () {
        // Arrange
        final debouncer = Debouncer(duration: Duration(milliseconds: 100));

        // Act & Assert - should not throw
        expect(() => debouncer.cancel(), returnsNormally);
        expect(debouncer.isPending, isFalse);

        // Cleanup
        debouncer.dispose();
      });

      test('should allow new actions after cancel', () async {
        // Arrange
        final debouncer = Debouncer(duration: Duration(milliseconds: 100));
        var callCount = 0;

        // Act
        debouncer.run(() => callCount++);
        debouncer.cancel();

        debouncer.run(() => callCount++);

        // Assert
        await Future.delayed(Duration(milliseconds: 150));
        expect(callCount, equals(1));

        // Cleanup
        debouncer.dispose();
      });
    });

    group('dispose', () {
      test('should cancel pending actions on dispose', () async {
        // Arrange
        final debouncer = Debouncer(duration: Duration(milliseconds: 100));
        var callCount = 0;

        // Act
        debouncer.run(() => callCount++);
        expect(debouncer.isPending, isTrue);

        debouncer.dispose();

        // Assert
        expect(debouncer.isPending, isFalse);

        // Wait to ensure action doesn't execute
        await Future.delayed(Duration(milliseconds: 150));
        expect(callCount, equals(0));
      });

      test('should handle dispose when no action is pending', () {
        // Arrange
        final debouncer = Debouncer(duration: Duration(milliseconds: 100));

        // Act & Assert - should not throw
        expect(() => debouncer.dispose(), returnsNormally);
      });

      test('should handle multiple dispose calls', () {
        // Arrange
        final debouncer = Debouncer(duration: Duration(milliseconds: 100));

        // Act & Assert - should not throw
        expect(() {
          debouncer.dispose();
          debouncer.dispose();
          debouncer.dispose();
        }, returnsNormally);
      });
    });
  });

  group('Throttler', () {
    group('run', () {
      test('should execute action immediately on first call', () async {
        // Arrange
        final throttler = Throttler(duration: Duration(milliseconds: 100));
        var callCount = 0;

        // Act
        throttler.run(() => callCount++);

        // Assert - should execute immediately
        expect(callCount, equals(1));
        expect(throttler.isThrottled, isTrue);

        // Cleanup
        throttler.dispose();
      });

      test('should throttle rapid successive calls', () async {
        // Arrange
        final throttler = Throttler(duration: Duration(milliseconds: 100));
        var callCount = 0;

        // Act - call multiple times rapidly
        throttler.run(() => callCount++); // Executes immediately
        throttler.run(() => callCount++); // Throttled
        throttler.run(() => callCount++); // Throttled, replaces previous

        // Assert - first call executes immediately
        expect(callCount, equals(1));
        expect(throttler.isThrottled, isTrue);

        // Wait for throttle period
        await Future.delayed(Duration(milliseconds: 150));

        // Last throttled call should execute
        expect(callCount, equals(2));

        // Cleanup
        throttler.dispose();
      });

      test('should execute pending action after throttle period', () async {
        // Arrange
        final throttler = Throttler(duration: Duration(milliseconds: 100));
        var lastValue = 0;

        // Act
        throttler.run(() => lastValue = 1); // Executes immediately
        await Future.delayed(Duration(milliseconds: 20));
        throttler.run(() => lastValue = 2); // Throttled
        await Future.delayed(Duration(milliseconds: 20));
        throttler.run(() => lastValue = 3); // Throttled, replaces previous

        // Assert - first value set immediately
        expect(lastValue, equals(1));

        // Wait for throttle period
        await Future.delayed(Duration(milliseconds: 100));

        // Last throttled value should be set
        expect(lastValue, equals(3));

        // Cleanup
        throttler.dispose();
      });

      test('should allow multiple executions if calls are spaced out', () async {
        // Arrange
        final throttler = Throttler(duration: Duration(milliseconds: 50));
        var callCount = 0;

        // Act
        throttler.run(() => callCount++);
        expect(callCount, equals(1));

        await Future.delayed(Duration(milliseconds: 100));

        throttler.run(() => callCount++);
        expect(callCount, equals(2));

        await Future.delayed(Duration(milliseconds: 100));

        throttler.run(() => callCount++);
        expect(callCount, equals(3));

        // Cleanup
        throttler.dispose();
      });

      test('should update isThrottled status correctly', () async {
        // Arrange
        final throttler = Throttler(duration: Duration(milliseconds: 50));

        // Act & Assert - initially not throttled
        expect(throttler.isThrottled, isFalse);

        // Execute action
        throttler.run(() {});
        expect(throttler.isThrottled, isTrue);

        // Wait for throttle period
        await Future.delayed(Duration(milliseconds: 100));
        expect(throttler.isThrottled, isFalse);

        // Cleanup
        throttler.dispose();
      });

      test('should handle high-frequency calls (scroll simulation)', () async {
        // Arrange
        final throttler = Throttler(duration: Duration(milliseconds: 100));
        var callCount = 0;

        // Act - simulate rapid scroll events
        for (var i = 0; i < 10; i++) {
          throttler.run(() => callCount++);
          await Future.delayed(Duration(milliseconds: 5));
        }

        // Assert - should have executed first call immediately
        expect(callCount, greaterThanOrEqualTo(1));
        expect(callCount, lessThanOrEqualTo(2));

        // Wait for final pending action (total loop time is ~50ms, so wait 100ms more)
        await Future.delayed(Duration(milliseconds: 150));

        // Should have executed at most 2 times (first + last pending)
        expect(callCount, greaterThanOrEqualTo(1));
        expect(callCount, lessThanOrEqualTo(2));

        // Cleanup
        throttler.dispose();
      });
    });

    group('cancel', () {
      test('should cancel pending throttled action', () async {
        // Arrange
        final throttler = Throttler(duration: Duration(milliseconds: 100));
        var callCount = 0;

        // Act
        throttler.run(() => callCount++); // Executes immediately
        throttler.run(() => callCount++); // Throttled
        throttler.cancel();

        // Assert - first call executed
        expect(callCount, equals(1));

        // Wait to ensure pending action doesn't execute
        await Future.delayed(Duration(milliseconds: 150));
        expect(callCount, equals(1));

        // Cleanup
        throttler.dispose();
      });

      test('should handle cancel when no action is pending', () {
        // Arrange
        final throttler = Throttler(duration: Duration(milliseconds: 100));

        // Act
        throttler.run(() {});
        throttler.cancel();

        // Act & Assert - should not throw
        expect(() => throttler.cancel(), returnsNormally);

        // Cleanup
        throttler.dispose();
      });

      test('should allow new actions after cancel', () async {
        // Arrange
        final throttler = Throttler(duration: Duration(milliseconds: 100));
        var callCount = 0;

        // Act
        throttler.run(() => callCount++);
        throttler.run(() => callCount++);
        throttler.cancel();

        // Wait for throttle period
        await Future.delayed(Duration(milliseconds: 150));

        // New action should work
        throttler.run(() => callCount++);
        expect(callCount, equals(2));

        // Cleanup
        throttler.dispose();
      });
    });

    group('dispose', () {
      test('should cancel pending actions on dispose', () async {
        // Arrange
        final throttler = Throttler(duration: Duration(milliseconds: 100));
        var callCount = 0;

        // Act
        throttler.run(() => callCount++); // Executes immediately
        throttler.run(() => callCount++); // Throttled
        throttler.dispose();

        // Assert - only first call executed
        expect(callCount, equals(1));

        // Wait to ensure pending action doesn't execute
        await Future.delayed(Duration(milliseconds: 150));
        expect(callCount, equals(1));
      });

      test('should handle dispose when no action is pending', () {
        // Arrange
        final throttler = Throttler(duration: Duration(milliseconds: 100));

        // Act
        throttler.run(() {});

        // Act & Assert - should not throw
        expect(() => throttler.dispose(), returnsNormally);
      });

      test('should handle multiple dispose calls', () {
        // Arrange
        final throttler = Throttler(duration: Duration(milliseconds: 100));

        // Act & Assert - should not throw
        expect(() {
          throttler.dispose();
          throttler.dispose();
          throttler.dispose();
        }, returnsNormally);
      });
    });
  });

  group('Integration Tests', () {
    test('Debouncer and Throttler should work independently', () async {
      // Arrange
      final debouncer = Debouncer(duration: Duration(milliseconds: 100));
      final throttler = Throttler(duration: Duration(milliseconds: 100));
      var debounceCalls = 0;
      var throttleCalls = 0;

      // Act
      for (var i = 0; i < 5; i++) {
        debouncer.run(() => debounceCalls++);
        throttler.run(() => throttleCalls++);
        await Future.delayed(Duration(milliseconds: 20));
      }

      // Assert - debouncer hasn't executed yet
      expect(debounceCalls, equals(0));
      // Throttler executes first call immediately and may have executed pending
      expect(throttleCalls, greaterThanOrEqualTo(1));
      expect(throttleCalls, lessThanOrEqualTo(2));

      // Wait for both to complete
      await Future.delayed(Duration(milliseconds: 200));

      // Debouncer should execute once (last call)
      expect(debounceCalls, equals(1));
      // Throttler should execute at least twice (first + last pending)
      expect(throttleCalls, greaterThanOrEqualTo(2));

      // Cleanup
      debouncer.dispose();
      throttler.dispose();
    });

    test('should handle different durations correctly', () async {
      // Arrange
      final shortDebouncer = Debouncer(duration: Duration(milliseconds: 50));
      final longDebouncer = Debouncer(duration: Duration(milliseconds: 150));
      var shortCalls = 0;
      var longCalls = 0;

      // Act
      shortDebouncer.run(() => shortCalls++);
      longDebouncer.run(() => longCalls++);

      // Wait for short duration
      await Future.delayed(Duration(milliseconds: 100));

      // Assert - short should have executed, long should not
      expect(shortCalls, equals(1));
      expect(longCalls, equals(0));

      // Wait for long duration
      await Future.delayed(Duration(milliseconds: 100));
      expect(longCalls, equals(1));

      // Cleanup
      shortDebouncer.dispose();
      longDebouncer.dispose();
    });
  });
}
