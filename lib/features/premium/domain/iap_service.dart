import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'premium_service.dart';

/// Product ID for the lifetime premium unlock.
/// Must match the product ID configured in Google Play Console.
const String kPremiumLifetimeProductId = 'scanai_premium_lifetime';

/// Set of all product IDs for querying.
const Set<String> kProductIds = {kPremiumLifetimeProductId};

/// Result of an IAP operation.
enum IAPResult {
  success,
  cancelled,
  error,
  notAvailable,
  alreadyOwned,
  pending,
}

/// Service for handling In-App Purchases via Google Play.
class IAPService {
  IAPService(this._premiumService);

  final PremiumService _premiumService;
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _premiumProduct;
  bool _isAvailable = false;
  bool _isInitialized = false;

  /// Whether IAP is available on this device.
  bool get isAvailable => _isAvailable;

  /// Whether the service has been initialized.
  bool get isInitialized => _isInitialized;

  /// The premium product details (for displaying price).
  ProductDetails? get premiumProduct => _premiumProduct;

  /// The formatted price string (e.g., "€2.99").
  String get priceString => _premiumProduct?.price ?? '€2.99';

  /// Initializes the IAP service.
  /// Call this once at app startup.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Check if IAP is available
    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      debugPrint('IAPService: In-app purchases not available');
      _isInitialized = true;
      return;
    }

    // Listen to purchase updates
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (error) {
        debugPrint('IAPService: Purchase stream error: $error');
      },
      onDone: () {
        _subscription?.cancel();
      },
    );

    // Load product details
    await _loadProducts();

    _isInitialized = true;
    debugPrint('IAPService: Initialized successfully');
  }

  /// Loads product details from the store.
  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(kProductIds);

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint(
            'IAPService: Products not found: ${response.notFoundIDs.join(", ")}');
      }

      if (response.productDetails.isNotEmpty) {
        _premiumProduct = response.productDetails.firstWhere(
          (p) => p.id == kPremiumLifetimeProductId,
          orElse: () => response.productDetails.first,
        );
        debugPrint(
            'IAPService: Loaded product: ${_premiumProduct?.id} - ${_premiumProduct?.price}');
      } else {
        debugPrint('IAPService: No products found');
      }
    } catch (e) {
      debugPrint('IAPService: Failed to load products: $e');
    }
  }

  /// Handles purchase updates from the stream.
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      debugPrint(
          'IAPService: Purchase update - ${purchase.productID}: ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Payment is pending (e.g., waiting for user action)
          debugPrint('IAPService: Purchase pending');

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Verify and deliver the product
          final valid = await _verifyPurchase(purchase);
          if (valid) {
            await _deliverProduct(purchase);
          }
          // Complete the purchase
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }

        case PurchaseStatus.error:
          debugPrint('IAPService: Purchase error: ${purchase.error}');
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }

        case PurchaseStatus.canceled:
          debugPrint('IAPService: Purchase cancelled');
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
      }
    }
  }

  /// Verifies a purchase is valid.
  /// In production, this should verify with your backend server.
  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    // For now, we trust the purchase from Google Play.
    // In a production app with a backend, you should:
    // 1. Send purchase.verificationData to your server
    // 2. Server verifies with Google Play Developer API
    // 3. Server returns verification result

    if (purchase.productID != kPremiumLifetimeProductId) {
      return false;
    }

    // Basic verification: check we have verification data
    if (purchase.verificationData.localVerificationData.isEmpty) {
      debugPrint('IAPService: No verification data');
      return false;
    }

    debugPrint('IAPService: Purchase verified locally');
    return true;
  }

  /// Delivers the product (activates premium).
  Future<void> _deliverProduct(PurchaseDetails purchase) async {
    if (purchase.productID == kPremiumLifetimeProductId) {
      // Get purchase token for storage
      String? purchaseToken;
      DateTime? purchaseDate;

      if (Platform.isAndroid) {
        // On Android, we can get more details
        purchaseToken = purchase.verificationData.serverVerificationData;
        if (purchase.transactionDate != null) {
          purchaseDate = DateTime.fromMillisecondsSinceEpoch(
            int.parse(purchase.transactionDate!),
          );
        }
      }

      // Activate premium via PremiumService
      await _premiumService.activatePremium(
        purchaseToken: purchaseToken ?? purchase.purchaseID ?? 'unknown',
        purchaseDate: purchaseDate,
      );

      debugPrint('IAPService: Premium activated!');
    }
  }

  /// Initiates a purchase of the premium lifetime product.
  Future<IAPResult> purchasePremium() async {
    if (!_isAvailable) {
      debugPrint('IAPService: IAP not available');
      return IAPResult.notAvailable;
    }

    if (_premiumProduct == null) {
      debugPrint('IAPService: Product not loaded');
      // Try to reload products
      await _loadProducts();
      if (_premiumProduct == null) {
        return IAPResult.notAvailable;
      }
    }

    try {
      final purchaseParam = PurchaseParam(
        productDetails: _premiumProduct!,
      );

      // For non-consumable products (lifetime purchase)
      final success = await _iap.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (success) {
        debugPrint('IAPService: Purchase initiated');
        return IAPResult.pending;
      } else {
        debugPrint('IAPService: Purchase initiation failed');
        return IAPResult.error;
      }
    } catch (e) {
      debugPrint('IAPService: Purchase error: $e');
      if (e.toString().contains('already owned')) {
        return IAPResult.alreadyOwned;
      }
      return IAPResult.error;
    }
  }

  /// Restores previous purchases.
  Future<IAPResult> restorePurchases() async {
    if (!_isAvailable) {
      debugPrint('IAPService: IAP not available');
      return IAPResult.notAvailable;
    }

    try {
      await _iap.restorePurchases();
      debugPrint('IAPService: Restore initiated');
      return IAPResult.pending;
    } catch (e) {
      debugPrint('IAPService: Restore error: $e');
      return IAPResult.error;
    }
  }

  /// Disposes the service and cancels subscriptions.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _isInitialized = false;
  }
}

/// Provider for the IAPService.
/// Must be initialized at app startup.
final iapServiceProvider = Provider<IAPService>((ref) {
  final premiumService = ref.watch(premiumServiceProvider);
  return IAPService(premiumService);
});

/// Provider that exposes the premium product price.
final premiumPriceProvider = Provider<String>((ref) {
  final iapService = ref.watch(iapServiceProvider);
  return iapService.priceString;
});

/// Provider that indicates if IAP is available.
final iapAvailableProvider = Provider<bool>((ref) {
  final iapService = ref.watch(iapServiceProvider);
  return iapService.isAvailable;
});
