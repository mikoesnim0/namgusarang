import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'coupon_model.dart';
import '../home/home_model.dart';
import '../home/home_provider.dart';

final couponsControllerProvider =
    NotifierProvider<CouponsController, List<Coupon>>(CouponsController.new);

enum CouponFilter {
  all,
  active,
  used,
  expired,
}

enum CouponSort {
  expiresSoon,
  expiresLate,
  title,
}

final couponFilterProvider = StateProvider<CouponFilter>((ref) {
  return CouponFilter.active;
});

final couponSortProvider = StateProvider<CouponSort>((ref) {
  return CouponSort.expiresSoon;
});

final visibleCouponsProvider = Provider<List<Coupon>>((ref) {
  final coupons = ref.watch(couponsControllerProvider);
  final filter = ref.watch(couponFilterProvider);
  final sort = ref.watch(couponSortProvider);

  Iterable<Coupon> filtered = coupons;
  switch (filter) {
    case CouponFilter.all:
      break;
    case CouponFilter.active:
      filtered = filtered.where((c) => c.status == CouponStatus.active);
    case CouponFilter.used:
      filtered = filtered.where((c) => c.status == CouponStatus.used);
    case CouponFilter.expired:
      filtered = filtered.where((c) => c.status == CouponStatus.expired);
  }

  final list = filtered.toList();
  switch (sort) {
    case CouponSort.expiresSoon:
      list.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    case CouponSort.expiresLate:
      list.sort((a, b) => b.expiresAt.compareTo(a.expiresAt));
    case CouponSort.title:
      list.sort((a, b) => a.title.compareTo(b.title));
  }

  return list;
});

class CouponsController extends Notifier<List<Coupon>> {
  @override
  List<Coupon> build() {
    final now = DateTime.now();
    return [
      Coupon(
        id: 'c1',
        title: '아메리카노 1잔 무료',
        description: '가맹점에서 4자리 코드 확인 후 사용 처리',
        verificationCode: '1234',
        status: CouponStatus.active,
        expiresAt: now.add(const Duration(days: 7)),
      ),
      Coupon(
        id: 'c2',
        title: '3,000원 할인 쿠폰',
        description: '결제 시 직원에게 코드 입력 요청',
        verificationCode: '7777',
        status: CouponStatus.active,
        expiresAt: now.add(const Duration(days: 3)),
      ),
      Coupon(
        id: 'c3',
        title: '편의점 1+1 쿠폰',
        description: '기간 만료된 예시',
        verificationCode: '0000',
        status: CouponStatus.expired,
        expiresAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  static bool isValidCode(String code) {
    if (code.length != 4) return false;
    for (final c in code.codeUnits) {
      if (c < 48 || c > 57) return false;
    }
    return true;
  }

  bool redeem({
    required String couponId,
    required String inputCode,
  }) {
    if (!isValidCode(inputCode)) return false;

    final idx = state.indexWhere((c) => c.id == couponId);
    if (idx < 0) return false;

    final coupon = state[idx];
    if (!coupon.isActive) return false;
    if (coupon.verificationCode != inputCode) return false;

    final next = [...state];
    next[idx] = coupon.copyWith(status: CouponStatus.used);
    state = next;

    // Dummy integration: coupon used -> mark "쿠폰 사용하기" mission as completed on Home
    ref.read(homeControllerProvider.notifier).completeMission(MissionType.coupon);
    return true;
  }
}

