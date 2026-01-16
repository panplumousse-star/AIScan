import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hand_signature/signature.dart';

import '../../domain/signature_service.dart';

/// State for the signature overlay screen.
///
/// Contains position, size, and signature data.
@immutable
class SignatureOverlayState {
  /// Creates a [SignatureOverlayState] with default values.
  const SignatureOverlayState({
    this.signatureBytes,
    this.signatureId,
    this.position = Offset.zero,
    this.signatureWidth = 200.0,
    this.opacity = 1.0,
    this.documentWidth = 0,
    this.documentHeight = 0,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  /// The signature image bytes.
  final Uint8List? signatureBytes;

  /// ID of saved signature (if using saved signature).
  final String? signatureId;

  /// Current position of the signature on the document.
  final Offset position;

  /// Current width of the signature (height maintains aspect ratio).
  final double signatureWidth;

  /// Opacity of the signature (0.0 - 1.0).
  final double opacity;

  /// Width of the document image.
  final int documentWidth;

  /// Height of the document image.
  final int documentHeight;

  /// Whether a signature is being loaded.
  final bool isLoading;

  /// Whether the signed document is being saved.
  final bool isSaving;

  /// Error message, if any.
  final String? error;

  /// Whether we have a signature ready.
  bool get hasSignature => signatureBytes != null && signatureBytes!.isNotEmpty;

  /// Whether any operation is in progress.
  bool get isBusy => isLoading || isSaving;

  /// Creates a copy with updated values.
  SignatureOverlayState copyWith({
    Uint8List? signatureBytes,
    String? signatureId,
    Offset? position,
    double? signatureWidth,
    double? opacity,
    int? documentWidth,
    int? documentHeight,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
    bool clearSignature = false,
    bool clearSignatureId = false,
  }) {
    return SignatureOverlayState(
      signatureBytes: clearSignature
          ? null
          : (signatureBytes ?? this.signatureBytes),
      signatureId: clearSignatureId ? null : (signatureId ?? this.signatureId),
      position: position ?? this.position,
      signatureWidth: signatureWidth ?? this.signatureWidth,
      opacity: opacity ?? this.opacity,
      documentWidth: documentWidth ?? this.documentWidth,
      documentHeight: documentHeight ?? this.documentHeight,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SignatureOverlayState &&
        other.signatureId == signatureId &&
        other.position == position &&
        other.signatureWidth == signatureWidth &&
        other.opacity == opacity &&
        other.documentWidth == documentWidth &&
        other.documentHeight == documentHeight &&
        other.isLoading == isLoading &&
        other.isSaving == isSaving &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(
    signatureId,
    position,
    signatureWidth,
    opacity,
    documentWidth,
    documentHeight,
    isLoading,
    isSaving,
    error,
  );
}

/// State notifier for the signature overlay.
class SignatureOverlayNotifier extends StateNotifier<SignatureOverlayState> {
  /// Creates a [SignatureOverlayNotifier] with the given service.
  SignatureOverlayNotifier(this._signatureService)
    : super(const SignatureOverlayState());

  final SignatureService _signatureService;

  /// Sets the document dimensions.
  void setDocumentDimensions(int width, int height) {
    state = state.copyWith(documentWidth: width, documentHeight: height);

    // Set initial position to bottom-center area (common signature location)
    if (state.position == Offset.zero) {
      final initialX = (width - state.signatureWidth) / 2;
      final initialY = height * 0.75 - 50; // 75% down the page
      state = state.copyWith(
        position: Offset(
          initialX.clamp(0, width - state.signatureWidth),
          initialY.clamp(0, height.toDouble() - 100),
        ),
      );
    }
  }

  /// Sets signature bytes directly (from signature screen).
  void setSignatureBytes(Uint8List bytes) {
    state = state.copyWith(signatureBytes: bytes, clearError: true);
  }

  /// Loads a saved signature by ID.
  Future<void> loadSignature(String signatureId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _signatureService.initialize();

      final signature = await _signatureService.getSignature(signatureId);
      if (signature == null) {
        state = state.copyWith(isLoading: false, error: 'Signature not found');
        return;
      }

      final bytes = await _signatureService.loadSignatureImage(signature);

      state = state.copyWith(
        signatureBytes: bytes,
        signatureId: signatureId,
        isLoading: false,
      );
    } on SignatureException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load signature: $e',
      );
    }
  }

  /// Loads the default signature.
  Future<void> loadDefaultSignature() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _signatureService.initialize();

      final signature = await _signatureService.getDefaultSignature();
      if (signature == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'No default signature found',
        );
        return;
      }

