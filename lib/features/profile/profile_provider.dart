import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../coupons/coupons_provider.dart';
import '../settings/settings_provider.dart';
import '../auth/auth_providers.dart';
import '../steps/step_metrics.dart';
import 'profile_model.dart';

String _yyyyMmDd(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

DateTime _localDate(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _cycleStartFromUserDoc(Map<String, dynamic>? userDoc) {
  final startStr = (userDoc?['cycleStartDate'] as String?)?.trim();
  final parsed =
      (startStr != null && startStr.isNotEmpty) ? DateTime.tryParse(startStr) : null;
  if (parsed != null) return _localDate(parsed);
  return _localDate(DateTime.now());
}

bool _isYyyyMmDdKey(String s) {
  // Strictly match `yyyy-MM-dd` so we don't accidentally sum malformed legacy ids.
  // (Monthly calendar grid also ignores non-matching keys.)
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s);
}

final cycleStepsSumProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();

  final userDoc = ref.watch(currentUserDocProvider).valueOrNull;
  final start = _cycleStartFromUserDoc(userDoc);
  final end = start.add(const Duration(days: 9));

  final startKey = _yyyyMmDd(start);
  final nextKey = _yyyyMmDd(end.add(const Duration(days: 1)));

  final q = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('daily_steps')
      .orderBy(FieldPath.documentId)
      .startAt([startKey])
      .endBefore([nextKey]);

  return q.snapshots().map((snap) {
    var sum = 0;
    for (final doc in snap.docs) {
      if (!_isYyyyMmDdKey(doc.id)) continue;
      final steps = doc.data()['steps'];
      if (steps is int) {
        sum += steps;
      } else if (steps is num) {
        sum += steps.round();
      }
    }
    return sum;
  });
});

final totalStepsSumProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();

  final q = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('daily_steps')
      .orderBy(FieldPath.documentId);

  return q.snapshots().map((snap) {
    var sum = 0;
    for (final doc in snap.docs) {
      if (!_isYyyyMmDdKey(doc.id)) continue;
      final steps = doc.data()['steps'];
      if (steps is int) {
        sum += steps;
      } else if (steps is num) {
        sum += steps.round();
      }
    }
    return sum;
  });
});

final personalStatsProvider = Provider<PersonalStats>((ref) {
  final coupons = ref.watch(couponsStreamProvider).valueOrNull ?? const [];
  ref.watch(settingsControllerProvider);
  final userDoc = ref.watch(currentUserDocProvider).valueOrNull;

  final cycleStart = _cycleStartFromUserDoc(userDoc);
  final cycleEnd = cycleStart.add(const Duration(days: 9));

  final cycleSteps = ref.watch(cycleStepsSumProvider).valueOrNull ?? 0;
  final totalSteps = ref.watch(totalStepsSumProvider).valueOrNull ?? 0;

  final weightKg = (userDoc?['weightKg'] is num)
      ? (userDoc?['weightKg'] as num).round()
      : 70; // fallback for legacy users

  // Calories: keep consistent with Home/Walker.
  final cycleCaloriesKcal = StepMetrics.kcalFromSteps(
    steps: cycleSteps,
    weightKg: weightKg,
  );
  final totalDistanceKm =
      totalSteps * 0.0007985; // ≈136.53km when totalSteps=170,943
  final totalCaloriesKcal = StepMetrics.kcalFromSteps(
    steps: totalSteps,
    weightKg: weightKg,
  );

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
