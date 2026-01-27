import 'package:flutter/material.dart';

import '../../../folders/domain/folder_model.dart';

/// Dialog for moving documents to a different folder.
///
/// Displays a list of available folders and allows the user to:
/// - Move documents to the root level (no folder)
/// - Move documents to an existing folder
/// - Create a new folder
///
/// Returns:
/// - `null` to move to root (My Documents)
/// - Folder ID `String` to move to that folder
/// - `'_cancelled_'` if the user cancels
///
/// Usage:
/// ```dart
/// final result = await showDialog<String?>(
///   context: context,
///   builder: (context) => MoveToFolderDialog(
///     folders: folders,
///     currentFolderId: currentFolderId,
///     selectedCount: selectedDocuments.length,
///     onCreateFolder: () {
///       Navigator.of(context).pop('_cancelled_');
///       // Show create folder dialog
///     },
///   ),
/// );
///
/// if (result != null && result != '_cancelled_') {
///   // Move documents to folder with ID: result
/// }
/// ```
class MoveToFolderDialog extends StatelessWidget {
  const MoveToFolderDialog({
    super.key,
    required this.folders,
    required this.currentFolderId,
    required this.selectedCount,
    required this.onCreateFolder,
  });

  final List<Folder> folders;
  final String? currentFolderId;
  final int selectedCount;
  final VoidCallback onCreateFolder;

  Color _parseColor(String? hexColor, ThemeData theme) {
    if (hexColor == null) return theme.colorScheme.secondary;
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } on Object catch (_) {
      return theme.colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
          'Move ${selectedCount == 1 ? 'document' : '$selectedCount documents'}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Root folder option (no folder)
            ListTile(
              leading: Icon(
                Icons.home_outlined,
                color: currentFolderId == null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              title: const Text('My Documents'),
              subtitle: const Text('Root level (no folder)'),
              selected: currentFolderId == null,
              onTap: currentFolderId == null
                  ? null
                  : () => Navigator.of(context).pop(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            if (folders.isNotEmpty) ...[
              const Divider(),
              // Existing folders list
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    final isCurrentFolder = folder.id == currentFolderId;
                    return ListTile(
                      leading: Icon(
                        Icons.folder,
                        color: isCurrentFolder
                            ? theme.colorScheme.primary
                            : _parseColor(folder.color, theme),
                      ),
                      title: Text(folder.name),
                      selected: isCurrentFolder,
                      enabled: !isCurrentFolder,
                      onTap: isCurrentFolder
                          ? null
                          : () => Navigator.of(context).pop(folder.id),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Create new folder button
            OutlinedButton.icon(
              onPressed: onCreateFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Create new folder'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop('_cancelled_'),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Option widget for share format selection dialog.
///
/// Displays a selectable option with an icon, title, subtitle, and chevron.
/// Used in dialogs to present different format or action choices to the user.
///
/// Features:
/// - Icon with colored background
/// - Title and subtitle text
/// - Chevron indicator
/// - Ripple effect on tap
/// - Adapts to light/dark theme
///
/// Usage:
/// ```dart
/// ShareFormatOption(
///   icon: Icons.picture_as_pdf,
///   iconColor: Colors.red,
///   title: 'PDF Document',
///   subtitle: 'High quality, universal format',
///   isDark: Theme.of(context).brightness == Brightness.dark,
///   onTap: () {
///     // Handle PDF export
///   },
/// )
/// ```
class ShareFormatOption extends StatelessWidget {
  const ShareFormatOption({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isDark,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