      final bytes = await _signatureService.loadSignatureImage(signature);

      state = state.copyWith(
        signatureBytes: bytes,
        signatureId: signature.id,
        isLoading: false,
      );
    } on SignatureException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load default signature: $e',
      );
    }
  }

  /// Updates the signature position.
  void updatePosition(Offset delta) {
    final newPosition = state.position + delta;

    // Clamp to document bounds
    final maxX = state.documentWidth - state.signatureWidth;
    final maxY =
        state.documentHeight.toDouble() - 100; // Approximate signature height

    state = state.copyWith(
      position: Offset(
        newPosition.dx.clamp(0, maxX.toDouble()),
        newPosition.dy.clamp(0, maxY),
      ),
    );
  }

  /// Sets the signature position directly.
  void setPosition(Offset position) {
    // Clamp to document bounds
    final maxX = state.documentWidth - state.signatureWidth;
    final maxY = state.documentHeight.toDouble() - 100;

    state = state.copyWith(
      position: Offset(
        position.dx.clamp(0, maxX.toDouble()),
        position.dy.clamp(0, maxY),
      ),
    );
  }

  /// Updates the signature width.
  void setSignatureWidth(double width) {
    final clampedWidth = width.clamp(
      50.0,
      state.documentWidth.toDouble() * 0.8,
    );

    // Adjust position if signature now extends beyond document
    var newPosition = state.position;
    final maxX = state.documentWidth - clampedWidth;
    if (state.position.dx > maxX) {
      newPosition = Offset(maxX.toDouble(), state.position.dy);
    }

    state = state.copyWith(signatureWidth: clampedWidth, position: newPosition);
  }

  /// Updates the opacity.
  void setOpacity(double opacity) {
    state = state.copyWith(opacity: opacity.clamp(0.1, 1.0));
  }

  /// Applies the signature to the document.
  Future<SignedDocument?> applySignature(Uint8List documentBytes) async {
    if (!state.hasSignature) {
      state = state.copyWith(error: 'No signature to apply');
      return null;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final result = await _signatureService.overlaySignatureOnDocument(
        documentBytes: documentBytes,
        signatureBytes: state.signatureBytes!,
        position: state.position,
        signatureWidth: state.signatureWidth,
        opacity: state.opacity,
      );

      state = state.copyWith(isSaving: false);
      return result;
    } on SignatureException catch (e) {
      state = state.copyWith(isSaving: false, error: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to apply signature: $e',
      );
      return null;
    }
  }

  /// Clears the current signature.
  void clearSignature() {
    state = state.copyWith(clearSignature: true, clearSignatureId: true);
  }

  /// Clears the current error.
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Riverpod provider for signature overlay state.
final signatureOverlayProvider =
    StateNotifierProvider.autoDispose<
      SignatureOverlayNotifier,
      SignatureOverlayState
    >((ref) {
      final signatureService = ref.watch(signatureServiceProvider);
      return SignatureOverlayNotifier(signatureService);
    });

/// Widget for overlaying a signature on a document image.
///
/// Provides an interactive interface for:
/// - Positioning the signature via drag gestures
/// - Resizing the signature via slider
/// - Adjusting opacity
/// - Previewing the result before saving
///
/// ## Usage
/// ```dart
/// SignatureOverlayScreen(
///   documentBytes: documentImageBytes,
///   signatureBytes: capturedSignatureBytes,
///   onSave: (signedDocumentBytes) {
///     // Handle the signed document
///   },
/// )
/// ```
class SignatureOverlayScreen extends ConsumerStatefulWidget {
  /// Creates a [SignatureOverlayScreen].
  const SignatureOverlayScreen({
    super.key,
    required this.documentBytes,
    this.signatureBytes,
    this.signatureId,
    this.onSave,
    this.onCancel,
  });

  /// The document image bytes to sign.
  final Uint8List documentBytes;

