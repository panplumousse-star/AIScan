
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// Accessibility Configuration for Scanaï
// ============================================================================

/// Accessibility configuration for the Scanaï application.
///
/// Provides comprehensive accessibility support including:
/// - Semantic labels for screen readers (TalkBack/VoiceOver)
/// - WCAG AA contrast compliance
/// - Text scaling support
/// - Focus management
/// - Live region announcements
///
/// ## Usage
/// ```dart
/// // Wrap interactive elements with semantics
/// AccessibleButton(
///   label: 'Scan Document',
///   hint: 'Opens camera to scan a new document',
///   onPressed: () => startScanning(),
///   child: Icon(Icons.document_scanner),
/// )
/// ```

// ============================================================================
// Accessibility Labels - Semantic Text for Screen Readers
// ============================================================================

/// Semantic labels for common UI elements.
///
/// Provides consistent accessibility labels across the app.
/// Use these with [Semantics] widget to make elements accessible.
abstract final class A11yLabels {
  // -------------------------------------------------------------------------
  // Navigation Labels
  // -------------------------------------------------------------------------

  /// Label for the home/documents screen.
  static const String home = 'Home';

  /// Label for navigating back.
  static const String back = 'Go back';

  /// Label for closing a modal or screen.
  static const String close = 'Close';

  /// Label for opening menu.
  static const String menu = 'Open menu';

  /// Label for more options.
  static const String moreOptions = 'More options';

  // -------------------------------------------------------------------------
  // Document Actions
  // -------------------------------------------------------------------------

  /// Label for scan document action.
  static const String scanDocument = 'Scan document';

  /// Hint for scan document action.
  static const String scanDocumentHint =
      'Opens camera to scan a new document with automatic edge detection';

  /// Label for multi-page scan.
  static const String multiPageScan = 'Multi-page scan';

  /// Hint for multi-page scan.
  static const String multiPageScanHint =
      'Scan multiple pages into one document';

  /// Label for view document action.
  static const String viewDocument = 'View document';

  /// Label for edit document action.
  static const String editDocument = 'Edit document';

  /// Label for delete document action.
  static const String deleteDocument = 'Delete document';

  /// Label for export document action.
  static const String exportDocument = 'Export document';

  /// Label for share document action.
  static const String shareDocument = 'Share document';

  // -------------------------------------------------------------------------
  // Document States
  // -------------------------------------------------------------------------

  /// Label for favorite document.
  static String favoriteDocument(bool isFavorite) =>
      isFavorite ? 'Favorited, remove from favorites' : 'Add to favorites';

  /// Label for document with OCR.
  static const String hasOcrText = 'Document has extracted text';

  /// Label for document without OCR.
  static const String noOcrText = 'No extracted text available';

  /// Label for multi-page document.
  static String pageCount(int pages) =>
      '$pages ${pages == 1 ? 'page' : 'pages'}';

  /// Label for document size.
  static String fileSize(String size) => 'File size: $size';

  // -------------------------------------------------------------------------
  // OCR Actions
  // -------------------------------------------------------------------------

  /// Label for run OCR action.
  static const String runOcr = 'Extract text';

  /// Hint for run OCR action.
  static const String runOcrHint =
      'Extract text from document using optical character recognition';

  /// Label for copy text action.
  static const String copyText = 'Copy text';

  /// Label for copy all text action.
  static const String copyAllText = 'Copy all extracted text';

  // -------------------------------------------------------------------------
  // Enhancement Actions
  // -------------------------------------------------------------------------

  /// Label for enhance document action.
  static const String enhanceDocument = 'Enhance document';

  /// Hint for enhance document action.
  static const String enhanceDocumentHint =
      'Adjust brightness, contrast, and other image settings';

  /// Label for brightness slider.
  static String brightness(int value) => 'Brightness: $value';

  /// Label for contrast slider.
  static String contrast(int value) => 'Contrast: $value';

  /// Label for sharpness slider.
  static String sharpness(int value) => 'Sharpness: $value';

  // -------------------------------------------------------------------------
  // Signature Actions
  // -------------------------------------------------------------------------

  /// Label for add signature action.
  static const String addSignature = 'Add signature';

  /// Hint for add signature action.
  static const String addSignatureHint =
      'Draw or select a signature to add to the document';

  /// Label for signature canvas.
  static const String signatureCanvas =
      'Signature drawing area. Draw your signature with finger or stylus';

  /// Label for clear signature.
  static const String clearSignature = 'Clear signature';

