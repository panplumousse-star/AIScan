import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hand_signature/signature.dart';

import '../domain/signature_service.dart';

/// State for the signature capture screen.
///
/// Contains the signature control, options, and capture state.
@immutable
class SignatureScreenState {
  /// Creates a [SignatureScreenState] with default values.
  const SignatureScreenState({
    this.control,
    this.options = const SignatureOptions.document(),
    this.selectedStyleIndex = 0,
    this.isSaving = false,
    this.isCapturing = false,
    this.capturedSignature,
    this.savedSignature,
    this.error,
    this.showPreview = false,
    this.undoStack = const [],
  });

  /// The hand signature control for drawing.
  final HandSignatureControl? control;

  /// Current signature options (stroke color, width, etc).
  final SignatureOptions options;

  /// Selected style preset index.
  final int selectedStyleIndex;

  /// Whether the signature is being saved.
  final bool isSaving;

  /// Whether signature capture is in progress.
  final bool isCapturing;

  /// Captured signature data (preview before save).
  final CapturedSignature? capturedSignature;

  /// Saved signature after successful save.
  final SavedSignature? savedSignature;

  /// Error message, if any.
  final String? error;

  /// Whether to show the preview of captured signature.
  final bool showPreview;

  /// Stack of undo states (paths).
  final List<List<CubicPath>> undoStack;

  /// Whether we're in any loading state.
  bool get isLoading => isSaving || isCapturing;

  /// Whether the control has any signature data.
  bool get hasSignature => control != null && !control!.isEmpty;

  /// Whether we have a captured signature ready to save.
  bool get hasCaptured => capturedSignature != null;

  /// Whether undo is available.
  bool get canUndo => undoStack.isNotEmpty;

  /// Creates a copy with updated values.
  SignatureScreenState copyWith({
    HandSignatureControl? control,
    SignatureOptions? options,
    int? selectedStyleIndex,
    bool? isSaving,
    bool? isCapturing,
    CapturedSignature? capturedSignature,
    SavedSignature? savedSignature,
    String? error,
    bool? showPreview,
    List<List<CubicPath>>? undoStack,
    bool clearControl = false,
    bool clearError = false,
    bool clearCaptured = false,
    bool clearSaved = false,
    bool clearUndo = false,
  }) {
    return SignatureScreenState(
      control: clearControl ? null : (control ?? this.control),
      options: options ?? this.options,
      selectedStyleIndex: selectedStyleIndex ?? this.selectedStyleIndex,
      isSaving: isSaving ?? this.isSaving,
      isCapturing: isCapturing ?? this.isCapturing,
      capturedSignature: clearCaptured
          ? null
          : (capturedSignature ?? this.capturedSignature),
      savedSignature: clearSaved
          ? null
          : (savedSignature ?? this.savedSignature),
      error: clearError ? null : (error ?? this.error),
      showPreview: showPreview ?? this.showPreview,
      undoStack: clearUndo ? const [] : (undoStack ?? this.undoStack),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SignatureScreenState &&
        other.options == options &&
        other.selectedStyleIndex == selectedStyleIndex &&
        other.isSaving == isSaving &&
        other.isCapturing == isCapturing &&
        other.error == error &&
        other.showPreview == showPreview;
  }

  @override
  int get hashCode => Object.hash(
    options,
    selectedStyleIndex,
    isSaving,
    isCapturing,
    error,
    showPreview,
  );
}

/// Available signature style presets.
enum SignatureStyle {
  /// Standard document signing style - black, medium thickness.
  document,

  /// Bold style - thicker strokes for visibility.
  bold,

  /// Fine style - thin, precise strokes.
  fine,

  /// Blue ink style - traditional blue pen appearance.
  blueInk,
}

/// State notifier for the signature screen.
///
/// Manages signature capture, styling, and save workflow.
class SignatureScreenNotifier extends StateNotifier<SignatureScreenState> {
  /// Creates a [SignatureScreenNotifier] with the given signature service.
  SignatureScreenNotifier(this._signatureService)
    : super(const SignatureScreenState()) {
    _initializeControl();
  }

