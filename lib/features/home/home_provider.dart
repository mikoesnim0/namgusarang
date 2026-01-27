import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_model.dart';

final homeControllerProvider =
    NotifierProvider<HomeController, HomeState>(HomeController.new);

class HomeController extends Notifier<HomeState> {
  @override
  HomeState build() {
    return HomeState.dummy();
  }

  void setTodaySteps(int steps) {
    final clamped = steps < 0 ? 0 : steps;
    final stepsCompleted = clamped >= state.mission.goalSteps;
    final missions = state.missions
        .map((m) => m.type == MissionType.steps
            ? m.copyWith(isCompleted: stepsCompleted)
            : m)
        .toList();
    state = state.copyWith(todaySteps: clamped, missions: missions);
  }

  void addSteps(int delta) {
    final next = (state.todaySteps + delta);
    final clamped = next < 0 ? 0 : next;
    final stepsCompleted = clamped >= state.mission.goalSteps;
    final missions = state.missions
        .map((m) => m.type == MissionType.steps
            ? m.copyWith(isCompleted: stepsCompleted)
            : m)
        .toList();
    state = state.copyWith(todaySteps: clamped, missions: missions);
  }

  void resetToday() {
    state = state.copyWith(todaySteps: 0);
  }

  void completeMission(MissionType type) {
    final missions = state.missions
        .map((m) => m.type == type ? m.copyWith(isCompleted: true) : m)
        .toList();
    state = state.copyWith(missions: missions);
  }
}
