import 'package:flutter/foundation.dart';

/// Represents a folder for organizing documents in the application.
///
/// Folders provide hierarchical organization for documents. They can be
/// nested to create a folder tree structure. Each folder can have a custom
/// color and icon for visual identification.
///
/// ## Database Schema Alignment
/// This model aligns with the `folders` table in SQLite:
/// - Primary key: [id] (UUID string)
/// - Required fields: [name], [createdAt], [updatedAt]
/// - Optional fields: [parentId], [color], [icon]
///
/// ## Folder Hierarchy
/// Folders support nesting via the [parentId] field:
/// - Root folders have `parentId = null`
/// - Nested folders reference their parent's [id]
/// - When a parent folder is deleted, children's [parentId] is set to null
///   (they become root folders)
///
/// ## Usage
/// ```dart
/// // Create a new folder
/// final folder = Folder(
///   id: uuid.v4(),
///   name: 'Work Documents',
///   createdAt: DateTime.now(),
///   updatedAt: DateTime.now(),
/// );
///
/// // Create a nested folder
/// final subfolder = Folder(
///   id: uuid.v4(),
///   name: 'Invoices',
///   parentId: folder.id,
///   color: '#4A90D9',
///   createdAt: DateTime.now(),
///   updatedAt: DateTime.now(),
/// );
///
/// // Convert to database map
/// final map = folder.toMap();
/// await database.insert('folders', map);
///
/// // Create from database result
/// final folder = Folder.fromMap(queryResult);
///
/// // Update with copyWith
/// final updated = folder.copyWith(name: 'New Name');
/// ```
@immutable
class Folder {
  /// Creates a [Folder] instance.
  ///
  /// Required parameters:
  /// - [id]: Unique identifier (UUID string)
  /// - [name]: Display name of the folder
  /// - [createdAt]: Creation timestamp
  /// - [updatedAt]: Last modification timestamp
  ///
  /// Optional parameters:
  /// - [parentId]: ID of parent folder for nested folders
  /// - [color]: Custom color as hex string (e.g., '#4A90D9')
  /// - [icon]: Icon name or codepoint for folder display
  const Folder({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.color,
    this.icon,
    this.isFavorite = false,
  });

  /// Unique identifier for the folder (UUID string).
  ///
  /// This is the primary key in the database and should be generated
  /// using the `uuid` package.
  final String id;

  /// Display name of the folder.
  ///
  /// This is shown in the folder list and navigation breadcrumbs.
  final String name;

  /// ID of the parent folder, or null if this is a root folder.
  ///
  /// References another folder in the `folders` table.
  /// When the parent folder is deleted, this is set to null.
  final String? parentId;

  /// Custom color for the folder as a hex string.
  ///
  /// Used for visual identification in the folder list.
  /// Format: '#RRGGBB' (e.g., '#4A90D9')
  ///
  /// If null, the default theme color is used.
  final String? color;

  /// Icon name or identifier for the folder.
  ///
  /// Can be a Material Icons name or custom icon identifier.
  /// If null, the default folder icon is used.
  final String? icon;

  /// Whether this folder is marked as a favorite.
  ///
  /// Favorite folders can be filtered and displayed prominently.
  final bool isFavorite;

  /// Timestamp when the folder was created.
  final DateTime createdAt;

  /// Timestamp when the folder was last modified.
  ///
  /// Updated when the folder's name, color, icon, or parent changes.
  final DateTime updatedAt;

