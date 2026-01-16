import 'package:flutter/foundation.dart';

// ============================================================
// Tag Model
// ============================================================

/// Represents a tag for categorizing and labeling documents.
///
/// Tags provide a flexible way to organize documents beyond folder hierarchy.
/// Multiple tags can be applied to a single document, and tags can be used
/// for cross-folder organization and filtering.
///
/// ## Database Schema Alignment
/// This model aligns with the `tags` table in SQLite:
/// - Primary key: [id] (UUID string)
/// - Required fields: [name], [color], [createdAt]
///
/// Tags are associated with documents via the `document_tags` junction table.
///
/// ## Usage
/// ```dart
/// // Create a new tag
/// final tag = Tag(
///   id: uuid.v4(),
///   name: 'Invoice',
///   color: '#4A90D9',
///   createdAt: DateTime.now(),
/// );
///
/// // Convert to database map
/// final map = tag.toMap();
/// await database.insert('tags', map);
///
/// // Create from database result
/// final tag = Tag.fromMap(queryResult);
///
/// // Update with copyWith
/// final updated = tag.copyWith(color: '#FF5722');
/// ```
@immutable
class Tag {
  /// Creates a [Tag] instance.
  ///
  /// Required parameters:
  /// - [id]: Unique identifier (UUID string)
  /// - [name]: Display name of the tag (must be unique)
  /// - [color]: Color as hex string (e.g., '#4A90D9')
  /// - [createdAt]: Creation timestamp
  const Tag({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  /// Unique identifier for the tag (UUID string).
  ///
  /// This is the primary key in the database and should be generated
  /// using the `uuid` package.
  final String id;

  /// Display name of the tag.
  ///
  /// This is shown on tag chips and in tag selection UI.
  /// Tag names must be unique across the application.
  final String name;

  /// Color for the tag as a hex string.
  ///
  /// Used for visual identification of the tag.
  /// Format: '#RRGGBB' (e.g., '#4A90D9')
  final String color;

  /// Timestamp when the tag was created.
  final DateTime createdAt;

  /// Creates a [Tag] from a database query result map.
  ///
  /// The [map] should contain keys matching the database column names.
  ///
  /// Example:
  /// ```dart
  /// final row = await database.query('tags', where: 'id = ?', whereArgs: [id]);
  /// final tag = Tag.fromMap(row.first);
  /// ```
  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as String,
      name: map['name'] as String,
      color: map['color'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Converts this tag to a map suitable for database insertion.
  ///
  /// The returned map uses database column names as keys.
  ///
  /// Example:
  /// ```dart
  /// final map = tag.toMap();
  /// await database.insert('tags', map);
  /// ```
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Creates a copy of this tag with the given fields replaced.
  ///
  /// All parameters are optional. Only non-null values will be used
  /// to replace the corresponding fields.
  ///
  /// Example:
  /// ```dart
  /// final updated = tag.copyWith(
  ///   color: '#FF5722',
  /// );
  /// ```
  Tag copyWith({String? id, String? name, String? color, DateTime? createdAt}) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tag &&
        other.id == id &&
        other.name == name &&
        other.color == color &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, color, createdAt);
  }

  @override
  String toString() {
    return 'Tag('
        'id: $id, '
        'name: $name, '
        'color: $color'
        ')';
  }
}

/// Extension methods for [List<Tag>].
///
/// Provides convenient filtering and sorting operations for tag lists.
extension TagListExtensions on List<Tag> {
  /// Sorts tags by name (alphabetically, case-insensitive).
  ///
  /// Returns a new sorted list, does not modify the original.
  List<Tag> sortedByName() {
    final sorted = List<Tag>.from(this);
    sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }

