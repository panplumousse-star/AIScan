import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scan_usage_model.dart';

/// Storage keys for scan usage tracking.
class _ScanUsageKeys {
  static const totalScanCount = 'aiscan_total_scan_count';
}

/// Service for tracking and managing scan usage for free users.
class ScanUsageService {
  ScanUsageService(this._prefs);

  final SharedPreferences _prefs;

  /// Loads the current scan usage from SharedPreferences.
  ScanUsage loadUsage() {
    final totalScans = _prefs.getInt(_ScanUsageKeys.totalScanCount) ?? 0;
    return ScanUsage(totalScans: totalScans);
  }

  /// Records a new scan, incrementing the counter.
  Future<ScanUsage> recordScan() async {
    final currentUsage = loadUsage();
    final newTotalScans = currentUsage.totalScans + 1;

    await _prefs.setInt(_ScanUsageKeys.totalScanCount, newTotalScans);

    return currentUsage.copyWith(totalScans: newTotalScans);
  }

  /// Resets the scan usage (used when user upgrades to premium or for testing).
  Future<void> resetUsage() async {
    await _prefs.remove(_ScanUsageKeys.totalScanCount);
  }
}

/// Provider for the ScanUsageService.
final scanUsageServiceProvider = Provider<ScanUsageService>((ref) {
  throw UnimplementedError(
    'scanUsageServiceProvider must be overridden with SharedPreferences instance',
  );
});

/// StateNotifier for managing scan usage state reactively.
class ScanUsageNotifier extends StateNotifier<ScanUsage> {
  ScanUsageNotifier(this._service) : super(_service.loadUsage());

  final ScanUsageService _service;

  /// Records a scan and updates the state.
  Future<void> recordScan() async {
    state = await _service.recordScan();
  }

  /// Resets usage (for premium upgrade or testing).
  Future<void> resetUsage() async {
    await _service.resetUsage();
    state = _service.loadUsage();
  }

  /// Refreshes the state from storage.
  void refresh() {
    state = _service.loadUsage();
  }
}

/// Provider for the scan usage state notifier.
final scanUsageProvider = StateNotifierProvider<ScanUsageNotifier, ScanUsage>((ref) {
  final service = ref.watch(scanUsageServiceProvider);
  return ScanUsageNotifier(service);
});

/// Provider that exposes whether the user can currently scan.
final canScanProvider = Provider<bool>((ref) {
  final usage = ref.watch(scanUsageProvider);
  return usage.canScan;
});

/// Provider that exposes the number of scans remaining.
final scansRemainingProvider = Provider<int>((ref) {
  final usage = ref.watch(scanUsageProvider);
  return usage.scansRemaining;
});