  /// Creates a [Folder] from a database query result map.
  ///
  /// The [map] should contain keys matching the database column names.
  /// Missing optional fields will use their default values.
  ///
  /// Example:
  /// ```dart
  /// final row = await database.query('folders', where: 'id = ?', whereArgs: [id]);
  /// final folder = Folder.fromMap(row.first);
  /// ```
  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as String,
      name: map['name'] as String,
      parentId: map['parent_id'] as String?,
      color: map['color'] as String?,
      icon: map['icon'] as String?,
      isFavorite: (map['is_favorite'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Converts this folder to a map suitable for database insertion.
  ///
  /// The returned map uses database column names as keys.
  ///
  /// Example:
  /// ```dart
  /// final map = folder.toMap();
  /// await database.insert('folders', map);
  /// ```
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'color': color,
      'icon': icon,
      'is_favorite': isFavorite ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Creates a copy of this folder with the given fields replaced.
  ///
  /// All parameters are optional. Only non-null values will be used
  /// to replace the corresponding fields.
  ///
  /// To explicitly set nullable fields to null, use the `clear*` flags:
  /// - [clearParentId]: Sets [parentId] to null (makes folder a root folder)
  /// - [clearColor]: Sets [color] to null (uses default theme color)
  /// - [clearIcon]: Sets [icon] to null (uses default folder icon)
  ///
  /// Example:
  /// ```dart
  /// // Update folder name
  /// final updated = folder.copyWith(
  ///   name: 'New Name',
  ///   updatedAt: DateTime.now(),
  /// );
  ///
  /// // Move folder to root level
  /// final root = folder.copyWith(
  ///   clearParentId: true,
  ///   updatedAt: DateTime.now(),
  /// );
  /// ```
  Folder copyWith({
    String? id,
    String? name,
    String? parentId,
    String? color,
    String? icon,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
    // Special flags to explicitly set nullable fields to null
    bool clearParentId = false,
    bool clearColor = false,
    bool clearIcon = false,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      color: clearColor ? null : (color ?? this.color),
      icon: clearIcon ? null : (icon ?? this.icon),
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Whether this folder is a root folder (has no parent).
  ///
  /// Root folders are displayed at the top level of the folder hierarchy.
  bool get isRoot => parentId == null;

  /// Whether this folder is a nested folder (has a parent).
  ///
  /// Inverse of [isRoot].
  bool get hasParent => parentId != null;

  /// Whether this folder has a custom color set.
  bool get hasColor => color != null;

  /// Whether this folder has a custom icon set.
  bool get hasIcon => icon != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Folder &&
        other.id == id &&
        other.name == name &&
        other.parentId == parentId &&
        other.color == color &&
        other.icon == icon &&
        other.isFavorite == isFavorite &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      parentId,
      color,
      icon,
      isFavorite,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'Folder('
        'id: $id, '
        'name: $name, '
        'parentId: $parentId, '
        'isRoot: $isRoot, '
        'isFavorite: $isFavorite'
        ')';
  }
}

/// Extension methods for [List<Folder>].
///
/// Provides convenient filtering and sorting operations for folder lists.
extension FolderListExtensions on List<Folder> {
  /// Filters to only root folders (those with no parent).
  ///
  /// These folders appear at the top level of the folder hierarchy.
  List<Folder> get roots => where((folder) => folder.isRoot).toList();

  /// Filters to folders that are children of a specific parent folder.
  ///
  /// Returns an empty list if [parentId] is null (use [roots] instead).
  List<Folder> childrenOf(String parentId) =>
      where((folder) => folder.parentId == parentId).toList();

  /// Filters to folders that have a custom color set.
  List<Folder> get withColor => where((folder) => folder.hasColor).toList();

  /// Filters to folders that have a custom icon set.
  List<Folder> get withIcon => where((folder) => folder.hasIcon).toList();

  /// Filters to folders that are marked as favorites.
  List<Folder> get favorites => where((folder) => folder.isFavorite).toList();

  /// Sorts folders by name (alphabetically, case-insensitive).
  ///
  /// Returns a new sorted list, does not modify the original.
  List<Folder> sortedByName() {
    final sorted = List<Folder>.from(this);
    sorted.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return sorted;
  }

  /// Sorts folders by creation date (newest first).
  ///
  /// Returns a new sorted list, does not modify the original.
  List<Folder> sortedByCreatedDesc() {
    final sorted = List<Folder>.from(this);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  /// Sorts folders by creation date (oldest first).
  ///
  /// Returns a new sorted list, does not modify the original.
  List<Folder> sortedByCreatedAsc() {
    final sorted = List<Folder>.from(this);
    sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  /// Sorts folders by update date (most recently updated first).
  ///
  /// Returns a new sorted list, does not modify the original.
  List<Folder> sortedByUpdatedDesc() {
    final sorted = List<Folder>.from(this);
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  /// Gets a folder by its ID.
  ///
  /// Returns the folder if found, otherwise returns null.
  Folder? findById(String id) {
    try {
      return firstWhere((folder) => folder.id == id);
    } on Object catch (_) {
      return null;
    }
  }

  /// Gets the full path of a folder (list of folder names from root to folder).
  ///
  /// Useful for displaying breadcrumb navigation.
  ///
  /// Returns an empty list if the folder ID is not found.
  /// Returns a single-element list for root folders.
  ///
  /// Example:
  /// ```dart
  /// final path = folders.pathTo('subfolder-id');
  /// // Returns: ['Documents', 'Work', 'Invoices']
  /// ```
  List<String> pathTo(String folderId) {
    final folder = findById(folderId);
    if (folder == null) return [];

    final path = <String>[folder.name];
    String? currentParentId = folder.parentId;

    while (currentParentId != null) {
      final parent = findById(currentParentId);
      if (parent == null) break;
      path.insert(0, parent.name);
      currentParentId = parent.parentId;
    }

    return path;
  }

  /// Gets the folder objects in the path from root to the specified folder.
  ///
  /// Similar to [pathTo] but returns [Folder] objects instead of names.
  ///
  /// Returns an empty list if the folder ID is not found.
  List<Folder> folderPathTo(String folderId) {
    final folder = findById(folderId);
    if (folder == null) return [];

    final path = <Folder>[folder];
    String? currentParentId = folder.parentId;

    while (currentParentId != null) {
      final parent = findById(currentParentId);
      if (parent == null) break;
      path.insert(0, parent);
      currentParentId = parent.parentId;
    }

    return path;
  }

  /// Checks if a folder is a descendant of another folder.
  ///
  /// Returns true if [childId] is nested under [ancestorId] at any level.
  /// Returns false if either ID is not found or if [childId] equals [ancestorId].
  bool isDescendantOf(String childId, String ancestorId) {
    if (childId == ancestorId) return false;

    final child = findById(childId);
    if (child == null) return false;

    String? currentParentId = child.parentId;
    while (currentParentId != null) {
      if (currentParentId == ancestorId) return true;
      final parent = findById(currentParentId);
      if (parent == null) break;
      currentParentId = parent.parentId;
    }

    return false;
  }

  /// Gets all descendants of a folder (children, grandchildren, etc.).
  ///
  /// Returns an empty list if the folder ID is not found.
  List<Folder> descendantsOf(String folderId) {
    final descendants = <Folder>[];
    final children = childrenOf(folderId);

    for (final child in children) {
      descendants.add(child);
      descendants.addAll(descendantsOf(child.id));
    }

    return descendants;
  }

  /// Gets the depth of a folder in the hierarchy.
  ///
  /// Root folders have depth 0.
  /// Returns -1 if the folder ID is not found.
  int depthOf(String folderId) {
    final folder = findById(folderId);
    if (folder == null) return -1;
    if (folder.isRoot) return 0;

    int depth = 0;
    String? currentParentId = folder.parentId;

    while (currentParentId != null) {
      depth++;
      final parent = findById(currentParentId);
      if (parent == null) break;
      currentParentId = parent.parentId;
    }

    return depth;
  }
}
