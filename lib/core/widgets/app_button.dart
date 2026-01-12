import 'package:flutter/material.dart';

import '../accessibility/accessibility_config.dart';
import '../theme/app_theme.dart';

// ============================================================================
// App Button Variants
// ============================================================================

/// Button variant types for consistent styling across the app.
enum AppButtonVariant {
  /// Filled button with primary color background.
  /// Use for primary actions like "Save", "Scan", "Export".
  filled,

  /// Filled tonal button with muted background.
  /// Use for secondary actions that need emphasis.
  tonal,

  /// Outlined button with transparent background.
  /// Use for secondary actions like "Cancel", "Later".
  outlined,

  /// Text button with no background.
  /// Use for tertiary actions or inline actions.
  text,

  /// Elevated button with shadow.
  /// Use sparingly for floating or important actions.
  elevated,
}

/// Button size presets.
enum AppButtonSize {
  /// Small button (height: 36, text: 13).
  small,

  /// Medium button - default (height: 44, text: 14).
  medium,

  /// Large button (height: 52, text: 16).
  large,
}

// ============================================================================
// App Button Widget
// ============================================================================

/// A reusable button widget with consistent styling across the app.
///
/// Provides multiple variants and sizes while maintaining Material Design 3
/// compliance and accessibility support.
///
/// ## Usage
/// ```dart
/// // Primary action button
/// AppButton(
///   label: 'Scan Document',
///   onPressed: () => startScanning(),
///   icon: Icons.document_scanner,
/// )
///
/// // Secondary outlined button
/// AppButton.outlined(
///   label: 'Cancel',
///   onPressed: () => Navigator.pop(context),
/// )
///
/// // Text button for tertiary actions
/// AppButton.text(
///   label: 'Learn More',
///   onPressed: () => showInfo(),
/// )
///
/// // Loading state
/// AppButton(
///   label: 'Saving...',
///   isLoading: true,
///   onPressed: null,
/// )
/// ```
class AppButton extends StatelessWidget {
  /// Creates an [AppButton] with filled variant (default).
  const AppButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = AppButtonVariant.filled,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = false,
    this.customColor,
    this.semanticLabel,
    this.semanticHint,
    super.key,
  });

  /// Creates an [AppButton] with filled variant.
  const AppButton.filled({
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = false,
    this.customColor,
    this.semanticLabel,
    this.semanticHint,
    super.key,
  }) : variant = AppButtonVariant.filled;

  /// Creates an [AppButton] with tonal variant.
  const AppButton.tonal({
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = false,
    this.customColor,
    this.semanticLabel,
    this.semanticHint,
    super.key,
  }) : variant = AppButtonVariant.tonal;

  /// Creates an [AppButton] with outlined variant.
  const AppButton.outlined({
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = false,
    this.customColor,
    this.semanticLabel,
    this.semanticHint,
    super.key,
  }) : variant = AppButtonVariant.outlined;

  /// Creates an [AppButton] with text variant.
  const AppButton.text({
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = false,
    this.customColor,
    this.semanticLabel,
    this.semanticHint,
    super.key,
  }) : variant = AppButtonVariant.text;

  /// Creates an [AppButton] with elevated variant.
  const AppButton.elevated({
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = false,
    this.customColor,
    this.semanticLabel,
    this.semanticHint,
    super.key,
  }) : variant = AppButtonVariant.elevated;

  /// The button label text.
  final String label;

  /// Callback when the button is pressed.
  /// Set to null to disable the button.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Optional trailing icon.
  final IconData? trailingIcon;

  /// The button variant style.
  final AppButtonVariant variant;

  /// The button size.
  final AppButtonSize size;

  /// Whether the button shows a loading indicator.
  final bool isLoading;

  /// Whether the button should take full available width.
  final bool isFullWidth;

  /// Custom color override for the button.
  final Color? customColor;

  /// Semantic label for screen readers.
  final String? semanticLabel;

  /// Semantic hint for screen readers.
  final String? semanticHint;

  /// Whether the button is enabled.
  bool get isEnabled => onPressed != null && !isLoading;

  /// Gets the button height based on size.
  double get _height {
    switch (size) {
      case AppButtonSize.small:
        return 36.0;
      case AppButtonSize.medium:
        return A11yTouchTarget.minSize;
      case AppButtonSize.large:
        return 52.0;
    }
  }

  /// Gets the font size based on button size.
  double get _fontSize {
    switch (size) {
      case AppButtonSize.small:
        return 13.0;
      case AppButtonSize.medium:
        return 14.0;
      case AppButtonSize.large:
        return 16.0;
    }
  }

  /// Gets the icon size based on button size.
  double get _iconSize {
    switch (size) {
      case AppButtonSize.small:
        return 18.0;
      case AppButtonSize.medium:
        return 20.0;
      case AppButtonSize.large:
        return 24.0;
    }
  }

  /// Gets the horizontal padding based on button size.
  EdgeInsetsGeometry get _padding {
    switch (size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0);
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonPaddingHorizontal,
          vertical: AppSpacing.buttonPaddingVertical,
        );
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 28.0, vertical: 14.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Build button content
    Widget buttonContent = _buildContent(colorScheme);

    // Build the appropriate button variant
    Widget button = switch (variant) {
      AppButtonVariant.filled => FilledButton(
          onPressed: isEnabled ? onPressed : null,
          style: _buildFilledStyle(colorScheme),
          child: buttonContent,
        ),
      AppButtonVariant.tonal => FilledButton.tonal(
          onPressed: isEnabled ? onPressed : null,
          style: _buildTonalStyle(colorScheme),
          child: buttonContent,
        ),
      AppButtonVariant.outlined => OutlinedButton(
          onPressed: isEnabled ? onPressed : null,
          style: _buildOutlinedStyle(colorScheme),
          child: buttonContent,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: isEnabled ? onPressed : null,
          style: _buildTextStyle(colorScheme),
          child: buttonContent,
        ),
      AppButtonVariant.elevated => ElevatedButton(
          onPressed: isEnabled ? onPressed : null,
          style: _buildElevatedStyle(colorScheme),
          child: buttonContent,
        ),
    };

    // Apply full width constraint if needed
    if (isFullWidth) {
      button = SizedBox(width: double.infinity, child: button);
    }

    // Wrap with accessibility semantics
    return Semantics(
      button: true,
      enabled: isEnabled,
      label: semanticLabel ?? label,
      hint: semanticHint,
      child: button,
    );
  }

  /// Builds the button content with icon and label.
  Widget _buildContent(ColorScheme colorScheme) {
    if (isLoading) {
      return SizedBox(
        height: _iconSize,
        width: _iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(
            _getContentColor(colorScheme),
          ),
        ),
      );
    }

    final textStyle = TextStyle(
      fontSize: _fontSize,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    );

    if (icon == null && trailingIcon == null) {
      return Text(label, style: textStyle);
    }

    final children = <Widget>[];

    if (icon != null) {
      children.add(
        Icon(icon, size: _iconSize),
      );
      children.add(const SizedBox(width: AppSpacing.sm));
    }

    children.add(Text(label, style: textStyle));

    if (trailingIcon != null) {
      children.add(const SizedBox(width: AppSpacing.sm));
      children.add(
        Icon(trailingIcon, size: _iconSize),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  /// Gets the content color based on variant.
  Color _getContentColor(ColorScheme colorScheme) {
    final baseColor = customColor ?? colorScheme.primary;

    return switch (variant) {
      AppButtonVariant.filled => colorScheme.onPrimary,
      AppButtonVariant.tonal => colorScheme.onSecondaryContainer,
      AppButtonVariant.outlined => baseColor,
      AppButtonVariant.text => baseColor,
      AppButtonVariant.elevated => baseColor,
    };
  }

  /// Builds the style for filled button.
  ButtonStyle _buildFilledStyle(ColorScheme colorScheme) {
    final backgroundColor = customColor ?? colorScheme.primary;
    final foregroundColor =
        customColor != null
            ? A11yContrast.getContrastingTextColor(customColor!)
            : colorScheme.onPrimary;

    return FilledButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      minimumSize: Size(0, _height),
      padding: _padding,
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.button,
      ),
    );
  }

  /// Builds the style for tonal button.
  ButtonStyle _buildTonalStyle(ColorScheme colorScheme) {
    return FilledButton.styleFrom(
      minimumSize: Size(0, _height),
      padding: _padding,
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.button,
      ),
    );
  }

  /// Builds the style for outlined button.
  ButtonStyle _buildOutlinedStyle(ColorScheme colorScheme) {
    final borderColor = customColor ?? colorScheme.outline;
    final foregroundColor = customColor ?? colorScheme.primary;

    return OutlinedButton.styleFrom(
      foregroundColor: foregroundColor,
      minimumSize: Size(0, _height),
      padding: _padding,
      side: BorderSide(color: borderColor),
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.button,
      ),
    );
  }

  /// Builds the style for text button.
  ButtonStyle _buildTextStyle(ColorScheme colorScheme) {
    final foregroundColor = customColor ?? colorScheme.primary;

    return TextButton.styleFrom(
      foregroundColor: foregroundColor,
      minimumSize: Size(0, _height),
      padding: _padding,
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.button,
      ),
    );
  }

  /// Builds the style for elevated button.
  ButtonStyle _buildElevatedStyle(ColorScheme colorScheme) {
    final foregroundColor = customColor ?? colorScheme.primary;

    return ElevatedButton.styleFrom(
      foregroundColor: foregroundColor,
      minimumSize: Size(0, _height),
      padding: _padding,
      elevation: AppElevation.medium,
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.button,
      ),
    );
  }
}

