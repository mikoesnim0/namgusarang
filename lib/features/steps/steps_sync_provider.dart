import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'steps_provider.dart';

// Optional: Add firebase_crashlytics to pubspec.yaml for production error tracking
// import 'package:firebase_crashlytics/firebase_crashlytics.dart';

final stepsSyncControllerProvider = NotifierProvider<StepsSyncController, void>(
  StepsSyncController.new,
);

class StepsSyncController extends Notifier<void> {
  Timer? _debounceTimer;
  Timer? _heartbeatTimer;
  int? _pendingSteps;
  int? _latestSteps;
  int? _lastSentSteps;
  DateTime? _lastSentAt;

  @override
  void build() {
    ref.listen<AsyncValue<int>>(todayStepsProvider, (_, next) {
      final steps = next.valueOrNull;
      if (steps == null) return;
      _latestSteps = steps;
      _scheduleSync(steps);
    });

    // Some devices/providers can stop emitting when the step count doesn't
    // change. Keep a low-frequency heartbeat so today's `daily_steps` keeps
    // getting persisted while the app is running.
    _heartbeatTimer ??= Timer.periodic(const Duration(minutes: 5), (_) {
      final steps = _latestSteps;
      if (steps == null) return;
      _scheduleSync(steps);
    });

    ref.onDispose(() {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    });
  }

  void _scheduleSync(int steps) {
    _pendingSteps = steps;
    // Throttle: flush at most once per 15s, always sending the latest value.
    if (_debounceTimer != null) return;
    _debounceTimer = Timer(const Duration(seconds: 15), _flush);
  }

  Future<void> _flush() async {
    final steps = _pendingSteps;
    _pendingSteps = null;
    _debounceTimer = null;
    if (steps == null) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    if (_shouldSkip(steps)) return;

    try {
      await _upsertSteps(user, steps);
      _lastSentSteps = steps;
      _lastSentAt = DateTime.now();
    } catch (e) {
      // CRITICAL FIX: Log sync failures for debugging
      debugPrint('[StepsSync] Failed to sync $steps steps for ${user.uid}: $e');

      // Optional: Uncomment if firebase_crashlytics is added to pubspec.yaml
      // FirebaseCrashlytics.instance.recordError(
      //   e,
      //   StackTrace.current,
      //   reason: 'Steps sync failed: $steps steps for ${user.uid}',
      //   fatal: false,
      // );

      // Best-effort sync only - will retry on next heartbeat (5min) or step change
    }

    final pending = _pendingSteps;
    if (pending != null && _debounceTimer == null) {
      _debounceTimer = Timer(const Duration(seconds: 15), _flush);
    }
  }

  bool _shouldSkip(int steps) {
    final lastAt = _lastSentAt;
    final lastSteps = _lastSentSteps;
    if (lastAt == null || lastSteps == null) return false;

    final elapsed = DateTime.now().difference(lastAt);
    final delta = (steps - lastSteps).abs();

    // Avoid spamming Firestore: send at most once per 30s unless the change is big.
    if (elapsed < const Duration(seconds: 30) && delta < 50) return true;
    return false;
  }

  static String _yyyyMmDd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _upsertSteps(User user, int todaySteps) async {
    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(user.uid);
    final now = DateTime.now().toLocal();
    final localDay = DateTime(now.year, now.month, now.day);
    final dayKey = _yyyyMmDd(localDay);
    final dailyRef = userRef.collection('daily_steps').doc(dayKey);

    final batch = db.batch();
    batch.set(userRef, {
      'todaySteps': todaySteps,
      'lastStepUpdateAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(dailyRef, {
      'date': dayKey,
      'steps': todaySteps,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }
}
