import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// Theme Mode Provider
// ============================================================================

/// Riverpod provider for the current theme mode.
///
/// Manages the application's theme mode state (light, dark, or system).
/// The theme mode is persisted using shared preferences (see settings_screen.dart).
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.system;
});

// ============================================================================
// App Colors
// ============================================================================

/// Defines the color palette for the Scanaï application.
///
/// Colors are designed to follow Material Design 3 guidelines while
/// maintaining a professional, trustworthy appearance appropriate
/// for a privacy-focused document scanner.
abstract final class AppColors {
  // Primary colors - Deep Blue (Trust, Professionalism, Tech)
  static const Color primaryLight = Color(0xFF2563EB); // Vibrant Royal Blue
  static const Color primaryDark = Color(0xFF60A5FA);

  // Secondary colors - Teal/Cyan (Modern, Fresh)
  static const Color secondaryLight = Color(0xFF0D9488);
  static const Color secondaryDark = Color(0xFF2DD4BF);

  // Tertiary colors - Violet (Premium, Creative)
  static const Color tertiaryLight = Color(0xFF7C3AED);
  static const Color tertiaryDark = Color(0xFFA78BFA);

  // Error colors
  static const Color errorLight = Color(0xFFDC2626);
  static const Color errorDark = Color(0xFFF87171);

  // Success colors
  static const Color successLight = Color(0xFF16A34A);
  static const Color successDark = Color(0xFF4ADE80);

  // Warning colors
  static const Color warningLight = Color(0xFFD97706);
  static const Color warningDark = Color(0xFFFBBF24);

  // Neutral colors
  static const Color neutralLight = Color(0xFF64748B); // Slate
  static const Color neutralDark = Color(0xFF94A3B8);

  // Surface colors for light theme
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF1F5F9); // Slate-100
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate-50

  // Surface colors for dark theme
  static const Color surfaceDark = Color(0xFF0F172A); // Slate-900
  static const Color surfaceVariantDark = Color(0xFF1E293B); // Slate-800
  static const Color backgroundDark = Color(0xFF020617); // Slate-950

  // Scanner-specific colors
  static const Color scannerOverlayLight = Color(0x80000000);
  static const Color scannerOverlayDark = Color(0x80000000);
  static const Color scannerBorderLight = Color(0xFF3B82F6);
  static const Color scannerBorderDark = Color(0xFF60A5FA);

  // Document card colors
  static const Color documentCardLight = Color(0xFFFFFFFF);
  static const Color documentCardDark = Color(0xFF1E293B);

  // Bento Pastel colors (Refined)
  static const Color bentoBluePastel = Color(0xFFEFF6FF); // Blue-50
  static const Color bentoBlueDark = Color(0xFFDBEAFE); // Blue-100
  static const Color bentoPinkPastel = Color(0xFFFEF2F2); // Red-50
  static const Color bentoOrangePastel = Color(0xFFFFF7ED); // Orange-50
  static const Color bentoGreenPastel = Color(0xFFF0FDF4); // Green-50
  static const Color bentoPurplePastel = Color(0xFFFAF5FF); // Purple-50
  static const Color bentoButtonBlue = Color(0xFF2563EB);
  static const Color bentoBackground = Color(0xFFF8FAFC);
  static const Color bentoCardWhite = Color(0xFFFFFFFF);

  // Folder colors for organization
  static const List<Color> folderColors = [
    Color(0xFFEF4444), // Red
    Color(0xFFF97316), // Orange
    Color(0xFFF59E0B), // Amber
    Color(0xFF84CC16), // Lime
    Color(0xFF10B981), // Emerald
    Color(0xFF06B6D4), // Cyan
    Color(0xFF3B82F6), // Blue
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFF64748B), // Slate
  ];

  /// Gets a contrasting text color for the given background color.
  static Color getContrastingTextColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? const Color(0xFF0F172A) : Colors.white;
  }
}

/// Defines consistent gradients used throughout the app.
abstract final class AppGradients {
  static const LinearGradient primary = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient scanner = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient premiumCard = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

// ============================================================================
// App Spacing
// ============================================================================

/// Defines consistent spacing values used throughout the app.
abstract final class AppSpacing {
  /// Extra small spacing (4.0)
  static const double xs = 4.0;

  /// Small spacing (8.0)
  static const double sm = 8.0;

  /// Medium spacing (16.0)
  static const double md = 16.0;

  /// Large spacing (24.0)
  static const double lg = 24.0;

  /// Extra large spacing (32.0)
  static const double xl = 32.0;

  /// Extra extra large spacing (48.0)
  static const double xxl = 48.0;

