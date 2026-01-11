import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../coupons/coupons_provider.dart';
import '../home/home_provider.dart';
import '../settings/settings_provider.dart';
import 'profile_model.dart';

final personalStatsProvider = Provider<PersonalStats>((ref) {
  final coupons = ref.watch(couponsControllerProvider);
  final home = ref.watch(homeControllerProvider);
  final settings = ref.watch(settingsControllerProvider).valueOrNull;

  // Dummy: total steps derived from todaySteps + some baseline.
  final totalSteps = (settings?.profile.nickname.isNotEmpty ?? false)
      ? (home.todaySteps + 170_943)
      : (home.todaySteps + 170_943);

  // Dummy heuristics
  final totalDistanceKm = totalSteps * 0.00075; // 0.75m per step
  final totalCaloriesKcal = (totalSteps * 0.04).round();

  final usedCoupons = coupons.where((c) => c.status.name == 'used').length;

  // Dummy savings: 2,000 won per used coupon.
  final savingsWon = usedCoupons * 2000;

  return PersonalStats(
    totalCouponsUsed: usedCoupons,
    totalCouponSavingsWon: savingsWon,
    totalSteps: totalSteps,
    totalDistanceKm: double.parse(totalDistanceKm.toStringAsFixed(2)),
    totalCaloriesKcal: totalCaloriesKcal,
  );
});

