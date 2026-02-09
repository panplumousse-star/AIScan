import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/security/secure_storage_service.dart';
import '../../scanner/presentation/state/scanner_screen_state.dart' show ScanBlockReason;
import 'premium_status_model.dart';
import 'scan_usage_service.dart';

/// Storage keys for premium data.
class _PremiumStorageKeys {
  /// Secure storage key for premium status (sensitive).
  static const premiumStatus = 'premium_status';

  /// Secure storage key for purchase token.
  static const purchaseToken = 'premium_purchase_token';

  /// Secure storage key for purchase date.
  static const purchaseDate = 'premium_purchase_date';

  /// SharedPreferences key for debug premium toggle.
  static const debugPremiumEnabled = 'aiscan_debug_premium_enabled';
}

/// Service for managing premium subscription status.
///
/// Uses [SecureStorageService] for sensitive purchase data and
/// [SharedPreferences] for the debug toggle (development only).
class PremiumService {
  PremiumService({
    required SecureStorageService secureStorage,
    required SharedPreferences sharedPreferences,
  })  : _secureStorage = secureStorage,
        _sharedPreferences = sharedPreferences;

  final SecureStorageService _secureStorage;
  final SharedPreferences _sharedPreferences;

  final StreamController<PremiumStatus> _statusController =
      StreamController<PremiumStatus>.broadcast();

  /// Stream of premium status changes.
  Stream<PremiumStatus> get statusStream => _statusController.stream;

  /// Loads the current premium status from secure storage.
  Future<PremiumStatus> loadPremiumStatus() async {
    try {
      final isPremiumStr =
          await _secureStorage.getUserData(_PremiumStorageKeys.premiumStatus);
      final purchaseToken =
          await _secureStorage.getUserData(_PremiumStorageKeys.purchaseToken);
      final purchaseDateStr =
          await _secureStorage.getUserData(_PremiumStorageKeys.purchaseDate);

      final isPremium = isPremiumStr == 'true';
      final purchaseDate = purchaseDateStr != null
          ? DateTime.tryParse(purchaseDateStr)
          : null;

      return PremiumStatus(
        isPremium: isPremium,
        purchaseDate: purchaseDate,
        purchaseToken: purchaseToken,
        isValidated: isPremium && purchaseToken != null,
      );
    } catch (e) {
      debugPrint('PremiumService: Failed to load premium status: $e');
      return const PremiumStatus();
    }
  }

  /// Activates premium status after a successful purchase.
  Future<void> activatePremium({
    required String purchaseToken,
    DateTime? purchaseDate,
  }) async {
    final date = purchaseDate ?? DateTime.now();

    await _secureStorage.storeUserData(
      _PremiumStorageKeys.premiumStatus,
      'true',
    );
    await _secureStorage.storeUserData(
      _PremiumStorageKeys.purchaseToken,
      purchaseToken,
    );
    await _secureStorage.storeUserData(
      _PremiumStorageKeys.purchaseDate,
      date.toIso8601String(),
    );

    final status = PremiumStatus(
      isPremium: true,
      purchaseDate: date,
      purchaseToken: purchaseToken,
      isValidated: true,
    );

    _statusController.add(status);
  }

  /// Deactivates premium status (for testing or if purchase is invalidated).
  Future<void> deactivatePremium() async {
    await _secureStorage.deleteUserData(_PremiumStorageKeys.premiumStatus);
    await _secureStorage.deleteUserData(_PremiumStorageKeys.purchaseToken);
    await _secureStorage.deleteUserData(_PremiumStorageKeys.purchaseDate);

    _statusController.add(const PremiumStatus());
  }

  /// Checks if debug premium mode is enabled.
  bool isDebugPremiumEnabled() {
    return _sharedPreferences
            .getBool(_PremiumStorageKeys.debugPremiumEnabled) ??
        false;
  }

  /// Sets the debug premium mode (development only).
  Future<void> setDebugPremiumEnabled(bool enabled) async {
    await _sharedPreferences.setBool(
      _PremiumStorageKeys.debugPremiumEnabled,
      enabled,
    );
  }

  /// Disposes the service and closes the stream.
  void dispose() {
    _statusController.close();
  }
}

