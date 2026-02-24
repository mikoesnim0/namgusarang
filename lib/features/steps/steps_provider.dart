import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import 'health_connect_steps_repository.dart';
import 'steps_repository.dart';

final stepsRepositoryProvider = Provider<StepsRepository>((ref) {
  return StepsRepository();
});

final healthConnectStepsRepositoryProvider =
    Provider<HealthConnectStepsRepository>((ref) {
  return HealthConnectStepsRepository();
});

final stepsAvailabilityProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(stepsRepositoryProvider).isAvailable();
});

final healthConnectAvailabilityProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(healthConnectStepsRepositoryProvider).isAvailable();
});

final healthConnectPermissionProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  return ref.watch(healthConnectStepsRepositoryProvider).hasStepsPermission();
});

final stepsPermissionStatusProvider =
    FutureProvider.autoDispose<StepsPermissionStatus>((ref) {
  return ref.watch(stepsRepositoryProvider).getPermissionStatus();
});

final sensorTodayStepsProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(stepsRepositoryProvider).watchTodaySteps();
});

/// Health Connect today steps provider
/// Returns:
/// - null: Health Connect not available or permission denied
/// - 0+: Actual step count (0 means no steps today)
final healthConnectTodayStepsProvider = StreamProvider.autoDispose<int?>((ref) {
  final repo = ref.watch(healthConnectStepsRepositoryProvider);

  return Stream<int?>.multi((controller) async {
    StreamSubscription<int>? sub;

    try {
      final available = await repo.isAvailable();
      final permitted = available && await repo.hasStepsPermission();
      if (!available || !permitted) {
        // CRITICAL FIX: Return null to distinguish "no permission" from "0 steps"
        controller.add(null);
        return;
      }

      sub = repo.watchTodayStepsTotal().listen(
            (steps) => controller.add(steps),
            onError: (_) => controller.add(null), // Error = null
          );
    } catch (_) {
      controller.add(null);
    }

    controller.onCancel = () async {
      await sub?.cancel();
    };
  }).distinct();
});

final todayStepsProvider = StreamProvider.autoDispose<int>((ref) {
  // Fuse:
  // - Use Health Connect totals when available (accurate even if the app was closed).
  // - Use sensor stream for quick real-time updates while the app is open.
  // - Ensure monotonic non-decreasing steps in UI.
  // - IMPORTANT: Allow reset on date change or large decrease (reboot/midnight).
  final sensorStream = ref.watch(sensorTodayStepsProvider.stream);
  final hcStream = ref.watch(healthConnectTodayStepsProvider.stream);

  return Stream<int>.multi((controller) async {
    StreamSubscription<int>? sensorSub;
    StreamSubscription<int?>? hcSub;

    var latestSensor = 0;
    var latestHc = 0;
    var lastEmitted = 0;
    var lastEmittedDate = DateTime.now();

    void emit() {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastDate = DateTime(
        lastEmittedDate.year,
        lastEmittedDate.month,
        lastEmittedDate.day,
      );

      // Date changed → reset counter (midnight crossed)
      if (today != lastDate) {
        lastEmitted = 0;
        lastEmittedDate = now;
      }

      final candidate = (latestSensor > latestHc) ? latestSensor : latestHc;

      // Large decrease detection: if candidate dropped by more than 1000 steps,
      // assume it's a legitimate reset (reboot, sensor reset, etc.)
      if (candidate + 1000 < lastEmitted) {
        lastEmitted = 0;
      }

      // Monotonic: only emit if increased (or reset occurred)
      final next = (candidate > lastEmitted) ? candidate : lastEmitted;
      if (next == lastEmitted) return;

      lastEmitted = next;
      lastEmittedDate = now;
      controller.add(next);
    }

    // Emit 0 initially to stabilize UI.
    controller.add(0);

    sensorSub = sensorStream.listen((v) {
      latestSensor = v;
      emit();
    }, onError: (_) {});

    hcSub = hcStream.listen((v) {
      // CRITICAL FIX: Handle null from Health Connect (permission denied)
      // null = no permission/not available → treat as 0 for sensor fallback
      latestHc = v ?? 0;
      emit();
    }, onError: (_) {});

    controller.onCancel = () async {
      await sensorSub?.cancel();
      await hcSub?.cancel();
    };
  }).distinct();
});
