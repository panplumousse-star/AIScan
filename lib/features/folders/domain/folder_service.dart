import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/database_helper.dart';
import 'folder_model.dart';

/// Riverpod provider for [FolderService].
///
/// Provides a singleton instance of the folder service for
/// dependency injection throughout the application.
final folderServiceProvider = Provider<FolderService>((ref) {
  final databaseHelper = ref.read(databaseHelperProvider);
  return FolderService(databaseHelper: databaseHelper);
});

/// Exception thrown when folder operations fail.
///
/// Contains the original error message and optional underlying exception.
class FolderServiceException implements Exception {
  /// Creates a [FolderServiceException] with the given [message].
  const FolderServiceException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'FolderServiceException: $message (caused by: $cause)';
    }
    return 'FolderServiceException: $message';
  }
}

/// Statistics about a folder.
///
/// Contains aggregate information about documents and subfolders.
@immutable
class FolderStats {
  /// Creates a [FolderStats] with the provided values.
  const FolderStats({
    required this.documentCount,
    required this.subfolderCount,
    required this.totalDocuments,
  });

  /// Number of documents directly in this folder.
  final int documentCount;

  /// Number of immediate subfolders.
  final int subfolderCount;

  /// Total documents including those in subfolders (recursive).
  final int totalDocuments;

  /// Whether this folder is empty (no documents and no subfolders).
  bool get isEmpty => documentCount == 0 && subfolderCount == 0;

  /// Whether this folder has any direct content (documents or subfolders).
  bool get hasContent => documentCount > 0 || subfolderCount > 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FolderStats &&
        other.documentCount == documentCount &&
        other.subfolderCount == subfolderCount &&
        other.totalDocuments == totalDocuments;
  }

  @override
  int get hashCode =>
      Object.hash(documentCount, subfolderCount, totalDocuments);

  @override
  String toString() =>
      'FolderStats('
      'documentCount: $documentCount, '
      'subfolderCount: $subfolderCount, '
      'totalDocuments: $totalDocuments)';
}

/// Service for managing folders with CRUD operations.
///
/// This service handles all folder operations including:
/// - Creating, reading, updating, and deleting folders
/// - Managing folder hierarchy (parent-child relationships)
/// - Querying folder structure and statistics
/// - Moving folders within the hierarchy
///
/// ## Folder Hierarchy
/// Folders support nesting via the parentId field:
/// - Root folders have `parentId = null`
/// - Nested folders reference their parent's ID
/// - When a parent folder is deleted, children become root folders
///   (parentId set to null via ON DELETE SET NULL)
///
/// ## Usage
/// ```dart
/// final folderService = ref.read(folderServiceProvider);
///
/// // Create a new folder
/// final folder = await folderService.createFolder(
///   name: 'Work Documents',
///   color: '#4A90D9',
/// );
///
/// // Create a subfolder
/// final subfolder = await folderService.createFolder(
///   name: 'Invoices',
///   parentId: folder.id,
/// );
///
/// // Get folder with children
/// final children = await folderService.getChildFolders(folder.id);
///
/// // Move folder to new parent
/// await folderService.moveFolder(subfolder.id, newParentId: null);
///
/// // Delete folder
/// await folderService.deleteFolder(folder.id);
/// ```
///
/// ## Important Notes
/// - Folder names are not required to be unique
/// - Circular parent-child references are prevented
/// - Deleting a folder with subfolders orphans them (they become root folders)
/// - Documents in a deleted folder have their folderId set to null
class FolderService {
  /// Creates a [FolderService] with the required dependencies.
  FolderService({required DatabaseHelper databaseHelper, Uuid? uuid})
    : _database = databaseHelper,
      _uuid = uuid ?? const Uuid();

  /// The database helper for storage operations.
  final DatabaseHelper _database;

  /// UUID generator for folder IDs.
  final Uuid _uuid;

  // ============================================================
  // Create Operations
  // ============================================================

