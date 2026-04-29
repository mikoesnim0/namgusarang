import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'steps_provider.dart';

final healthConnectBackfillControllerProvider =
    NotifierProvider<HealthConnectBackfillController, void>(
  HealthConnectBackfillController.new,
);

class HealthConnectBackfillController extends Notifier<void> {
  bool _isRunning = false;

  @override
  void build() {
    // no-op
  }

  Future<void> backfillMonth(DateTime month) async {
    if (_isRunning) return;
    _isRunning = true;
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) return;

      final repo = ref.read(healthConnectStepsRepositoryProvider);
      final available = await repo.isAvailable();
      if (!available) return;
      final permitted = await repo.hasStepsPermission();
      if (!permitted) return;

      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 1);

      final totals = await repo.getDailyTotals(
        startInclusive: start,
        endExclusive: end,
      );

      if (totals.isEmpty) return;

      final db = FirebaseFirestore.instance;
      final userRef = db.collection('users').doc(user.uid);

      final batch = db.batch();
      for (final entry in totals.entries) {
        final dayKey = entry.key; // yyyy-MM-dd
        final steps = entry.value;
        final dailyRef = userRef.collection('daily_steps').doc(dayKey);
        batch.set(dailyRef, {
          'date': dayKey,
          'steps': steps,
          'source': 'health_connect',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } finally {
      _isRunning = false;
    }
  }
}

