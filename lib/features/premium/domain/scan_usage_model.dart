import 'package:freezed_annotation/freezed_annotation.dart';

part 'scan_usage_model.freezed.dart';
part 'scan_usage_model.g.dart';

/// Tracks the user's scan usage for free tier limitations.
@freezed
class ScanUsage with _$ScanUsage {
  const ScanUsage._();

  const factory ScanUsage({
    /// Total number of scans performed by free user.
    @Default(0) int totalScans,

    /// Maximum number of scans allowed for free users.
    @Default(10) int maxFreeScans,
  }) = _ScanUsage;

  factory ScanUsage.fromJson(Map<String, dynamic> json) =>
      _$ScanUsageFromJson(json);

  /// Returns true if the user has remaining free scans.
  bool get hasScansRemaining => totalScans < maxFreeScans;

  /// Returns the number of scans remaining.
  int get scansRemaining => (maxFreeScans - totalScans).clamp(0, maxFreeScans);

  /// Returns true if the user can perform a scan.
  bool get canScan => hasScansRemaining;
}
