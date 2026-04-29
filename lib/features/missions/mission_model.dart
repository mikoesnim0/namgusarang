/// Admin `mission_instances` 컬렉션의 문서를 앱에서 사용하는 형태로 정규화.
/// PRD 07_미션_관리 참고.
class ActiveMission {
  const ActiveMission({
    required this.instanceId,
    required this.name,
    required this.description,
    required this.startAt,
    required this.endAt,
    required this.durationDays,
    required this.targetSteps,
    required this.targetDays,
    required this.achievementType,
    this.rewardCouponId,
    this.rewardCouponName = '',
  });

  final String instanceId;
  final String name;
  final String description;
  final DateTime? startAt;
  final DateTime? endAt;
  final int durationDays;
  final int targetSteps;
  final int targetDays;
  final String achievementType;
  final String? rewardCouponId;
  final String rewardCouponName;

  factory ActiveMission.fromMap(Map<String, dynamic> m) {
    DateTime? parseDate(dynamic v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return ActiveMission(
      instanceId: (m['instanceId'] as String?)?.trim() ?? '',
      name: (m['name'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      startAt: parseDate(m['startAt']),
      endAt: parseDate(m['endAt']),
      durationDays: (m['durationDays'] as num?)?.round() ?? 10,
      targetSteps: (m['targetSteps'] as num?)?.round() ?? 5000,
      targetDays: (m['targetDays'] as num?)?.round() ?? 3,
      achievementType: (m['achievementType'] as String?) ?? 'n_days',
      rewardCouponId: (m['rewardCouponId'] as String?),
      rewardCouponName: (m['rewardCouponName'] as String?) ?? '',
    );
  }
}

/// `coupon_policies` 문서 중 현재 미션에 연결된 것.
class ActiveCouponPolicy {
  const ActiveCouponPolicy({
    required this.couponId,
    required this.name,
    required this.description,
    required this.discountAmount,
    required this.minPurchase,
    required this.validityDays,
    required this.duplicateUse,
  });

  final String couponId;
  final String name;
  final String description;
  final int discountAmount;
  final int minPurchase;
  final int validityDays;
  final bool duplicateUse;

  factory ActiveCouponPolicy.fromMap(Map<String, dynamic> m) {
    return ActiveCouponPolicy(
      couponId: (m['couponId'] as String?)?.trim() ?? '',
      name: (m['name'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      discountAmount: (m['discountAmount'] as num?)?.round() ?? 0,
      minPurchase: (m['minPurchase'] as num?)?.round() ?? 0,
      validityDays: (m['validityDays'] as num?)?.round() ?? 7,
      duplicateUse: m['duplicateUse'] == true,
    );
  }
}

class ActiveMissionAndPolicy {
  const ActiveMissionAndPolicy({this.mission, this.policy});
  final ActiveMission? mission;
  final ActiveCouponPolicy? policy;

  bool get isEmpty => mission == null;
}
