import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State provider for flash toggle.
///
/// Manages the flash state for the scanner controls.
/// Note: ML Kit handles flash internally, this provides UI state.
final flashEnabledProvider = StateProvider<bool>((ref) => false);

/// A large circular button for capturing document scans.
///
/// This button triggers the document scanning workflow and provides
/// visual feedback during the scanning process.
///
/// ## Usage
/// ```dart
/// CaptureButton(
///   onPressed: () => ref.read(scannerScreenProvider.notifier).quickScan(),
///   isLoading: state.isScanning,
/// )
/// ```
class CaptureButton extends StatelessWidget {
  /// Creates a [CaptureButton].
  const CaptureButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.size = 72.0,
  });

  /// Callback invoked when the button is pressed.
  ///
  /// Should trigger the document scanning workflow.
  final VoidCallback? onPressed;

  /// Whether a scan is currently in progress.
  ///
  /// When true, displays a loading indicator instead of the capture icon.
  final bool isLoading;

  /// The diameter of the capture button.
  ///
  /// Defaults to 72.0 pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: isLoading ? 'Scanning in progress' : 'Capture document',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.primary,
            width: 4,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Material(
          color: isLoading
              ? colorScheme.primary.withOpacity(0.7)
              : colorScheme.primary,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            customBorder: const CircleBorder(),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: size * 0.35,
                      height: size * 0.35,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : Icon(
                      Icons.camera_alt,
                      size: size * 0.4,
                      color: colorScheme.onPrimary,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A toggle button for controlling the camera flash.
///
/// Provides visual feedback for flash state with on/off icons.
/// Note: ML Kit handles actual flash control internally when
/// the scanner is active; this widget manages UI state.
///
/// ## Usage
/// ```dart
/// FlashToggleButton(
///   isEnabled: isFlashOn,
///   onToggle: (enabled) => setState(() => isFlashOn = enabled),
/// )
/// ```
class FlashToggleButton extends StatelessWidget {
  /// Creates a [FlashToggleButton].
  const FlashToggleButton({
    super.key,
    required this.isEnabled,
    required this.onToggle,
    this.size = 48.0,
  });

  /// Whether the flash is currently enabled.
  final bool isEnabled;

  /// Callback invoked when the flash state is toggled.
  final ValueChanged<bool> onToggle;

  /// The diameter of the button.
  ///
  /// Defaults to 48.0 pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: isEnabled ? 'Flash on, tap to turn off' : 'Flash off, tap to turn on',
      child: Material(
        color: isEnabled
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onToggle(!isEnabled),
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              isEnabled ? Icons.flash_on : Icons.flash_off,
              color: isEnabled
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
              size: size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// A Riverpod-aware version of [FlashToggleButton].
///
/// Automatically manages flash state using [flashEnabledProvider].
///
/// ## Usage
/// ```dart
/// const FlashToggleButtonConsumer()
/// ```
class FlashToggleButtonConsumer extends ConsumerWidget {
  /// Creates a [FlashToggleButtonConsumer].
  const FlashToggleButtonConsumer({
    super.key,
    this.size = 48.0,
  });

  /// The diameter of the button.
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(flashEnabledProvider);

    return FlashToggleButton(
      isEnabled: isEnabled,
      onToggle: (enabled) {
        ref.read(flashEnabledProvider.notifier).state = enabled;
      },
      size: size,
    );
  }
}

/// A button for importing documents from the device gallery.
///
/// Allows users to select existing photos as documents instead of
/// capturing new ones with the camera.
///
/// ## Usage
/// ```dart
/// GalleryImportButton(
///   onPressed: () => ref.read(scannerScreenProvider.notifier)
///     .startScan(options: const ScannerOptions(allowGalleryImport: true)),
/// )
/// ```
class GalleryImportButton extends StatelessWidget {
  /// Creates a [GalleryImportButton].
  const GalleryImportButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.size = 48.0,
  });

  /// Callback invoked when the button is pressed.
  ///
  /// Should trigger gallery import workflow.
  final VoidCallback? onPressed;

  /// Whether an import is currently in progress.
  final bool isLoading;

  /// The diameter of the button.
  ///
  /// Defaults to 48.0 pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: isLoading ? 'Importing from gallery' : 'Import from gallery',
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: isLoading
                ? Padding(
                    padding: EdgeInsets.all(size * 0.25),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : Icon(
                    Icons.photo_library_outlined,
                    color: colorScheme.onSurfaceVariant,
                    size: size * 0.5,
                  ),
          ),
        ),
      ),
    );
  }
}

/// A button for switching between single and multi-page scan modes.
///
/// Provides visual feedback for the current scanning mode and allows
/// users to toggle between capturing single pages or multiple pages.
///
/// ## Usage
/// ```dart
/// ScanModeButton(
///   isMultiPage: scanMode == ScanMode.multiPage,
///   onToggle: (isMulti) => setState(() => scanMode = isMulti
///     ? ScanMode.multiPage
///     : ScanMode.single),
/// )
/// ```
class ScanModeButton extends StatelessWidget {
  /// Creates a [ScanModeButton].
  const ScanModeButton({
    super.key,
    required this.isMultiPage,
    required this.onToggle,
    this.size = 48.0,
  });

  /// Whether multi-page mode is currently active.
  final bool isMultiPage;

  /// Callback invoked when the scan mode is toggled.
  final ValueChanged<bool> onToggle;

