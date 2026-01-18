import 'package:flutter/material.dart';

/// View mode for the documents list.
enum DocumentsViewMode {
  /// Display documents in a grid layout with large thumbnails.
  grid,

  /// Display documents in a list layout with smaller thumbnails.
  list,
}

/// Sort options for documents.
enum DocumentsSortBy {
  /// Sort by creation date (newest first).
  createdDesc('Recent', Icons.schedule),

  /// Sort by creation date (oldest first).
  createdAsc('Oldest', Icons.history),

  /// Sort by title (alphabetically).
  title('Title', Icons.sort_by_alpha),

  /// Sort by file size (largest first).
  size('Size', Icons.storage),

  /// Sort by last modified date.
  updatedDesc('Modified', Icons.update);

  const DocumentsSortBy(this.label, this.icon);

  /// Display label for this sort option.
  final String label;

  /// Icon for this sort option.
  final IconData icon;
}

/// Filter options for documents.
@immutable
class DocumentsFilter {
  /// Creates a [DocumentsFilter] with default values.
  const DocumentsFilter({
    this.folderId,
    this.favoritesOnly = false,
    this.hasOcrOnly = false,
    this.tagIds = const [],
  });

  /// Filter to a specific folder. Null means all documents.
  final String? folderId;

  /// Show only favorite documents.
  final bool favoritesOnly;

  /// Show only documents with OCR text.
  final bool hasOcrOnly;

  /// Filter to documents with specific tags.
  final List<String> tagIds;

  /// Whether any filter is active.
  bool get hasActiveFilters =>
      folderId != null || favoritesOnly || hasOcrOnly || tagIds.isNotEmpty;

  /// Creates a copy with updated values.
  DocumentsFilter copyWith({
    String? folderId,
    bool? favoritesOnly,
    bool? hasOcrOnly,
    List<String>? tagIds,
    bool clearFolderId = false,
    bool clearTags = false,
  }) {
    return DocumentsFilter(
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      hasOcrOnly: hasOcrOnly ?? this.hasOcrOnly,
      tagIds: clearTags ? const [] : (tagIds ?? this.tagIds),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DocumentsFilter) return false;
    return folderId == other.folderId &&
        favoritesOnly == other.favoritesOnly &&
        hasOcrOnly == other.hasOcrOnly &&
        _listEquals(tagIds, other.tagIds);
  }

  @override
  int get hashCode =>
      Object.hash(folderId, favoritesOnly, hasOcrOnly, Object.hashAll(tagIds));

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
