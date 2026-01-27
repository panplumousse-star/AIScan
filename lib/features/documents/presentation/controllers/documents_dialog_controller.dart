import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/document_repository.dart';
import '../../../../core/widgets/bento_rename_document_dialog.dart';
import '../../../folders/domain/folder_model.dart';
import '../../../folders/domain/folder_service.dart';
import '../../../folders/presentation/widgets/bento_folder_dialog.dart';
import '../documents_screen.dart'
    show DocumentsScreenState, DocumentsScreenNotifier;
import '../widgets/dialog_widgets.dart';
import '../widgets/filter_sheet.dart' as filter_sheet;

/// Dialog controller for documents screen.
///
/// Provides static methods for showing various dialogs and handling user interactions.
/// Extracted to reduce the size of the main documents_screen.dart file.
class DocumentsDialogController {
  /// Shows confirmation dialog for deleting selected documents/folders.
  ///
  /// If folders contain documents, shows options to either keep documents or delete everything.
  static Future<void> showDeleteConfirmation(
    BuildContext context,
    DocumentsScreenState state,
    DocumentsScreenNotifier notifier,
    WidgetRef ref,
  ) async {
    final folderCount = state.selectedFolderCount;
    final docCount = state.selectedDocumentCount;

    // If folders are selected, check if they contain documents
    int documentsInFoldersCount = 0;
    if (folderCount > 0) {
      final repository = ref.read(documentRepositoryProvider);
      for (final folderId in state.selectedFolderIds) {
        final docsInFolder = await repository.getDocumentsInFolder(folderId);
        documentsInFoldersCount += docsInFolder.length;
      }
    }

    if (!context.mounted) return;

    // If folders contain documents, show special dialog with options
    if (documentsInFoldersCount > 0) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete folders'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The selected ${folderCount == 1 ? 'folder contains' : 'folders contain'} '
                '$documentsInFoldersCount ${documentsInFoldersCount == 1 ? 'document' : 'documents'}.',
              ),
              const SizedBox(height: 12),
              const Text('What would you like to do?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('keep'),
              child: const Text('Keep documents'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('delete_all'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete all'),
            ),
          ],
        ),
      );

      if (result == 'delete_all') {
        // Delete folders and their documents
        await notifier.deleteAllSelectedWithDocuments();
      } else if (result == 'keep') {
        // Delete folders only, documents become root-level
        await notifier.deleteAllSelected();
      }
      return;
    }

    // Standard confirmation for documents only or empty folders
    String message;
    if (folderCount > 0 && docCount > 0) {
      message =
          'Delete $folderCount ${folderCount == 1 ? 'folder' : 'folders'} and '
          '$docCount ${docCount == 1 ? 'document' : 'documents'}?';
    } else if (folderCount > 0) {
      message =
          'Delete $folderCount ${folderCount == 1 ? 'folder' : 'folders'}?';
    } else {
      message = 'Delete $docCount ${docCount == 1 ? 'document' : 'documents'}?';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm deletion'),
        content: Text('$message\n\nThis action cannot be undone.'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await notifier.deleteAllSelected();
    }
  }

  /// Shows filter sheet for sorting and filtering documents.
  static void showFilterSheet(
    BuildContext context,
    DocumentsScreenState state,
    DocumentsScreenNotifier notifier,
  ) {
    unawaited(filter_sheet.showFilterSheet(
      context: context,
      currentSortBy: state.sortBy,
      currentFilter: state.filter,
      onSortByChanged: notifier.setSortBy,
      onFilterChanged: notifier.setFilter,
    ));
  }

  /// Shows dialog to move selected documents to a folder.
  static Future<void> showMoveSelectedToFolderDialog(
    BuildContext context,
    DocumentsScreenState state,
    DocumentsScreenNotifier notifier,
    WidgetRef ref,
  ) async {
    final folderService = ref.read(folderServiceProvider);
    final folders = await folderService.getAllFolders();

    if (!context.mounted) return;

    final selectedFolderId = await showDialog<String>(
      context: context,
      builder: (context) => MoveToFolderDialog(
        folders: folders,
        currentFolderId: state.currentFolderId,
        selectedCount: state.selectedCount,
        onCreateFolder: () async {
          final result = await _showCreateFolderForMoveDialog(context);
          if (result != null && result.name.isNotEmpty) {
            try {
              final newFolder = await folderService.createFolder(
                name: result.name,
                color: result.color,
              );
              if (context.mounted) {
                Navigator.of(context).pop(newFolder.id);
              }
            } on Object catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to create folder: $e')),
                );
              }
            }
          }
        },
      ),
    );

    // User cancelled
    if (selectedFolderId == '_cancelled_') return;

    // Move selected documents to folder
    final movedCount = await notifier.moveSelectedToFolder(selectedFolderId);
    if (context.mounted && movedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selectedFolderId == null
                ? 'Moved $movedCount ${movedCount == 1 ? 'document' : 'documents'} to My Documents'
                : 'Moved $movedCount ${movedCount == 1 ? 'document' : 'documents'} to folder',
          ),
        ),
      );
    }
  }

  /// Shows dialog to create a new folder when moving documents.
  static Future<BentoFolderDialogResult?> _showCreateFolderForMoveDialog(
      BuildContext context) async {
    return showDialog<BentoFolderDialogResult>(
      context: context,
      builder: (context) => const BentoFolderDialog(),
    );
  }

  /// Shows dialog to create a new folder with color picker.
  static Future<void> showCreateNewFolderDialog(
    BuildContext context,
    DocumentsScreenNotifier notifier,
    WidgetRef ref,
  ) async {
    final result = await showDialog<BentoFolderDialogResult>(
      context: context,
      builder: (context) => const BentoFolderDialog(),
    );

    if (result != null && result.name.isNotEmpty) {
      final folderService = ref.read(folderServiceProvider);
      try {
        await folderService.createFolder(
          name: result.name,
          color: result.color,
        );
        await notifier.loadDocuments();
      } on Object catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Échec de la création du dossier: $e')),
          );
        }
      }
    }
  }

  /// Shows dialog to rename a document.
  static Future<void> showRenameDialog(
    BuildContext context,
    String documentId,
    String currentTitle,
    DocumentsScreenNotifier notifier,
  ) async {
    final newTitle = await showBentoRenameDocumentDialog(
      context,
      currentTitle: currentTitle,
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != currentTitle) {
      await notifier.renameDocument(documentId, newTitle);
    }
  }

  /// Shows dialog to edit folder (name + color).
  static Future<void> showEditFolderDialog(
    BuildContext context,
    Folder folder,
    DocumentsScreenNotifier notifier,
  ) async {
    final result = await showDialog<BentoFolderDialogResult>(
      context: context,
      builder: (context) => BentoFolderDialog(
        folder: folder,
        isEditing: true,
      ),
    );

    if (result != null) {
      final hasNameChange =
          result.name != folder.name && result.name.isNotEmpty;
      final hasColorChange = result.color != folder.color;

      if (hasNameChange || hasColorChange) {
        await notifier.updateFolder(
          folderId: folder.id,
          name: hasNameChange ? result.name : null,
          color: hasColorChange ? result.color : null,
        );
      }
    }
  }
}
