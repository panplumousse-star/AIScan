import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/widgets/bento_background.dart';
import '../../../core/widgets/bento_confirmation_dialog.dart';
import '../../../core/widgets/scanai_loader.dart';
import '../domain/image_processor.dart';

part 'enhancement_screen.freezed.dart';

/// State for the enhancement screen.
///
/// Contains all adjustment values and processing state.
@freezed
class EnhancementScreenState with _$EnhancementScreenState {
  const EnhancementScreenState._();

  /// Creates an [EnhancementScreenState] with default values.
  factory EnhancementScreenState({
    /// Brightness adjustment (-100 to 100).
    @Default(0) int brightness,

    /// Contrast adjustment (-100 to 100).
    @Default(0) int contrast,

    /// Sharpness enhancement (0 to 100).
    @Default(0) int sharpness,

    /// Saturation adjustment (-100 to 100).
    @Default(0) int saturation,

    /// Whether grayscale/B&W mode is enabled.
    @Default(false) bool grayscale,

    /// Whether auto-enhancement is enabled.
    @Default(false) bool autoEnhance,

    /// Whether noise reduction is enabled.
    @Default(false) bool denoise,

    /// Currently selected enhancement preset, if any.
    EnhancementPreset? selectedPreset,

    /// Whether image processing is in progress.
    @Default(false) bool isProcessing,

    /// Whether the enhanced image is being saved.
    @Default(false) bool isSaving,

    /// Error message, if any.
    String? error,

    /// Preview image bytes after enhancement.
    Uint8List? previewBytes,

    /// Original image bytes before enhancement.
    Uint8List? originalBytes,

    /// Preview-sized image bytes for faster processing.
    Uint8List? previewSizedBytes,

    /// Path to the source image file.
    String? imagePath,
    // ignore: redirect_to_invalid_return_type
  }) = _EnhancementScreenState;

  /// Whether we're in any loading state.
  bool get isLoading => isProcessing || isSaving;

  /// Whether we have a preview to show.
  bool get hasPreview => previewBytes != null;

  /// Whether we have original data loaded.
  bool get hasOriginal => originalBytes != null;

  /// Whether any enhancement has been applied.
  bool get hasEnhancements =>
      brightness != 0 ||
      contrast != 0 ||
      sharpness > 0 ||
      saturation != 0 ||
      grayscale ||
      autoEnhance ||
      denoise;

  /// Creates the [EnhancementOptions] from current state.
  EnhancementOptions toEnhancementOptions() {
    return EnhancementOptions(
      brightness: brightness,
      contrast: contrast,
      sharpness: sharpness,
      saturation: saturation,
      grayscale: grayscale,
      autoEnhance: autoEnhance,
      denoise: denoise,
    );
  }
}

/// State notifier for the enhancement screen.
///
/// Manages enhancement adjustments and preview generation with debouncing.
class EnhancementScreenNotifier extends StateNotifier<EnhancementScreenState> {
  /// Creates an [EnhancementScreenNotifier] with the given image processor.
  EnhancementScreenNotifier(
    this._imageProcessor,
  ) : super(EnhancementScreenState());

  final ImageProcessor _imageProcessor;
  Timer? _debounceTimer;

  /// Duration to wait before applying preview updates.
  static const _debounceDuration = Duration(milliseconds: 300);

  /// Loads an image from the given file path.
  Future<void> loadImage(String imagePath) async {
    state = state.copyWith(
      imagePath: imagePath,
      isProcessing: true,
      error: null,
    );

    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        state = state.copyWith(
          isProcessing: false,
          error: 'Image file not found',
        );
        return;
      }

