import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

class HealthConnectStepsRepository {
  HealthConnectStepsRepository({Health? health}) : _health = health ?? Health();

  final Health _health;
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    if (!defaultTargetPlatform.isAndroid) return false;
    try {
      await _ensureConfigured();
      return await _health.isHealthConnectAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasStepsPermission() async {
    try {
      await _ensureConfigured();
      final ok = await _health.hasPermissions([HealthDataType.STEPS]);
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestStepsPermission() async {
    try {
      await _ensureConfigured();
      final ok = await _health.requestAuthorization([HealthDataType.STEPS]);
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<int?> getTotalStepsForToday() async {
    if (!await isAvailable()) return null;
    if (!await hasStepsPermission()) return null;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = now;
    return getTrustedStepsInInterval(start: start, end: end);
  }

  /// "Trusted" steps sum based on raw Health Connect records.
  ///
  /// Why this exists:
  /// - Aggregates are fast but opaque (may include manual or unwanted sources).
  /// - Raw records provide `recordingMethod` and `sourceId` so we can filter.
  ///
  /// Currently we only filter out `RecordingMethod.manual` by default.
  /// You can optionally provide [allowedSourceIds] (package names) to restrict
  /// to known sources (e.g., Samsung Health / Google Fit).
  Future<int?> getTrustedStepsInInterval({
    required DateTime start,
    required DateTime end,
    Set<String>? allowedSourceIds,
  }) async {
    if (!await isAvailable()) return null;
    if (!await hasStepsPermission()) return null;
    try {
      final points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.STEPS],
        startTime: start,
        endTime: end,
        recordingMethodsToFilter: const [RecordingMethod.manual],
      );

      var sum = 0;
      for (final p in points) {
        if (p.type != HealthDataType.STEPS) continue;
        if (allowedSourceIds != null &&
            allowedSourceIds.isNotEmpty &&
            !allowedSourceIds.contains(p.sourceId)) {
          continue;
        }

        final v = p.value;
        if (v is NumericHealthValue) {
          sum += v.numericValue.round();
        }
      }
      return sum < 0 ? 0 : sum;
    } catch (_) {
      // Fallback to aggregate if raw query fails on some devices.
      try {
        final total = await _health.getTotalStepsInInterval(start, end);
        return total;
      } catch (_) {
        return null;
      }
    }
  }

  Future<Map<String, int>> getDailyTotals({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    if (!await isAvailable()) return const {};
    if (!await hasStepsPermission()) return const {};

    final results = <String, int>{};
    var cursor = DateTime(
      startInclusive.year,
      startInclusive.month,
      startInclusive.day,
    );
    final end = DateTime(endExclusive.year, endExclusive.month, endExclusive.day);

    while (cursor.isBefore(end)) {
      final next = cursor.add(const Duration(days: 1));
      final total = await getTrustedStepsInInterval(start: cursor, end: next);
      if (total != null && total > 0) {
        results[_yyyyMmDd(cursor)] = total;
      }
      cursor = next;
    }
    return results;
  }

  Stream<int> watchTodayStepsTotal({
    Duration pollInterval = const Duration(seconds: 20),
  }) async* {
    // Yield once quickly, then poll.
    while (true) {
      final value = await getTotalStepsForToday();
      yield value ?? 0;
      await Future<void>.delayed(pollInterval);
    }
  }

  static String _yyyyMmDd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

extension on TargetPlatform {
  bool get isAndroid => this == TargetPlatform.android;
}