  final SignatureService _signatureService;

  /// Initialize the signature control.
  void _initializeControl() {
    final control = _signatureService.createControl(options: state.options);
    state = state.copyWith(control: control);
  }

  /// Changes the signature style preset.
  void setStyle(SignatureStyle style) {
    final SignatureOptions newOptions;
    final int styleIndex;

    switch (style) {
      case SignatureStyle.document:
        newOptions = const SignatureOptions.document();
        styleIndex = 0;
      case SignatureStyle.bold:
        newOptions = const SignatureOptions.bold();
        styleIndex = 1;
      case SignatureStyle.fine:
        newOptions = const SignatureOptions.fine();
        styleIndex = 2;
      case SignatureStyle.blueInk:
        newOptions = const SignatureOptions.blueInk();
        styleIndex = 3;
    }

    // Create new control with new options
    final control = _signatureService.createControl(options: newOptions);

    state = state.copyWith(
      options: newOptions,
      selectedStyleIndex: styleIndex,
      control: control,
      clearUndo: true,
      clearCaptured: true,
      showPreview: false,
    );
  }

  /// Sets custom stroke color.
  void setStrokeColor(Color color) {
    final newOptions = state.options.copyWith(strokeColor: color);
    final control = _signatureService.createControl(options: newOptions);

    state = state.copyWith(
      options: newOptions,
      control: control,
      selectedStyleIndex: -1, // Custom color deselects presets
      clearUndo: true,
      clearCaptured: true,
      showPreview: false,
    );
  }

  /// Sets custom stroke width.
  void setStrokeWidth(double width) {
    final newOptions = state.options.copyWith(strokeWidth: width);
    final control = _signatureService.createControl(options: newOptions);

    state = state.copyWith(
      options: newOptions,
      control: control,
      selectedStyleIndex: -1, // Custom width deselects presets
      clearUndo: true,
      clearCaptured: true,
      showPreview: false,
    );
  }

  /// Called when drawing starts.
  void onDrawStart() {
    // Save current state for undo before new strokes
    if (state.control != null) {
      final currentPaths = List<CubicPath>.from(state.control!.paths);
      if (currentPaths.isNotEmpty) {
        final newStack = List<List<CubicPath>>.from(state.undoStack);
        // Limit undo stack to 10 states
        if (newStack.length >= 10) {
          newStack.removeAt(0);
        }
        newStack.add(currentPaths);
        state = state.copyWith(undoStack: newStack);
      }
    }
  }

  /// Clears the current signature.
  void clearSignature() {
    state.control?.clear();
    state = state.copyWith(
      clearUndo: true,
      clearCaptured: true,
      showPreview: false,
    );
  }

  /// Undoes the last stroke.
  void undo() {
    if (!state.canUndo || state.control == null) return;

    final newStack = List<List<CubicPath>>.from(state.undoStack);
    final previousPaths = newStack.removeLast();

    state.control!.clear();
    for (final path in previousPaths) {
      state.control!.paths.add(path);
    }

    state = state.copyWith(
      undoStack: newStack,
      clearCaptured: true,
      showPreview: false,
    );
  }

  /// Captures the current signature for preview.
  Future<void> captureSignature() async {
    if (state.control == null || state.control!.isEmpty) {
      state = state.copyWith(error: 'Please draw a signature first');
      return;
    }

    state = state.copyWith(isCapturing: true, clearError: true);

    try {
      final captured = await _signatureService.captureSignature(
        state.control!,
        options: state.options,
      );

      state = state.copyWith(
        isCapturing: false,
        capturedSignature: captured,
        showPreview: true,
      );
    } on SignatureException catch (e) {
      state = state.copyWith(isCapturing: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        isCapturing: false,
        error: 'Failed to capture signature',
      );
    }
  }

