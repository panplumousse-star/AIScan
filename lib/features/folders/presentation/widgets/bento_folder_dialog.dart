import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/widgets/bento_card.dart';
import '../../../../core/widgets/bento_mascot.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/folder_model.dart';

/// Result from folder creation/edition dialog.
class BentoFolderDialogResult {
  const BentoFolderDialogResult({
    required this.name,
    this.color,
    this.icon,
    this.clearColor = false,
    this.clearIcon = false,
  });

  final String name;
  final String? color;
  final String? icon;
  final bool clearColor;
  final bool clearIcon;
}

/// Shows a dialog for creating or editing a folder.
///
/// Returns [BentoFolderDialogResult] if the user confirms, or null if cancelled.
///
/// Usage:
/// ```dart
/// // Create new folder
/// final result = await showBentoFolderDialog(context);
///
/// // Edit existing folder
/// final result = await showBentoFolderDialog(context, folder: existingFolder);
/// ```
Future<BentoFolderDialogResult?> showBentoFolderDialog(
  BuildContext context, {
  Folder? folder,
}) {
  return showDialog<BentoFolderDialogResult>(
    context: context,
    builder: (context) => BentoFolderDialog(
      folder: folder,
      isEditing: folder != null,
    ),
  );
}

class BentoFolderDialog extends StatefulWidget {
  const BentoFolderDialog({
    super.key,
    this.folder,
    this.isEditing = false,
  });

  final Folder? folder;
  final bool isEditing;

  @override
  State<BentoFolderDialog> createState() => _BentoFolderDialogState();
}

class _BentoFolderDialogState extends State<BentoFolderDialog> {
  late final TextEditingController _nameController;
  String? _selectedColor;
  String? _error;

  static const List<String> _folderColors = [
    '#F44336', // Red
    '#E91E63', // Pink
    '#9C27B0', // Purple
    '#673AB7', // Deep Purple
    '#3F51B5', // Indigo
    '#2196F3', // Blue
    '#03A9F4', // Light Blue
    '#00BCD4', // Cyan
    '#009688', // Teal
    '#4CAF50', // Green
    '#8BC34A', // Light Green
    '#CDDC39', // Lime
    '#FFEB3B', // Yellow
    '#FFC107', // Amber
    '#FF9800', // Orange
    '#FF5722', // Deep Orange
    '#795548', // Brown
    '#607D8B', // Blue Grey
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.folder?.name ?? '');
    _selectedColor = widget.folder?.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final l10n = AppLocalizations.of(context);
    if (name.isEmpty) {
      setState(
          () => _error = l10n?.nameCannotBeEmpty ?? 'Name cannot be empty');
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(BentoFolderDialogResult(
      name: name,
      color: _selectedColor,
      clearColor: _selectedColor == null && widget.folder?.color != null,
    ));
  }

  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } on Object catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Material(
              color: Colors.transparent,
              child: BentoCard(
                elevation: 6,
                padding: const EdgeInsets.all(24),
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: 32, // Added missing borderRadius
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with title and mascot
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.isEditing
                                ? (l10n?.editFolder ?? 'Edit folder')
                                : (l10n?.createFolder ?? 'Create folder'),
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        BentoLevitationWidget(
                          child: BentoMascot(
                            height: 80,
                            variant: BentoMascotVariant.folderEdit,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Name input field
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: TextField(
                        controller: _nameController,
                        autofocus: true,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n?.folderName ?? 'Folder name...',
                          hintStyle: TextStyle(
                            fontFamily: 'Outfit',
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                          errorText: _error,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Color picker label
                    Text(
                      'Couleur',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Color picker
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        // No color / Default option
                        _ColorChip(
                          isSelected: _selectedColor == null,
                          color: colorScheme.secondary.withValues(alpha: 0.5),
                          onTap: () => setState(() => _selectedColor = null),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                        ..._folderColors.map((hex) => _ColorChip(
                              isSelected: _selectedColor == hex,
                              color: _parseColor(hex),
                              onTap: () => setState(() => _selectedColor = hex),
                            )),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              l10n?.cancel ?? 'Cancel',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [
                                        const Color(0xFF312E81),
                                        const Color(0xFF1E1B4B)
                                      ]
                                    : [
                                        const Color(0xFF6366F1),
                                        const Color(0xFF4F46E5)
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _submit,
                                borderRadius: BorderRadius.circular(20),
                                child: Center(
                                  child: Text(
                                    widget.isEditing
                                        ? (l10n?.save ?? 'Save')
                                        : (l10n?.create ?? 'Create'),
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.isSelected,
    required this.color,
    required this.onTap,
    this.child,
  });

  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: child ??
            (isSelected
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : null),
      ),
    );
  }
}
