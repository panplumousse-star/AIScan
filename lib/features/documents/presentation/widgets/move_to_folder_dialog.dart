import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/bento_card.dart';
import '../../../../core/widgets/bento_mascot.dart';
import '../../../../core/widgets/bento_speech_bubble.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../folders/domain/folder_model.dart';
import '../../../folders/presentation/widgets/bento_folder_dialog.dart';

/// Shows a dialog for moving a document to a different folder.
///
/// Returns the selected folder ID if confirmed, '_cancelled_' if cancelled,
/// or null if dismissed.
///
/// Usage:
/// ```dart
/// final result = await showMoveToFolderDialog(
///   context,
///   folders: foldersList,
///   currentFolderId: document.folderId,
///   onCreateFolder: (name, color) => folderService.createFolder(name, color),
/// );
/// if (result != null && result != '_cancelled_') {
///   // Move document to folder with ID: result
/// }
/// ```
Future<String?> showMoveToFolderDialog(
  BuildContext context, {
  required List<Folder> folders,
  required String? currentFolderId,
  required Future<Folder?> Function(String name, String? color) onCreateFolder,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => MoveToFolderDialog(
      folders: folders,
      currentFolderId: currentFolderId,
      onCreateFolder: onCreateFolder,
    ),
  );
}

/// Dialog for moving a document to a different folder.
class MoveToFolderDialog extends StatefulWidget {
  const MoveToFolderDialog({
    super.key,
    required this.folders,
    required this.currentFolderId,
    required this.onCreateFolder,
  });

  final List<Folder> folders;
  final String? currentFolderId;
  final Future<Folder?> Function(String name, String? color) onCreateFolder;

  @override
  State<MoveToFolderDialog> createState() => _MoveToFolderDialogState();
}

class _MoveToFolderDialogState extends State<MoveToFolderDialog> {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                borderRadius: 32,
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
                                l10n?.saveUnder ?? 'Save under...',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n?.chooseDestinationFolder ?? 'Choose a destination folder',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Mascot on right with speech bubble
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            BentoSpeechBubble(
                              tailDirection: BubbleTailDirection.downRight,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : const Color(0xFFEEF2FF),
                              borderColor: Colors.transparent,
                              borderWidth: 0,
                              borderRadius: 12,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              child: Text(
                                l10n?.save ?? 'Save',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E1B4B),
                                ),
                              ),
                            ),
                            BentoLevitationWidget(
                              child: BentoMascot(
                                height: 70,
                                variant: BentoMascotVariant.folderEdit,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Folder list
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.35,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // "My Documents" option
                            _FolderOptionTile(
                              onTap: () =>
                                  setState(() => _selectedFolderId = null),
                              icon: Icons.description_rounded,
                              title: l10n?.myDocuments ?? 'My Documents',
                              color: const Color(0xFF4F46E5),
                              isSelected: _selectedFolderId == null,
                              theme: theme,
                            ),
                            const SizedBox(height: 8),
                            // Specific folders
                            ...widget.folders.map((folder) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _FolderOptionTile(
                                    onTap: () => setState(
                                        () => _selectedFolderId = folder.id),
                                    icon: Icons.folder_rounded,
                                    title: folder.name,
                                    color: _parseColor(folder.color),
                                    isSelected: _selectedFolderId == folder.id,
                                    theme: theme,
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Create new folder button
                    InkWell(
                      onTap: _showCreateFolderDialog,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.add_circle_outline_rounded,
                              size: 24,
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n?.createNewFolder ?? 'New Folder',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop('_cancelled_'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              l10n?.cancel ?? 'Cancel',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _save,
                                borderRadius: BorderRadius.circular(14),
                                child: Center(
                                  child: Text(
                                    l10n?.save ?? 'Save',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onPrimary,
                                      fontSize: 15,
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

class _FolderOptionTile extends StatelessWidget {
  const _FolderOptionTile({
    required this.onTap,
    required this.icon,
    required this.title,
    required this.color,
    required this.isSelected,
    required this.theme,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final Color color;
  final bool isSelected;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.3)
                : theme.colorScheme.onSurface.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