  /// Exits preview mode to edit signature.
  void editSignature() {
    state = state.copyWith(showPreview: false, clearCaptured: true);
  }

  /// Saves the captured signature.
  Future<SavedSignature?> saveSignature({
    required String label,
    bool setAsDefault = false,
  }) async {
    if (state.capturedSignature == null) {
      // First capture if not already captured
      await captureSignature();
      if (state.capturedSignature == null) return null;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      // Ensure service is initialized
      await _signatureService.initialize();

      final saved = await _signatureService.saveSignature(
        state.capturedSignature!,
        label: label,
        setAsDefault: setAsDefault,
      );

      state = state.copyWith(isSaving: false, savedSignature: saved);

      return saved;
    } on SignatureException catch (e) {
      state = state.copyWith(isSaving: false, error: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to save signature',
      );
      return null;
    }
  }

  /// Clears the current error.
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Riverpod provider for the signature screen state.
final signatureScreenProvider =
    StateNotifierProvider.autoDispose<
      SignatureScreenNotifier,
      SignatureScreenState
    >((ref) {
      final signatureService = ref.watch(signatureServiceProvider);
      return SignatureScreenNotifier(signatureService);
    });

/// Signature capture screen with drawing canvas.
///
/// Provides a comprehensive UI for drawing electronic signatures with:
/// - Smooth velocity-based stroke thickness for natural signatures
/// - Multiple style presets (Document, Bold, Fine, Blue Ink)
/// - Undo functionality
/// - Preview before save
/// - Save with label option
///
/// ## Usage
/// ```dart
/// // Basic usage
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => const SignatureScreen(),
///   ),
/// );
///
/// // With callback
/// SignatureScreen(
///   onSave: (captured, saved) {
///     // Handle the captured/saved signature
///   },
/// )
///
/// // Selection mode (for picking existing or creating new)
/// SignatureScreen(
///   selectionMode: true,
///   onSignatureSelected: (signatureBytes) {
///     // Use the signature bytes for overlay
///   },
/// )
/// ```
///
/// ## Return Value
/// When saved, pops with a [SavedSignature] result containing the
/// saved signature data and metadata.
class SignatureScreen extends ConsumerStatefulWidget {
  /// Creates a [SignatureScreen].
  const SignatureScreen({
    super.key,
    this.onSave,
    this.onSignatureSelected,
    this.selectionMode = false,
    this.title,
    this.initialLabel,
  });

  /// Callback invoked when signature is saved.
  ///
  /// Receives both the captured signature data and saved record.
  final void Function(CapturedSignature captured, SavedSignature saved)? onSave;

  /// Callback for selection mode when signature is selected.
  ///
  /// Receives the PNG bytes of the signature.
  final void Function(Uint8List signatureBytes)? onSignatureSelected;

  /// Whether the screen is in selection mode (for overlay workflow).
  final bool selectionMode;

  /// Optional title for the app bar.
  final String? title;

  /// Initial label suggestion for save dialog.
  final String? initialLabel;

  @override
  ConsumerState<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends ConsumerState<SignatureScreen> {
  final TextEditingController _labelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _labelController.text = widget.initialLabel ?? '';
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signatureScreenProvider);
    final notifier = ref.read(signatureScreenProvider.notifier);
    final theme = Theme.of(context);