/// Provider for the PremiumService.
final premiumServiceProvider = Provider<PremiumService>((ref) {
  throw UnimplementedError(
    'premiumServiceProvider must be overridden with required dependencies',
  );
});

/// Provider for the debug premium toggle state.
final debugPremiumProvider = NotifierProvider<DebugPremiumNotifier, bool>(
  DebugPremiumNotifier.new,
);

/// Notifier for the debug premium toggle.
class DebugPremiumNotifier extends Notifier<bool> {
  late final PremiumService _service;

  @override
  bool build() {
    _service = ref.watch(premiumServiceProvider);
    return _service.isDebugPremiumEnabled();
  }

  /// Toggles the debug premium mode.
  Future<void> toggle() async {
    final newValue = !state;
    await _service.setDebugPremiumEnabled(newValue);
    state = newValue;
  }

  /// Sets the debug premium mode to a specific value.
  Future<void> setEnabled(bool enabled) async {
    await _service.setDebugPremiumEnabled(enabled);
    state = enabled;
  }
}

/// Provider for the premium status stream.
final premiumStatusStreamProvider = StreamProvider<PremiumStatus>((ref) {
  final service = ref.watch(premiumServiceProvider);

  // Create a stream that emits the initial status, then listens for changes
  return Stream.fromFuture(service.loadPremiumStatus())
      .asyncExpand((initial) async* {
    yield initial;
    yield* service.statusStream;
  });
});

/// Provider that exposes the current premium status synchronously.
final premiumStatusProvider = Provider<PremiumStatus>((ref) {
  final asyncStatus = ref.watch(premiumStatusStreamProvider);
  return asyncStatus.maybeWhen(
    data: (status) => status,
    orElse: () => const PremiumStatus(),
  );
});

/// Main provider to check if user has premium access.
///
/// This provider checks the actual premium status from secure storage.
///
/// NOTE: Debug premium toggle has been removed for security reasons.
/// Use a separate debug build flavor if testing is needed.
final isPremiumProvider = Provider<bool>((ref) {
  // Check the actual premium status only
  // Debug bypass removed for production security (SEC-01)
  final status = ref.watch(premiumStatusProvider);
  return status.isPremium && status.isValidated;
});

/// Provider that checks if a feature is available for the user.
///
/// Returns true if:
/// - User has premium access, OR
/// - The feature is available in the free tier
final featureAvailableProvider =
    Provider.family<bool, PremiumFeature>((ref, feature) {
  final isPremium = ref.watch(isPremiumProvider);
  if (isPremium) return true;

  // Free features are always available
  return feature.isFreeFeature;
});

/// Enumeration of features that can be gated behind premium.
enum PremiumFeature {
  /// Unlimited scans (free tier: 10 max)
  unlimitedScans,

  /// Multi-page scanning (free tier: single page only)
  multiPageScan,

  /// PDF export functionality
  pdfExport,

  /// Document sharing
  sharing,

  /// OCR text extraction
  ocr,
}

extension PremiumFeatureExtension on PremiumFeature {
  /// Returns true if this feature is available in the free tier.
  bool get isFreeFeature => false;

  /// Returns the localization key for this feature's name.
  String get nameKey {
    switch (this) {
      case PremiumFeature.unlimitedScans:
        return 'premium_feature_unlimited_scans';
      case PremiumFeature.multiPageScan:
        return 'premium_feature_multipage';
      case PremiumFeature.pdfExport:
        return 'premium_feature_pdf_export';
      case PremiumFeature.sharing:
        return 'premium_feature_sharing';
      case PremiumFeature.ocr:
        return 'premium_feature_ocr';
    }
  }
}

/// Provider that checks if the user can save a document.
///
/// Free users are limited to 10 documents. This check is performed
/// at save time, not at scan time (users can always scan).
final savePermissionProvider = Provider<ScanBlockReason>((ref) {
  final isPremium = ref.watch(isPremiumProvider);
  if (isPremium) return ScanBlockReason.none;

  final usage = ref.watch(scanUsageProvider);

  if (usage.hasReachedLimit) {
    return ScanBlockReason.documentLimitReached;
  }

  return ScanBlockReason.none;
});