  /// Standard page padding (horizontal)
  static const double pagePaddingHorizontal = 16.0;

  /// Standard page padding (vertical)
  static const double pagePaddingVertical = 16.0;

  /// Standard card padding
  static const double cardPadding = 16.0;

  /// Standard button padding (horizontal)
  static const double buttonPaddingHorizontal = 24.0;

  /// Standard button padding (vertical)
  static const double buttonPaddingVertical = 12.0;

  /// Standard icon button size
  static const double iconButtonSize = 48.0;

  /// Standard list tile vertical padding
  static const double listTileVertical = 12.0;
}

// ============================================================================
// App Border Radius
// ============================================================================

/// Defines consistent border radius values used throughout the app.
abstract final class AppBorderRadius {
  /// Small border radius (4.0)
  static const double sm = 4.0;

  /// Medium border radius (8.0)
  static const double md = 8.0;

  /// Large border radius (12.0)
  static const double lg = 12.0;

  /// Extra large border radius (16.0)
  static const double xl = 16.0;

  /// Circular/pill border radius (999.0)
  static const double circular = 999.0;

  /// Standard card border radius
  static BorderRadius get card => BorderRadius.circular(lg);

  /// Standard button border radius
  static BorderRadius get button => BorderRadius.circular(lg);

  /// Standard input border radius
  static BorderRadius get input => BorderRadius.circular(lg);

  /// Standard chip border radius
  static BorderRadius get chip => BorderRadius.circular(md);

  /// Standard dialog border radius
  static BorderRadius get dialog => BorderRadius.circular(xl);

  /// Standard bottom sheet border radius
  static BorderRadius get bottomSheet => const BorderRadius.vertical(
        top: Radius.circular(xl),
      );

  /// Standard FAB border radius
  static BorderRadius get fab => BorderRadius.circular(xl);
}

// ============================================================================
// App Elevation
// ============================================================================

/// Defines consistent elevation values used throughout the app.
abstract final class AppElevation {
  /// No elevation (0.0)
  static const double none = 0.0;

  /// Low elevation (1.0)
  static const double low = 1.0;

  /// Medium elevation (2.0)
  static const double medium = 2.0;

  /// High elevation (4.0)
  static const double high = 4.0;

  /// Extra high elevation (8.0)
  static const double extraHigh = 8.0;
}

// ============================================================================
// App Duration
// ============================================================================

/// Defines consistent animation duration values used throughout the app.
abstract final class AppDuration {
  /// Short duration for micro-interactions (100ms)
  static const Duration short = Duration(milliseconds: 100);

  /// Standard duration for most animations (200ms)
  static const Duration standard = Duration(milliseconds: 200);

  /// Medium duration for page transitions (300ms)
  static const Duration medium = Duration(milliseconds: 300);

  /// Long duration for complex animations (400ms)
  static const Duration long = Duration(milliseconds: 400);

  /// Extra long duration for emphasis (500ms)
  static const Duration extraLong = Duration(milliseconds: 500);
}

// ============================================================================
// App Theme
// ============================================================================

/// Central theme configuration for the Scanaï application.
///
/// Provides consistent theming following Material Design 3 guidelines.
/// Supports both light and dark themes with system preference detection.
///
/// ## Usage
/// ```dart
/// MaterialApp(
///   theme: AppTheme.lightTheme,
///   darkTheme: AppTheme.darkTheme,
///   themeMode: ref.watch(themeModeProvider),
/// )
/// ```
///
/// ## Theme Structure
/// - **Color Scheme**: Material 3 seed-based color generation
/// - **Typography**: Material 3 text styles
/// - **Component Themes**: Customized for document scanner UX
/// - **Accessibility**: High contrast support, proper text scaling
abstract final class AppTheme {
  // ==========================================================================
  // Light Theme
  // ==========================================================================

  /// The light theme for the application.
  static ThemeData get lightTheme => _buildLightTheme();

  static ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryLight,
      secondary: AppColors.secondaryLight,
      tertiary: AppColors.tertiaryLight,
      error: AppColors.errorLight,
      surface: AppColors.surfaceLight,
      surfaceContainerHighest: AppColors.surfaceVariantLight,
    );

    final textTheme = ThemeData.light().textTheme.apply(fontFamily: 'Outfit');

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: textTheme,

