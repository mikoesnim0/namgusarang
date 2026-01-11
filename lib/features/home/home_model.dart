enum MissionType {
  steps,
  visit,
  invite,
  coupon,
}

class StepMission {
  const StepMission({
    required this.title,
    required this.goalSteps,
  });

  final String title;
  final int goalSteps;
}

class MissionItem {
  const MissionItem({
    required this.title,
    required this.type,
    required this.badge,
    required this.isCompleted,
  });

  final String title;
  final MissionType type;
  final String badge; // e.g. "+3,000", "쿠폰", "1회"
  final bool isCompleted;

  MissionItem copyWith({bool? isCompleted}) {
    return MissionItem(
      title: title,
      type: type,
      badge: badge,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class MissionCycle {
  const MissionCycle({
    required this.roundTitle,
    required this.daysLeft,
  });

  final String roundTitle; // e.g. "2회차"
  final int daysLeft; // e.g. 4
}

class HomeState {
  const HomeState({
    required this.todaySteps,
    required this.mission,
    required this.cycle,
    required this.missions,
    required this.milestones,
  });

  final int todaySteps;
  final StepMission mission;
  final MissionCycle cycle;
  final List<MissionItem> missions; // 3~5 items
  final List<int> milestones; // e.g. 1..10 day/mission checkpoints

  double get progress {
    if (mission.goalSteps <= 0) return 0;
    final p = todaySteps / mission.goalSteps;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
  }

  int get remainingSteps {
    final left = mission.goalSteps - todaySteps;
    return left > 0 ? left : 0;
  }

  HomeState copyWith({
    int? todaySteps,
    StepMission? mission,
    MissionCycle? cycle,
    List<MissionItem>? missions,
    List<int>? milestones,
  }) {
    return HomeState(
      todaySteps: todaySteps ?? this.todaySteps,
      mission: mission ?? this.mission,
      cycle: cycle ?? this.cycle,
      missions: missions ?? this.missions,
      milestones: milestones ?? this.milestones,
    );
  }

  static HomeState dummy() {
    const stepMission = StepMission(title: '오늘 5,000보 걷기', goalSteps: 5000);
    const cycle = MissionCycle(roundTitle: '2회차', daysLeft: 4);
    const milestones = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

    // 초기 더미: 오늘 걸음수 기반으로 완료 여부가 바뀌는 항목 1개 + 고정 더미 3개
    const todaySteps = 2866;
    final stepsCompleted = todaySteps >= stepMission.goalSteps;

    final missions = [
      MissionItem(
        title: '오늘 5,000보 걷기',
        type: MissionType.steps,
        badge: '+3,000',
        isCompleted: stepsCompleted,
      ),
      const MissionItem(
        title: '근처 가맹점 방문하기',
        type: MissionType.visit,
        badge: '1회',
        isCompleted: false,
      ),
      const MissionItem(
        title: '친구 초대하기',
        type: MissionType.invite,
        badge: '1명',
        isCompleted: false,
      ),
      const MissionItem(
        title: '쿠폰 사용하기',
        type: MissionType.coupon,
        badge: '쿠폰',
        isCompleted: false,
      ),
    ];

    return HomeState(
      todaySteps: todaySteps,
      mission: stepMission,
      cycle: cycle,
      missions: missions,
      milestones: milestones,
    );
  }
}