  /// Sorts tags by creation date (newest first).
  ///
  /// Returns a new sorted list, does not modify the original.
  List<Tag> sortedByCreatedDesc() {
    final sorted = List<Tag>.from(this);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  /// Sorts tags by creation date (oldest first).
  ///
  /// Returns a new sorted list, does not modify the original.
  List<Tag> sortedByCreatedAsc() {
    final sorted = List<Tag>.from(this);
    sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  /// Gets a tag by its ID.
  ///
  /// Returns the tag if found, otherwise returns null.
  Tag? findById(String id) {
    try {
      return firstWhere((tag) => tag.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Gets a tag by its name (case-insensitive).
  ///
  /// Returns the tag if found, otherwise returns null.
  Tag? findByName(String name) {
    try {
      return firstWhere((tag) => tag.name.toLowerCase() == name.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  /// Filters tags that match a search query (case-insensitive).
  ///
  /// Matches against the tag name.
  List<Tag> search(String query) {
    if (query.isEmpty) return List<Tag>.from(this);
    final lowerQuery = query.toLowerCase();
    return where((tag) => tag.name.toLowerCase().contains(lowerQuery)).toList();
  }

  /// Filters tags by a list of IDs.
  ///
  /// Returns tags whose IDs are in the provided list.
  /// Useful for getting Tag objects from a list of tag IDs.
  List<Tag> whereIds(List<String> ids) {
    return where((tag) => ids.contains(tag.id)).toList();
  }

  /// Filters tags by color.
  ///
  /// Returns tags that have the specified color.
  List<Tag> withColor(String color) {
    return where((tag) => tag.color == color).toList();
  }

  /// Gets unique colors used by tags.
  ///
  /// Returns a set of all colors used.
  Set<String> get uniqueColors => map((tag) => tag.color).toSet();
}

// ============================================================
// Document OCR Status
// ============================================================

/// Status of OCR (Optical Character Recognition) processing for a document.
///
/// Documents progress through these states during OCR processing:
/// 1. [pending] - Initial state, OCR has not been performed
/// 2. [processing] - OCR is currently running
/// 3. [completed] - OCR finished successfully
/// 4. [failed] - OCR encountered an error
enum OcrStatus {
  /// OCR has not been performed on this document.
  pending('pending'),

  /// OCR is currently in progress.
  processing('processing'),

  /// OCR completed successfully, text is available.
  completed('completed'),

  /// OCR failed due to an error.
  failed('failed');

  /// Creates an [OcrStatus] with the given database [value].
  const OcrStatus(this.value);

  /// The string value stored in the database.
  final String value;

  /// Creates an [OcrStatus] from a database string value.
  ///
  /// Returns [OcrStatus.pending] if the value is null or unrecognized.
  static OcrStatus fromString(String? value) {
    if (value == null) return OcrStatus.pending;
    return OcrStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => OcrStatus.pending,
    );
  }
}

/// Represents a scanned document in the application.
///
/// Documents are the core data entity in AIScan. Each document represents
/// a scanned file with associated metadata, OCR text, and organizational
/// properties.
///
/// ## Multi-Page Support
/// Documents can contain multiple pages, each stored as a separate encrypted
/// PNG image. The [pagesPaths] field contains the ordered list of encrypted
/// page file paths. Use [filePath] getter for backward compatibility (returns
/// first page path).
///
/// ## Database Schema Alignment
/// This model aligns with the `documents` table in SQLite:
/// - Primary key: [id] (UUID string)
/// - Required fields: [title], [createdAt], [updatedAt]
/// - Optional fields: All other properties
/// - Pages are stored in the separate `document_pages` table
///
/// ## Security Considerations
/// - [pagesPaths] points to encrypted PNG files on disk
/// - [thumbnailPath] points to an encrypted thumbnail
/// - [ocrText] contains encrypted OCR results (encrypted in database)
/// - Never store or log unencrypted document content
///
/// ## Usage
/// ```dart
/// // Create a new document with multiple pages
/// final doc = Document(
///   id: uuid.v4(),
///   title: 'My Document',
///   pagesPaths: ['/path/to/page1.enc', '/path/to/page2.enc'],
///   createdAt: DateTime.now(),
///   updatedAt: DateTime.now(),
/// );
///
/// // Convert to database map
/// final map = doc.toMap();
/// await database.insert('documents', map);
///
/// // Create from database result (pages loaded separately)
/// final doc = Document.fromMap(queryResult, pagesPaths: pagePaths);
///
/// // Update with copyWith
/// final updated = doc.copyWith(title: 'New Title');
/// ```
@immutable
class Document {
  /// Creates a [Document] instance.
  ///
  /// Required parameters:
  /// - [id]: Unique identifier (UUID string)
  /// - [title]: Display title of the document
  /// - [pagesPaths]: List of paths to encrypted page images (PNG)
  /// - [createdAt]: Creation timestamp
  /// - [updatedAt]: Last modification timestamp
  const Document({
    required this.id,
    required this.title,
    required this.pagesPaths,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.thumbnailPath,
    this.originalFileName,
    this.fileSize = 0,
    this.mimeType,
    this.ocrText,
    this.ocrStatus = OcrStatus.pending,
    this.folderId,
    this.isFavorite = false,
    this.tags = const [],
  });

  /// Unique identifier for the document (UUID string).
  ///
  /// This is the primary key in the database and should be generated
  /// using the `uuid` package.
  final String id;

  /// Display title of the document.
  ///
  /// This is shown in the document library and can be edited by the user.
  final String title;

  /// Optional description or notes about the document.
  final String? description;

  /// List of paths to encrypted page images.
  ///
  /// Each page is stored as a separate encrypted PNG file.
  /// The list is ordered by page number (first element = page 1).
  /// This field is populated from the `document_pages` table.
  final List<String> pagesPaths;

  /// Path to the first page (for backward compatibility).
  ///
  /// Returns empty string if no pages exist.
  String get filePath => pagesPaths.isNotEmpty ? pagesPaths.first : '';

  /// Number of pages in the document.
  ///
  /// Computed from [pagesPaths] length.
  int get pageCount => pagesPaths.length;

  /// Path to the encrypted thumbnail image.
  ///
  /// Used for displaying document previews in the library view.
  final String? thumbnailPath;

  /// Original file name before encryption.
  ///
  /// Preserved for export functionality to restore the original name.
  final String? originalFileName;

  /// Total file size in bytes (sum of all encrypted pages).
  final int fileSize;

  /// MIME type of the document pages.
  ///
  /// For PNG storage: 'image/png'
  final String? mimeType;

  /// OCR-extracted text content.
  ///
  /// This text is stored encrypted in the database and is used for
  /// full-text search functionality.
  final String? ocrText;

  /// Current status of OCR processing.
  ///
  /// See [OcrStatus] for possible values.
  final OcrStatus ocrStatus;

  /// ID of the parent folder, or null if in root.
  ///
  /// References the `folders` table in the database.
  final String? folderId;

  /// Whether this document is marked as favorite.
  final bool isFavorite;

  /// List of tag IDs associated with this document.
  ///
  /// Note: Tags are stored in the `document_tags` junction table,
  /// not directly in the documents table. This field is populated
  /// when loading documents with their tags.
  final List<String> tags;

  /// Timestamp when the document was created.
  final DateTime createdAt;

  /// Timestamp when the document was last modified.
  final DateTime updatedAt;

  /// Creates a [Document] from a database query result map.
  ///
  /// The [map] should contain keys matching the database column names.
  /// Missing optional fields will use their default values.
  ///
  /// Required parameters:
  /// - [pagesPaths]: List of page file paths (loaded from document_pages table)
  ///
  /// Optionally accepts a [tags] list to populate the tags field,
  /// since tags come from a separate junction table query.
  factory Document.fromMap(
    Map<String, dynamic> map, {
    required List<String> pagesPaths,
    List<String>? tags,
  }) {
    return Document(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      pagesPaths: pagesPaths,
      thumbnailPath: map['thumbnail_path'] as String?,
      originalFileName: map['original_file_name'] as String?,
      fileSize: map['file_size'] as int? ?? 0,
      mimeType: map['mime_type'] as String?,
      ocrText: map['ocr_text'] as String?,
      ocrStatus: OcrStatus.fromString(map['ocr_status'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      folderId: map['folder_id'] as String?,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      tags: tags ?? const [],
    );
  }

  /// Converts this document to a map suitable for database insertion.
  ///
  /// The returned map uses database column names as keys.
  /// Note: [tags] and [pagesPaths] are not included as they're stored
  /// in separate tables (document_tags and document_pages).
  ///
  /// Example:
  /// ```dart
  /// final map = document.toMap();
  /// await database.insert('documents', map);
  /// ```
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'thumbnail_path': thumbnailPath,
      'original_file_name': originalFileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'ocr_text': ocrText,
      'ocr_status': ocrStatus.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'folder_id': folderId,
      'is_favorite': isFavorite ? 1 : 0,
    };
  }

  /// Creates a copy of this document with the given fields replaced.
  ///
  /// All parameters are optional. Only non-null values will be used
  /// to replace the corresponding fields.
  ///
  /// Example:
  /// ```dart
  /// final updated = document.copyWith(
  ///   title: 'New Title',
  ///   isFavorite: true,
  /// );
  /// ```
  Document copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? pagesPaths,
    String? thumbnailPath,
    String? originalFileName,
    int? fileSize,
    String? mimeType,
    String? ocrText,
    OcrStatus? ocrStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? folderId,
    bool? isFavorite,
    List<String>? tags,
    // Special flag to explicitly set nullable fields to null
    bool clearDescription = false,
    bool clearThumbnailPath = false,
    bool clearOriginalFileName = false,
    bool clearMimeType = false,
    bool clearOcrText = false,
    bool clearFolderId = false,
  }) {
    return Document(
      id: id ?? this.id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      pagesPaths: pagesPaths ?? this.pagesPaths,
      thumbnailPath: clearThumbnailPath
          ? null
          : (thumbnailPath ?? this.thumbnailPath),
      originalFileName: clearOriginalFileName
          ? null
          : (originalFileName ?? this.originalFileName),
      fileSize: fileSize ?? this.fileSize,
      mimeType: clearMimeType ? null : (mimeType ?? this.mimeType),
      ocrText: clearOcrText ? null : (ocrText ?? this.ocrText),
      ocrStatus: ocrStatus ?? this.ocrStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
    );
  }

  /// Whether OCR has been completed for this document.
  bool get hasOcrText => ocrStatus == OcrStatus.completed && ocrText != null;

  /// Whether this document is in a folder.
  bool get isInFolder => folderId != null;

  /// Whether this document has a thumbnail.
  bool get hasThumbnail => thumbnailPath != null;

  /// Whether this document has tags.
  bool get hasTags => tags.isNotEmpty;

  /// The number of tags on this document.
  int get tagCount => tags.length;

  /// Whether this document has a specific tag.
  ///
  /// Returns true if the document has the tag with the given [tagId].
  bool hasTag(String tagId) => tags.contains(tagId);

  /// Whether this document has any of the specified tags.
  ///
  /// Returns true if the document has at least one of the [tagIds].
  /// Returns false if [tagIds] is empty.
  bool hasAnyTag(List<String> tagIds) {
    if (tagIds.isEmpty) return false;
    return tags.any((tag) => tagIds.contains(tag));
  }

  /// Whether this document has all of the specified tags.
  ///
  /// Returns true if the document has every one of the [tagIds].
  /// Returns true if [tagIds] is empty.
  bool hasAllTags(List<String> tagIds) {
    if (tagIds.isEmpty) return true;
    return tagIds.every((tagId) => tags.contains(tagId));
  }

  /// Whether this document is a multi-page document.
  bool get isMultiPage => pageCount > 1;

  /// Human-readable file size string.
  ///
  /// Returns sizes in appropriate units (B, KB, MB, GB).
  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Document &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        listEquals(other.pagesPaths, pagesPaths) &&
        other.thumbnailPath == thumbnailPath &&
        other.originalFileName == originalFileName &&
        other.fileSize == fileSize &&
        other.mimeType == mimeType &&
        other.ocrText == ocrText &&
        other.ocrStatus == ocrStatus &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.folderId == folderId &&
        other.isFavorite == isFavorite &&
        listEquals(other.tags, tags);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      description,
      Object.hashAll(pagesPaths),
      thumbnailPath,
      originalFileName,
      fileSize,
      mimeType,
      ocrText,
      ocrStatus,
      createdAt,
      updatedAt,
      folderId,
      isFavorite,
      Object.hashAll(tags),
    );
  }

  @override
  String toString() {
    return 'Document('
        'id: $id, '
        'title: $title, '
        'pageCount: $pageCount, '
        'ocrStatus: ${ocrStatus.value}, '
        'isFavorite: $isFavorite, '
        'folderId: $folderId, '
        'tags: ${tags.length}'
        ')';
  }
}

/// Extension methods for [List<Document>].
extension DocumentListExtensions on List<Document> {
  /// Filters documents that are favorites.
  List<Document> get favorites => where((doc) => doc.isFavorite).toList();

  /// Filters documents that have completed OCR.
  List<Document> get withOcr => where((doc) => doc.hasOcrText).toList();

  /// Filters documents in a specific folder.
  List<Document> inFolder(String? folderId) =>
      where((doc) => doc.folderId == folderId).toList();

  /// Filters documents with a specific tag.
  List<Document> withTag(String tagId) =>
      where((doc) => doc.tags.contains(tagId)).toList();

  /// Filters documents that have ANY of the specified tags.
  ///
  /// Returns documents that contain at least one of the provided tag IDs.
  /// Returns all documents if [tagIds] is empty.
  List<Document> withAnyTag(List<String> tagIds) {
    if (tagIds.isEmpty) return List<Document>.from(this);
    return where((doc) => doc.tags.any((tag) => tagIds.contains(tag))).toList();
  }

  /// Filters documents that have ALL of the specified tags.
  ///
  /// Returns documents that contain every one of the provided tag IDs.
  /// Returns all documents if [tagIds] is empty.
  List<Document> withAllTags(List<String> tagIds) {
    if (tagIds.isEmpty) return List<Document>.from(this);
    return where(
      (doc) => tagIds.every((tagId) => doc.tags.contains(tagId)),
    ).toList();
  }

  /// Filters documents that have no tags.
  List<Document> get withoutTags => where((doc) => doc.tags.isEmpty).toList();

  /// Filters documents that have tags.
  List<Document> get tagged => where((doc) => doc.hasTags).toList();

  /// Counts documents for each tag ID.
  ///
  /// Returns a map of tag ID to document count.
  /// Only counts tags that appear in the document list.
  Map<String, int> tagCounts() {
    final counts = <String, int>{};
    for (final doc in this) {
      for (final tagId in doc.tags) {
        counts[tagId] = (counts[tagId] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Gets all unique tag IDs used by documents in the list.
  Set<String> get allTagIds {
    final ids = <String>{};
    for (final doc in this) {
      ids.addAll(doc.tags);
    }
    return ids;
  }

  /// Sorts documents by creation date (newest first).
  List<Document> sortedByCreatedDesc() {
    final sorted = List<Document>.from(this);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  /// Sorts documents by creation date (oldest first).
  List<Document> sortedByCreatedAsc() {
    final sorted = List<Document>.from(this);
    sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  /// Sorts documents by update date (most recently updated first).
  List<Document> sortedByUpdatedDesc() {
    final sorted = List<Document>.from(this);
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  /// Sorts documents by title (alphabetically).
  List<Document> sortedByTitle() {
    final sorted = List<Document>.from(this);
    sorted.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return sorted;
  }

  /// Sorts documents by file size (largest first).
  List<Document> sortedBySize() {
    final sorted = List<Document>.from(this);
    sorted.sort((a, b) => b.fileSize.compareTo(a.fileSize));
    return sorted;
  }
}