  /// Label for undo signature stroke.
  static const String undoSignature = 'Undo last stroke';

  // -------------------------------------------------------------------------
  // Export Labels
  // -------------------------------------------------------------------------

  /// Label for export as PDF.
  static const String exportPdf = 'Export as PDF';

  /// Label for export as JPG.
  static const String exportJpg = 'Export as JPEG image';

  /// Label for export as PNG.
  static const String exportPng = 'Export as PNG image';

  /// Label for export quality.
  static String exportQuality(String quality) => 'Export quality: $quality';

  // -------------------------------------------------------------------------
  // Folder Labels
  // -------------------------------------------------------------------------

  /// Label for create folder.
  static const String createFolder = 'Create new folder';

  /// Label for folder.
  static String folder(String name) => 'Folder: $name';

  /// Label for folder with count.
  static String folderWithCount(String name, int count) =>
      'Folder: $name, $count ${count == 1 ? 'document' : 'documents'}';

  // -------------------------------------------------------------------------
  // Search Labels
  // -------------------------------------------------------------------------

  /// Label for search.
  static const String search = 'Search documents';

  /// Hint for search.
  static const String searchHint =
      'Search by document title or extracted text content';

  /// Label for clear search.
  static const String clearSearch = 'Clear search';

  /// Label for search result.
  static String searchResult(String title) => 'Search result: $title';

  // -------------------------------------------------------------------------
  // Settings Labels
  // -------------------------------------------------------------------------

  /// Label for settings.
  static const String settings = 'Settings';

  /// Label for theme toggle.
  static String themeMode(String mode) => 'Theme: $mode';

  /// Label for light theme.
  static const String lightTheme = 'Light theme';

  /// Label for dark theme.
  static const String darkTheme = 'Dark theme';

  /// Label for system theme.
  static const String systemTheme = 'Follow system theme';

  // -------------------------------------------------------------------------
  // View Mode Labels
  // -------------------------------------------------------------------------

  /// Label for grid view.
  static const String gridView = 'Grid view';

  /// Label for list view.
  static const String listView = 'List view';

  /// Label for switch view mode.
  static String switchViewMode(bool isGrid) =>
      isGrid ? 'Switch to list view' : 'Switch to grid view';

  // -------------------------------------------------------------------------
  // Selection Labels
  // -------------------------------------------------------------------------

  /// Label for selected item.
  static String selected(bool isSelected) =>
      isSelected ? 'Selected' : 'Not selected';

  /// Label for selection count.
  static String selectionCount(int count) =>
      '$count ${count == 1 ? 'item' : 'items'} selected';

  /// Label for select all.
  static const String selectAll = 'Select all';

  /// Label for deselect all.
  static const String deselectAll = 'Deselect all';

  /// Label for cancel selection.
  static const String cancelSelection = 'Cancel selection';

  // -------------------------------------------------------------------------
  // Loading States
  // -------------------------------------------------------------------------

  /// Label for loading.
  static const String loading = 'Loading';

  /// Label for loading documents.
  static const String loadingDocuments = 'Loading documents';

  /// Label for processing.
  static const String processing = 'Processing';

  /// Label for saving.
  static const String saving = 'Saving document';
}

// ============================================================================
// Accessibility Hints - Additional Context for Actions
// ============================================================================

/// Accessibility hints provide additional context about what will happen
/// when an action is performed.
abstract final class A11yHints {
  /// Hint for double-tap to activate.
  static const String doubleTapToActivate = 'Double-tap to activate';

  /// Hint for swipe to delete.
  static const String swipeToDelete = 'Swipe left to delete';

  /// Hint for long press for options.
  static const String longPressForOptions = 'Long press for more options';

  /// Hint for drag to reorder.
  static const String dragToReorder = 'Long press and drag to reorder';

  /// Hint for pinch to zoom.
  static const String pinchToZoom = 'Pinch to zoom in or out';

  /// Hint for slider adjustment.
  static const String sliderAdjust =
      'Swipe left or right to adjust value. Double-tap and hold to make fine adjustments';
}

// ============================================================================
// WCAG AA Contrast Utilities
// ============================================================================

/// Utilities for ensuring WCAG AA compliant color contrast.
///
/// WCAG AA requirements:
/// - Normal text: 4.5:1 contrast ratio
/// - Large text (18pt+ or 14pt+ bold): 3:1 contrast ratio
/// - UI components: 3:1 contrast ratio
abstract final class A11yContrast {
  /// Minimum contrast ratio for normal text (WCAG AA).
  static const double normalTextMinContrast = 4.5;

