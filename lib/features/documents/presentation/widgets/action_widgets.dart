import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Prominent floating action button for one-click scan workflow.
///
/// Features:
/// - Large, extended FAB with clear call-to-action
/// - Haptic feedback for tactile confirmation
/// - Semantic labels for accessibility
/// - Elevated styling to draw attention
class QuickScanFab extends StatelessWidget {
  const QuickScanFab({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  void _handlePressed() {
    // Provide haptic feedback for immediate tactile response
    unawaited(HapticFeedback.mediumImpact());
    onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: 'Scan new document',
      hint: 'Double tap to open camera scanner',
      child: FloatingActionButton.extended(
        onPressed: onPressed != null ? _handlePressed : null,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scan'),
        tooltip: 'Scan new document (one tap)',
        elevation: 6,
        highlightElevation: 8,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        // Extended width for easier tap target
        extendedPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        extendedTextStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
