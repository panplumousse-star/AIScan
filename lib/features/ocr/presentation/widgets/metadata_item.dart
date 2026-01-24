import 'package:flutter/material.dart';

/// Single metadata item in the metadata bar.
///
/// Displays an icon with a value and label stacked vertically.
///
/// Usage:
/// ```dart
/// MetadataItem(
///   icon: Icons.text_fields,
///   label: 'Words',
///   value: '123',
///   theme: Theme.of(context),
/// )
/// ```
class MetadataItem extends StatelessWidget {
  const MetadataItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
