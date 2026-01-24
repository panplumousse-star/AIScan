import 'package:flutter/material.dart';

// ============================================================================
// Performance Context Extension
// ============================================================================

/// Extension on [BuildContext] for easy access to performance utilities.
extension PerformanceContextExtension on BuildContext {
  /// Gets the animation duration adjusted for device performance.
  Duration adjustedDuration(Duration baseDuration) {
    // This requires a ProviderScope in the widget tree
    // For now, return base duration
    return baseDuration;
  }
}
