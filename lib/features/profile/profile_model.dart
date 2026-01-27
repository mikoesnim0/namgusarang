class PersonalStats {
  const PersonalStats({
    required this.cycleStart,
    required this.cycleEnd,
    required this.totalCouponsUsed,
    required this.totalCouponSavingsWon,
    required this.cycleSteps,
    required this.cycleCaloriesKcal,
    required this.totalSteps,
    required this.totalDistanceKm,
    required this.totalCaloriesKcal,
  });

  final DateTime cycleStart;
  final DateTime cycleEnd;
  final int totalCouponsUsed;
  final int totalCouponSavingsWon;
  final int cycleSteps;
  final int cycleCaloriesKcal;
  final int totalSteps;
  final double totalDistanceKm;
  final int totalCaloriesKcal;
}