  /// Optional pre-captured signature bytes.
  final Uint8List? signatureBytes;

  /// Optional saved signature ID to load.
  final String? signatureId;

  /// Callback when signature is applied and saved.
  final void Function(Uint8List signedDocumentBytes)? onSave;

  /// Callback when operation is cancelled.
  final VoidCallback? onCancel;

  @override
  ConsumerState<SignatureOverlayScreen> createState() =>
      _SignatureOverlayScreenState();
}

class _SignatureOverlayScreenState
    extends ConsumerState<SignatureOverlayScreen> {
  final GlobalKey _documentKey = GlobalKey();
  Size _displaySize = Size.zero;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSignature();
    });
  }

  Future<void> _initializeSignature() async {
    final notifier = ref.read(signatureOverlayProvider.notifier);

    // Set signature if provided
    if (widget.signatureBytes != null) {
      notifier.setSignatureBytes(widget.signatureBytes!);
    } else if (widget.signatureId != null) {
      await notifier.loadSignature(widget.signatureId!);
    } else {
      // Try to load default signature
      await notifier.loadDefaultSignature();
    }
  }

  void _onImageLayout(int imageWidth, int imageHeight) {
    final notifier = ref.read(signatureOverlayProvider.notifier);
    notifier.setDocumentDimensions(imageWidth, imageHeight);

    // Calculate display scale for gesture handling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_documentKey.currentContext != null) {
        final box =
            _documentKey.currentContext!.findRenderObject() as RenderBox;
        _displaySize = box.size;
        _scale = imageWidth / _displaySize.width;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signatureOverlayProvider);
    final notifier = ref.read(signatureOverlayProvider.notifier);
    final theme = Theme.of(context);

    // Listen for errors
    ref.listen<SignatureOverlayState>(signatureOverlayProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
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
        title: const Text('Add Signature'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            widget.onCancel?.call();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          if (state.hasSignature)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Change signature',
              onPressed: () => _showSignatureOptions(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Document with signature overlay
          Expanded(
            child: _DocumentWithOverlay(
              documentKey: _documentKey,
              documentBytes: widget.documentBytes,
              state: state,
              onImageLayout: _onImageLayout,
              onSignatureMove: (delta) {
                // Convert screen delta to image coordinates
                notifier.updatePosition(
                  Offset(delta.dx * _scale, delta.dy * _scale),
                );
              },
              theme: theme,
            ),
          ),

          // Controls panel
          if (state.hasSignature)
            _ControlsPanel(
              state: state,
              onWidthChanged: notifier.setSignatureWidth,
              onOpacityChanged: notifier.setOpacity,
              theme: theme,
            ),

          // Bottom action bar
          _BottomBar(
            state: state,
            onCancel: () {
              widget.onCancel?.call();
              Navigator.of(context).pop();
            },
            onApply: () => _applySignature(context, state, notifier),
            onSelectSignature: !state.hasSignature
                ? () => _showSignatureOptions(context)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _showSignatureOptions(BuildContext context) async {
    final result = await showModalBottomSheet<_SignatureOptionResult>(
      context: context,
      builder: (context) => const _SignatureOptionsSheet(),
    );

    if (result == null || !mounted) return;

    final notifier = ref.read(signatureOverlayProvider.notifier);

    switch (result.type) {
      case _SignatureOptionType.create:
        // Navigate to signature screen to create new signature
        if (mounted) {
          final signatureBytes = await Navigator.of(context).push<Uint8List>(
            MaterialPageRoute(
              builder: (context) => _CreateSignatureWrapper(
                onSignatureCreated: (bytes) {
                  Navigator.of(context).pop(bytes);
                },
              ),
            ),
          );
          if (signatureBytes != null && mounted) {
            notifier.setSignatureBytes(signatureBytes);
          }
        }
      case _SignatureOptionType.select:
        if (result.signatureId != null) {
          await notifier.loadSignature(result.signatureId!);
        }
      case _SignatureOptionType.useDefault:
        await notifier.loadDefaultSignature();
    }
  }

  Future<void> _applySignature(
    BuildContext context,
    SignatureOverlayState state,
    SignatureOverlayNotifier notifier,
  ) async {
    final result = await notifier.applySignature(widget.documentBytes);

    if (result != null && mounted) {
      widget.onSave?.call(result.imageBytes);
      Navigator.of(context).pop(result.imageBytes);
    }
  }
}

/// Document viewer with signature overlay.
class _DocumentWithOverlay extends StatelessWidget {
  const _DocumentWithOverlay({
    required this.documentKey,
    required this.documentBytes,
    required this.state,
    required this.onImageLayout,
    required this.onSignatureMove,
    required this.theme,
  });

  final GlobalKey documentKey;
  final Uint8List documentBytes;
  final SignatureOverlayState state;
  final void Function(int width, int height) onImageLayout;
  final void Function(Offset delta) onSignatureMove;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.colorScheme.surfaceContainerLowest,
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return FutureBuilder<ui.Image>(
                future: _decodeImage(documentBytes),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final image = snapshot.data!;

                  // Notify parent of image dimensions
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onImageLayout(image.width, image.height);
                  });

                  return Stack(
                    key: documentKey,
                    children: [
                      // Document image
                      Image.memory(
                        documentBytes,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),

                      // Signature overlay
                      if (state.hasSignature && state.documentWidth > 0)
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Calculate scale factor
                              final scale =
                                  constraints.maxWidth / state.documentWidth;

                              return Stack(
                                children: [
                                  Positioned(
                                    left: state.position.dx * scale,
                                    top: state.position.dy * scale,
                                    child: GestureDetector(
                                      onPanUpdate: (details) {
                                        onSignatureMove(details.delta);
                                      },
                                      child: _SignatureWidget(
                                        signatureBytes: state.signatureBytes!,
                                        width: state.signatureWidth * scale,
                                        opacity: state.opacity,
                                        theme: theme,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                      // Loading overlay
                      if (state.isBusy)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.3),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

/// The draggable signature widget.
class _SignatureWidget extends StatelessWidget {
  const _SignatureWidget({
    required this.signatureBytes,
    required this.width,
    required this.opacity,
    required this.theme,
  });

  final Uint8List signatureBytes;
  final double width;
  final double opacity;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.7),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Opacity(
          opacity: opacity,
          child: Image.memory(
            signatureBytes,
            width: width,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

/// Controls panel for adjusting signature.
class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel({
    required this.state,
    required this.onWidthChanged,
    required this.onOpacityChanged,
    required this.theme,
  });

  final SignatureOverlayState state;
  final ValueChanged<double> onWidthChanged;
  final ValueChanged<double> onOpacityChanged;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Size slider
          Row(
            children: [
              Icon(
                Icons.photo_size_select_small,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                'Size',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Expanded(
                child: Slider(
                  value: state.signatureWidth,
                  min: 50,
                  max: math.max(state.documentWidth.toDouble() * 0.8, 100),
                  onChanged: onWidthChanged,
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  '${state.signatureWidth.round()}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),

          // Opacity slider
          Row(
            children: [
              Icon(
                Icons.opacity,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                'Opacity',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Expanded(
                child: Slider(
                  value: state.opacity,
                  min: 0.1,
                  max: 1.0,
                  onChanged: onOpacityChanged,
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  '${(state.opacity * 100).round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),

          // Hint text
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  'Drag signature to reposition',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ],
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
    required this.onCancel,
    required this.onApply,
    this.onSelectSignature,
  });

  final SignatureOverlayState state;
  final VoidCallback onCancel;
  final VoidCallback onApply;
  final VoidCallback? onSelectSignature;

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
              onPressed: state.isBusy ? null : onCancel,
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),

          // Apply/Select button
          Expanded(
            flex: 2,
            child: state.hasSignature
                ? FilledButton.icon(
                    onPressed: state.isBusy ? null : onApply,
                    icon: state.isSaving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(
                      state.isSaving ? 'Applying...' : 'Apply Signature',
                    ),
                  )
                : FilledButton.icon(
                    onPressed: onSelectSignature,
                    icon: const Icon(Icons.draw, size: 18),
                    label: const Text('Select Signature'),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Signature options bottom sheet.
class _SignatureOptionsSheet extends ConsumerWidget {
  const _SignatureOptionsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final signatureService = ref.read(signatureServiceProvider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Choose Signature', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 16),

          // Create new signature option
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.add,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            title: const Text('Create New Signature'),
            subtitle: const Text('Draw a new signature'),
            onTap: () {
              Navigator.of(context).pop(
                const _SignatureOptionResult(type: _SignatureOptionType.create),
              );
            },
          ),

          // Use default signature option
          FutureBuilder<SavedSignature?>(
            future: _getDefaultSignature(signatureService),
            builder: (context, snapshot) {
              if (snapshot.data == null) return const SizedBox.shrink();

              return ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.star,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                title: Text(snapshot.data!.label),
                subtitle: const Text('Default signature'),
                onTap: () {
                  Navigator.of(context).pop(
                    const _SignatureOptionResult(
                      type: _SignatureOptionType.useDefault,
                    ),
                  );
                },
              );
            },
          ),

          // Saved signatures list
          FutureBuilder<List<SavedSignature>>(
            future: _getAllSignatures(signatureService),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }

              final signatures = snapshot.data!
                  .where((s) => !s.isDefault)
                  .toList();

              if (signatures.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      'Other Signatures',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  ...signatures
                      .take(5)
                      .map(
                        (sig) => ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.draw_outlined,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          title: Text(sig.label),
                          subtitle: Text(
                            'Created ${_formatDate(sig.createdAt)}',
                          ),
                          onTap: () {
                            Navigator.of(context).pop(
                              _SignatureOptionResult(
                                type: _SignatureOptionType.select,
                                signatureId: sig.id,
                              ),
                            );
                          },
                        ),
                      ),
                ],
              );
            },
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Future<SavedSignature?> _getDefaultSignature(SignatureService service) async {
    try {
      await service.initialize();
      return await service.getDefaultSignature();
    } catch (_) {
      return null;
    }
  }

  Future<List<SavedSignature>> _getAllSignatures(
    SignatureService service,
  ) async {
    try {
      await service.initialize();
      return await service.getAllSignatures();
    } catch (_) {
      return [];
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Result from signature options sheet.
class _SignatureOptionResult {
  const _SignatureOptionResult({required this.type, this.signatureId});

  final _SignatureOptionType type;
  final String? signatureId;
}

/// Types of signature selection options.
enum _SignatureOptionType { create, select, useDefault }

/// Wrapper for navigating to signature creation.
class _CreateSignatureWrapper extends ConsumerWidget {
  const _CreateSignatureWrapper({required this.onSignatureCreated});

  final void Function(Uint8List bytes) onSignatureCreated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Import the signature screen dynamically to avoid circular deps
    return _SimpleSignatureCapture(onCapture: onSignatureCreated);
  }
}

/// Simple signature capture widget for inline use.
class _SimpleSignatureCapture extends ConsumerStatefulWidget {
  const _SimpleSignatureCapture({required this.onCapture});

  final void Function(Uint8List bytes) onCapture;

  @override
  ConsumerState<_SimpleSignatureCapture> createState() =>
      _SimpleSignatureCaptureState();
}

class _SimpleSignatureCaptureState
    extends ConsumerState<_SimpleSignatureCapture> {
  late HandSignatureControl _control;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _control = HandSignatureControl(
      threshold: 0.01,
      smoothRatio: 0.65,
      velocityRange: 2.0,
    );
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Draw Signature'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Clear',
            onPressed: () => _control.clear(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Hint text
                  Center(
                    child: Text(
                      'Draw your signature here',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                    ),
                  ),

                  // Signature pad
                  Positioned.fill(
                    child: HandSignature(
                      control: _control,
                      color: Colors.black,
                      width: 2.0,
                      maxWidth: 6.0,
                      type: SignatureDrawType.shape,
                    ),
                  ),

                  // Processing indicator
                  if (_isCapturing)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white.withOpacity(0.8),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom bar
          Container(
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
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _isCapturing ? null : _captureSignature,
                    icon: _isCapturing
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(
                      _isCapturing ? 'Processing...' : 'Use Signature',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureSignature() async {
    if (_control.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw a signature first')),
      );
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final pngBytes = await _control.toImage(
        color: Colors.black,
        background: Colors.transparent,
        fit: true,
        maxStrokeWidth: 6.0,
        exportPenColor: true,
      );

      if (pngBytes == null || pngBytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to capture signature')),
          );
        }
        return;
      }

      widget.onCapture(pngBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }
}
