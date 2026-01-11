import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hangookji_namgu/features/home/home_provider.dart';

void main() {
  test('HomeController addSteps increments and clamps at 0', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final initial = container.read(homeControllerProvider);
    expect(initial.todaySteps, greaterThanOrEqualTo(0));

    container.read(homeControllerProvider.notifier).addSteps(100);
    expect(container.read(homeControllerProvider).todaySteps,
        initial.todaySteps + 100);

    container.read(homeControllerProvider.notifier).addSteps(-999999);
    expect(container.read(homeControllerProvider).todaySteps, 0);
  });

  test('HomeState progress caps at 1.0 when goal reached', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(homeControllerProvider.notifier);
    // Force to exceed goal.
    controller.addSteps(100000);
    final state = container.read(homeControllerProvider);
    expect(state.progress, 1.0);
    expect(state.remainingSteps, 0);
  });

  test('Steps mission flips to completed when reaching goal', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final initial = container.read(homeControllerProvider);
    final stepsMissionBefore = initial.missions.firstWhere((m) => m.type.name == 'steps');
    expect(stepsMissionBefore.isCompleted, isFalse);

    // Add enough steps to reach goal.
    final need = initial.mission.goalSteps - initial.todaySteps;
    container.read(homeControllerProvider.notifier).addSteps(need);
    final after = container.read(homeControllerProvider);
    final stepsMissionAfter = after.missions.firstWhere((m) => m.type.name == 'steps');
    expect(stepsMissionAfter.isCompleted, isTrue);
  });
}