      final bytes = await file.readAsBytes();
      state = state.copyWith(
        originalBytes: bytes,
        previewBytes: bytes,
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Failed to load image: $e',
      );
    }
  }

  /// Loads an image from raw bytes.
  void loadImageBytes(Uint8List bytes) {
    state = state.copyWith(
      originalBytes: bytes,
      previewBytes: bytes,
    );
  }

  /// Sets brightness and schedules preview update.
  void setBrightness(int value) {
    state = state.copyWith(
      brightness: value.clamp(-100, 100),
      selectedPreset: null,
    );
    _schedulePreviewUpdate();
  }

  /// Sets contrast and schedules preview update.
  void setContrast(int value) {
    state = state.copyWith(
      contrast: value.clamp(-100, 100),
      selectedPreset: null,
    );
    _schedulePreviewUpdate();
  }

  /// Sets sharpness and schedules preview update.
  void setSharpness(int value) {
    state = state.copyWith(
      sharpness: value.clamp(0, 100),
      selectedPreset: null,
    );
    _schedulePreviewUpdate();
  }

  /// Sets saturation and schedules preview update.
  void setSaturation(int value) {
    state = state.copyWith(
      saturation: value.clamp(-100, 100),
      selectedPreset: null,
    );
    _schedulePreviewUpdate();
  }

  /// Toggles grayscale mode.
  void setGrayscale(bool enabled) {
    state = state.copyWith(
      grayscale: enabled,
      selectedPreset: null,
    );
    _schedulePreviewUpdate();
  }

  /// Toggles auto-enhancement.
  void setAutoEnhance(bool enabled) {
    state = state.copyWith(
      autoEnhance: enabled,
      selectedPreset: null,
    );
    _schedulePreviewUpdate();
  }

  /// Toggles noise reduction.
  void setDenoise(bool enabled) {
    state = state.copyWith(
      denoise: enabled,
      selectedPreset: null,
    );
    _schedulePreviewUpdate();
  }

  /// Applies a preset configuration.
  void applyPreset(EnhancementPreset preset) {
    final options = EnhancementOptions.fromPreset(preset);
    state = state.copyWith(
      brightness: options.brightness,
      contrast: options.contrast,
      sharpness: options.sharpness,
      saturation: options.saturation,
      grayscale: options.grayscale,
      autoEnhance: options.autoEnhance,
      denoise: options.denoise,
      selectedPreset: preset,
    );
    _schedulePreviewUpdate();
  }

  /// Resets all enhancements to default values.
  void resetEnhancements() {
    state = state.copyWith(
      brightness: 0,
      contrast: 0,
      sharpness: 0,
      saturation: 0,
      grayscale: false,
      autoEnhance: false,
      denoise: false,
      selectedPreset: null,
    );

    // Show original image immediately
    if (state.originalBytes != null) {
      state = state.copyWith(previewBytes: state.originalBytes);
    }
  }

  /// Schedules a debounced preview update.
  void _schedulePreviewUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, _updatePreview);
  }

  /// Updates the preview with current enhancement settings.
  Future<void> _updatePreview() async {
    if (state.originalBytes == null) return;
    if (!state.hasEnhancements) {
      // No enhancements, show original
      state = state.copyWith(previewBytes: state.originalBytes);
      return;
    }

    state = state.copyWith(
      isProcessing: true,
      error: null,
    );

    try {
      final result = await _imageProcessor.enhanceFromBytes(
        state.originalBytes!,
        options: state.toEnhancementOptions(),
        // ignore: avoid_redundant_argument_values
        outputFormat: ImageOutputFormat.jpeg,
        quality: 85, // Lower quality for preview
      );

      // Only update if still mounted and state hasn't changed
      if (mounted) {
        state = state.copyWith(
          previewBytes: result.bytes,
          isProcessing: false,
        );
      }
    } on ImageProcessorException catch (e) {
      if (mounted) {
        state = state.copyWith(
          isProcessing: false,
          error: e.message,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isProcessing: false,
          error: 'Failed to process image',
        );
      }
    }
  }

  /// Forces an immediate preview update.
  Future<void> forcePreviewUpdate() async {
    _debounceTimer?.cancel();
    await _updatePreview();
  }

  /// Gets the enhanced image bytes with full quality.
  ///
  /// Returns null if no original image is loaded.
  Future<Uint8List?> getEnhancedBytes({
    ImageOutputFormat format = ImageOutputFormat.jpeg,
    int quality = 90,
  }) async {
    if (state.originalBytes == null) return null;

    if (!state.hasEnhancements) {
      return state.originalBytes;
    }

    state = state.copyWith(
      isSaving: true,
      error: null,
    );

    try {
      final result = await _imageProcessor.enhanceFromBytes(
        state.originalBytes!,
        options: state.toEnhancementOptions(),
        outputFormat: format,
        quality: quality,
      );

      state = state.copyWith(isSaving: false);
      return result.bytes;
    } on ImageProcessorException catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: e.message,
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to save enhanced image',
      );
      return null;
    }
  }

  /// Saves the enhanced image to a file.
  ///
  /// Returns the path to the saved file, or null on failure.
  Future<String?> saveEnhancedImage(
    String outputPath, {
    ImageOutputFormat format = ImageOutputFormat.jpeg,
    int quality = 90,
  }) async {
    final bytes = await getEnhancedBytes(format: format, quality: quality);
    if (bytes == null) return null;

    try {
      final file = File(outputPath);
      await file.writeAsBytes(bytes);
      return outputPath;
    } catch (e) {
      state = state.copyWith(error: 'Failed to save file: $e');
      return null;
    }
  }

  /// Clears the current error.
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Riverpod provider for the enhancement screen state.
final enhancementScreenProvider = StateNotifierProvider.autoDispose<
    EnhancementScreenNotifier, EnhancementScreenState>(
  (ref) {
    final imageProcessor = ref.watch(imageProcessorProvider);
    return EnhancementScreenNotifier(imageProcessor);
  },
);