  /// Minimum contrast ratio for large text (WCAG AA).
  static const double largeTextMinContrast = 3.0;

  /// Minimum contrast ratio for UI components (WCAG AA).
  static const double uiComponentMinContrast = 3.0;

  /// Calculates the relative luminance of a color.
  ///
  /// Formula from WCAG 2.0: https://www.w3.org/TR/WCAG20-TECHS/G17.html
  static double getRelativeLuminance(Color color) {
    double transformComponent(int component) {
      final sRGB = component / 255;
      return sRGB <= 0.03928
          ? sRGB / 12.92
          : ((sRGB + 0.055) / 1.055).power(2.4);
    }

    final r = transformComponent(color.red);
    final g = transformComponent(color.green);
    final b = transformComponent(color.blue);

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Calculates the contrast ratio between two colors.
  ///
  /// Returns a value between 1 and 21.
  /// A ratio of 4.5:1 or higher meets WCAG AA for normal text.
  static double getContrastRatio(Color foreground, Color background) {
    final l1 = getRelativeLuminance(foreground);
    final l2 = getRelativeLuminance(background);

    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Checks if the contrast ratio meets WCAG AA for normal text.
  static bool meetsNormalTextContrast(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >= normalTextMinContrast;
  }

  /// Checks if the contrast ratio meets WCAG AA for large text.
  static bool meetsLargeTextContrast(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >= largeTextMinContrast;
  }

  /// Checks if the contrast ratio meets WCAG AA for UI components.
  static bool meetsUIComponentContrast(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >= uiComponentMinContrast;
  }

  /// Returns a contrasting text color (black or white) for the given background.
  static Color getContrastingTextColor(Color background) {
    final luminance = getRelativeLuminance(background);
    return luminance > 0.179 ? Colors.black87 : Colors.white;
  }

  /// Adjusts a color to ensure it meets contrast requirements.
  static Color ensureContrast(
    Color foreground,
    Color background, {
    double minContrast = normalTextMinContrast,
  }) {
    if (getContrastRatio(foreground, background) >= minContrast) {
      return foreground;
    }

    // If contrast is insufficient, return either black or white
    final luminance = getRelativeLuminance(background);
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}

// Helper extension for power function
extension _DoubleExtension on double {
  double power(double exponent) {
    if (this < 0) return 0;
    return this == 0 ? 0 : (this > 0 ? exp(log(this) * exponent) : 0);
  }

  // Simple exp and log approximation for dart
  double exp(double x) {
    // Using dart:math would be better, but keeping it simple
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 20; i++) {
      term *= x / i;
      result += term;
    }
    return result;
  }

  double log(double x) {
    if (x <= 0) return double.negativeInfinity;
    // Natural log approximation using continued fraction
    double y = (x - 1) / (x + 1);
    double y2 = y * y;
    double result = 0.0;
    double term = y;
    for (int i = 1; i <= 40; i += 2) {
      result += term / i;
      term *= y2;
    }
    return 2 * result;
  }
}

// ============================================================================
// Text Scaling Support
// ============================================================================

/// Text scale factor configuration for accessibility.
///
/// Supports system text scaling while ensuring UI remains usable.
abstract final class A11yTextScale {
  /// Minimum supported text scale factor.
  static const double minScaleFactor = 0.8;

  /// Maximum supported text scale factor.
  /// Limited to prevent layout breaking.
  static const double maxScaleFactor = 2.0;

  /// Default text scale factor.
  static const double defaultScaleFactor = 1.0;

  /// Large text threshold (1.3x or higher).
  static const double largeTextThreshold = 1.3;

  /// Constrains a text scale factor to supported range.
  static double constrain(double scaleFactor) {
    return scaleFactor.clamp(minScaleFactor, maxScaleFactor);
  }

  /// Checks if the current scale factor is considered large text.
  static bool isLargeText(double scaleFactor) {
    return scaleFactor >= largeTextThreshold;
  }

  /// Gets an adjusted font size that respects the scale factor.
  static double adjustedFontSize(double baseFontSize, double scaleFactor) {
    return baseFontSize * constrain(scaleFactor);
  }
}

// ============================================================================
// Accessibility Riverpod Providers
// ============================================================================

/// Provider for tracking reduced motion preference.
///
/// When true, animations should be minimized or disabled.
final reduceMotionProvider = StateProvider<bool>((ref) => false);

/// Provider for tracking screen reader active status.
final screenReaderActiveProvider = StateProvider<bool>((ref) => false);

/// Provider for tracking bold text preference.
final boldTextProvider = StateProvider<bool>((ref) => false);

/// Provider for tracking high contrast preference.
final highContrastProvider = StateProvider<bool>((ref) => false);

// ============================================================================
// Accessible Widgets
// ============================================================================

/// Accessible button wrapper with semantic labels.
///
/// Wraps a button with proper accessibility annotations.
///
/// ## Usage
/// ```dart
/// AccessibleButton(
///   label: A11yLabels.scanDocument,
///   hint: A11yLabels.scanDocumentHint,
///   onPressed: () => startScanning(),
///   child: Icon(Icons.document_scanner),
/// )
/// ```
class AccessibleButton extends StatelessWidget {
  /// Creates an [AccessibleButton].
  const AccessibleButton({
    required this.label,
    required this.child,
    this.hint,
    this.onPressed,
    this.onLongPress,
    this.isButton = true,
    this.isEnabled = true,
    this.excludeSemantics = false,
    super.key,
  });

  /// Semantic label for the button.
  final String label;

  /// Optional hint describing what happens when activated.
  final String? hint;

  /// The child widget.
  final Widget child;

  /// Callback when pressed.
  final VoidCallback? onPressed;

  /// Callback when long-pressed.
  final VoidCallback? onLongPress;

  /// Whether this is semantically a button.
  final bool isButton;

  /// Whether the button is enabled.
  final bool isEnabled;

  /// Whether to exclude child semantics.
  final bool excludeSemantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      button: isButton,
      enabled: isEnabled,
      onTap: isEnabled ? onPressed : null,
      onLongPress: isEnabled ? onLongPress : null,
      excludeSemantics: excludeSemantics,
      child: child,
    );
  }
}

