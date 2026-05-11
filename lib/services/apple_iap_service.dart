import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/package_info.dart';

class AppleIapPurchaseResult {
  final bool success;
  final String? message;
  final PurchaseDetails? purchaseDetails;

  const AppleIapPurchaseResult({
    required this.success,
    this.message,
    this.purchaseDetails,
  });
}

class ApplePurchasePayload {
  final String productId;
  final String transactionId;
  final String? verificationData;
  final String? serverVerificationData;
  final String status;

  const ApplePurchasePayload({
    required this.productId,
    required this.transactionId,
    required this.status,
    this.verificationData,
    this.serverVerificationData,
  });
}

class AppleIapService {
  AppleIapService._();

  static final InAppPurchase _instance = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static final StreamController<List<PurchaseDetails>> _purchaseUpdates =
      StreamController<List<PurchaseDetails>>.broadcast();

  static Stream<List<PurchaseDetails>> get purchaseUpdates =>
      _purchaseUpdates.stream;

  static Future<void> ensureInitialized() async {
    if (_subscription != null) return;
    _subscription = _instance.purchaseStream.listen(
      (purchases) async {
        _purchaseUpdates.add(purchases);
        for (final purchase in purchases) {
          if (purchase.pendingCompletePurchase) {
            await _instance.completePurchase(purchase);
          }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Apple IAP purchase stream error: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    return _instance.isAvailable();
  }

  static Future<ProductDetailsResponse> queryProducts(
    Iterable<PackageInfo> packages,
    TargetPlatform platform,
  ) async {
    final ids = packages
        .map((pkg) => pkg.productIdForPlatform(platform)?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    return _instance.queryProductDetails(ids);
  }

  static Future<AppleIapPurchaseResult> buy(ProductDetails product) async {
    final available = await isAvailable();
    if (!available) {
      return const AppleIapPurchaseResult(
        success: false,
        message: 'In-App Purchase is not available on this device.',
      );
    }

    final param = PurchaseParam(productDetails: product);
    final launched = await _instance.buyConsumable(
      purchaseParam: param,
      autoConsume: true,
    );
    if (!launched) {
      return const AppleIapPurchaseResult(
        success: false,
        message: 'Unable to start the purchase flow.',
      );
    }

    return const AppleIapPurchaseResult(success: true);
  }

  static Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  static ApplePurchasePayload? toPayload(PurchaseDetails purchase) {
    final transactionId = purchase.purchaseID?.trim();
    final productId = purchase.productID.trim();
    if (transactionId == null || transactionId.isEmpty || productId.isEmpty) {
      return null;
    }
    return ApplePurchasePayload(
      productId: productId,
      transactionId: transactionId,
      verificationData: purchase.verificationData.localVerificationData,
      serverVerificationData:
          purchase.verificationData.serverVerificationData,
      status: purchase.status.name,
    );
  }
}
