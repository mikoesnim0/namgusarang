import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

typedef DailyStepsByDay = Map<int, int>;

final monthlyDailyStepsProvider =
    StreamProvider.autoDispose.family<DailyStepsByDay, DateTime>((ref, month) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();

  final start = DateTime(month.year, month.month, 1);
  final nextMonth = DateTime(month.year, month.month + 1, 1);
  final startKey = _yyyyMmDd(start);
  final nextKey = _yyyyMmDd(nextMonth);

  final q = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('daily_steps')
      .orderBy(FieldPath.documentId)
      .startAt([startKey])
      .endBefore([nextKey]);

  return q.snapshots().map((snap) {
    final map = <int, int>{};
    for (final doc in snap.docs) {
      final id = doc.id; // yyyy-MM-dd
      final day = _dayFromKey(id);
      if (day == null) continue;
      final data = doc.data();
      final steps = data['steps'];
      if (steps is int) {
        map[day] = steps;
      } else if (steps is num) {
        map[day] = steps.toInt();
      }
    }
    return map;
  });
});

String _yyyyMmDd(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

int? _dayFromKey(String key) {
  // key = yyyy-MM-dd
  final parts = key.split('-');
  if (parts.length != 3) return null;
  return int.tryParse(parts[2]);
}

