import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'steps_provider.dart';

final stepsSyncControllerProvider =
    AutoDisposeNotifierProvider<StepsSyncController, void>(
  StepsSyncController.new,
);

class StepsSyncController extends AutoDisposeNotifier<void> {
  Timer? _debounceTimer;
  int? _pendingSteps;
  int? _lastSentSteps;
  DateTime? _lastSentAt;

  @override
  void build() {
    ref.listen<AsyncValue<int>>(todayStepsProvider, (_, next) {
      final steps = next.valueOrNull;
      if (steps == null) return;
      _scheduleSync(steps);
    });

    ref.onDispose(() {
      _debounceTimer?.cancel();
      _debounceTimer = null;
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
    } catch (_) {
      // Best-effort sync only.
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

  Future<void> _upsertSteps(User user, int todaySteps) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    await ref.set(
      {
        'todaySteps': todaySteps,
        'lastStepUpdateAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