  /// Creates a new folder.
  ///
  /// Parameters:
  /// - [name]: Display name for the folder (required)
  /// - [parentId]: ID of the parent folder, or null for root folder
  /// - [color]: Custom color as hex string (e.g., '#4A90D9')
  /// - [icon]: Icon name or identifier
  ///
  /// Returns the created [Folder] with all metadata.
  ///
  /// Throws [FolderServiceException] if:
  /// - The parent folder doesn't exist (if parentId provided)
  /// - Creation fails due to database error
  Future<Folder> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
  }) async {
    try {
      // Validate name
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        throw const FolderServiceException('Folder name cannot be empty');
      }

      // Validate parent exists if provided
      if (parentId != null) {
        final parentExists = await _database.exists(
          DatabaseHelper.tableFolders,
          parentId,
        );
        if (!parentExists) {
          throw FolderServiceException('Parent folder not found: $parentId');
        }
      }

      final id = _uuid.v4();
      final now = DateTime.now();

      final folder = Folder(
        id: id,
        name: trimmedName,
        parentId: parentId,
        color: color,
        icon: icon,
        createdAt: now,
        updatedAt: now,
      );

      await _database.insert(DatabaseHelper.tableFolders, folder.toMap());

      return folder;
    } catch (e) {
      if (e is FolderServiceException) {
        rethrow;
      }
      throw FolderServiceException('Failed to create folder: $name', cause: e);
    }
  }

  // ============================================================
  // Read Operations
  // ============================================================

  /// Gets a folder by ID.
  ///
  /// Returns the [Folder] if found, or `null` if not found.
  ///
  /// Throws [FolderServiceException] if the query fails.
  Future<Folder?> getFolder(String id) async {
    try {
      final result = await _database.getById(DatabaseHelper.tableFolders, id);

      if (result == null) {
        return null;
      }

      return Folder.fromMap(result);
    } catch (e) {
      throw FolderServiceException('Failed to get folder: $id', cause: e);
    }
  }

  /// Gets all folders.
  ///
  /// Returns a list of all folders, sorted by name by default.
  ///
  /// Parameters:
  /// - [orderBy]: SQL ORDER BY clause (default: name ASC)
  ///
  /// Throws [FolderServiceException] if the query fails.
  Future<List<Folder>> getAllFolders({String? orderBy}) async {
    try {
      final results = await _database.query(
        DatabaseHelper.tableFolders,
        orderBy: orderBy ?? '${DatabaseHelper.columnName} ASC',
      );

      return results.map((row) => Folder.fromMap(row)).toList();
    } catch (e) {
      throw FolderServiceException('Failed to get all folders', cause: e);
    }
  }

  /// Gets all root folders (folders with no parent).
  ///
  /// Returns a list of root folders, sorted by name by default.
  ///
  /// Parameters:
  /// - [orderBy]: SQL ORDER BY clause (default: name ASC)
  ///
  /// Throws [FolderServiceException] if the query fails.
  Future<List<Folder>> getRootFolders({String? orderBy}) async {
    try {
      final results = await _database.query(
        DatabaseHelper.tableFolders,
        where: '${DatabaseHelper.columnParentId} IS NULL',
        orderBy: orderBy ?? '${DatabaseHelper.columnName} ASC',
      );

      return results.map((row) => Folder.fromMap(row)).toList();
    } catch (e) {
      throw FolderServiceException('Failed to get root folders', cause: e);
    }
  }

  /// Gets child folders of a specific parent folder.
  ///
  /// Parameters:
  /// - [parentId]: The parent folder ID
  /// - [orderBy]: SQL ORDER BY clause (default: name ASC)
  ///
  /// Returns a list of direct child folders.
  ///
  /// Throws [FolderServiceException] if the query fails.
  Future<List<Folder>> getChildFolders(
    String parentId, {
    String? orderBy,
  }) async {
    try {
      final results = await _database.query(
        DatabaseHelper.tableFolders,
        where: '${DatabaseHelper.columnParentId} = ?',
        whereArgs: [parentId],
        orderBy: orderBy ?? '${DatabaseHelper.columnName} ASC',
      );

      return results.map((row) => Folder.fromMap(row)).toList();
    } catch (e) {
      throw FolderServiceException(
        'Failed to get child folders of: $parentId',
        cause: e,
      );
    }
  }

  /// Gets all descendant folders of a parent folder (recursive).
  ///
  /// Returns all folders nested under the given parent,
  /// including children, grandchildren, etc.
  ///
  /// Parameters:
  /// - [parentId]: The parent folder ID
  ///
  /// Returns a list of all descendant folders.
  ///
  /// Throws [FolderServiceException] if the query fails.
  Future<List<Folder>> getDescendantFolders(String parentId) async {
    try {
      final allFolders = await getAllFolders();
      return allFolders.descendantsOf(parentId);
    } catch (e) {
      if (e is FolderServiceException) {
        rethrow;
      }
      throw FolderServiceException(
        'Failed to get descendant folders of: $parentId',
        cause: e,
      );
    }
  }

  /// Gets the path from root to a folder.
  ///
  /// Returns a list of folders from the root ancestor to the specified folder,
  /// useful for breadcrumb navigation.
  ///
  /// Parameters:
  /// - [folderId]: The target folder ID
  ///
  /// Returns an empty list if the folder is not found.
  /// Returns a single-element list for root folders.
  ///
  /// Throws [FolderServiceException] if the query fails.
  Future<List<Folder>> getFolderPath(String folderId) async {
    try {
      final allFolders = await getAllFolders();
      return allFolders.folderPathTo(folderId);
    } catch (e) {
      if (e is FolderServiceException) {
        rethrow;
      }
      throw FolderServiceException(
        'Failed to get folder path: $folderId',
        cause: e,
      );
    }
  }

  /// Gets the depth of a folder in the hierarchy.
  ///
  /// Root folders have depth 0.
  /// Returns -1 if the folder is not found.
  ///
  /// Throws [FolderServiceException] if the query fails.
  Future<int> getFolderDepth(String folderId) async {
    try {
      final allFolders = await getAllFolders();
      return allFolders.depthOf(folderId);
    } catch (e) {
      if (e is FolderServiceException) {
        rethrow;
      }
      throw FolderServiceException(
        'Failed to get folder depth: $folderId',
        cause: e,
      );
    }
  }

  /// Gets the total count of all folders.
  ///
  /// Throws [FolderServiceException] if the query fails.
  Future<int> getFolderCount() async {
    try {
      return await _database.count(DatabaseHelper.tableFolders);
    } catch (e) {
      throw FolderServiceException('Failed to get folder count', cause: e);
    }
  }

  /// Checks if a folder exists.
  ///
  /// Throws [FolderServiceException] if the query fails.
  Future<bool> folderExists(String id) async {
    try {
      return await _database.exists(DatabaseHelper.tableFolders, id);
    } catch (e) {
      throw FolderServiceException(
        'Failed to check folder existence: $id',
        cause: e,
      );
    }
  }

  // ============================================================
  // Statistics Operations
  // ============================================================

  /// Gets the number of documents directly in a folder.
  ///
  /// Parameters:
  /// - [folderId]: The folder ID, or null for root-level documents
  ///
  /// Throws [FolderServiceException] if the query fails.
  Future<int> getDocumentCount(String? folderId) async {
    try {
      return await _database.count(
        DatabaseHelper.tableDocuments,
        where: folderId != null
            ? '${DatabaseHelper.columnFolderId} = ?'
            : '${DatabaseHelper.columnFolderId} IS NULL',
        whereArgs: folderId != null ? [folderId] : null,
      );
    } catch (e) {
      throw FolderServiceException(
        'Failed to get document count for folder: $folderId',
        cause: e,
      );
    }
  }

  /// Gets statistics about a folder.
  ///
  /// Returns [FolderStats] containing:
  /// - Document count (direct)
  /// - Subfolder count
  /// - Total documents (including nested folders)
  ///
  /// Parameters:
  /// - [folderId]: The folder ID
  ///
  /// Throws [FolderServiceException] if the query fails.
  Future<FolderStats> getFolderStats(String folderId) async {
    try {
      // Get direct document count
      final documentCount = await getDocumentCount(folderId);

      // Get subfolder count
      final subfolders = await getChildFolders(folderId);
      final subfolderCount = subfolders.length;

      // Calculate total documents including subfolders
      int totalDocuments = documentCount;
      for (final subfolder in subfolders) {
        final subStats = await getFolderStats(subfolder.id);
        totalDocuments += subStats.totalDocuments;
      }

      return FolderStats(
        documentCount: documentCount,
        subfolderCount: subfolderCount,
        totalDocuments: totalDocuments,
      );
    } catch (e) {
      if (e is FolderServiceException) {
        rethrow;
      }
      throw FolderServiceException(
        'Failed to get folder stats: $folderId',
        cause: e,
      );
    }
  }

  /// Checks if a folder is empty (no documents and no subfolders).
  ///
  /// Parameters:
  /// - [folderId]: The folder ID
  ///
  /// Throws [FolderServiceException] if the query fails.
  Future<bool> isFolderEmpty(String folderId) async {
    try {
      final stats = await getFolderStats(folderId);
      return stats.isEmpty;
    } catch (e) {
      if (e is FolderServiceException) {
        rethrow;
      }
      throw FolderServiceException(
        'Failed to check if folder is empty: $folderId',
        cause: e,
      );
    }
  }

  // ============================================================
  // Update Operations
  // ============================================================

  /// Updates a folder's metadata.
  ///
  /// This method updates the folder's name, color, and/or icon.
  /// To change the parent folder, use [moveFolder] instead.
  ///
  /// Parameters:
  /// - [folder]: The folder with updated values
  ///
  /// Returns the updated [Folder].
  ///
  /// Throws [FolderServiceException] if:
  /// - The folder doesn't exist
  /// - The new name is empty
  /// - The update fails due to database error
  Future<Folder> updateFolder(Folder folder) async {
    try {
      // Validate name
      final trimmedName = folder.name.trim();
      if (trimmedName.isEmpty) {
        throw const FolderServiceException('Folder name cannot be empty');
      }

      final updatedFolder = folder.copyWith(
        name: trimmedName,
        updatedAt: DateTime.now(),
      );

      final rowsAffected = await _database.update(
        DatabaseHelper.tableFolders,
        updatedFolder.toMap(),
        where: '${DatabaseHelper.columnId} = ?',
        whereArgs: [folder.id],
      );

      if (rowsAffected == 0) {
        throw FolderServiceException('Folder not found: ${folder.id}');
      }

      return updatedFolder;
    } catch (e) {
      if (e is FolderServiceException) {
        rethrow;
      }
      throw FolderServiceException(
        'Failed to update folder: ${folder.id}',
        cause: e,
      );
    }
  }

  /// Renames a folder.
  ///
  /// Convenience method for updating only the folder name.
  ///
  /// Parameters:
  /// - [folderId]: The folder ID
  /// - [newName]: The new folder name
  ///
  /// Returns the updated [Folder].
  ///
  /// Throws [FolderServiceException] if the rename fails.
  Future<Folder> renameFolder(String folderId, String newName) async {
    try {
      final folder = await getFolder(folderId);
      if (folder == null) {
        throw FolderServiceException('Folder not found: $folderId');
      }

      return await updateFolder(folder.copyWith(name: newName));
    } catch (e) {
      if (e is FolderServiceException) {
        rethrow;
      }
      throw FolderServiceException(
        'Failed to rename folder: $folderId',
        cause: e,
      );
    }
  }

  /// Updates a folder's color.
  ///
  /// Parameters:
  /// - [folderId]: The folder ID
  /// - [color]: The new color (hex string), or null to clear
  ///
  /// Returns the updated [Folder].
  ///
  /// Throws [FolderServiceException] if the update fails.
  Future<Folder> updateFolderColor(String folderId, String? color) async {
    try {
      final folder = await getFolder(folderId);
      if (folder == null) {
        throw FolderServiceException('Folder not found: $folderId');
      }

      return await updateFolder(
        folder.copyWith(color: color, clearColor: color == null),
      );
    } catch (e) {
      if (e is FolderServiceException) {
        rethrow;
      }
      throw FolderServiceException(
        'Failed to update folder color: $folderId',
        cause: e,
      );
    }
  }

  /// Updates a folder's icon.
  ///
  /// Parameters:
  /// - [folderId]: The folder ID
  /// - [icon]: The new icon name, or null to clear
  ///
  /// Returns the updated [Folder].
  ///
  /// Throws [FolderServiceException] if the update fails.
  Future<Folder> updateFolderIcon(String folderId, String? icon) async {
    try {
      final folder = await getFolder(folderId);
      if (folder == null) {
        throw FolderServiceException('Folder not found: $folderId');
      }

      return await updateFolder(
        folder.copyWith(icon: icon, clearIcon: icon == null),
      );
    } catch (e) {
      if (e is FolderServiceException) {
        rethrow;
      }
      throw FolderServiceException(
        'Failed to update folder icon: $folderId',
        cause: e,
      );
    }
  }

  /// Moves a folder to a new parent.
  ///
  /// Parameters:
  /// - [folderId]: The folder ID to move
  /// - [newParentId]: The new parent folder ID, or null to make root
  ///
  /// Returns the updated [Folder].
  ///
  /// Throws [FolderServiceException] if:
  /// - The folder doesn't exist
  /// - The new parent doesn't exist (if not null)
  /// - Moving would create a circular reference (parent can't be descendant)
  /// - The folder is being moved to itself
  Future<Folder> moveFolder(String folderId, {String? newParentId}) async {
    try {
      // Validate folder exists
      final folder = await getFolder(folderId);
      if (folder == null) {
        throw FolderServiceException('Folder not found: $folderId');
      }

      // Can't move to self
      if (newParentId == folderId) {
        throw const FolderServiceException('Cannot move folder to itself');
      }

      // Validate new parent exists if provided
      if (newParentId != null) {
        final newParentExists = await _database.exists(
          DatabaseHelper.tableFolders,
          newParentId,
        );
        if (!newParentExists) {
          throw FolderServiceException(
            'New parent folder not found: $newParentId',
          );
        }

        // Prevent circular reference - new parent can't be a descendant
        final allFolders = await getAllFolders();
        if (allFolders.isDescendantOf(newParentId, folderId)) {
          throw const FolderServiceException(
            'Cannot move folder into its own descendant (circular reference)',
          );
        }
      }

      // No change needed if already at target location
      if (folder.parentId == newParentId) {
        return folder;
      }

      final updatedFolder = folder.copyWith(
        parentId: newParentId,
        clearParentId: newParentId == null,
        updatedAt: DateTime.now(),
      );

      await _database.update(
        DatabaseHelper.tableFolders,
        updatedFolder.toMap(),
        where: '${DatabaseHelper.columnId} = ?',
        whereArgs: [folderId],
      );

      return updatedFolder;
    } catch (e) {
      if (e is FolderServiceException) {
        rethrow;
      }
      throw FolderServiceException(
        'Failed to move folder: $folderId',
        cause: e,
      );
    }
  }

  // ============================================================
  // Delete Operations
  // ============================================================

  /// Deletes a folder.
  ///
  /// When a folder is deleted:
  /// - Child folders become root folders (parentId set to null)
  /// - Documents in the folder have their folderId set to null
  ///
  /// This is handled by the database foreign key ON DELETE SET NULL.
  ///
  /// Parameters:
  /// - [folderId]: The folder ID to delete
  ///
  /// Throws [FolderServiceException] if:
  /// - The folder doesn't exist
  /// - Deletion fails due to database error
  Future<void> deleteFolder(String folderId) async {
    try {
      // Verify folder exists
      final folder = await getFolder(folderId);
      if (folder == null) {
        throw FolderServiceException('Folder not found: $folderId');
      }

      await _database.delete(
        DatabaseHelper.tableFolders,
        where: '${DatabaseHelper.columnId} = ?',
        whereArgs: [folderId],
      );
    } catch (e) {
      if (e is FolderServiceException) {
        rethrow;
      }
      throw FolderServiceException(
        'Failed to delete folder: $folderId',
        cause: e,
      );
    }
  }

  /// Deletes a folder and all its descendants (recursive).
  ///
  /// This method deletes the folder and all nested subfolders.
  /// Documents in deleted folders will have their folderId set to null.
  ///
  /// Parameters:
  /// - [folderId]: The folder ID to delete
  ///
  /// Returns the count of deleted folders.
  ///
  /// Throws [FolderServiceException] if deletion fails.
  Future<int> deleteFolderRecursive(String folderId) async {
    try {
      // Verify folder exists
      final folder = await getFolder(folderId);
      if (folder == null) {
        throw FolderServiceException('Folder not found: $folderId');
      }

      // Get all descendants (already sorted from children outward)
      final descendants = await getDescendantFolders(folderId);

      // Delete in reverse order (deepest first) to avoid orphaning
      int deleteCount = 0;
      for (final descendant in descendants.reversed) {
        await _database.delete(
          DatabaseHelper.tableFolders,
          where: '${DatabaseHelper.columnId} = ?',
          whereArgs: [descendant.id],
        );
        deleteCount++;
      }

      // Delete the folder itself
      await _database.delete(
        DatabaseHelper.tableFolders,
        where: '${DatabaseHelper.columnId} = ?',
        whereArgs: [folderId],
      );
      deleteCount++;

      return deleteCount;
    } catch (e) {
      if (e is FolderServiceException) {
        rethrow;
      }
      throw FolderServiceException(
        'Failed to delete folder recursively: $folderId',
        cause: e,
      );
    }
  }

  /// Deletes multiple folders.
  ///
  /// Throws [FolderServiceException] if any deletion fails.
  Future<void> deleteFolders(List<String> folderIds) async {
    try {
      for (final id in folderIds) {
        await deleteFolder(id);
      }
    } catch (e) {
      if (e is FolderServiceException) {
        rethrow;
      }
      throw FolderServiceException('Failed to delete folders', cause: e);
    }
  }

  // ============================================================
  // Search Operations
  // ============================================================

  /// Searches folders by name.
  ///
  /// Performs a case-insensitive partial match on folder names.
  ///
  /// Parameters:
  /// - [query]: The search query
  /// - [orderBy]: SQL ORDER BY clause (default: name ASC)
  ///
  /// Returns folders matching the query.
  ///
  /// Throws [FolderServiceException] if the search fails.
  Future<List<Folder>> searchFolders(String query, {String? orderBy}) async {
    try {
      final trimmedQuery = query.trim();
      if (trimmedQuery.isEmpty) {
        return [];
      }

      final results = await _database.query(
        DatabaseHelper.tableFolders,
        where: '${DatabaseHelper.columnName} LIKE ?',
        whereArgs: ['%$trimmedQuery%'],
        orderBy: orderBy ?? '${DatabaseHelper.columnName} ASC',
      );

      return results.map((row) => Folder.fromMap(row)).toList();
    } catch (e) {
      throw FolderServiceException(
        'Failed to search folders: $query',
        cause: e,
      );
    }
  }

  // ============================================================
  // Utility Methods
  // ============================================================

  /// Checks if the service is ready for operations.
  ///
  /// Returns true if the database is initialized.
  Future<bool> isReady() async {
    return _database.isInitialized;
  }

  /// Initializes the service.
  ///
  /// This should be called during app startup to ensure
  /// the database is ready for folder operations.
  ///
  /// Returns true if initialization was successful.
  Future<bool> initialize() async {
    try {
      await _database.initialize();
      return true;
    } catch (e) {
      throw FolderServiceException(
        'Failed to initialize folder service',
        cause: e,
      );
    }
  }

  /// Gets folder hierarchy as a flat list with depth information.
  ///
  /// Returns folders in order suitable for display in a tree view,
  /// with each folder annotated with its depth level.
  ///
  /// Returns a list of (Folder, depth) pairs.
  ///
  /// Throws [FolderServiceException] if the query fails.
  Future<List<(Folder, int)>> getFolderHierarchy() async {
    try {
      final allFolders = await getAllFolders();
      final result = <(Folder, int)>[];

      // Build hierarchy starting from root folders
      void addFolderWithChildren(Folder folder, int depth) {
        result.add((folder, depth));
        final children = allFolders.childrenOf(folder.id);
        for (final child in children.sortedByName()) {
          addFolderWithChildren(child, depth + 1);
        }
      }

      // Start with root folders
      final rootFolders = allFolders.roots.sortedByName();
      for (final root in rootFolders) {
        addFolderWithChildren(root, 0);
      }

      return result;
    } catch (e) {
      if (e is FolderServiceException) {
        rethrow;
      }
      throw FolderServiceException('Failed to get folder hierarchy', cause: e);
    }
  }

  /// Gets folders suitable for a folder picker (excludes a folder and its descendants).
  ///
  /// Useful when moving a folder - can't move into itself or descendants.
  ///
  /// Parameters:
  /// - [excludeFolderId]: The folder ID to exclude (with its descendants)
  ///
  /// Returns folders that can be selected as a new parent.
  ///
  /// Throws [FolderServiceException] if the query fails.
  Future<List<Folder>> getSelectableFolders(String? excludeFolderId) async {
    try {
      final allFolders = await getAllFolders();

      if (excludeFolderId == null) {
        return allFolders;
      }

      // Get IDs to exclude
      final excludeIds = <String>{excludeFolderId};
      final descendants = allFolders.descendantsOf(excludeFolderId);
      for (final d in descendants) {
        excludeIds.add(d.id);
      }

      // Return folders not in exclude set
      return allFolders.where((f) => !excludeIds.contains(f.id)).toList();
    } catch (e) {
      if (e is FolderServiceException) {
        rethrow;
      }
      throw FolderServiceException(
        'Failed to get selectable folders',
        cause: e,
      );
    }
  }
}
