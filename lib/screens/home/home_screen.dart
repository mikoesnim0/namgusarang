import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';
import 'dart:math' as math;

import '../../features/foods/food_equivalents.dart';
import '../../features/home/home_model.dart';
import '../../features/home/home_provider.dart';
import '../../features/coupons/coupons_provider.dart';
import '../../features/missions/missions_provider.dart';
import '../../features/places/place.dart';
import '../../features/places/places_provider.dart';
import '../../features/steps/steps_provider.dart';
import '../../features/steps/steps_repository.dart';
import '../../features/steps/steps_sync_provider.dart';
import '../../features/steps/step_metrics.dart';
import '../../features/settings/settings_provider.dart';
import '../../features/auth/auth_providers.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/place_info_popup.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  // Temporary: hide "오늘 할 일" and debug actions during the release.
  // Flip to false after launch.
  static const bool _hideTodoAndDebugUi = true;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _didScheduleIntroDialog = false;
  String? _introForUid;

  // PRD 07_미션_관리: 10일 중 3일 이상 달성 시 쿠폰 1장.
  // 회차/목표일수는 Admin의 MissionInstance가 앱에 연동되면 그 값으로 대체된다.
  static const int _cycleCouponThresholdDays = 3;

  // 동일 회차에서 쿠폰 발급 다이얼로그가 중복으로 뜨는 것을 방지하기 위한 플래그.
  int? _lastCouponIssuedCycleIndex;

  String _fmtDate(DateTime d) {
    final yy = (d.year % 100).toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yy.$mm.$dd';
  }

  String _fmtTodayLabel(DateTime d) => '오늘 ${_fmtDate(d)}';

  String _yyyyMmDd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  DateTime _localDate(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<int>>(todayStepsProvider, (_, next) {
      final steps = next.valueOrNull;
      if (steps == null) return;
      ref.read(homeControllerProvider.notifier).setTodaySteps(steps);
    });

    ref.watch(stepsSyncControllerProvider);

    // Admin 이 운영하는 활성 미션 + 쿠폰 정책을 읽어 하드코딩 값을 대체한다.
    // 아직 서버 설정이 없으면 fallback 으로 기존 상수 (5000보/3일/10일) 를 사용한다.
    final activeMission = ref.watch(activeMissionProvider).valueOrNull;
    final mission = activeMission?.mission;
    final serverTargetSteps = mission?.targetSteps ?? 5000;
    final serverTargetDays = mission?.targetDays ?? _cycleCouponThresholdDays;
    final serverDurationDays = mission?.durationDays ?? 10;

    // 미션의 목표 걸음수가 바뀌면 HomeController 상태에 반영.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(homeControllerProvider.notifier)
          .setGoalSteps(serverTargetSteps);
    });

    final home = ref.watch(homeControllerProvider);
    final settingsAsync = ref.watch(settingsControllerProvider);
    final userDoc = ref.watch(currentUserDocProvider).valueOrNull;
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final authUid = authUser?.uid;
    final settingsNickname = settingsAsync.valueOrNull?.profile.nickname;
    final docNickname = (userDoc?['nickname'] as String?)?.trim();
    final authNickname = authUser?.displayName?.trim();
    final nickname = (docNickname?.isNotEmpty == true)
        ? docNickname!
        : (authNickname?.isNotEmpty == true)
        ? authNickname!
        : (settingsNickname?.trim().isNotEmpty == true)
        ? settingsNickname!.trim()
        : '닉네임';

    final now = DateTime.now();
    final todayLocal = _localDate(now);
    final todayStr = _yyyyMmDd(todayLocal);

    // 회차 길이(durationDays)는 Admin 설정을 따른다. 서버 값을 못 읽으면 10일.
    final cycleStartStr = (userDoc?['cycleStartDate'] as String?)?.trim();
    final cycleStartDate = (cycleStartStr != null && cycleStartStr.isNotEmpty)
        ? DateTime.tryParse(cycleStartStr)
        : null;
    final cycleStartLocal = cycleStartDate != null
        ? _localDate(cycleStartDate)
        : todayLocal;
    final rawDayIndex = todayLocal.difference(cycleStartLocal).inDays + 1;
    final dayIndex = rawDayIndex.clamp(1, serverDurationDays);
    final isCycleOver = rawDayIndex > serverDurationDays;

    final cycleIndex = (userDoc?['cycleIndex'] is num)
        ? (userDoc?['cycleIndex'] as num).round().clamp(1, 9999)
        : 1;

    final completedDaysRaw =
        (userDoc?['cycleCompletedDays'] as List?) ?? const [];
    final completedDays =
        completedDaysRaw
            .map((e) => (e is num) ? e.round() : int.tryParse(e.toString()))
            .whereType<int>()
            .where((d) => d >= 1 && d <= serverDurationDays)
            .toSet()
            .toList()
          ..sort();

    final failedDaysRaw = (userDoc?['cycleFailedDays'] as List?) ?? const [];
    final failedDays =
        failedDaysRaw
            .map((e) => (e is num) ? e.round() : int.tryParse(e.toString()))
            .whereType<int>()
            .where((d) => d >= 1 && d <= serverDurationDays)
            .toSet()
            .toList()
          ..sort();

    final daysLeft = (serverDurationDays - rawDayIndex).clamp(0, serverDurationDays);
    final cycleStart = isCycleOver ? todayLocal : cycleStartLocal;
    final cycleEnd = cycleStart.add(Duration(days: serverDurationDays - 1));
    final cycleRange = '${_fmtDate(cycleStart)} ~ ${_fmtDate(cycleEnd)}';
    final todayLabel = _fmtTodayLabel(todayLocal);
    final todayIndex = dayIndex;
    final weightKg = (userDoc?['weightKg'] is num)
        ? (userDoc?['weightKg'] as num).round()
        : 70;

    // Ensure cycle exists / rolls over automatically (once per day).
    if (authUid != null &&
        (userDoc?['lastCycleCheckDate'] as String?)?.trim() != todayStr) {
      unawaited(
        ref.read(usersRepositoryProvider).ensureCycleReady(
              uid: authUid,
              durationDays: serverDurationDays,
              goalSteps: serverTargetSteps,
            ),
      );
    }

    // Show first-time intro once.
    if (authUid != null && _introForUid != authUid) {
      // New user session mounted in the same shell instance.
      _introForUid = authUid;
      _didScheduleIntroDialog = false;
    }

    if (authUid != null &&
        (userDoc?['introSeen'] != true) &&
        !_didScheduleIntroDialog) {
      _didScheduleIntroDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;
        // Hard guard: show only once per device+user (Firestore can fail in
        // release builds depending on rules/network).
        final prefs = await SharedPreferences.getInstance();
        final prefKey = 'introSeen_v1_$authUid';
        if (prefs.getBool(prefKey) == true) return;
        await prefs.setBool(prefKey, true);

        // Also mark in Firestore for cross-device consistency (best-effort).
        try {
          await ref.read(usersRepositoryProvider).markIntroSeen(uid: authUid);
        } catch (_) {}
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Walker홀릭 시작하기'),
            content: const Text(
              'Walker홀릭은 10일 동안 “걷기 미션”을 진행하고,\n'
              '목표를 달성하면 쿠폰을 발급받아 사용할 수 있는 앱입니다.\n\n'
              '• 오늘의 걸음 수: 목표 달성까지 남은 걸음 확인\n'
              '• 쿠폰함: 발급된 쿠폰 확인/사용\n'
              '• 지도: 쿠폰 사용 가능한 매장 확인\n\n'
              '지금부터 10일 미션을 시작할까요?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('시작'),
              ),
            ],
          ),
        );
      });
    }

    final permissionStatus = ref
        .watch(stepsPermissionStatusProvider)
        .valueOrNull;
    final showTodoAndDebug = !HomeScreen._hideTodoAndDebugUi && !kReleaseMode;

    // PRD 07: 회차 기간 동안 targetDays 이상 달성 시 쿠폰 1장. 임계값/목표 걸음수는
    // Admin(mission_instances) 값을 따른다. 서버 값이 없으면 fallback(5000보/3일).
    ref.listen<HomeState>(homeControllerProvider, (prev, next) {
      if (prev == null) return;
      bool isStepsDone(HomeState s) =>
          s.missions.any((m) => m.type == MissionType.steps && m.isCompleted);
      final wasDone = isStepsDone(prev);
      final nowDone = isStepsDone(next);
      if (wasDone || !nowDone) return;
      if (authUid == null) return;

      () async {
        // PRD 03: 제재/탈퇴요청/리스크 플래그 계정은 쿠폰 발급 시도 자체를 스킵.
        // 서버(claimCycleReward)도 동일 검증을 하지만 UX 상 불필요한 호출을 막는다.
        final userStatus =
            (userDoc?['status'] as String?)?.trim().toLowerCase();
        final riskFlagged = userDoc?['riskFlag'] == true;
        if (userStatus == 'sanctioned' ||
            userStatus == 'withdrawal_requested' ||
            riskFlagged) {
          return;
        }

        final alreadyCompletedToday = completedDays.contains(todayIndex);
        await ref
            .read(usersRepositoryProvider)
            .markCycleDayCompleted(uid: authUid, dayIndex: todayIndex);

        final projected = alreadyCompletedToday
            ? completedDays.length
            : completedDays.length + 1;
        if (projected < serverTargetDays) return;

        if (!context.mounted) return;
        await _issueCouponForCycleAchievement(
          context,
          ref,
          cycleIndex: cycleIndex,
          targetDays: serverTargetDays,
          targetSteps: serverTargetSteps,
        );
      }();
    });

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // Keep enough spacing so the scroll content never sits behind the dock.
    final navHeight = MediaQuery.sizeOf(context).height * (230.0 / 1920.0);
    final bottomPad = (navHeight + bottomInset + 24).clamp(96.0, 320.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _HomeHeader(
            nickname: nickname,
            roundTitle: '$cycleIndex회차',
            daysLeft: daysLeft,
            onProfileTap: () => context.push('/my/info'),
            onSettingsTap: () => context.push('/settings'),
            todayLabel: todayLabel,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingHorizontal,
                12,
                AppSpacing.screenPaddingHorizontal,
                bottomPad,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () async {
                          await showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('가이드'),
                              content: const Text(
                                'Walker홀릭은 “걷기 미션”을 달성하면 쿠폰을 발급받고,\n'
                                '지도에서 쿠폰 사용 가능한 매장을 확인할 수 있는 앱입니다.\n\n'
                                '- 오늘의 걸음 수: 목표 달성까지 남은 걸음 확인\n'
                                '- 쿠폰함: 발급된 쿠폰 확인/사용\n'
                                '- 지도: 쿠폰 사용 가능한 매장 확인\n',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('닫기'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Text(
                          '가이드',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        cycleRange,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => context.push('/my/subscription'),
                        child: Text(
                          '구독관리',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (permissionStatus == StepsPermissionStatus.denied ||
                      permissionStatus == StepsPermissionStatus.restricted) ...[
                    _StepsPermissionCard(
                      onGrant: () async {
                        final ok = await ref
                            .read(stepsRepositoryProvider)
                            .requestPermission();
                        if (!context.mounted) return;
                        ref.invalidate(stepsPermissionStatusProvider);
                        if (ok) ref.invalidate(todayStepsProvider);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  _SuccessDaysCard(
                    milestones: home.milestones,
                    completed: completedDays,
                    failed: failedDays,
                    todayIndex: todayIndex,
                    daysLeft: daysLeft,
                  ),
                  const SizedBox(height: 22),
                  _TodayStepsCard(
                    steps: home.todaySteps,
                    goalSteps: home.mission.goalSteps,
                    remainingSteps: home.remainingSteps,
                    progress: home.progress,
                    weightKg: weightKg,
                  ),
                  const SizedBox(height: 10),
                  // [DEBUG] 걸음수 진단 카드 — 배포 시 비활성화
                  // if (permissionStatus != StepsPermissionStatus.granted ||
                  //     home.todaySteps < 20) ...[
                  //   AppCard(
                  //     padding: const EdgeInsets.all(AppSpacing.paddingMD),
                  //     margin: EdgeInsets.zero,
                  //     child: Column(
                  //       crossAxisAlignment: CrossAxisAlignment.start,
                  //       children: [
                  //         Row(
                  //           children: [
                  //             Text('걸음수 진단', style: AppTypography.labelLarge),
                  //             const Spacer(),
                  //             Text(
                  //               '권한: ${permissionStatus?.name ?? 'unknown'}',
                  //               style: AppTypography.bodySmall.copyWith(
                  //                 color: AppColors.textSecondary,
                  //                 fontWeight: FontWeight.w700,
                  //               ),
                  //             ),
                  //           ],
                  //         ),
                  //         const SizedBox(height: 8),
                  //         Text(
                  //           '걸음수가 안 늘어나면 대시보드에서 센서 상태를 확인하고, 권한을 다시 요청해보세요.',
                  //           style: AppTypography.bodySmall.copyWith(
                  //             color: AppColors.textSecondary,
                  //           ),
                  //         ),
                  //         const SizedBox(height: 12),
                  //         Row(
                  //           children: [
                  //             Expanded(
                  //               child: AppButton(
                  //                 text: '대시보드 열기',
                  //                 variant: ButtonVariant.outline,
                  //                 isFullWidth: true,
                  //                 onPressed: () => context.push('/walker'),
                  //               ),
                  //             ),
                  //             const SizedBox(width: 12),
                  //             Expanded(
                  //               child: AppButton(
                  //                 text: '권한 재요청',
                  //                 variant: ButtonVariant.outline,
                  //                 isFullWidth: true,
                  //                 onPressed: () async {
                  //                   final ok = await ref
                  //                       .read(stepsRepositoryProvider)
                  //                       .requestPermission();
                  //                   if (!context.mounted) return;
                  //                   ref.invalidate(
                  //                     stepsPermissionStatusProvider,
                  //                   );
                  //                   if (ok) ref.invalidate(todayStepsProvider);
                  //                 },
                  //               ),
                  //             ),
                  //           ],
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ],
                  const SizedBox(height: 18),
                  _CouponPlacesMapCard(
                    placesAsync: ref.watch(activePlacesProvider),
                    onOpenFullMap: () => context.push('/map'),
                  ),
                  const SizedBox(height: 12),
                  if (showTodoAndDebug) ...[
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.paddingMD),
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('오늘 할 일', style: AppTypography.labelLarge),
                          const SizedBox(height: AppSpacing.paddingSM),
                          for (var i = 0; i < home.missions.length; i++) ...[
                            _MissionTile(m: home.missions[i]),
                            if (i != home.missions.length - 1)
                              const Divider(height: 16),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.paddingMD),
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('디버그 액션', style: AppTypography.labelLarge),
                          const SizedBox(height: AppSpacing.paddingMD),
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  text: '+100',
                                  variant: ButtonVariant.outline,
                                  onPressed: () => ref
                                      .read(homeControllerProvider.notifier)
                                      .addSteps(100),
                                  isFullWidth: true,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.paddingMD),
                              Expanded(
                                child: AppButton(
                                  text: '+500',
                                  variant: ButtonVariant.outline,
                                  onPressed: () => ref
                                      .read(homeControllerProvider.notifier)
                                      .addSteps(500),
                                  isFullWidth: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.paddingMD),
                          AppButton(
                            text: '지도로 보기 (2차)',
                            variant: ButtonVariant.text,
                            onPressed: () {},
                            isFullWidth: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 회차 미션 달성 시 Cloud Function(`claimCycleReward`)을 호출해 쿠폰을 발급한다.
  /// 쿠폰 발급/검증/사용내역 로그 작성은 모두 서버에서 수행되고, 앱은 결과만 받아
  /// 다이얼로그를 띄운다. 중복 발급은 서버 트랜잭션이 차단한다.
  Future<void> _issueCouponForCycleAchievement(
    BuildContext context,
    WidgetRef ref, {
    required int cycleIndex,
    required int targetDays,
    required int targetSteps,
  }) async {
    // 같은 build 사이클에서 listener가 연속 트리거되는 걸 막는 로컬 가드.
    if (_lastCouponIssuedCycleIndex == cycleIndex) return;
    _lastCouponIssuedCycleIndex = cycleIndex;

    // 쿠폰 사용 가능한 상점 힌트 (서버가 최종 결정. 힌트만 전달).
    final places =
        ref.read(activePlacesProvider).valueOrNull ?? const <Place>[];
    final hintStoreId = places
        .firstWhere(
          (p) => p.hasCoupons && p.useCode.isNotEmpty,
          orElse: () => const Place(id: '', name: '', lat: 0, lng: 0),
        )
        .id;

    final result = await claimCycleReward(
      storeId: hintStoreId.isEmpty ? null : hintStoreId,
    );
    if (!result.ok) {
      // 이미 발급 받았거나(already_issued) 서버 검증 실패 - 조용히 종료.
      // 실패 이유를 디버그 로그 수준에서 남기고 사용자에겐 별도 다이얼로그 없음.
      return;
    }
    if (!context.mounted) return;

    final action = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('축하합니다!'),
        content: Text(
          '$cycleIndex회차 미션 달성!\n'
          '($targetDays일 이상 $targetSteps보 달성)\n\n'
          '쿠폰이 ${result.placeName}에서 사용 가능합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(0),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(1),
            child: const Text('쿠폰 상세'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(2),
            child: const Text('쿠폰함 보기'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    if (action == 1) {
      context.push('/coupons/${result.couponId}');
    } else if (action == 2) {
      context.go('/coupons');
    }
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.nickname,
    required this.roundTitle,
    required this.daysLeft,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.todayLabel,
  });

  final String nickname;
  final String roundTitle;
  final int daysLeft;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;
  final String todayLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.brandTeal, AppColors.brandSky],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingHorizontal,
            vertical: 12,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Text(
                      roundTitle,
                      style: AppTypography.h5.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                    Text(
                      todayLabel,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  onTap: onProfileTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.gray200,
                        child: Icon(
                          Icons.person,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.textOnPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: '설정',
                  onPressed: onSettingsTap,
                  icon: const Icon(
                    Icons.settings,
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DaysLeftCard extends StatelessWidget {
  const _DaysLeftCard({required this.daysLeft});

  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final clamped = daysLeft.clamp(0, 99);
    final text = clamped.toString().padLeft(2, '0');
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Text('이번 미션 종료까지', style: AppTypography.bodyMedium),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DigitBox(digit: text[0]),
              const SizedBox(width: 6),
              _DigitBox(digit: text[1]),
              const SizedBox(width: 6),
              Text('일 남았어요!', style: AppTypography.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _DigitBox extends StatelessWidget {
  const _DigitBox({required this.digit, this.large = false});

  final String digit;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final w = large ? 40.0 : 28.0;
    final h = large ? 50.0 : 36.0;
    final style = large
        ? AppTypography.h5.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 28,
          )
        : AppTypography.h5.copyWith(fontWeight: FontWeight.w700);

    return Container(
      width: w,
      height: h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(digit, style: style),
    );
  }
}

class _SuccessDaysCard extends StatelessWidget {
  const _SuccessDaysCard({
    required this.milestones,
    required this.completed,
    required this.failed,
    required this.todayIndex,
    required this.daysLeft,
  });

  final List<int> milestones;
  final List<int> completed;
  final List<int> failed;
  final int todayIndex;
  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final clamped = daysLeft.clamp(0, 99);
    final text = clamped.toString().padLeft(2, '0');
    const requiredDays = 3;

    return Column(
      children: [
        // ── Countdown (카드 바깥) ──
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '이번 미션 종료까지',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            _DigitBox(digit: text[0], large: true),
            const SizedBox(width: 6),
            _DigitBox(digit: text[1], large: true),
            const SizedBox(width: 10),
            Text(
              '일 남았어요!',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // ── 안내 텍스트 + 데이 서클 (경계 없이, FAFAFA 배경) ──
        Builder(builder: (context) {
          final remaining = (requiredDays - completed.length).clamp(0, requiredDays);
          final label = remaining > 0
              ? '10일 중 $remaining일만 목표에 달성 하면 돼요!'
              : '목표를 모두 달성했어요!';
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.paddingMD,
              vertical: AppSpacing.paddingLG,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            ),
            child: Column(
              children: [
                Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(
                    color: const Color(0xFF757576),
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 8.0;
                    final available = constraints.maxWidth;
                    final size =
                        ((available - spacing * 9) / 10).clamp(28.0, 44.0);

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final n in milestones) ...[
                          _SuccessDayCircle(
                            text: '$n',
                            filled: n <= todayIndex && completed.contains(n),
                            isToday: n == todayIndex,
                            isFuture: n > todayIndex,
                            isFailed: failed.contains(n),
                            size: size,
                          ),
                          if (n != milestones.last)
                            const SizedBox(width: spacing),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _SuccessDayCircle extends StatelessWidget {
  const _SuccessDayCircle({
    required this.text,
    required this.filled,
    required this.isToday,
    required this.isFuture,
    required this.isFailed,
    required this.size,
  });

  final String text;
  final bool filled;
  final bool isToday;
  final bool isFuture;
  final bool isFailed;
  final double size;

  @override
  Widget build(BuildContext context) {
    // ── 색상 결정 (타겟 디자인 기준) ──
    final Color bgColor;
    final Color fgColor;
    final Color borderColor;
    final double borderWidth;

    if (isFailed) {
      bgColor = Colors.red.shade50;
      fgColor = Colors.red.shade700;
      borderColor = Colors.red.shade200;
      borderWidth = 1;
    } else if (filled) {
      // 완료 (오늘 포함): 진한 민트 채움, 흰 글자
      bgColor = AppColors.brandTeal;
      fgColor = Colors.white;
      borderColor = AppColors.brandTeal;
      borderWidth = 0;
    } else if (isToday) {
      // 오늘 (미완료): 민트 테두리, 흰 배경
      bgColor = AppColors.surface;
      fgColor = AppColors.brandTeal;
      borderColor = AppColors.brandTeal;
      borderWidth = 2;
    } else if (isFuture) {
      // 미래: 밝은 회색
      bgColor = AppColors.gray100;
      fgColor = AppColors.gray400;
      borderColor = AppColors.gray100;
      borderWidth = 0;
    } else {
      // 과거 미완료: 중간 회색
      bgColor = AppColors.gray200;
      fgColor = AppColors.textSecondary;
      borderColor = AppColors.gray200;
      borderWidth = 0;
    }

    final fontSize = size > 34 ? 14.0 : 11.0;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: borderWidth > 0
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
      ),
      child: Text(
        isFailed ? '✕' : text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: fgColor,
        ),
      ),
    );
  }
}

class _TodayStepsCard extends StatelessWidget {
  const _TodayStepsCard({
    required this.steps,
    required this.goalSteps,
    required this.remainingSteps,
    required this.progress,
    required this.weightKg,
  });

  final int steps;
  final int goalSteps;
  final int remainingSteps;
  final double progress;
  final int weightKg;

  @override
  Widget build(BuildContext context) {
    final kcal = StepMetrics.kcalFromSteps(steps: steps, weightKg: weightKg);
    final km = steps * 0.00023;
    final percent = progress * 100;
    final foodEquivalent = suggestFoodEquivalentForKcal(kcal);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Text('오늘의 걸음 수', style: AppTypography.labelLarge)),
          const SizedBox(height: 4),
          Center(
            child: Text(
              remainingSteps == 0
                  ? '목표 달성!'
                  : '${_comma(remainingSteps)}보 더 걸으면 목표 달성!',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primary500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _StepProgressBar(
            steps: steps,
            goalSteps: goalSteps,
            progress: progress,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (foodEquivalent != null && kcal > 0) ...[
                      _SmallFoodEquivalentLine(foodEquivalent),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      '${kcal}kcal/${km.toStringAsFixed(2)}km',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '달성률 ',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${percent.toStringAsFixed(2)}%',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primary500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({
    required this.steps,
    required this.goalSteps,
    required this.progress,
  });

  final int steps;
  final int goalSteps;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0);
    const height = 36.0;
    final radius = height / 2;

    // UX rules:
    // - Before walking starts (< 20 steps): gray bar + black shoe icon.
    // - After walking starts (>= 20): green fill + shoe icon inside the fill.
    // - Avoid overlap: until 1500 steps, show the step count to the right of the shoe.
    //   After that, keep the current style (step count pinned at the left).
    final isStarted = steps >= 20;
    final showStepsOnLeft = steps >= 1500;
    final shoe = isStarted
        ? Image.asset(
            'assets/icons/shoe.png',
            width: 18,
            height: 18,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.directions_walk,
              size: 18,
              color: Colors.white,
            ),
          )
        : const Icon(
            Icons.directions_walk,
            size: 18,
            color: AppColors.textSecondary,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        final fillW = math.max(height, totalW * (isStarted ? safeProgress : 0));
        final iconLeft = (fillW - 18 - 12).clamp(12.0, totalW - 18 - 12);
        final stepsText = _comma(steps);
        final stepsTextStyle = AppTypography.bodyMedium.copyWith(
          color: isStarted ? Colors.white : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        );

        final stepsPainter = TextPainter(
          text: TextSpan(text: stepsText, style: stepsTextStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: totalW);
        final stepsTextW = stepsPainter.width;

        final stepsRightOfShoeLeft = (iconLeft + 18 + 8)
            .clamp(12.0, totalW - stepsTextW - 12.0)
            .toDouble();

        return Stack(
          children: [
            Container(
              height: height,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(radius),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '매일 ${_comma(goalSteps)}보 걷기',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: fillW,
                  height: height,
                  decoration: BoxDecoration(
                    color: isStarted ? AppColors.primary500 : AppColors.gray200,
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
              ),
            ),
            if (showStepsOnLeft)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(stepsText, style: stepsTextStyle),
                ),
              )
            else
              Positioned(
                left: stepsRightOfShoeLeft,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    stepsText,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: iconLeft,
              top: 0,
              bottom: 0,
              child: Align(alignment: Alignment.centerLeft, child: shoe),
            ),
          ],
        );
      },
    );
  }
}

class _SmallFoodEquivalentLine extends StatelessWidget {
  const _SmallFoodEquivalentLine(this.result);

  final FoodEquivalentResult result;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          result.food.iconAssetPath,
          width: 14,
          height: 14,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.restaurant,
            size: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${result.food.nameKr} × ${result.servings}',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CouponPlacesMapCard extends StatelessWidget {
  const _CouponPlacesMapCard({
    required this.placesAsync,
    required this.onOpenFullMap,
  });

  final AsyncValue<List<Place>> placesAsync;
  final VoidCallback onOpenFullMap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('쿠폰 사용 가능한 매장 표시', style: AppTypography.bodySmall),
              const Spacer(),
              TextButton(
                onPressed: onOpenFullMap,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary500,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                ),
                child: const Text('지도 크게 보기'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              child: placesAsync.when(
                data: (places) => _PlacesMiniMap(places: places),
                loading: () => Container(
                  color: AppColors.gray100,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                ),
                error: (e, _) => Container(
                  color: AppColors.gray100,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(AppSpacing.paddingMD),
                  child: Text(
                    'places 로드 실패: $e',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlacesMiniMap extends ConsumerStatefulWidget {
  const _PlacesMiniMap({required this.places});

  final List<Place> places;

  @override
  ConsumerState<_PlacesMiniMap> createState() => _PlacesMiniMapState();
}

class _PlacesMiniMapState extends ConsumerState<_PlacesMiniMap> {
  NaverMapController? _controller;
  String _lastSignature = '';
  bool _isRequestingLocation = false;
  NOverlayImage? _placeMarkerIcon;
  Place? _selectedPlace;
  bool _didAutoLocate = false;

  Future<void> _zoomIn() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.updateCamera(NCameraUpdate.zoomIn());
  }

  Future<void> _zoomOut() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.updateCamera(NCameraUpdate.zoomOut());
  }

  @override
  void didUpdateWidget(covariant _PlacesMiniMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMarkers();
  }

  Future<void> _syncMarkers() async {
    final controller = _controller;
    if (controller == null) return;

    final signature = widget.places.map((p) => p.id).join('|');
    if (signature == _lastSignature) return;
    _lastSignature = signature;

    await controller.clearOverlays(type: NOverlayType.marker);

    _placeMarkerIcon ??= await _buildPlaceMarkerIcon(context);

    final overlays = <NAddableOverlay>{};
    for (final p in widget.places) {
      if (!p.hasCoupons) continue; // MVP: only show coupon-enabled stores.
      final marker = NMarker(
        id: p.id,
        position: NLatLng(p.lat, p.lng),
        icon: _placeMarkerIcon,
        anchor: NPoint.relativeCenter,
        // Design spec was measured on a 1080px-wide device (typically ~3.0 DPR -> 360dp).
        // Convert physical px -> logical px (dp) so it looks consistent across devices.
        size: const Size(49 / 3.0, 49 / 3.0),
        caption: NOverlayCaption(text: p.name),
      );
      marker.setOnTapListener((_) {
        if (!mounted) return;
        setState(() => _selectedPlace = p);
      });
      overlays.add(marker);
    }
    if (overlays.isNotEmpty) {
      await controller.addOverlayAll(overlays);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    final target = widget.places.isNotEmpty
        ? NLatLng(widget.places.first.lat, widget.places.first.lng)
        : const NLatLng(35.1595, 129.0756);

    return Stack(
      children: [
        NaverMap(
          options: NaverMapViewOptions(
            // We use an explicit consent flow before requesting location permission.
            locationButtonEnable: false,
            initialCameraPosition: NCameraPosition(target: target, zoom: 14),
          ),
          onMapReady: (controller) async {
            _controller = controller;
            await _syncMarkers();
            if (!_didAutoLocate && mounted) {
              _didAutoLocate = true;
              await _handleMyLocationTap(context);
            }
          },
        ),
        if (_selectedPlace != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 56 + safeBottom,
            child: ref
                .watch(placeCouponsProvider(_selectedPlace!.id))
                .when(
                  data: (coupons) => PlaceInfoPopup(
                    place: _selectedPlace!,
                    coupons: coupons
                        .where((c) => c.isActive)
                        .map((c) => c.title)
                        .toList(),
                    onClose: () => setState(() => _selectedPlace = null),
                  ),
                  loading: () => PlaceInfoPopup(
                    place: _selectedPlace!,
                    coupons: const [],
                    onClose: () => setState(() => _selectedPlace = null),
                  ),
                  error: (_, __) => PlaceInfoPopup(
                    place: _selectedPlace!,
                    coupons: const [],
                    onClose: () => setState(() => _selectedPlace = null),
                  ),
                ),
          ),
        Positioned(
          right: 12,
          bottom: 12 + safeBottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _MiniMapControlButton(icon: Icons.add, onPressed: _zoomIn),
              const SizedBox(height: 8),
              _MiniMapControlButton(icon: Icons.remove, onPressed: _zoomOut),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _isRequestingLocation
                    ? null
                    : () => _handleMyLocationTap(context),
                icon: const Icon(Icons.my_location, size: 18),
                label: const Text('현 위치'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.paddingMD,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleMyLocationTap(BuildContext context) async {
    setState(() => _isRequestingLocation = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        await Geolocator.openLocationSettings();
      }

      var perm = await Geolocator.checkPermission();

      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.deniedForever) {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('위치 기능 안내'),
            content: const Text('현재 위치 표시 기능을 사용하려면\n설정에서 위치 접근을 활성화할 수 있습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
              TextButton(
                onPressed: () async {
                  await Geolocator.openAppSettings();
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
                child: const Text('설정 열기'),
              ),
            ],
          ),
        );
        return;
      }

      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final controller = _controller;
      if (controller == null) return;

      await _setMyLocationOverlay(
        controller,
        NLatLng(pos.latitude, pos.longitude),
      );

      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(pos.latitude, pos.longitude),
          zoom: 15,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRequestingLocation = false);
    }
  }

  Future<void> _setMyLocationOverlay(
    NaverMapController controller,
    NLatLng position,
  ) async {
    final overlay = controller.getLocationOverlay();
    // Use the native accuracy circle as a small "red dot" to avoid
    // any custom image rendering issues in the mini-map.
    overlay.setIconAlpha(0);
    overlay.setSubIconAlpha(0);
    overlay.setAnchor(NPoint.relativeCenter);
    overlay.setCircleColor(Colors.red.shade600);
    overlay.setCircleRadius(6);
    overlay.setCircleOutlineColor(Colors.white);
    overlay.setCircleOutlineWidth(2);
    overlay.setIsVisible(true);
    overlay.setPosition(position);
  }

  Future<NOverlayImage> _buildPlaceMarkerIcon(BuildContext context) async {
    return NOverlayImage.fromWidget(
      context: context,
      // 49px/31px are physical pixels @ ~3.0 DPR.
      size: const Size(49 / 3.0, 49 / 3.0),
      widget: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring: 49px, 47% opacity (#10C4AE @ 0.47)
          Container(
            width: 49 / 3.0,
            height: 49 / 3.0,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x7810C4AE), // ~47% alpha
            ),
          ),
          // Inner dot: 31px, solid #10C4AE
          Container(
            width: 31 / 3.0,
            height: 31 / 3.0,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF10C4AE),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMapControlButton extends StatelessWidget {
  const _MiniMapControlButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Icon(
              icon,
              size: 22,
              color: enabled ? Colors.black87 : Colors.black26,
            ),
          ),
        ),
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.m});

  final MissionItem m;

  @override
  Widget build(BuildContext context) {
    final icon = switch (m.type) {
      MissionType.steps => Icons.directions_walk,
      MissionType.visit => Icons.store_mall_directory,
      MissionType.invite => Icons.person_add_alt_1,
      MissionType.coupon => Icons.confirmation_number,
    };

    final (bg, fg) = switch (m.type) {
      MissionType.steps => (AppColors.primary100, AppColors.primary900),
      MissionType.visit => (AppColors.secondary100, AppColors.secondary900),
      MissionType.invite => (AppColors.primary50, AppColors.primary800),
      MissionType.coupon => (AppColors.gray100, AppColors.gray800),
    };

    final titleStyle = AppTypography.bodyMedium.copyWith(
      decoration: m.isCompleted ? TextDecoration.lineThrough : null,
      color: m.isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            m.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: m.isCompleted
                ? AppColors.primary500
                : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(m.title, style: titleStyle)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Text(
              m.badge,
              style: AppTypography.labelSmall.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

String _comma(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final idx = text.length - i;
    buffer.write(text[i]);
    if (idx > 1 && idx % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String _percent(double value) => (value * 100).toStringAsFixed(1);

class _StepsPermissionCard extends StatelessWidget {
  const _StepsPermissionCard({required this.onGrant});
  final VoidCallback onGrant;
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          const Icon(Icons.directions_walk, color: AppColors.primary500),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '걸음 수 측정을 위해 활동 권한이 필요합니다.',
              style: AppTypography.bodySmall,
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onGrant,
            child: Text(
              '권한 허용',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primary500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}