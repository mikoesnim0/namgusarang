import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'mission_model.dart';

const String _functionsRegion = 'asia-northeast3';

FirebaseFunctions _functions() =>
    FirebaseFunctions.instanceFor(region: _functionsRegion);

/// 현재 로그인한 사용자에게 적용되는 활성 MissionInstance + 연결된 CouponPolicy 를
/// Cloud Function `getActiveMissionAndPolicy` 로 가져온다.
///
/// Admin 이 값을 바꿔도 앱 재시작 없이 반영되어야 하므로, auth state 가 바뀌거나
/// [missionsRefreshProvider] 가 bump 될 때 재호출된다.
final missionsRefreshProvider = StateProvider<int>((_) => 0);

final activeMissionProvider =
    FutureProvider<ActiveMissionAndPolicy>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  ref.watch(missionsRefreshProvider);
  if (user == null) return const ActiveMissionAndPolicy();

  final callable = _functions().httpsCallable('getActiveMissionAndPolicy');
  final res = await callable.call<Map<Object?, Object?>>(<String, dynamic>{});
  final data = _toStringMap(res.data);

  final missionMap = _toStringMap(data['mission']);
  final policyMap = _toStringMap(data['policy']);

  return ActiveMissionAndPolicy(
    mission: missionMap.isEmpty ? null : ActiveMission.fromMap(missionMap),
    policy: policyMap.isEmpty ? null : ActiveCouponPolicy.fromMap(policyMap),
  );
});

/// 회차 보상 청구. 성공 시 Firestore `users/{uid}/coupons/{id}` 에 쿠폰이 생성된다.
/// 호출자는 `unawaited` 해도 되고 결과를 기다려 다이얼로그를 띄워도 된다.
Future<ClaimCycleRewardResult> claimCycleReward({String? storeId}) async {
  final callable = _functions().httpsCallable('claimCycleReward');
  try {
    final res = await callable.call<Map<Object?, Object?>>(<String, dynamic>{
      if (storeId != null) 'storeId': storeId,
    });
    final data = _toStringMap(res.data);
    return ClaimCycleRewardResult(
      ok: data['ok'] == true,
      reason: (data['reason'] as String?),
      couponId: (data['couponId'] as String?) ?? '',
      placeId: (data['placeId'] as String?) ?? '',
      placeName: (data['placeName'] as String?) ?? '',
    );
  } on FirebaseFunctionsException catch (e) {
    return ClaimCycleRewardResult(
      ok: false,
      reason: e.code,
      couponId: '',
      placeId: '',
      placeName: '',
      errorMessage: e.message,
    );
  }
}

/// 쿠폰 사용(서버 검증). 실패 이유는 `reason` 필드로 내려온다.
Future<bool> redeemCoupon({
  required String couponId,
  required String code,
}) async {
  final callable = _functions().httpsCallable('redeemCoupon');
  try {
    await callable.call<Map<Object?, Object?>>(<String, dynamic>{
      'couponId': couponId,
      'code': code,
    });
    return true;
  } on FirebaseFunctionsException {
    return false;
  }
}

class ClaimCycleRewardResult {
  const ClaimCycleRewardResult({
    required this.ok,
    required this.reason,
    required this.couponId,
    required this.placeId,
    required this.placeName,
    this.errorMessage,
  });
  final bool ok;
  final String? reason;
  final String couponId;
  final String placeId;
  final String placeName;
  final String? errorMessage;
}

Map<String, dynamic> _toStringMap(Object? raw) {
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
  return <String, dynamic>{};
}
