import 'package:cloud_firestore/cloud_firestore.dart';

/// 구독 혜택의 출처
enum SubscriptionSource { googlePlay, referral, none }

/// 현재 유저의 구독 상태 + 등급별 혜택
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.isPremium,
    required this.source,
    this.expiresAt,
  });

  final bool isPremium;
  final SubscriptionSource source;
  final DateTime? expiresAt;

  // 등급별 혜택
  int get couponDiscountAmount => isPremium ? 1500 : 500;
  int get couponMinAmount => isPremium ? 15000 : 10000;
  int get missionsPerMonth => isPremium ? 3 : 1;

  static SubscriptionStatus free() =>
      const SubscriptionStatus(isPremium: false, source: SubscriptionSource.none);

  /// entitlements 서브컬렉션 우선, user doc 폴백 (마이그레이션 기간 지원)
  static SubscriptionStatus fromEntitlementAndUserDoc({
    Map<String, dynamic>? entitlement,
    Map<String, dynamic>? userDoc,
  }) {
    if (entitlement != null && entitlement.isNotEmpty) {
      return _fromEntitlementDoc(entitlement);
    }
    return fromUserDoc(userDoc);
  }

  /// entitlements/subscription 서브컬렉션에서 구독 상태 파싱
  static SubscriptionStatus _fromEntitlementDoc(Map<String, dynamic> doc) {
    final now = DateTime.now();
    final status = doc['status'] as String? ?? '';
    final sourceStr = doc['source'] as String? ?? '';

    final source = switch (sourceStr) {
      'google_play' => SubscriptionSource.googlePlay,
      'referral' => SubscriptionSource.referral,
      _ => SubscriptionSource.none,
    };

    if (status != 'premium') return free();

    final expiresTs = doc['expiresAt'];
    if (expiresTs is Timestamp) {
      final expiresAt = expiresTs.toDate();
      if (expiresAt.isAfter(now)) {
        return SubscriptionStatus(
          isPremium: true,
          source: source,
          expiresAt: expiresAt,
        );
      }
    }

    // freeUntil 체크 (referral)
    final freeUntilTs = doc['freeUntil'];
    if (freeUntilTs is Timestamp) {
      final freeUntil = freeUntilTs.toDate();
      if (freeUntil.isAfter(now)) {
        return SubscriptionStatus(
          isPremium: true,
          source: SubscriptionSource.referral,
          expiresAt: freeUntil,
        );
      }
    }

    return free();
  }

  /// 기존 users/{uid} 플랫 문서에서 구독 상태 파싱 (하위 호환)
  static SubscriptionStatus fromUserDoc(Map<String, dynamic>? doc) {
    if (doc == null) return free();
    final now = DateTime.now();

    // 1. 유료 구독 확인
    final status = doc['subscriptionStatus'] as String? ?? '';
    if (status == 'premium') {
      final expiresTs = doc['subscriptionExpiresAt'];
      if (expiresTs is Timestamp) {
        final expiresAt = expiresTs.toDate();
        if (expiresAt.isAfter(now)) {
          return SubscriptionStatus(
            isPremium: true,
            source: SubscriptionSource.googlePlay,
            expiresAt: expiresAt,
          );
        }
      }
    }

    // 2. 초대 코드 무료 체험 기간 확인
    final freeUntilTs = doc['subscriptionFreeUntil'];
    if (freeUntilTs is Timestamp) {
      final freeUntil = freeUntilTs.toDate();
      if (freeUntil.isAfter(now)) {
        return SubscriptionStatus(
          isPremium: true,
          source: SubscriptionSource.referral,
          expiresAt: freeUntil,
        );
      }
    }

    return free();
  }
}
