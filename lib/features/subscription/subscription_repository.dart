import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// 구독 상품 ID
const kSubscriptionProductId = 'premium_monthly';

/// In-App Purchase 구독 처리 레포지토리
class SubscriptionRepository {
  final _iap = InAppPurchase.instance;

  Future<bool> isAvailable() => _iap.isAvailable();

  /// 'premium_monthly' 상품 정보 로드
  Future<ProductDetails?> loadProduct() async {
    final response = await _iap.queryProductDetails({kSubscriptionProductId});
    if (response.productDetails.isNotEmpty) {
      return response.productDetails.first;
    }
    return null;
  }

  /// 구독 시작 (스토어 결제창 열기)
  Future<bool> buySubscription(ProductDetails product) {
    final param = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  /// 기존 구독 복원
  Future<void> restorePurchases() => _iap.restorePurchases();

  /// 결제 완료 이벤트 스트림
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  /// 구매 완료 처리 (소비)
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);

  /// Cloud Function에 구매 토큰 전달하여 구독 활성화
  Future<void> activateOnServer(PurchaseDetails purchase) async {
    await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
        .httpsCallable('activateSubscription')
        .call({
      'purchaseToken': purchase.verificationData.serverVerificationData,
      'productId': purchase.productID,
      'orderId': purchase.purchaseID ?? '',
    });
  }
}
