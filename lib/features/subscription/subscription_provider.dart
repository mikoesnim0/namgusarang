import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../auth/auth_providers.dart';
import 'subscription_model.dart';
import 'subscription_repository.dart';

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

// ---------------------------------------------------------------------------
// entitlements/subscription 서브컬렉션 실시간 리스너
// ---------------------------------------------------------------------------

final subscriptionEntitlementProvider =
    StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('entitlements')
      .doc('subscription')
      .snapshots()
      .map((s) => s.data());
});

// ---------------------------------------------------------------------------
// 현재 유저 구독 상태 (서브컬렉션 우선, user doc 폴백)
// ---------------------------------------------------------------------------

final subscriptionStatusProvider = Provider<SubscriptionStatus>((ref) {
  final entitlement = ref.watch(subscriptionEntitlementProvider).valueOrNull;
  final userDoc = ref.watch(currentUserDocProvider).valueOrNull;
  return SubscriptionStatus.fromEntitlementAndUserDoc(
    entitlement: entitlement,
    userDoc: userDoc,
  );
});

// ---------------------------------------------------------------------------
// 구독 구매 상태 (StateNotifier)
// ---------------------------------------------------------------------------

enum SubscriptionPurchaseState { idle, loading, success, error }

class SubscriptionPurchaseNotifier
    extends StateNotifier<AsyncValue<SubscriptionPurchaseState>> {
  SubscriptionPurchaseNotifier(this._ref)
      : super(const AsyncValue.data(SubscriptionPurchaseState.idle)) {
    _listenToPurchaseStream();
  }

  final Ref _ref;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  void _listenToPurchaseStream() {
    final repo = _ref.read(subscriptionRepositoryProvider);
    _purchaseSub = repo.purchaseStream.listen(_onPurchaseUpdate);
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = const AsyncValue.data(SubscriptionPurchaseState.loading);

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleSuccess(purchase);

        case PurchaseStatus.error:
          final msg = purchase.error?.message ?? '구독 처리 중 오류가 발생했습니다.';
          state = AsyncValue.error(msg, StackTrace.current);

        case PurchaseStatus.canceled:
          state = const AsyncValue.data(SubscriptionPurchaseState.idle);
      }

      // pendingCompletePurchase 처리 (오류 상태 포함)
      if (purchase.pendingCompletePurchase) {
        try {
          await _ref
              .read(subscriptionRepositoryProvider)
              .completePurchase(purchase);
        } catch (_) {
          // complete 실패는 무시 (스토어가 재시도함)
        }
      }
    }
  }

  Future<void> _handleSuccess(PurchaseDetails purchase) async {
    state = const AsyncValue.data(SubscriptionPurchaseState.loading);
    try {
      final repo = _ref.read(subscriptionRepositoryProvider);
      await repo.activateOnServer(purchase);
      state = const AsyncValue.data(SubscriptionPurchaseState.success);
    } catch (e, st) {
      state = AsyncValue.error(
        '구독 활성화 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
        st,
      );
    }
  }

  /// 구독 시작
  Future<void> subscribe() async {
    state = const AsyncValue.data(SubscriptionPurchaseState.loading);
    try {
      final repo = _ref.read(subscriptionRepositoryProvider);
      final product = await repo.loadProduct();
      if (product == null) {
        state = AsyncValue.error('상품 정보를 불러올 수 없습니다.', StackTrace.current);
        return;
      }
      final ok = await repo.buySubscription(product);
      if (!ok) {
        state = AsyncValue.error('결제를 시작할 수 없습니다.', StackTrace.current);
      }
      // 이후 처리는 _onPurchaseUpdate에서 처리
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 기존 구독 복원
  Future<void> restorePurchases() async {
    state = const AsyncValue.data(SubscriptionPurchaseState.loading);
    try {
      final repo = _ref.read(subscriptionRepositoryProvider);
      await repo.restorePurchases();
      // 결과는 _onPurchaseUpdate에서 처리
      // 복원할 구독이 없으면 idle로 유지
      if (state.valueOrNull == SubscriptionPurchaseState.loading) {
        state = const AsyncValue.data(SubscriptionPurchaseState.idle);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void resetError() {
    state = const AsyncValue.data(SubscriptionPurchaseState.idle);
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}

final subscriptionPurchaseProvider = StateNotifierProvider<
    SubscriptionPurchaseNotifier, AsyncValue<SubscriptionPurchaseState>>(
  (ref) => SubscriptionPurchaseNotifier(ref),
);