    // Listen for errors and show snackbar
    ref.listen<SignatureScreenState>(signatureScreenProvider, (previous, next) {
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
        title: Text(widget.title ?? 'Sign'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => _handleClose(context, state),
        ),
        actions: [
          // Undo button
          if (!state.showPreview)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Undo',
              onPressed: state.canUndo ? notifier.undo : null,
            ),
          // Clear button
          if (!state.showPreview)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear',
              onPressed: state.hasSignature ? notifier.clearSignature : null,
            ),
        ],
      ),
      body: Column(
        children: [
          // Style selector (when not in preview)
          if (!state.showPreview)
            _StyleSelector(
              selectedIndex: state.selectedStyleIndex,
              onStyleSelected: notifier.setStyle,
              theme: theme,
            ),

          // Signature canvas or preview
          Expanded(
            child: state.showPreview
                ? _SignaturePreview(
                    capturedSignature: state.capturedSignature!,
                    theme: theme,
                  )
                : _SignatureCanvas(
                    state: state,
                    notifier: notifier,
                    theme: theme,
                  ),
          ),

          // Bottom bar with actions
          _BottomBar(
            state: state,
            selectionMode: widget.selectionMode,
            onCancel: () => _handleClose(context, state),
            onContinue: () => _handleContinue(context, state, notifier),
            onEdit: state.showPreview ? notifier.editSignature : null,
          ),
        ],
      ),
    );
  }

  Future<void> _handleClose(
    BuildContext context,
    SignatureScreenState state,
  ) async {
    if (state.hasSignature || state.hasCaptured) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard signature?'),
          content: const Text(
            'You have an unsaved signature. Are you sure you want to discard it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Discard'),
            ),
          ],
        ),
      );

      if (shouldDiscard == true && mounted) {
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleContinue(
    BuildContext context,
    SignatureScreenState state,
    SignatureScreenNotifier notifier,
  ) async {
    if (state.showPreview) {
      // Show save dialog
      await _showSaveDialog(context, state, notifier);
    } else {
      // Capture signature for preview
      await notifier.captureSignature();
    }
  }

  Future<void> _showSaveDialog(
    BuildContext context,
    SignatureScreenState state,
    SignatureScreenNotifier notifier,
  ) async {
    // For selection mode, use signature directly without saving
    if (widget.selectionMode) {
      widget.onSignatureSelected?.call(state.capturedSignature!.pngBytes);
      if (mounted) {
        Navigator.of(context).pop(state.capturedSignature);
      }
      return;
    }

    // Show save dialog
    final result = await showDialog<_SaveDialogResult>(
      context: context,
      builder: (context) => _SaveDialog(
        controller: _labelController,
        initialLabel: widget.initialLabel,
      ),
    );

    if (result == null) return;

    final saved = await notifier.saveSignature(
      label: result.label,
      setAsDefault: result.setAsDefault,
    );

    if (saved != null) {
      widget.onSave?.call(state.capturedSignature!, saved);

      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    }
  }
}

/// Style preset selector row.
class _StyleSelector extends StatelessWidget {
  const _StyleSelector({
    required this.selectedIndex,
    required this.onStyleSelected,
    required this.theme,
  });

  final int selectedIndex;
  final ValueChanged<SignatureStyle> onStyleSelected;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Style',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StyleChip(
                  label: 'Document',
                  color: Colors.black,
                  isSelected: selectedIndex == 0,
                  onSelected: () => onStyleSelected(SignatureStyle.document),
                ),
                const SizedBox(width: 8),
                _StyleChip(
                  label: 'Bold',
                  color: Colors.black,
                  strokeWidth: 4.0,
                  isSelected: selectedIndex == 1,
                  onSelected: () => onStyleSelected(SignatureStyle.bold),
                ),
                const SizedBox(width: 8),
                _StyleChip(
                  label: 'Fine',
                  color: Colors.black,
                  strokeWidth: 1.0,
                  isSelected: selectedIndex == 2,
                  onSelected: () => onStyleSelected(SignatureStyle.fine),
                ),
                const SizedBox(width: 8),
                _StyleChip(
                  label: 'Blue Ink',
                  color: const Color(0xFF1A237E),
                  isSelected: selectedIndex == 3,
                  onSelected: () => onStyleSelected(SignatureStyle.blueInk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single style selector chip.
class _StyleChip extends StatelessWidget {
  const _StyleChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onSelected,
    this.strokeWidth = 2.0,
  });

  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onSelected;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: color == Colors.black
                    ? theme.colorScheme.outline
                    : color.withOpacity(0.5),
              ),
            ),
            child: Center(
              child: Container(
                width: strokeWidth * 2,
                height: strokeWidth * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
    );
  }
}

