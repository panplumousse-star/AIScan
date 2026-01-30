import 'package:freezed_annotation/freezed_annotation.dart';

part 'scan_usage_model.freezed.dart';
part 'scan_usage_model.g.dart';

/// Tracks the user's document usage for free tier limitations.
///
/// Free users can save up to [maxFreeDocuments] documents.
/// The limit is checked at save time, not at scan time.
@freezed
class ScanUsage with _$ScanUsage {
  const ScanUsage._();

  const factory ScanUsage({
    /// Total number of documents saved by free user.
    @Default(0) int documentCount,

    /// Maximum number of documents allowed for free users.
    @Default(10) int maxFreeDocuments,
  }) = _ScanUsage;

  factory ScanUsage.fromJson(Map<String, dynamic> json) =>
      _$ScanUsageFromJson(json);

  /// Returns true if the user can save more documents.
  bool get canSaveDocument => documentCount < maxFreeDocuments;

  /// Returns the number of documents remaining.
  int get documentsRemaining =>
      (maxFreeDocuments - documentCount).clamp(0, maxFreeDocuments);

  /// Returns true if the document limit has been reached.
  bool get hasReachedLimit => documentCount >= maxFreeDocuments;

  // Legacy compatibility - kept for existing code references
  /// @deprecated Use [documentCount] instead.
  int get totalScans => documentCount;

  /// @deprecated Use [maxFreeDocuments] instead.
  int get maxFreeScans => maxFreeDocuments;

  /// @deprecated Use [canSaveDocument] instead.
  bool get hasScansRemaining => canSaveDocument;

  /// @deprecated Use [documentsRemaining] instead.
  int get scansRemaining => documentsRemaining;

  /// @deprecated Use [canSaveDocument] instead.
  bool get canScan => canSaveDocument;
}
