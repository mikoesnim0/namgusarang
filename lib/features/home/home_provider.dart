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

  /// Admin(mission_instances)가 정의한 목표 걸음수로 갱신한다.
  /// 같은 값이면 무시하여 불필요한 rebuild를 피한다.
  void setGoalSteps(int goalSteps) {
    if (goalSteps <= 0 || goalSteps == state.mission.goalSteps) return;
    final newMission = StepMission(
      title: '오늘 $goalSteps보 걷기',
      goalSteps: goalSteps,
    );
    final stepsCompleted = state.todaySteps >= goalSteps;
    final missions = state.missions
        .map((m) => m.type == MissionType.steps
            ? m.copyWith(isCompleted: stepsCompleted)
            : m)
        .toList();
    state = state.copyWith(mission: newMission, missions: missions);
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
