import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/folders/domain/folder_model.dart';
import '../../features/folders/presentation/widgets/bento_folder_dialog.dart';
import 'bento_card.dart';
import 'animated_widgets.dart';

/// Shows the Bento-style move to folder dialog.
///
/// Returns the selected folder ID, or null for root, or '_cancelled_' if cancelled.
Future<String?> showBentoMoveToFolderDialog(
  BuildContext context, {
  required List<Folder> folders,
  required Future<Folder?> Function(String name, String? color) onCreateFolder,
  String? currentFolderId,
  int selectedCount = 1,
  String? title,
  String? subtitle,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => BentoMoveToFolderDialog(
      folders: folders,
      currentFolderId: currentFolderId,
      selectedCount: selectedCount,
      title: title,
      subtitle: subtitle,
      onCreateFolder: onCreateFolder,
    ),
  );
}

/// Bento-style dialog for moving documents to a different folder.
class BentoMoveToFolderDialog extends StatefulWidget {
  const BentoMoveToFolderDialog({
    super.key,
    required this.folders,
    required this.onCreateFolder,
    this.currentFolderId,
    this.selectedCount = 1,
    this.title,
    this.subtitle,
  });

  final List<Folder> folders;
  final String? currentFolderId;
  final int selectedCount;
  final String? title;
  final String? subtitle;
  final Future<Folder?> Function(String name, String? color) onCreateFolder;

  @override
  State<BentoMoveToFolderDialog> createState() => _BentoMoveToFolderDialogState();
}

class _BentoMoveToFolderDialogState extends State<BentoMoveToFolderDialog> {
  late String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.currentFolderId;
  }

  Future<void> _showCreateFolderDialog() async {
    final result = await showBentoFolderDialog(context);
    if (result != null && result.name.isNotEmpty && mounted) {
      final newFolder = await widget.onCreateFolder(result.name, result.color);
      if (newFolder != null && mounted) {
        setState(() => _selectedFolderId = newFolder.id);
      }
    }
  }

  void _save() {
    Navigator.of(context).pop(_selectedFolderId);
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null) return const Color(0xFF4F46E5);
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF4F46E5);
    }
  }

  String get _defaultTitle {
    if (widget.selectedCount == 1) {
      return 'Enregistrer sous...';
    }
    return 'Déplacer ${widget.selectedCount} documents';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with title and mascot
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title on left
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title ?? _defaultTitle,
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.subtitle ?? 'Choisis un dossier de destination',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Mascot on right
                        BentoLevitationWidget(
                          child: Image.asset(
                            'assets/images/scanai_range.png',
                            height: 90,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Folders list
                    Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        children: [
                          // Root folder option
                          _FolderOption(
                            icon: Icons.home_rounded,
                            name: 'Mes Documents',
                            subtitle: 'Racine (sans dossier)',
                            color: theme.colorScheme.primary,
                            isSelected: _selectedFolderId == null,
                            onTap: () => setState(() => _selectedFolderId = null),
                            isDark: isDark,
                          ),
                          if (widget.folders.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Divider(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.1),
                              ),
                            ),
                            ...widget.folders.map((folder) => _FolderOption(
                              icon: Icons.folder_rounded,
                              name: folder.name,
                              color: _parseColor(folder.color),
                              isSelected: _selectedFolderId == folder.id,
                              onTap: () => setState(() => _selectedFolderId = folder.id),
                              isDark: isDark,
                            )),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Create folder button
                    OutlinedButton.icon(
                      onPressed: _showCreateFolderDialog,
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('Créer un nouveau dossier'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop('_cancelled_'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Annuler',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _save,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              widget.selectedCount == 1 ? 'Enregistrer' : 'Déplacer',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700,
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

/// Folder option item for the move dialog.
class _FolderOption extends StatelessWidget {
  const _FolderOption({
    required this.icon,
    required this.name,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    this.subtitle,
  });

  final IconData icon;
  final String name;
  final String? subtitle;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white.withValues(alpha: 0.1) : color.withValues(alpha: 0.1))
                : null,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: color.withValues(alpha: 0.5), width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: color,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
