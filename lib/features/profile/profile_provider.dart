import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../coupons/coupons_provider.dart';
import '../home/home_provider.dart';
import '../settings/settings_provider.dart';
import 'profile_model.dart';

final personalStatsProvider = Provider<PersonalStats>((ref) {
  final coupons = ref.watch(couponsStreamProvider).valueOrNull ?? const [];
  final home = ref.watch(homeControllerProvider);
  ref.watch(settingsControllerProvider);

  final now = DateTime.now();
  final cycleEnd = now.add(Duration(days: home.cycle.daysLeft));
  final cycleStart = cycleEnd.subtract(const Duration(days: 9));

  // Dummy baseline values (to match UI sample, and it still reacts to todaySteps changes).
  final cycleSteps =
      37_688 + home.todaySteps; // default: 40,554 when todaySteps=2,866
  final totalSteps =
      168_077 + home.todaySteps; // default: 170,943 when todaySteps=2,866

  // Dummy heuristics (kcal/거리 환산은 추후 신체정보/헬스데이터 기반으로 교체 예정)
  final cycleCaloriesKcal = (cycleSteps * 0.03538).round();
  final totalDistanceKm =
      totalSteps * 0.0007985; // ≈136.53km when totalSteps=170,943
  final totalCaloriesKcal = (totalSteps * 0.03381)
      .round(); // ≈5,780kcal when totalSteps=170,943

  final usedCoupons = coupons.where((c) => c.status.name == 'used').length;

  // Dummy savings: 2,000 won per used coupon.
  final savingsWon = usedCoupons * 2000;

  return PersonalStats(
    cycleStart: cycleStart,
    cycleEnd: cycleEnd,
    totalCouponsUsed: usedCoupons,
    totalCouponSavingsWon: savingsWon,
    cycleSteps: cycleSteps,
    cycleCaloriesKcal: cycleCaloriesKcal,
    totalSteps: totalSteps,
    totalDistanceKm: double.parse(totalDistanceKm.toStringAsFixed(2)),
    totalCaloriesKcal: totalCaloriesKcal,
  );
});