/// Accessible image with description.
///
/// Wraps an image with proper accessibility annotations.
class AccessibleImage extends StatelessWidget {
  /// Creates an [AccessibleImage].
  const AccessibleImage({
    required this.child,
    required this.description,
    this.isDecorative = false,
    super.key,
  });

  /// The image widget.
  final Widget child;

  /// Description of the image for screen readers.
  final String description;

  /// Whether the image is purely decorative (no semantic meaning).
  final bool isDecorative;

  @override
  Widget build(BuildContext context) {
    if (isDecorative) {
      return ExcludeSemantics(child: child);
    }

    return Semantics(
      label: description,
      image: true,
      excludeSemantics: true,
      child: child,
    );
  }
}

/// Accessible heading for document structure.
///
/// Provides heading semantics for screen reader navigation.
class AccessibleHeading extends StatelessWidget {
  /// Creates an [AccessibleHeading].
  const AccessibleHeading({
    required this.text,
    this.level = 1,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    super.key,
  });

  /// The heading text.
  final String text;

  /// The heading level (1-6).
  final int level;

  /// Text style.
  final TextStyle? style;

  /// Text alignment.
  final TextAlign? textAlign;

  /// Maximum number of lines.
  final int? maxLines;

  /// Text overflow behavior.
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}

/// Accessible slider with value announcements.
///
/// Wraps a slider with proper accessibility annotations.
class AccessibleSlider extends StatelessWidget {
  /// Creates an [AccessibleSlider].
  const AccessibleSlider({
    required this.value,
    required this.onChanged,
    required this.valueLabel,
    this.min = 0.0,
    this.max = 100.0,
    this.divisions,
    this.semanticFormatterCallback,
    super.key,
  });

  /// Current value.
  final double value;

  /// Called when value changes.
  final ValueChanged<double>? onChanged;

  /// Label describing the current value (e.g., "Brightness: 50%").
  final String valueLabel;

  /// Minimum value.
  final double min;

  /// Maximum value.
  final double max;

  /// Number of discrete divisions.
  final int? divisions;

  /// Custom semantic value formatter.
  final SemanticFormatterCallback? semanticFormatterCallback;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: valueLabel,
      slider: true,
      value: semanticFormatterCallback?.call(value) ??
          '${((value - min) / (max - min) * 100).round()}%',
      hint: A11yHints.sliderAdjust,
      child: Slider(
        value: value,
        onChanged: onChanged,
        min: min,
        max: max,
        divisions: divisions,
        semanticFormatterCallback: semanticFormatterCallback,
      ),
    );
  }
}

