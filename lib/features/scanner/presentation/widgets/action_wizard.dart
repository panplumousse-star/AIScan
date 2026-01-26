/// Multi-step action wizard for document scanning workflow.
///
/// This widget provides a guided three-step interface for managing
/// scanned documents, from naming to folder organization to final actions.
///
/// Features:
/// - Three-step workflow (Rename, Folder selection, Final actions)
/// - Animated card flip transitions between steps
/// - Folder search and creation capabilities
/// - Color-coded folder UI
/// - Loading states with pulse animations
/// - Haptic feedback for tactile confirmation
/// - Auto-progression when document is saved
///
/// The wizard is designed to streamline the post-scan workflow and
/// ensure proper document organization.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../folders/domain/folder_model.dart';
import '../../../folders/domain/folder_service.dart';
import '../../../folders/presentation/widgets/bento_folder_dialog.dart';

/// Multi-step action wizard for document scanning workflow.
///
/// This widget guides users through a three-step process after scanning a document:
/// 1. **Rename Step**: Edit the document name
/// 2. **Folder Step**: Select a destination folder (or create new)
/// 3. **Final Actions**: Share, Export, or Finish
///
/// Features:
/// - Animated card flip transitions between steps
/// - Folder search and creation
/// - Folder color-coded UI
/// - Loading states with pulse animations
/// - Haptic feedback on interactions
///
/// The wizard automatically progresses through steps when the document is saved.
///
/// Usage:
/// ```dart
/// ActionWizard(
///   initialTitle: 'scanai_20240123_143052',
///   isSaved: false,
///   onSave: (title, folderId) async {
///     await saveScan(title, folderId);
///   },
///   onDelete: () => deleteScan(),
///   onShare: () => shareDocument(),
///   onExport: () => exportDocument(),
///   onDone: () => navigateToDocuments(),
/// )
/// ```
class ActionWizard extends StatefulWidget {
  const ActionWizard({
    super.key,
    required this.initialTitle,
    required this.isSaved,
    required this.onSave,
    required this.onDelete,
    required this.onShare,
    required this.onExport,
    required this.onDone,
  });

  /// Initial document title (typically a timestamp)
  final String initialTitle;

  /// Whether the document has been saved to storage
  final bool isSaved;

  /// Callback when saving the document with title and optional folder ID
  final Function(String title, String? folderId) onSave;

  /// Callback when deleting the scan
  final VoidCallback onDelete;

  /// Callback when sharing the document
  final VoidCallback onShare;

  /// Callback when exporting the document to external storage
  final VoidCallback onExport;

  /// Callback when finishing the workflow
  final VoidCallback onDone;

  @override
  State<ActionWizard> createState() => _ActionWizardState();
}

