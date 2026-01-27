import 'package:flutter/material.dart';

/// Factory methods for common TextStyles used across light and dark themes.
///
/// This class eliminates duplication by providing consistent TextStyle
/// definitions that adapt to any ColorScheme. Each method takes a
/// [ColorScheme] parameter and returns the appropriate styled text.
///
/// ## Usage
/// ```dart
/// final colorScheme = Theme.of(context).colorScheme;
/// Text('Hello', style: AppTextStyles.hintStyle(colorScheme));
/// ```
abstract final class AppTextStyles {
  // ===========================================================================
  // App Bar
  // ===========================================================================

  /// Title style for AppBar.
  static TextStyle appBarTitle(ColorScheme cs) => TextStyle(
        fontFamily: 'Outfit',
        color: cs.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      );

  // ===========================================================================
  // Buttons
  // ===========================================================================

  /// Text style for elevated and filled buttons.
  static const TextStyle buttonPrimary = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  /// Text style for outlined and text buttons.
  static const TextStyle buttonSecondary = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  // ===========================================================================
  // Input Decoration
  // ===========================================================================

  /// Hint text style for input fields.
  static TextStyle hintStyle(ColorScheme cs) => TextStyle(
        fontFamily: 'Outfit',
        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
      );

  // ===========================================================================
  // Chips
  // ===========================================================================

  /// Label style for chips.
  static TextStyle chipLabel(ColorScheme cs) => TextStyle(
        fontFamily: 'Outfit',
        color: cs.onSurfaceVariant,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      );

  // ===========================================================================
  // List Tiles
  // ===========================================================================

  /// Title style for list tiles.
  static TextStyle listTileTitle(ColorScheme cs) => TextStyle(
        fontFamily: 'Outfit',
        color: cs.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  /// Subtitle style for list tiles.
  static TextStyle listTileSubtitle(ColorScheme cs) => TextStyle(
        fontFamily: 'Outfit',
        color: cs.onSurfaceVariant,
        fontSize: 14,
      );

  // ===========================================================================
  // Dialogs
  // ===========================================================================

  /// Title style for dialogs.
  static TextStyle dialogTitle(ColorScheme cs) => TextStyle(
        fontFamily: 'Outfit',
        color: cs.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      );

  /// Content style for dialogs.
  static TextStyle dialogContent(ColorScheme cs) => TextStyle(
        fontFamily: 'Outfit',
        color: cs.onSurfaceVariant,
        fontSize: 14,
      );

  // ===========================================================================
  // Snackbars
  // ===========================================================================

  /// Content style for snackbars.
  static TextStyle snackBarContent(ColorScheme cs) => TextStyle(
        fontFamily: 'Outfit',
        color: cs.onInverseSurface,
        fontSize: 14,
      );

  // ===========================================================================
  // Sliders
  // ===========================================================================

  /// Value indicator style for sliders.
  static TextStyle sliderValueIndicator(ColorScheme cs) => TextStyle(
        fontFamily: 'Outfit',
        color: cs.onPrimaryContainer,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      );

  // ===========================================================================
  // Navigation Bar
  // ===========================================================================

  /// Label style for navigation bar items.
  static TextStyle navigationBarLabel(
    ColorScheme cs, {
    required bool isSelected,
  }) =>
      TextStyle(
        fontFamily: 'Outfit',
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        color: isSelected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
      );

  // ===========================================================================
  // Popup Menu
  // ===========================================================================

  /// Text style for popup menu items.
  static TextStyle popupMenuItem(ColorScheme cs) => TextStyle(
        fontFamily: 'Outfit',
        color: cs.onSurface,
        fontSize: 14,
      );

  // ===========================================================================
  // Tooltips
  // ===========================================================================

  /// Text style for tooltips.
  static TextStyle tooltip(ColorScheme cs) => TextStyle(
        fontFamily: 'Outfit',
        color: cs.onInverseSurface,
        fontSize: 12,
      );

  // ===========================================================================
  // Badges
  // ===========================================================================

  /// Text style for badges.
  static const TextStyle badge = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 10,
    fontWeight: FontWeight.w700,
  );
}
