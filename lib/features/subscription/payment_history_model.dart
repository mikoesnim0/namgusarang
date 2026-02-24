import 'package:cloud_firestore/cloud_firestore.dart';

/// 결제 이벤트 유형
enum PaymentEventType {
  subscriptionNew,
  subscriptionRenewed,
  subscriptionCanceled,
  subscriptionExpired,
  subscriptionRecovered,
  subscriptionOnHold,
  subscriptionGracePeriod,
  subscriptionRevoked,
  referralGrant,
  voidedPurchase,
  unknown;

  static PaymentEventType fromString(String s) {
    return switch (s) {
      'subscription_new' => PaymentEventType.subscriptionNew,
      'subscription_renewed' => PaymentEventType.subscriptionRenewed,
      'subscription_canceled' => PaymentEventType.subscriptionCanceled,
      'subscription_expired' => PaymentEventType.subscriptionExpired,
      'subscription_recovered' => PaymentEventType.subscriptionRecovered,
      'subscription_on_hold' => PaymentEventType.subscriptionOnHold,
      'subscription_grace_period' => PaymentEventType.subscriptionGracePeriod,
      'subscription_revoked' => PaymentEventType.subscriptionRevoked,
      'referral_grant' => PaymentEventType.referralGrant,
      'voided_purchase' => PaymentEventType.voidedPurchase,
      _ => PaymentEventType.unknown,
    };
  }

  /// 한글 표시 라벨
  String get label => switch (this) {
        PaymentEventType.subscriptionNew => '최초 결제',
        PaymentEventType.subscriptionRenewed => '자동 갱신',
        PaymentEventType.subscriptionCanceled => '구독 해지',
        PaymentEventType.subscriptionExpired => '구독 만료',
        PaymentEventType.subscriptionRecovered => '구독 복원',
        PaymentEventType.subscriptionOnHold => '결제 보류',
        PaymentEventType.subscriptionGracePeriod => '유예 기간',
        PaymentEventType.subscriptionRevoked => '구독 취소(환불)',
        PaymentEventType.referralGrant => '초대 혜택',
        PaymentEventType.voidedPurchase => '결제 무효',
        PaymentEventType.unknown => '기타',
      };
}

/// 결제 내역 이벤트
class PaymentHistoryEvent {
  const PaymentHistoryEvent({
    required this.id,
    required this.type,
    required this.productId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.source,
    this.orderId,
    this.expiresAt,
    this.note,
  });

  final String id;
  final PaymentEventType type;
  final String productId;
  final int amount;
  final String currency;
  final String status;
  final DateTime createdAt;
  final String source;
  final String? orderId;
  final DateTime? expiresAt;
  final String? note;

  factory PaymentHistoryEvent.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    return PaymentHistoryEvent(
      id: docId,
      type: PaymentEventType.fromString(data['eventType'] as String? ?? ''),
      productId: data['productId'] as String? ?? '',
      amount: (data['amount'] as num?)?.round() ?? 0,
      currency: data['currency'] as String? ?? 'KRW',
      status: data['status'] as String? ?? 'completed',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      source: data['source'] as String? ?? '',
      orderId: data['orderId'] as String?,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      note: data['note'] as String?,
    );
  }
}