class _ActionWizardState extends State<ActionWizard>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _pulseController;
  late Animation<double> _flipAnimation;
  late Animation<double> _pulseAnimation;
  late TextEditingController _titleController;
  late TextEditingController _folderSearchController;

  int _step = 0; // 0: Rename, 1: Folder selection, 2: Final Actions
  String? _selectedFolderId;
  String _folderSearchQuery = '';
  bool _isSavingLocal = false;

  @override
  void initState() {
    super.initState();
    // Initialize empty if unsaved to show the "temporary" timestamp hint
    _titleController =
        TextEditingController(text: widget.isSaved ? widget.initialTitle : '');
    _folderSearchController = TextEditingController();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    if (widget.isSaved) {
      _step = 2;
      _flipController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(ActionWizard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSaved && !oldWidget.isSaved) {
      // Artificially wait a bit for the pulse to feel intentional and complete
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;

        setState(() {
          _isSavingLocal = false;
          _step = 2;
        });
        _pulseController.stop();
        _flipController.forward();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _folderSearchController.dispose();
    _flipController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleNextWithFlip() async {
    // Phase 1: Flip to halfway (90 degrees)
    await _flipController.animateTo(0.5,
        duration: const Duration(milliseconds: 300));

    // Switch to step 1
    setState(() => _step = 1);

    // Phase 2: Complete the flip
    await _flipController.animateTo(1.0,
        duration: const Duration(milliseconds: 300));

    // Reset controller for next potential flip (step 1 -> step 2)
    _flipController.value = 0.0;
  }

  Future<void> _handleBackWithFlip() async {
    await _flipController.animateTo(0.5,
        duration: const Duration(milliseconds: 300));
    setState(() => _step = 0);
    await _flipController.reverse();
    _flipController.value = 0.0;
  }

  Future<void> _handleSaveWithFlip() async {
    // Use the controller text if provided, otherwise fallback to the temporary timestamp title
    final finalTitle = _titleController.text.trim().isEmpty
        ? widget.initialTitle
        : _titleController.text.trim();

    setState(() => _isSavingLocal = true);
    unawaited(_pulseController.repeat(reverse: true));

    // The actual save happens via widget.onSave.
    widget.onSave(finalTitle, _selectedFolderId);

    // Note: didUpdateWidget will detect isSaved change and trigger the final flip.
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320, // Consistent fixed height for all steps
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * pi;
          final isBack = angle > pi / 2;

          return Stack(
            children: [
              Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                alignment: Alignment.center,
                child: isBack
                    ? Transform(
                        transform: Matrix4.identity()..rotateY(pi),
                        alignment: Alignment.center,
                        child: _step == 1
                            ? _buildFolderStep()
                            : _buildFinalActions(),
                      )
                    : (_step == 0 ? _buildRenameStep() : _buildFolderStep()),
              ),
              // Full-screen loading removed in favor of button-specific pulse animation
            ],
          );
        },
      ),
    );
  }

  Widget _buildRenameStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              labelText: l10n?.documentName ?? 'Document name',
              labelStyle: TextStyle(
                fontFamily: 'Outfit',
                color: isDark ? Colors.white60 : Colors.black45,
                fontWeight: FontWeight.w600,
              ),
              hintText: 'ex: ${widget.initialTitle}',
              hintStyle: TextStyle(
                fontFamily: 'Outfit',
                color: isDark ? Colors.white30 : Colors.black26,
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFFFFFFFF).withValues(alpha: 0.05)
                  : const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF4F46E5),
                  width: 2,
                ),
              ),
              prefixIcon:
                  const Icon(Icons.edit_note_rounded, color: Color(0xFF4F46E5)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSimpleButton(
                  label: l10n?.delete ?? 'Delete',
                  icon: Icons.delete_outline_rounded,
                  onTap: widget.onDelete,
                  color: Colors.redAccent,
                  isSecondary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSimpleButton(
                  label: l10n?.save ?? 'Save',
                  icon: Icons.arrow_forward_rounded,
                  onTap: _handleNextWithFlip,
                  color: const Color(0xFF4F46E5),
                  isSecondary: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFolderStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    return Consumer(
      builder: (context, ref, _) {
        final folderService = ref.read(folderServiceProvider);
        return FutureBuilder<List<Folder>>(
          future: folderService.getAllFolders(),
          builder: (context, snapshot) {
            final folders = snapshot.data ?? [];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Back and Search integrated
                  Row(
                    children: [
                      IconButton(
                        onPressed: _handleBackWithFlip,
                        icon: const Icon(Icons.arrow_back_rounded, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.2)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextField(
                            controller: _folderSearchController,
                            onChanged: (value) =>
                                setState(() => _folderSearchQuery = value),
                            style: const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                            decoration: InputDecoration(
                              hintText:
                                  l10n?.searchFolder ?? 'Search folder...',
                              hintStyle: TextStyle(
                                  fontFamily: 'Outfit',
                                  color:
                                      isDark ? Colors.white30 : Colors.black38,
                                  fontSize: 13),
                              prefixIcon:
                                  const Icon(Icons.search_rounded, size: 18),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 9),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 85, // Reduced height for more compact cards
                    child: Builder(
                      builder: (context) {
                        // Sort folders by creation date descent (newest first)
                        final sortedFolders = List<Folder>.from(folders)
                          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                        final filteredFolders = _folderSearchQuery.isEmpty
                            ? sortedFolders
                            : sortedFolders
                                .where((f) => f.name
                                    .toLowerCase()
                                    .contains(_folderSearchQuery.toLowerCase()))
                                .toList();

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredFolders.length +
                              (_folderSearchQuery.isEmpty ? 2 : 0),
                          itemBuilder: (context, index) {
                            if (_folderSearchQuery.isEmpty) {
                              if (index == 0 && filteredFolders.isNotEmpty) {
                                // NEWEST FOLDER (takes index 0)
                                final folder = filteredFolders[0];
                                final isSelected =
                                    _selectedFolderId == folder.id;
                                return _buildFolderOption(
                                  icon: Icons.folder_rounded,
                                  label: folder.name,
                                  isSelected: isSelected,
                                  onTap: () => setState(
                                      () => _selectedFolderId = folder.id),
                                  color: folder.color != null
                                      ? _parseColor(folder.color!)
                                      : null,
                                );
                              }

                              if (index == (filteredFolders.isEmpty ? 0 : 1)) {
                                // Create New Folder
                                return _buildFolderOption(
                                  icon: Icons.create_new_folder_outlined,
                                  label: l10n?.newFolder ?? 'New',
                                  isSelected: false,
                                  onTap: () async {
                                    final result = await showDialog<
                                        BentoFolderDialogResult>(
                                      context: context,
                                      builder: (context) =>
                                          const BentoFolderDialog(),
                                    );
                                    if (result != null &&
                                        result.name.isNotEmpty) {
                                      try {
                                        final newFolder =
                                            await folderService.createFolder(
                                          name: result.name,
                                          color: result.color,
                                        );
                                        setState(() {
                                          _selectedFolderId = newFolder.id;
                                          _folderSearchQuery = '';
                                          _folderSearchController.clear();
                                        });
                                      } catch (e) {
                                        if (context.mounted) {
                                          final l10n =
                                              AppLocalizations.of(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    '${l10n?.folderCreationFailed ?? 'Folder creation failed'}: $e')),
                                          );
                                        }
                                      }
                                    }
                                  },
                                );
                              }
                              if (index == (filteredFolders.isEmpty ? 1 : 2)) {
                                // Root folder (no folder)
                                final isSelected = _selectedFolderId == null;
                                return _buildFolderOption(
                                  icon: Icons.home_outlined,
                                  label: l10n?.myDocs ?? 'My Docs',
                                  isSelected: isSelected,
                                  onTap: () =>
                                      setState(() => _selectedFolderId = null),
                                );
                              }

                              // Other folders (starting from index 3)
                              if (index >= 3) {
                                final folder = filteredFolders[index - 2];
                                final isSelected =
                                    _selectedFolderId == folder.id;
                                return _buildFolderOption(
                                  icon: Icons.folder_rounded,
                                  label: folder.name,
                                  isSelected: isSelected,
                                  onTap: () => setState(
                                      () => _selectedFolderId = folder.id),
                                  color: folder.color != null
                                      ? _parseColor(folder.color!)
                                      : null,
                                );
                              }
                              return const SizedBox();
                            } else {
                              // Search results: alphabetical or recent
                              final folder = filteredFolders[index];
                              final isSelected = _selectedFolderId == folder.id;
                              return _buildFolderOption(
                                icon: Icons.folder_rounded,
                                label: folder.name,
                                isSelected: isSelected,
                                onTap: () => setState(
                                    () => _selectedFolderId = folder.id),
                                color: folder.color != null
                                    ? _parseColor(folder.color!)
                                    : null,
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Builder(
                    builder: (context) {
                      Color btnColor =
                          const Color(0xFF4F46E5); // Default Indigo
                      if (_selectedFolderId != null) {
                        final folder = folders.firstWhere(
                            (f) => f.id == _selectedFolderId,
                            orElse: () => folders.first);
                        if (folder.color != null) {
                          btnColor = _parseColor(folder.color!);
                        }
                      }

                      return _buildSimpleButton(
                        label: l10n?.saveHere ?? 'Save here',
                        icon: Icons.check_circle_rounded,
                        onTap: _handleSaveWithFlip,
                        color: btnColor,
                        isSecondary: false,
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFolderOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (color?.withValues(alpha: 0.1) ??
                  const Color(0xFF4F46E5).withValues(alpha: 0.1))
              : (isDark
                  ? Colors.black.withValues(alpha: 0.1)
                  : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (color ?? const Color(0xFF4F46E5))
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color ??
                  (isSelected
                      ? const Color(0xFF4F46E5)
                      : (isDark ? Colors.white60 : Colors.black38)),
              size: 20, // Slightly smaller as requested
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white54 : Colors.black54),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalActions() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row with Share and Export tiles
          Row(
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1.3,
                  child: _buildActionTile(
                    icon: Icons.share_rounded,
                    label: l10n?.share ?? 'Share',
                    onTap: widget.onShare,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1.3,
                  child: _buildActionTile(
                    icon: Icons.save_alt_rounded,
                    label: l10n?.export ?? 'Export',
                    onTap: widget.onExport,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Full-width Finish button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: _buildActionTile(
              icon: Icons.check_circle_rounded,
              label: l10n?.finish ?? 'Finish',
              onTap: widget.onDone,
              color: const Color(0xFF4F46E5),
              isWide: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required bool isSecondary,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: isSecondary
              ? (isDark
                  ? Colors.redAccent.withValues(alpha: 0.1)
                  : const Color(0xFFFEF2F2))
              : color,
          borderRadius: BorderRadius.circular(20),
          border: isSecondary
              ? Border.all(color: color.withValues(alpha: 0.3), width: 1.5)
              : null,
          boxShadow: isSecondary
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: _isSavingLocal ? 0.6 : 0.3),
                    blurRadius: _isSavingLocal ? 20 : 12,
                    spreadRadius: _isSavingLocal ? 4 : 0,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: _isSavingLocal ? _pulseAnimation.value : 1.0,
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSecondary ? color : Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isSecondary ? color : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    double? height,
    bool isWide = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF000000).withValues(alpha: 0.6)
              : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isWide
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}