  /// The diameter of the button.
  ///
  /// Defaults to 48.0 pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: isMultiPage
          ? 'Multi-page mode active, tap for single page'
          : 'Single page mode active, tap for multi-page',
      child: Material(
        color: isMultiPage
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onToggle(!isMultiPage),
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.description_outlined,
                  color: isMultiPage
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  size: size * 0.45,
                ),
                if (isMultiPage)
                  Positioned(
                    right: size * 0.15,
                    bottom: size * 0.15,
                    child: Container(
                      width: size * 0.3,
                      height: size * 0.3,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add,
                          color: colorScheme.onPrimary,
                          size: size * 0.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A composite widget containing all scanner control buttons.
///
/// Provides a ready-to-use scanner control bar with:
/// - Gallery import button (left)
/// - Capture button (center)
/// - Flash toggle button (right)
///
/// ## Layout
/// ```
/// [Gallery]  [    Capture    ]  [Flash]
/// ```
///
/// ## Usage
/// ```dart
/// ScannerControls(
///   onCapture: () => startScan(),
///   onGalleryImport: () => importFromGallery(),
///   isScanning: isLoading,
/// )
/// ```
class ScannerControls extends StatelessWidget {
  /// Creates a [ScannerControls] widget.
  const ScannerControls({
    super.key,
    required this.onCapture,
    this.onGalleryImport,
    this.isScanning = false,
    this.showFlash = true,
    this.showGallery = true,
    this.captureButtonSize = 72.0,
    this.secondaryButtonSize = 48.0,
    this.flashEnabled = false,
    this.onFlashToggle,
  });

  /// Callback invoked when the capture button is pressed.
  final VoidCallback onCapture;

  /// Callback invoked when the gallery import button is pressed.
  ///
  /// If null, the gallery button will be disabled.
  final VoidCallback? onGalleryImport;

  /// Whether a scan is currently in progress.
  final bool isScanning;

  /// Whether to show the flash toggle button.
  final bool showFlash;

  /// Whether to show the gallery import button.
  final bool showGallery;

  /// The size of the main capture button.
  final double captureButtonSize;

  /// The size of secondary buttons (flash, gallery).
  final double secondaryButtonSize;

  /// Whether the flash is currently enabled.
  final bool flashEnabled;

  /// Callback invoked when the flash is toggled.
  ///
  /// If null, the flash button will manage its own state.
  final ValueChanged<bool>? onFlashToggle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Gallery import button (left side)
            if (showGallery)
              GalleryImportButton(
                onPressed: isScanning ? null : onGalleryImport,
                isLoading: false,
                size: secondaryButtonSize,
              )
            else
              SizedBox(width: secondaryButtonSize),

            // Main capture button (center)
            CaptureButton(
              onPressed: isScanning ? null : onCapture,
              isLoading: isScanning,
              size: captureButtonSize,
            ),

            // Flash toggle button (right side)
            if (showFlash)
              onFlashToggle != null
                  ? FlashToggleButton(
                      isEnabled: flashEnabled,
                      onToggle: onFlashToggle!,
                      size: secondaryButtonSize,
                    )
                  : FlashToggleButtonConsumer(size: secondaryButtonSize)
            else
              SizedBox(width: secondaryButtonSize),
          ],
        ),
      ),
    );
  }
}

/// An animated capture button with a pulsing effect.
///
/// Extends [CaptureButton] with a subtle animation to draw
/// attention when ready to capture.
///
/// ## Usage
/// ```dart
/// AnimatedCaptureButton(
///   onPressed: () => startScan(),
///   animate: !isScanning,
/// )
/// ```
class AnimatedCaptureButton extends StatefulWidget {
  /// Creates an [AnimatedCaptureButton].
  const AnimatedCaptureButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.animate = true,
    this.size = 72.0,
  });

  /// Callback invoked when the button is pressed.
  final VoidCallback? onPressed;

  /// Whether a scan is currently in progress.
  final bool isLoading;

  /// Whether to animate the button.
  ///
  /// Set to false to disable the pulsing animation.
  final bool animate;

  /// The diameter of the capture button.
  final double size;

  @override
  State<AnimatedCaptureButton> createState() => _AnimatedCaptureButtonState();
}

class _AnimatedCaptureButtonState extends State<AnimatedCaptureButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.animate && !widget.isLoading) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedCaptureButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !widget.isLoading) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.animate && !widget.isLoading ? _scaleAnimation.value : 1.0,
          child: CaptureButton(
            onPressed: widget.onPressed,
            isLoading: widget.isLoading,
            size: widget.size,
          ),
        );
      },
    );
  }
}

/// A compact scanner controls bar designed for bottom positioning.
///
/// Provides a minimalist control bar suitable for overlay positioning
/// at the bottom of a camera preview.
///
/// ## Usage
/// ```dart
/// Positioned(
///   bottom: 0,
///   left: 0,
///   right: 0,
///   child: CompactScannerControls(
///     onCapture: () => startScan(),
///   ),
/// )
/// ```
class CompactScannerControls extends StatelessWidget {
  /// Creates a [CompactScannerControls] widget.
  const CompactScannerControls({
    super.key,
    required this.onCapture,
    this.onGalleryImport,
    this.isScanning = false,
    this.backgroundColor,
  });

  /// Callback invoked when the capture button is pressed.
  final VoidCallback onCapture;

  /// Callback invoked when gallery import is requested.
  final VoidCallback? onGalleryImport;

  /// Whether a scan is currently in progress.
  final bool isScanning;

  /// Background color for the controls bar.
  ///
  /// If null, uses a semi-transparent surface color.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surface.withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ScannerControls(
        onCapture: onCapture,
        onGalleryImport: onGalleryImport,
        isScanning: isScanning,
        captureButtonSize: 64.0,
        secondaryButtonSize: 44.0,
      ),
    );
  }
}
