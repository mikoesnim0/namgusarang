/// Simple step-derived metrics used across the app.
///
/// We intentionally keep this lightweight and deterministic so that
/// "kcal" values stay consistent between Home / Profile / Walker screens.
class StepMetrics {
  StepMetrics._();

  /// Calories burned per step per kg for "slow walking" (2.8 MET).
  ///
  /// Based on: Calories = MET * 3.5 * Weight(kg) * Time(min) / 200
  /// and an empirical mapping from steps→time used by the product spec:
  /// - slow (2.8 MET): `Weight × 0.00049 × Steps`
  static const double kcalPerStepPerKgSlow = 0.00049;

  /// Returns kcal burned for a given [steps] and [weightKg].
  ///
  /// Uses the slow-walking coefficient only (no speed modes yet),
  /// per product requirements.
  static int kcalFromSteps({
    required int steps,
    required int weightKg,
  }) {
    final safeSteps = steps < 0 ? 0 : steps;
    final safeWeight = weightKg <= 0 ? 0 : weightKg;
    final kcal = safeWeight * kcalPerStepPerKgSlow * safeSteps;
    return kcal.round();
  }
}

