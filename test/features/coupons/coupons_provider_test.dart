import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hangookji_namgu/features/coupons/coupon_model.dart';
import 'package:hangookji_namgu/features/coupons/coupons_provider.dart';
import 'package:hangookji_namgu/features/home/home_model.dart';
import 'package:hangookji_namgu/features/home/home_provider.dart';

void main() {
  test('CouponsController.isValidCode validates 4 digits only', () {
    expect(CouponsController.isValidCode(''), isFalse);
    expect(CouponsController.isValidCode('123'), isFalse);
    expect(CouponsController.isValidCode('12345'), isFalse);
    expect(CouponsController.isValidCode('12a4'), isFalse);
    expect(CouponsController.isValidCode('1234'), isTrue);
  });

  test('redeem marks coupon as used when code matches', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final coupons = container.read(couponsControllerProvider);
    final active = coupons.firstWhere((c) => c.status == CouponStatus.active);

    // coupon mission should start incomplete
    final beforeHome = container.read(homeControllerProvider);
    final couponMissionBefore =
        beforeHome.missions.firstWhere((m) => m.type == MissionType.coupon);
    expect(couponMissionBefore.isCompleted, isFalse);

    final ok = container.read(couponsControllerProvider.notifier).redeem(
          couponId: active.id,
          inputCode: active.verificationCode,
        );
    expect(ok, isTrue);

    final after = container.read(couponsControllerProvider);
    final updated = after.firstWhere((c) => c.id == active.id);
    expect(updated.status, CouponStatus.used);

    // home mission should be completed after redeem
    final afterHome = container.read(homeControllerProvider);
    final couponMissionAfter =
        afterHome.missions.firstWhere((m) => m.type == MissionType.coupon);
    expect(couponMissionAfter.isCompleted, isTrue);
  });

  test('redeem fails for wrong code', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final coupons = container.read(couponsControllerProvider);
    final active = coupons.firstWhere((c) => c.status == CouponStatus.active);

    final ok = container.read(couponsControllerProvider.notifier).redeem(
          couponId: active.id,
          inputCode: '9999',
        );
    expect(ok, isFalse);
    final after = container.read(couponsControllerProvider);
    final same = after.firstWhere((c) => c.id == active.id);
    expect(same.status, CouponStatus.active);
  });

  test('visibleCouponsProvider filters and sorts', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // default: active only
    container.read(couponFilterProvider.notifier).state = CouponFilter.active;
    final active = container.read(visibleCouponsProvider);
    expect(active.every((c) => c.status == CouponStatus.active), isTrue);

    // sort by title
    container.read(couponSortProvider.notifier).state = CouponSort.title;
    final byTitle = container.read(visibleCouponsProvider);
    final titles = byTitle.map((c) => c.title).toList();
    final sorted = [...titles]..sort();
    expect(titles, sorted);

    // all should include expired
    container.read(couponFilterProvider.notifier).state = CouponFilter.all;
    final all = container.read(visibleCouponsProvider);
    expect(all.any((c) => c.status == CouponStatus.expired), isTrue);
  });
}

