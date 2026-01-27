import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hangookji_namgu/features/coupons/coupon_model.dart';
import 'package:hangookji_namgu/features/coupons/coupons_provider.dart';
void main() {
  test('CouponsRepository.isValidCode validates 6 digits only', () {
    expect(CouponsRepository.isValidCode(''), isFalse);
    expect(CouponsRepository.isValidCode('12345'), isFalse);
    expect(CouponsRepository.isValidCode('1234567'), isFalse);
    expect(CouponsRepository.isValidCode('12a456'), isFalse);
    expect(CouponsRepository.isValidCode('123456'), isTrue);
  });

  test('visibleCouponsProvider filters and sorts (stream override)', () async {
    final now = DateTime(2026, 1, 27);
    final fake = <Coupon>[
      Coupon(
        id: 'c1',
        title: 'A 쿠폰',
        description: 'desc',
        verificationCode: '123456',
        placeId: 'p1',
        placeName: '샘플매장1',
        status: CouponStatus.active,
        expiresAt: now.add(const Duration(days: 7)),
      ),
      Coupon(
        id: 'c2',
        title: 'B 쿠폰',
        description: 'desc',
        verificationCode: '654321',
        placeId: 'p1',
        placeName: '샘플매장1',
        status: CouponStatus.expired,
        expiresAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        couponsStreamProvider.overrideWith((ref) => Stream.value(fake)),
      ],
    );
    addTearDown(container.dispose);

    // Wait for the first stream event.
    await container.read(couponsStreamProvider.future);

    // default: active only
    container.read(couponFilterProvider.notifier).state = CouponFilter.active;
    final active = container.read(visibleCouponsProvider).valueOrNull!;
    expect(active.every((c) => c.status == CouponStatus.active), isTrue);

    // sort by title
    container.read(couponFilterProvider.notifier).state = CouponFilter.all;
    container.read(couponSortProvider.notifier).state = CouponSort.title;
    final byTitle = container.read(visibleCouponsProvider).valueOrNull!;
    final titles = byTitle.map((c) => c.title).toList();
    final sorted = [...titles]..sort();
    expect(titles, sorted);
  });
}
