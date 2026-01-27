import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../security/sensitive_data_detector.dart';

/// Shows a warning dialog when sensitive data is detected in text.
///
/// This dialog warns users when they attempt to copy text that may contain
/// sensitive information (credit cards, passwords, SSNs, etc.) to the clipboard,
/// as clipboard content can be accessed by other apps.
///
/// Returns `true` if the user chooses to copy anyway, `false` if cancelled.
///
/// ## Usage
/// ```dart
/// final shouldCopy = await showSensitiveDataWarningDialog(
///   context: context,
///   ref: ref,
///   detection: detectionResult,
/// );
/// if (shouldCopy) {
///   // Proceed with copy
/// }
/// ```
Future<bool> showSensitiveDataWarningDialog({
  required BuildContext context,
  required WidgetRef ref,
  required SensitiveDataDetectionResult detection,
}) async {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final detector = ref.read(sensitiveDataDetectorProvider);

  // Get human-readable description of detected types
  final detectedDescription = detector.getSensitiveDataDescription(detection);

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(
        Icons.warning_amber_rounded,
        color: theme.colorScheme.error,
        size: 48,
      ),
      title: const Text('Sensitive Data Detected'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The text you are copying may contain sensitive information that could be accessed by other apps.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withAlpha(77),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.error.withAlpha(77),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detected:',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detectedDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Copy Anyway'),
        ),
      ],
    ),
  );

  return result ?? false;
}