/// Enhancement preview screen with adjustment controls.
///
/// Provides a comprehensive UI for adjusting document images with:
/// - Live preview of enhancements
/// - Sliders for brightness, contrast, sharpness, and saturation
/// - Toggle switches for grayscale, auto-enhance, and denoise
/// - Quick-apply preset buttons
/// - Reset and save actions
///
/// ## Usage
/// ```dart
/// // From a file path
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => EnhancementScreen(imagePath: '/path/to/image.jpg'),
///   ),
/// );
///
/// // From raw bytes
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => EnhancementScreen(imageBytes: bytes),
///   ),
/// );
///
/// // With callback
/// EnhancementScreen(
///   imagePath: path,
///   onSave: (enhancedBytes) {
///     // Handle the enhanced image
///   },
/// )
/// ```
///
/// ## Return Value
/// When saved, pops with a [ProcessedImage] result containing the
/// enhanced image data and applied operations.
class EnhancementScreen extends ConsumerStatefulWidget {
  /// Creates an [EnhancementScreen].
  ///
  /// Either [imagePath] or [imageBytes] must be provided.
  const EnhancementScreen({
    super.key,
    this.imagePath,
    this.imageBytes,
    this.onSave,
    this.title,
  }) : assert(
          imagePath != null || imageBytes != null,
          'Either imagePath or imageBytes must be provided',
        );

  /// Path to the image file to enhance.
  final String? imagePath;

  /// Raw bytes of the image to enhance.
  final Uint8List? imageBytes;

  /// Callback invoked when the enhanced image is saved.
  ///
  /// Receives the enhanced image bytes.
  final void Function(Uint8List enhancedBytes)? onSave;

  /// Optional title for the app bar.
  final String? title;

  @override
  ConsumerState<EnhancementScreen> createState() => _EnhancementScreenWidgetState();
}

