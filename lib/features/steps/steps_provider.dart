import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'steps_repository.dart';

final stepsRepositoryProvider = Provider<StepsRepository>((ref) {
  return StepsRepository();
});

final stepsPermissionStatusProvider =
    FutureProvider.autoDispose<StepsPermissionStatus>((ref) {
  return ref.watch(stepsRepositoryProvider).getPermissionStatus();
});

final todayStepsProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(stepsRepositoryProvider).watchTodaySteps();
});