/// Signature drawing canvas.
class _SignatureCanvas extends StatelessWidget {
  const _SignatureCanvas({
    required this.state,
    required this.notifier,
    required this.theme,
  });

  final SignatureScreenState state;
  final SignatureScreenNotifier notifier;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Guide text
          if (!state.hasSignature)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.gesture,
                    size: 48,
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Draw your signature here',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Write naturally - speed affects stroke thickness',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),

          // Signature baseline guide
          Positioned(
            left: 20,
            right: 20,
            bottom: 60,
            child: Container(
              height: 1,
              color: theme.colorScheme.outline.withOpacity(0.15),
            ),
          ),

          // Signature pad
          if (state.control != null)
            Positioned.fill(
              child: HandSignature(
                control: state.control!,
                color: state.options.strokeColor,
                width: state.options.strokeWidth,
                maxWidth: state.options.maxStrokeWidth,
                type: SignatureDrawType.shape,
                onPointerDown: () => notifier.onDrawStart(),
              ),
            ),

          // Processing indicator
          if (state.isCapturing)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.8),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

/// Signature preview widget.
class _SignaturePreview extends StatelessWidget {
  const _SignaturePreview({
    required this.capturedSignature,
    required this.theme,
  });

  final CapturedSignature capturedSignature;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Preview header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Preview',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${capturedSignature.width} x ${capturedSignature.height}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  capturedSignature.pngSizeFormatted,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Signature image
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.memory(
                    capturedSignature.pngBytes,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom action bar.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.state,
    required this.selectionMode,
    required this.onCancel,
    required this.onContinue,
    this.onEdit,
  });

  final SignatureScreenState state;
  final bool selectionMode;
  final VoidCallback onCancel;
  final VoidCallback onContinue;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          // Cancel button
          Expanded(
            child: OutlinedButton(
              onPressed: state.isLoading ? null : onCancel,
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),

          // Edit button (when in preview)
          if (state.showPreview && onEdit != null) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: state.isLoading ? null : onEdit,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Continue/Save button
          Expanded(
            flex: state.showPreview ? 1 : 2,
            child: FilledButton.icon(
              onPressed:
                  state.isLoading || (!state.hasSignature && !state.showPreview)
                  ? null
                  : onContinue,
              icon: state.isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : Icon(
                      state.showPreview
                          ? (selectionMode ? Icons.check : Icons.save)
                          : Icons.arrow_forward,
                      size: 18,
                    ),
              label: Text(
                state.isLoading
                    ? (state.isSaving ? 'Saving...' : 'Processing...')
                    : (state.showPreview
                          ? (selectionMode ? 'Use Signature' : 'Save')
                          : 'Continue'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Result from save dialog.
class _SaveDialogResult {
  const _SaveDialogResult({required this.label, required this.setAsDefault});

  final String label;
  final bool setAsDefault;
}

/// Save dialog for entering signature label.
class _SaveDialog extends StatefulWidget {
  const _SaveDialog({required this.controller, this.initialLabel});

  final TextEditingController controller;
  final String? initialLabel;

  @override
  State<_SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<_SaveDialog> {
  bool _setAsDefault = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller.text.isEmpty && widget.initialLabel != null) {
      widget.controller.text = widget.initialLabel!;
    }
    if (widget.controller.text.isEmpty) {
      widget.controller.text = 'My Signature';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Save Signature'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Label',
              hintText: 'Enter a name for this signature',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _setAsDefault,
                onChanged: (value) =>
                    setState(() => _setAsDefault = value ?? false),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _setAsDefault = !_setAsDefault),
                  child: Text(
                    'Set as default signature',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final label = widget.controller.text.trim();
            if (label.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a label')),
              );
              return;
            }
            Navigator.of(
              context,
            ).pop(_SaveDialogResult(label: label, setAsDefault: _setAsDefault));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