      // App Bar Theme
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: AppElevation.none,
        scrolledUnderElevation: AppElevation.low,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: colorScheme.surface,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(
          color: colorScheme.onSurfaceVariant,
          size: 24,
        ),
      ),

      // Scaffold Background
      scaffoldBackgroundColor: AppColors.backgroundLight,

      // Card Theme
      cardTheme: CardThemeData(
        elevation: AppElevation.low,
        color: AppColors.documentCardLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.card,
        ),
        margin: const EdgeInsets.all(AppSpacing.sm),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: AppElevation.low,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingHorizontal,
            vertical: AppSpacing.buttonPaddingVertical,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.button,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Filled Button Theme
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingHorizontal,
            vertical: AppSpacing.buttonPaddingVertical,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.button,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingHorizontal,
            vertical: AppSpacing.buttonPaddingVertical,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.button,
          ),
          side: BorderSide(color: colorScheme.outline),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.button,
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Icon Button Theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize:
              const Size(AppSpacing.iconButtonSize, AppSpacing.iconButtonSize),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: AppElevation.medium,
        focusElevation: AppElevation.high,
        hoverElevation: AppElevation.high,
        highlightElevation: AppElevation.high,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.fab,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: AppBorderRadius.input,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.input,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.input,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.input,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.input,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        hintStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.secondaryContainer,
        disabledColor:
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        labelStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.chip,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.card,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        iconColor: colorScheme.onSurfaceVariant,
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        elevation: AppElevation.extraHigh,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.dialog,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        elevation: AppElevation.extraHigh,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.bottomSheet,
        ),
        dragHandleColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        dragHandleSize: const Size(32, 4),
        showDragHandle: true,
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onInverseSurface,
          fontSize: 14,
        ),
        actionTextColor: colorScheme.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.card,
        ),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primaryContainer,
        circularTrackColor: colorScheme.primaryContainer,
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.primaryContainer,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
        valueIndicatorColor: colorScheme.primaryContainer,
        valueIndicatorTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onPrimaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        ),
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: colorScheme.outlineVariant,
      ),

      // Navigation Bar Theme
      navigationBarTheme: NavigationBarThemeData(
        elevation: AppElevation.medium,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: isSelected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),

      // Popup Menu Theme
      popupMenuTheme: PopupMenuThemeData(
        elevation: AppElevation.high,
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.card,
        ),
        textStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onSurface,
          fontSize: 14,
        ),
      ),

      // Tooltip Theme
      tooltipTheme: TooltipThemeData(
        preferBelow: true,
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: AppBorderRadius.chip,
        ),
        textStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onInverseSurface,
          fontSize: 12,
        ),
      ),

      // Badge Theme
      badgeTheme: BadgeThemeData(
        backgroundColor: colorScheme.error,
        textColor: colorScheme.onError,
        textStyle: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),

      // Segmented Button Theme
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.secondaryContainer;
            }
            return colorScheme.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.onSecondaryContainer;
            }
            return colorScheme.onSurface;
          }),
          side: WidgetStateProperty.all(
            BorderSide(color: colorScheme.outline),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // Dark Theme
  // ==========================================================================

  /// The dark theme for the application.
  static ThemeData get darkTheme => _buildDarkTheme();

  static ThemeData _buildDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryDark,
      brightness: Brightness.dark,
      secondary: AppColors.secondaryDark,
      tertiary: AppColors.tertiaryDark,
      error: AppColors.errorDark,
      surface: AppColors.surfaceDark,
      surfaceContainerHighest: AppColors.surfaceVariantDark,
    );

    final textTheme = ThemeData.dark().textTheme.apply(fontFamily: 'Outfit');

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme,

      // App Bar Theme
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: AppElevation.none,
        scrolledUnderElevation: AppElevation.low,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: colorScheme.surface,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(
          color: colorScheme.onSurfaceVariant,
          size: 24,
        ),
      ),

      // Scaffold Background
      scaffoldBackgroundColor: AppColors.surfaceDark,

      // Card Theme
      cardTheme: CardThemeData(
        elevation: AppElevation.low,
        color: AppColors.documentCardDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.card,
        ),
        margin: const EdgeInsets.all(AppSpacing.sm),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: AppElevation.low,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingHorizontal,
            vertical: AppSpacing.buttonPaddingVertical,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.button,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Filled Button Theme
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingHorizontal,
            vertical: AppSpacing.buttonPaddingVertical,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.button,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingHorizontal,
            vertical: AppSpacing.buttonPaddingVertical,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.button,
          ),
          side: BorderSide(color: colorScheme.outline),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.button,
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Icon Button Theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize:
              const Size(AppSpacing.iconButtonSize, AppSpacing.iconButtonSize),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: AppElevation.medium,
        focusElevation: AppElevation.high,
        hoverElevation: AppElevation.high,
        highlightElevation: AppElevation.high,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.fab,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: AppBorderRadius.input,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.input,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.input,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.input,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.input,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        hintStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.secondaryContainer,
        disabledColor:
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        labelStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.chip,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.card,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        iconColor: colorScheme.onSurfaceVariant,
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        elevation: AppElevation.extraHigh,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.dialog,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        elevation: AppElevation.extraHigh,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.bottomSheet,
        ),
        dragHandleColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        dragHandleSize: const Size(32, 4),
        showDragHandle: true,
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onInverseSurface,
          fontSize: 14,
        ),
        actionTextColor: colorScheme.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.card,
        ),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primaryContainer,
        circularTrackColor: colorScheme.primaryContainer,
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.primaryContainer,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
        valueIndicatorColor: colorScheme.primaryContainer,
        valueIndicatorTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onPrimaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        ),
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: colorScheme.outlineVariant,
      ),

      // Navigation Bar Theme
      navigationBarTheme: NavigationBarThemeData(
        elevation: AppElevation.medium,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: isSelected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),

      // Popup Menu Theme
      popupMenuTheme: PopupMenuThemeData(
        elevation: AppElevation.high,
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.card,
        ),
        textStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onSurface,
          fontSize: 14,
        ),
      ),

      // Tooltip Theme
      tooltipTheme: TooltipThemeData(
        preferBelow: true,
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: AppBorderRadius.chip,
        ),
        textStyle: TextStyle(
          fontFamily: 'Outfit',
          color: colorScheme.onInverseSurface,
          fontSize: 12,
        ),
      ),

      // Badge Theme
      badgeTheme: BadgeThemeData(
        backgroundColor: colorScheme.error,
        textColor: colorScheme.onError,
        textStyle: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Segmented Button Theme
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.secondaryContainer;
            }
            return colorScheme.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.onSecondaryContainer;
            }
            return colorScheme.onSurface;
          }),
          side: WidgetStateProperty.all(
            BorderSide(color: colorScheme.outline),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // Theme Extensions & Utilities
  // ==========================================================================

  /// Returns the appropriate scanner overlay color for the current brightness.
  static Color getScannerOverlayColor(Brightness brightness) {
    return brightness == Brightness.light
        ? AppColors.scannerOverlayLight
        : AppColors.scannerOverlayDark;
  }

  /// Returns the appropriate scanner border color for the current brightness.
  static Color getScannerBorderColor(Brightness brightness) {
    return brightness == Brightness.light
        ? AppColors.scannerBorderLight
        : AppColors.scannerBorderDark;
  }

  /// Returns the success color for the current brightness.
  static Color getSuccessColor(Brightness brightness) {
    return brightness == Brightness.light
        ? AppColors.successLight
        : AppColors.successDark;
  }

  /// Returns the warning color for the current brightness.
  static Color getWarningColor(Brightness brightness) {
    return brightness == Brightness.light
        ? AppColors.warningLight
        : AppColors.warningDark;
  }

  /// Gets a folder color by index from the predefined palette.
  static Color getFolderColor(int index) {
    return AppColors.folderColors[index % AppColors.folderColors.length];
  }

  /// Parses a color from a hex string (e.g., "#FF0000" or "FF0000").
  static Color? parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) return null;

    try {
      String hex = colorString.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex'; // Add alpha if not present
      }
      return Color(int.parse(hex, radix: 16));
    } on Object catch (_) {
      return null;
    }
  }

  /// Converts a color to a hex string (e.g., "#FF0000").
  static String colorToHex(Color color, {bool includeHash = true}) {
    final hex = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return includeHash ? '#$hex' : hex;
  }
}

// ============================================================================
// Theme Extension Methods
// ============================================================================

/// Extension methods on [BuildContext] for easier theme access.
extension ThemeContextExtension on BuildContext {
  /// Gets the current [ThemeData].
  ThemeData get theme => Theme.of(this);

  /// Gets the current [ColorScheme].
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Gets the current [TextTheme].
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Returns true if the current theme is dark.
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Returns true if the current theme is light.
  bool get isLightMode => Theme.of(this).brightness == Brightness.light;

  /// Gets the success color for the current theme.
  Color get successColor => AppTheme.getSuccessColor(Theme.of(this).brightness);

  /// Gets the warning color for the current theme.
  Color get warningColor => AppTheme.getWarningColor(Theme.of(this).brightness);

  /// Gets the scanner overlay color for the current theme.
  Color get scannerOverlayColor =>
      AppTheme.getScannerOverlayColor(Theme.of(this).brightness);

  /// Gets the scanner border color for the current theme.
  Color get scannerBorderColor =>
      AppTheme.getScannerBorderColor(Theme.of(this).brightness);
}