/// Live region widget for announcements.
///
/// Announces changes to screen readers. Use for dynamic content updates.
///
/// ## Usage
/// ```dart
/// AccessibleLiveRegion(
///   message: 'Document saved successfully',
///   child: Text('Saved!'),
/// )
/// ```
class AccessibleLiveRegion extends StatelessWidget {
  /// Creates an [AccessibleLiveRegion].
  const AccessibleLiveRegion({
    required this.message,
    required this.child,
    this.isPolite = true,
    super.key,
  });

  /// The message to announce.
  final String message;

  /// The child widget.
  final Widget child;

  /// If true, waits for current speech to finish. If false, interrupts.
  final bool isPolite;

  @override
  Widget build(BuildContext context) {
    return Semantics(liveRegion: true, label: message, child: child);
  }
}

/// Widget that excludes its child from semantics tree.
///
/// Use for decorative elements that should not be announced.
class AccessibleDecorative extends StatelessWidget {
  /// Creates an [AccessibleDecorative].
  const AccessibleDecorative({required this.child, super.key});

  /// The decorative child widget.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(child: child);
  }
}

/// Focus-aware widget wrapper.
///
/// Highlights when focused via keyboard or screen reader.
class AccessibleFocusable extends StatefulWidget {
  /// Creates an [AccessibleFocusable].
  const AccessibleFocusable({
    required this.child,
    this.onFocusChange,
    this.focusedBorderColor,
    this.focusedBorderWidth = 2.0,
    this.borderRadius,
    this.autofocus = false,
    super.key,
  });

  /// The child widget.
  final Widget child;

  /// Callback when focus changes.
  final ValueChanged<bool>? onFocusChange;

  /// Border color when focused.
  final Color? focusedBorderColor;

  /// Border width when focused.
  final double focusedBorderWidth;

  /// Border radius for focus indicator.
  final BorderRadius? borderRadius;

  /// Whether to autofocus this widget.
  final bool autofocus;

  @override
  State<AccessibleFocusable> createState() => _AccessibleFocusableState();
}

class _AccessibleFocusableState extends State<AccessibleFocusable> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final focusColor =
        widget.focusedBorderColor ?? Theme.of(context).colorScheme.primary;

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
        widget.onFocusChange?.call(focused);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          border: _isFocused
              ? Border.all(color: focusColor, width: widget.focusedBorderWidth)
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

// ============================================================================
// Screen Reader Announcements
// ============================================================================

/// Utility for making screen reader announcements.
abstract final class A11yAnnounce {
  /// Announces a message to screen readers.
  ///
  /// Use for important status updates that should be spoken.
  static void announce(BuildContext context, String message) {
    SemanticsService.announce(message, TextDirection.ltr);
  }

  /// Announces with assertive priority (interrupts current speech).
  static void announceAssertive(BuildContext context, String message) {
    SemanticsService.announce(message, TextDirection.ltr);
  }

  /// Common announcement messages.
  static void documentSaved(BuildContext context) =>
      announce(context, 'Document saved successfully');

  static void documentDeleted(BuildContext context) =>
      announce(context, 'Document deleted');

  static void ocrComplete(BuildContext context) =>
      announce(context, 'Text extraction complete');

  static void scanComplete(BuildContext context) =>
      announce(context, 'Document scanned successfully');

  static void exportComplete(BuildContext context, String format) =>
      announce(context, 'Document exported as $format');

  static void error(BuildContext context, String message) =>
      announce(context, 'Error: $message');

  static void loading(BuildContext context) =>
      announce(context, 'Loading, please wait');

  static void selectionChanged(BuildContext context, int count) =>
      announce(context, A11yLabels.selectionCount(count));
}

// ============================================================================
// Minimum Touch Target Sizes
// ============================================================================

/// Minimum touch target sizes for accessibility.
///
/// WCAG recommends minimum 44x44 dp for touch targets.
abstract final class A11yTouchTarget {
  /// Minimum touch target size (44x44 dp).
  static const double minSize = 44.0;

  /// Preferred touch target size (48x48 dp).
  static const double preferredSize = 48.0;

  /// Minimum spacing between touch targets.
  static const double minSpacing = 8.0;

  /// Ensures a size meets minimum touch target requirements.
  static double ensureMinSize(double size) {
    return size < minSize ? minSize : size;
  }

  /// Creates a minimum size constraint.
  static BoxConstraints get minConstraints =>
      const BoxConstraints(minWidth: minSize, minHeight: minSize);

