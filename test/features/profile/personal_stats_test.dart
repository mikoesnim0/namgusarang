import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hangookji_namgu/features/profile/profile_provider.dart';

void main() {
  test('personalStatsProvider returns non-negative values', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final stats = container.read(personalStatsProvider);
    expect(stats.totalCouponsUsed, greaterThanOrEqualTo(0));
    expect(stats.totalCouponSavingsWon, greaterThanOrEqualTo(0));
    expect(stats.totalSteps, greaterThanOrEqualTo(0));
    expect(stats.totalDistanceKm, greaterThanOrEqualTo(0));
    expect(stats.totalCaloriesKcal, greaterThanOrEqualTo(0));
  });
}

