import 'package:flutter/foundation.dart';

/// Storage usage statistics.
///
/// Contains information about document storage usage including
/// document count and sizes for different storage categories.
@immutable
class StorageStats {
  /// Creates a [StorageStats] with the provided values.
  const StorageStats({
    required this.documentCount,
    required this.documentsSize,
    required this.thumbnailsSize,
    required this.tempSize,
    required this.totalSize,
  });

  /// Creates a [StorageStats] from a map.
  ///
  /// Typically used to convert from DocumentRepository.getStorageInfo() result.
  factory StorageStats.fromMap(Map<String, dynamic> map) {
    return StorageStats(
      documentCount: map['documentCount'] as int? ?? 0,
      documentsSize: map['documentsSize'] as int? ?? 0,
      thumbnailsSize: map['thumbnailsSize'] as int? ?? 0,
      tempSize: map['tempSize'] as int? ?? 0,
      totalSize: map['totalSize'] as int? ?? 0,
    );
  }

  /// Number of documents in storage.
  final int documentCount;

  /// Total size of encrypted documents in bytes.
  final int documentsSize;

  /// Total size of encrypted thumbnails in bytes.
  final int thumbnailsSize;

  /// Total size of temporary files in bytes.
  final int tempSize;

  /// Total size combining documents and thumbnails in bytes.
  final int totalSize;

  /// Whether storage is empty (no documents).
  bool get isEmpty => documentCount == 0;

  /// Whether storage has any documents.
  bool get hasContent => documentCount > 0;

  /// Formats a byte size into a human-readable string.
  ///
  /// Examples:
  /// - 500 bytes -> "500 B"
  /// - 1536 bytes -> "1.5 KB"
  /// - 1048576 bytes -> "1.0 MB"
  /// - 1073741824 bytes -> "1.0 GB"
  static String formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Formatted documents size (e.g., "1.5 MB").
  String get formattedDocumentsSize => formatSize(documentsSize);

  /// Formatted thumbnails size (e.g., "500 KB").
  String get formattedThumbnailsSize => formatSize(thumbnailsSize);

  /// Formatted temporary files size (e.g., "100 KB").
  String get formattedTempSize => formatSize(tempSize);

  /// Formatted total size (e.g., "2.0 MB").
  String get formattedTotalSize => formatSize(totalSize);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StorageStats &&
        other.documentCount == documentCount &&
        other.documentsSize == documentsSize &&
        other.thumbnailsSize == thumbnailsSize &&
        other.tempSize == tempSize &&
        other.totalSize == totalSize;
  }

  @override
  int get hashCode => Object.hash(
        documentCount,
        documentsSize,
        thumbnailsSize,
        tempSize,
        totalSize,
      );

  @override
  String toString() => 'StorageStats('
      'documentCount: $documentCount, '
      'documentsSize: $documentsSize, '
      'thumbnailsSize: $thumbnailsSize, '
      'tempSize: $tempSize, '
      'totalSize: $totalSize)';
}