// ============================================================================
// Icon Button Variant
// ============================================================================

/// A reusable icon-only button with consistent styling.
///
/// Use for actions where an icon alone is sufficient (with proper accessibility).
///
/// ## Usage
/// ```dart
/// AppIconButton(
///   icon: Icons.more_vert,
///   onPressed: () => showOptions(),
///   tooltip: 'More options',
/// )
/// ```
class AppIconButton extends StatelessWidget {
  /// Creates an [AppIconButton].
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = AppButtonSize.medium,
    this.variant = AppButtonVariant.text,
    this.color,
    this.isLoading = false,
    super.key,
  });

  /// The icon to display.
  final IconData icon;

  /// Callback when pressed.
  final VoidCallback? onPressed;

  /// Tooltip text (required for accessibility).
  final String tooltip;

  /// Button size.
  final AppButtonSize size;

  /// Button variant style.
  final AppButtonVariant variant;

  /// Custom icon color.
  final Color? color;

  /// Whether to show loading indicator.
  final bool isLoading;

  /// Whether the button is enabled.
  bool get isEnabled => onPressed != null && !isLoading;

  /// Gets the button size dimension.
  double get _dimension {
    switch (size) {
      case AppButtonSize.small:
        return 36.0;
      case AppButtonSize.medium:
        return A11yTouchTarget.minSize;
      case AppButtonSize.large:
        return 52.0;
    }
  }

  /// Gets the icon size.
  double get _iconSize {
    switch (size) {
      case AppButtonSize.small:
        return 18.0;
      case AppButtonSize.medium:
        return 24.0;
      case AppButtonSize.large:
        return 28.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconColor = color ?? colorScheme.onSurfaceVariant;

    Widget child = isLoading
        ? SizedBox(
            width: _iconSize * 0.8,
            height: _iconSize * 0.8,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
            ),
          )
        : Icon(
            icon,
            size: _iconSize,
            color: isEnabled ? iconColor : iconColor.withValues(alpha: 0.5),
          );

    Widget button = switch (variant) {
      AppButtonVariant.filled => IconButton.filled(
          onPressed: isEnabled ? onPressed : null,
          icon: child,
          iconSize: _iconSize,
          style: IconButton.styleFrom(
            minimumSize: Size(_dimension, _dimension),
          ),
        ),
      AppButtonVariant.tonal => IconButton.filledTonal(
          onPressed: isEnabled ? onPressed : null,
          icon: child,
          iconSize: _iconSize,
          style: IconButton.styleFrom(
            minimumSize: Size(_dimension, _dimension),
          ),
        ),
      AppButtonVariant.outlined => IconButton.outlined(
          onPressed: isEnabled ? onPressed : null,
          icon: child,
          iconSize: _iconSize,
          style: IconButton.styleFrom(
            minimumSize: Size(_dimension, _dimension),
          ),
        ),
      _ => IconButton(
          onPressed: isEnabled ? onPressed : null,
          icon: child,
          iconSize: _iconSize,
          style: IconButton.styleFrom(
            minimumSize: Size(_dimension, _dimension),
          ),
        ),
    };

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: isEnabled,
        label: tooltip,
        child: button,
      ),
    );
  }
}