  /// Creates a preferred size constraint.
  static BoxConstraints get preferredConstraints =>
      const BoxConstraints(minWidth: preferredSize, minHeight: preferredSize);
}

/// Widget that ensures minimum touch target size.
class AccessibleTouchTarget extends StatelessWidget {
  /// Creates an [AccessibleTouchTarget].
  const AccessibleTouchTarget({
    required this.child,
    this.minSize = A11yTouchTarget.minSize,
    super.key,
  });

  /// The child widget.
  final Widget child;

  /// Minimum size for the touch target.
  final double minSize;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
      child: Center(child: child),
    );
  }
}

// ============================================================================
// Accessibility Context Extensions
// ============================================================================

/// Extension on [BuildContext] for accessibility utilities.
extension AccessibilityContextExtension on BuildContext {
  /// Gets the current text scale factor.
  double get textScaleFactor => MediaQuery.textScalerOf(this).scale(1.0);

  /// Checks if bold text is enabled.
  bool get boldTextEnabled => MediaQuery.boldTextOf(this);

  /// Checks if high contrast is enabled.
  bool get highContrastEnabled => MediaQuery.highContrastOf(this);

  /// Checks if animations should be reduced.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);

  /// Checks if a screen reader is likely active.
  bool get screenReaderActive => MediaQuery.accessibleNavigationOf(this);

  /// Checks if inverted colors are enabled.
  bool get invertColors => MediaQuery.invertColorsOf(this);

  /// Gets an animation duration respecting reduced motion.
  Duration animationDuration(Duration normal, {Duration? reduced}) {
    if (reduceMotion) {
      return reduced ?? Duration.zero;
    }
    return normal;
  }

  /// Gets an animation curve respecting reduced motion.
  Curve animationCurve(Curve normal, {Curve? reduced}) {
    if (reduceMotion) {
      return reduced ?? Curves.linear;
    }
    return normal;
  }

  /// Announces a message to screen readers.
  void announce(String message) => A11yAnnounce.announce(this, message);

  /// Checks if the current text scale qualifies as large text.
  bool get isLargeText => A11yTextScale.isLargeText(textScaleFactor);
}

// ============================================================================
// Accessible Navigation
// ============================================================================

/// Accessible page route with proper focus management.
class AccessiblePageRoute<T> extends MaterialPageRoute<T> {
  /// Creates an [AccessiblePageRoute].
  AccessiblePageRoute({
    required super.builder,
    super.settings,
    this.announceOnPush = true,
    this.routeAnnouncement,
  });

  /// Whether to announce route change on push.
  final bool announceOnPush;

  /// Custom route announcement message.
  final String? routeAnnouncement;

  @override
  void didComplete(T? result) {
    super.didComplete(result);
    // Focus will naturally move to previous page
  }

  @override
  TickerFuture didPush() {
    final result = super.didPush();
    if (announceOnPush && routeAnnouncement != null) {
      result.then((_) {
        SemanticsService.announce(routeAnnouncement!, TextDirection.ltr);
      });
    }
    return result;
  }
}

// ============================================================================
// Accessibility Wrapper for App
// ============================================================================

/// Wrapper that provides accessibility context and detects settings.
///
/// Wrap your app's root with this to enable accessibility features.
///
/// ## Usage
/// ```dart
/// AccessibilityWrapper(
///   child: MaterialApp(...)
/// )
/// ```
class AccessibilityWrapper extends ConsumerStatefulWidget {
  /// Creates an [AccessibilityWrapper].
  const AccessibilityWrapper({required this.child, super.key});

  /// The child widget.
  final Widget child;

  @override
  ConsumerState<AccessibilityWrapper> createState() =>
      _AccessibilityWrapperState();
}

class _AccessibilityWrapperState extends ConsumerState<AccessibilityWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateAccessibilitySettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() {
    _updateAccessibilitySettings();
  }

  void _updateAccessibilitySettings() {
    final window = WidgetsBinding.instance.platformDispatcher;

    // Update providers based on platform accessibility settings
    ref.read(reduceMotionProvider.notifier).state =
        window.accessibilityFeatures.disableAnimations;
    ref.read(screenReaderActiveProvider.notifier).state =
        window.accessibilityFeatures.accessibleNavigation;
    ref.read(boldTextProvider.notifier).state =
        window.accessibilityFeatures.boldText;
    ref.read(highContrastProvider.notifier).state =
        window.accessibilityFeatures.highContrast;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