class _EnhancementScreenWidgetState extends ConsumerState<EnhancementScreen> {
  @override
  void initState() {
    super.initState();

    // Load the image after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(enhancementScreenProvider.notifier);
      if (widget.imagePath != null) {
        notifier.loadImage(widget.imagePath!);
      } else if (widget.imageBytes != null) {
        notifier.loadImageBytes(widget.imageBytes!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(enhancementScreenProvider);
    final notifier = ref.read(enhancementScreenProvider.notifier);
    final theme = Theme.of(context);

    // Listen for errors and show snackbar
    ref.listen<EnhancementScreenState>(enhancementScreenProvider,
        (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: notifier.clearError,
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Enhance'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _handleClose(context, state),
        ),
        actions: [
          if (state.hasEnhancements)
            TextButton(
              onPressed: notifier.resetEnhancements,
              child: const Text('Reset'),
            ),
        ],
      ),
      body: Stack(
        children: [
          BentoBackground(),
          Column(
            children: [
              // Preview area
              Expanded(
                child: _PreviewArea(
                  state: state,
                ),
              ),

              // Controls panel
              _ControlsPanel(
                state: state,
                notifier: notifier,
                theme: theme,
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        state: state,
        onCancel: () => _handleClose(context, state),
        onSave: () => _handleSave(context, state, notifier),
      ),
    );
  }

  Future<void> _handleClose(
      BuildContext context, EnhancementScreenState state) async {
    if (state.hasEnhancements) {
      final shouldDiscard = await showBentoConfirmationDialog(
        context,
        title: 'Discard changes?',
        message:
            'You have unsaved enhancements. Are you sure you want to discard them?',
        confirmButtonText: 'Discard',
        isDestructive: true,
      );

      if (shouldDiscard == true && mounted) {
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSave(
    BuildContext context,
    EnhancementScreenState state,
    EnhancementScreenNotifier notifier,
  ) async {
    final bytes = await notifier.getEnhancedBytes();
    if (bytes != null) {
      widget.onSave?.call(bytes);

      if (mounted) {
        // Return the enhanced bytes
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop(bytes);
      }
    }
  }
}

/// Preview area showing the enhanced image.
class _PreviewArea extends StatelessWidget {
  const _PreviewArea({
    required this.state,
  });

  final EnhancementScreenState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Image preview
          Positioned.fill(
            child: state.hasPreview
                ? InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.memory(
                      state.previewBytes!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true, // Prevents flicker during updates
                      errorBuilder: (context, error, stackTrace) {
                        return _buildErrorPlaceholder(context);
                      },
                    ),
                  )
                : _buildLoadingPlaceholder(context),
          ),

          // Processing indicator overlay
          if (state.isProcessing)
            Positioned.fill(
              child: Container(
                color: theme.brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.5)
                    : theme.colorScheme.surface.withValues(alpha: 0.5),
                child: Center(
                  child: ScanaiLoader(size: 60),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingPlaceholder(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.2)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScanaiLoader(size: 50),
            const SizedBox(height: 24),
            Text(
              'Préparation de l\'image...',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.errorContainer,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 64,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load preview',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Controls panel with sliders and toggles.
class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel({
    required this.state,
    required this.notifier,
    required this.theme,
  });

  final EnhancementScreenState state;
  final EnhancementScreenNotifier notifier;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0F172A).withValues(alpha: 0.95)
            : theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle indicator
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Presets
            _PresetChips(
              selectedPreset: state.selectedPreset,
              onPresetSelected: notifier.applyPreset,
              theme: theme,
            ),
            const SizedBox(height: 16),

            // Adjustment sliders
            _EnhancementSlider(
              label: 'Brightness',
              icon: Icons.brightness_6_outlined,
              value: state.brightness.toDouble(),
              min: -100,
              max: 100,
              onChanged: (value) => notifier.setBrightness(value.round()),
              theme: theme,
            ),

            _EnhancementSlider(
              label: 'Contrast',
              icon: Icons.contrast_outlined,
              value: state.contrast.toDouble(),
              min: -100,
              max: 100,
              onChanged: (value) => notifier.setContrast(value.round()),
              theme: theme,
            ),

            _EnhancementSlider(
              label: 'Sharpness',
              icon: Icons.details_outlined,
              value: state.sharpness.toDouble(),
              min: 0,
              max: 100,
              onChanged: (value) => notifier.setSharpness(value.round()),
              theme: theme,
            ),

            _EnhancementSlider(
              label: 'Saturation',
              icon: Icons.palette_outlined,
              value: state.saturation.toDouble(),
              min: -100,
              max: 100,
              enabled: !state.grayscale,
              onChanged: (value) => notifier.setSaturation(value.round()),
              theme: theme,
            ),

            const SizedBox(height: 8),

            // Toggle switches
            _ToggleRow(
              state: state,
              notifier: notifier,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

/// Preset selection chips.
class _PresetChips extends StatelessWidget {
  const _PresetChips({
    required this.selectedPreset,
    required this.onPresetSelected,
    required this.theme,
  });

  final EnhancementPreset? selectedPreset;
  final ValueChanged<EnhancementPreset> onPresetSelected;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Presets',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: EnhancementPreset.values.map((preset) {
              final isSelected = selectedPreset == preset;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(_getPresetLabel(preset)),
                  selected: isSelected,
                  onSelected: (_) => onPresetSelected(preset),
                  avatar: Icon(
                    _getPresetIcon(preset),
                    size: 18,
                  ),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _getPresetLabel(EnhancementPreset preset) {
    switch (preset) {
      case EnhancementPreset.document:
        return 'Document';
      case EnhancementPreset.highContrast:
        return 'High Contrast';
      case EnhancementPreset.blackAndWhite:
        return 'B&W';
      case EnhancementPreset.photo:
        return 'Photo';
      case EnhancementPreset.none:
        return 'Original';
    }
  }

  IconData _getPresetIcon(EnhancementPreset preset) {
    switch (preset) {
      case EnhancementPreset.document:
        return Icons.description_outlined;
      case EnhancementPreset.highContrast:
        return Icons.contrast;
      case EnhancementPreset.blackAndWhite:
        return Icons.monochrome_photos_outlined;
      case EnhancementPreset.photo:
        return Icons.photo_outlined;
      case EnhancementPreset.none:
        return Icons.image_outlined;
    }
  }
}

/// A single enhancement slider with label and icon.
class _EnhancementSlider extends StatelessWidget {
  const _EnhancementSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.theme,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ThemeData theme;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: enabled
                ? colorScheme.onSurfaceVariant
                // ignore: deprecated_member_use
                : colorScheme.onSurface.withOpacity(0.38),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: enabled
                    ? colorScheme.onSurface
                    // ignore: deprecated_member_use
                    : colorScheme.onSurface.withOpacity(0.38),
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF6366F1),
                inactiveTrackColor:
                    const Color(0xFF6366F1).withValues(alpha: 0.2),
                thumbColor: const Color(0xFF6366F1),
                overlayColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                trackHeight: 4,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: (max - min).round(),
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value.round().toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: enabled
                    ? colorScheme.onSurfaceVariant
                    // ignore: deprecated_member_use
                    : colorScheme.onSurface.withOpacity(0.38),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggle switches row for boolean options.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.state,
    required this.notifier,
    required this.theme,
  });

  final EnhancementScreenState state;
  final EnhancementScreenNotifier notifier;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ToggleChip(
          label: 'B&W',
          icon: Icons.monochrome_photos_outlined,
          isSelected: state.grayscale,
          onSelected: notifier.setGrayscale,
          theme: theme,
        ),
        _ToggleChip(
          label: 'Auto',
          icon: Icons.auto_fix_high_outlined,
          isSelected: state.autoEnhance,
          onSelected: notifier.setAutoEnhance,
          theme: theme,
        ),
        _ToggleChip(
          label: 'Denoise',
          icon: Icons.blur_on_outlined,
          isSelected: state.denoise,
          onSelected: notifier.setDenoise,
          theme: theme,
        ),
      ],
    );
  }
}

/// A single toggle chip button.
class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onSelected,
    required this.theme,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final ValueChanged<bool> onSelected;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      avatar: Icon(icon, size: 18),
      selected: isSelected,
      onSelected: onSelected,
      showCheckmark: true,
    );
  }
}

/// Bottom action bar with cancel and save buttons.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.state,
    required this.onCancel,
    required this.onSave,
  });

  final EnhancementScreenState state;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0F172A)
            : theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _BentoSecondaryButton(
              onPressed: state.isLoading ? null : onCancel,
              label: 'Annuler',
              theme: theme,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _BentoPrimaryButton(
              onPressed: state.isLoading || !state.hasOriginal ? null : onSave,
              label: state.isSaving ? 'Enregistrement...' : 'Appliquer',
              icon: state.isSaving ? null : Icons.check_circle_rounded,
              theme: theme,
              isLoading: state.isSaving,
            ),
          ),
        ],
      ),
    );
  }
}

class _BentoPrimaryButton extends StatelessWidget {
  const _BentoPrimaryButton({
    required this.onPressed,
    required this.label,
    this.icon,
    required this.theme,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final ThemeData theme;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: onPressed != null
            ? LinearGradient(
                colors: isDark
                    ? [const Color(0xFF312E81), const Color(0xFF1E1B4B)]
                    : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: onPressed == null
            ? theme.disabledColor.withValues(alpha: 0.2)
            : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else if (icon != null)
                  Icon(icon, color: Colors.white, size: 20),
                if (isLoading || icon != null) const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 16,
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

class _BentoSecondaryButton extends StatelessWidget {
  const _BentoSecondaryButton({
    required this.onPressed,
    required this.label,
    required this.theme,
  });

  final VoidCallback? onPressed;
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.1)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w700,
                color: theme.brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.7)
                    : const Color(0xFF475569),
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
