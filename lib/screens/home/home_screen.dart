import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'dart:async';
import 'dart:math' as math;

import '../../features/foods/food_equivalents.dart';
import '../../features/home/home_model.dart';
import '../../features/home/home_provider.dart';
import '../../features/coupons/coupons_provider.dart';
import '../../features/places/place.dart';
import '../../features/places/places_provider.dart';
import '../../features/steps/steps_provider.dart';
import '../../features/steps/steps_repository.dart';
import '../../features/steps/steps_sync_provider.dart';
import '../../features/settings/settings_provider.dart';
import '../../features/auth/auth_providers.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/place_info_popup.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // Temporary: hide "오늘 할 일" and debug actions during the release.
  // Flip to false after launch.
  static const bool _hideTodoAndDebugUi = true;

  String _fmtDate(DateTime d) {
    final yy = (d.year % 100).toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yy.$mm.$dd';
  }

  String _fmtTodayLabel(DateTime d) => '오늘 ${_fmtDate(d)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<int>>(todayStepsProvider, (_, next) {
      final steps = next.valueOrNull;
      if (steps == null) return;
      ref.read(homeControllerProvider.notifier).setTodaySteps(steps);
    });

    // Coupon issuance UX (MVP): when the steps mission flips incomplete -> complete,
    // issue a coupon to the current user and show a confirmation dialog.
    ref.listen<HomeState>(homeControllerProvider, (prev, next) {
      if (prev == null) return;

      bool isStepsDone(HomeState s) =>
          s.missions.any((m) => m.type == MissionType.steps && m.isCompleted);

      final wasDone = isStepsDone(prev);
      final nowDone = isStepsDone(next);
      if (wasDone || !nowDone) return;

      unawaited(_issueCouponForStepsMission(context, ref));
    });
    ref.watch(stepsSyncControllerProvider);

    final home = ref.watch(homeControllerProvider);
    final settingsAsync = ref.watch(settingsControllerProvider);
    final userDoc = ref.watch(currentUserDocProvider).valueOrNull;
    final authUser = ref.watch(authStateProvider).valueOrNull;
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

    final cycleEnd = DateTime.now().add(Duration(days: home.cycle.daysLeft));
    final cycleStart = cycleEnd.subtract(const Duration(days: 9));
    final cycleRange = '${_fmtDate(cycleStart)} ~ ${_fmtDate(cycleEnd)}';
    final todayLabel = _fmtTodayLabel(DateTime.now());
    final todayIndex = (10 - home.cycle.daysLeft).clamp(1, 10);

    final permissionStatus = ref
        .watch(stepsPermissionStatusProvider)
        .valueOrNull;
    final showTodoAndDebug = !_hideTodoAndDebugUi && !kReleaseMode;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: Column(
        children: [
          _HomeHeader(
            nickname: nickname,
            roundTitle: home.cycle.roundTitle,
            daysLeft: home.cycle.daysLeft,
            onProfileTap: () => context.push('/my/info'),
            onSettingsTap: () => context.push('/settings'),
            todayLabel: todayLabel,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingHorizontal,
                12,
                AppSpacing.screenPaddingHorizontal,
                120,
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
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('구독관리는 추후 연결됩니다.')),
                        ),
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
                    completed: home.completedMilestones,
                    todayIndex: todayIndex,
                  ),
                  const SizedBox(height: 12),
                  _TodayStepsCard(
                    steps: home.todaySteps,
                    goalSteps: home.mission.goalSteps,
                    remainingSteps: home.remainingSteps,
                    progress: home.progress,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/walker'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary500,
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: AppSpacing.paddingMD,
                      ),
                    ),
                    child: const Text('Walker 모니터 열기'),
                  ),
                  _CouponPlacesMapCard(
                    placesAsync: ref.watch(activePlacesProvider),
                    onOpenFullMap: () => context.go('/map'),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.paddingMD),
                    margin: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('오늘의 미션', style: AppTypography.labelLarge),
                        const SizedBox(height: AppSpacing.paddingSM),
                        Text(
                          home.mission.title,
                          style: AppTypography.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.paddingSM),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusFull,
                          ),
                          child: LinearProgressIndicator(
                            value: home.progress,
                            minHeight: 8,
                            backgroundColor: AppColors.gray100,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary500,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.paddingSM),
                        Row(
                          children: [
                            Text(
                              '${(home.progress * 100).round()}%',
                              style: AppTypography.bodySmall,
                            ),
                            const Spacer(),
                            Text(
                              home.remainingSteps == 0
                                  ? '완료!'
                                  : '${home.remainingSteps}보 남았어요',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
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

  Future<void> _issueCouponForStepsMission(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    // Pick a place (coupon-enabled first).
    final places = ref.read(activePlacesProvider).valueOrNull ?? const <Place>[];
    final place = places.firstWhere(
      (p) => p.hasCoupons,
      orElse: () => places.isNotEmpty ? places.first : const Place(id: 'place_001', name: '샘플매장', lat: 0, lng: 0),
    );

    final templates = const [
      ('아메리카노 1잔 무료', '매장에서 6자리 인증 코드를 입력하면 사용 처리됩니다.'),
      ('3,000원 할인 쿠폰', '결제 시 직원에게 6자리 코드를 보여주세요.'),
      ('1+1 쿠폰', '대상 상품에 한해 1+1 적용됩니다.'),
    ];

    final idx = DateTime.now().day % templates.length;
    final (title, description) = templates[idx];

    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final issueKey = 'steps_${y}${m}${d}';

    final code = (math.Random().nextInt(900000) + 100000).toString();
    final expiresAt = now.add(const Duration(days: 7));

    final issued = await ref.read(couponsRepositoryProvider).issueCouponForUser(
          uid: user.uid,
          couponId: issueKey,
          data: {
            'title': title,
            'description': description,
            'verificationCode': code,
            'status': 'active',
            'expiresAt': expiresAt,
            'placeId': place.id,
            'placeName': place.name,
            'issuedFor': issueKey,
          },
        );

    if (!issued) return;
    if (!context.mounted) return;

    final action = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('쿠폰 발급 완료'),
        content: Text('미션을 완료해서 쿠폰이 발급되었습니다.\n\n[$title]\n${place.name}'),
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
      context.push('/coupons/$issueKey');
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
  const _DigitBox({required this.digit});

  final String digit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        digit,
        style: AppTypography.h5.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SuccessDaysCard extends StatelessWidget {
  const _SuccessDaysCard({
    required this.milestones,
    required this.completed,
    required this.todayIndex,
  });

  final List<int> milestones;
  final List<int> completed;
  final int todayIndex;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('성공한 날', style: AppTypography.labelLarge),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '10일 중 3일만 목표에 달성 하면 돼요!',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 6.0;
              final available = constraints.maxWidth;
              // Make 10 circles fit without horizontal scrolling.
              final size = ((available - spacing * 9) / 10).clamp(20.0, 30.0);

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final n in milestones) ...[
                    _SuccessDayCircle(
                      text: '$n',
                      filled: completed.contains(n),
                      isToday: n == todayIndex,
                      size: size,
                    ),
                    if (n != milestones.last) const SizedBox(width: spacing),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SuccessDayCircle extends StatelessWidget {
  const _SuccessDayCircle({
    required this.text,
    required this.filled,
    required this.isToday,
    required this.size,
  });

  final String text;
  final bool filled;
  final bool isToday;
  final double size;

  @override
  Widget build(BuildContext context) {
    final borderColor = isToday ? Colors.red.shade400 : AppColors.border;
    final bgColor = filled ? AppColors.primary500 : AppColors.gray100;
    final fgColor = filled ? AppColors.textOnPrimary : AppColors.textSecondary;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(color: borderColor, width: isToday ? 2 : 1),
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(
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
  });

  final int steps;
  final int goalSteps;
  final int remainingSteps;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final kcal = (steps * 0.023).round();
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
            height: 200,
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
      overlays.add(
        marker,
      );
    }
    if (overlays.isNotEmpty) {
      await controller.addOverlayAll(overlays);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          },
        ),
        if (_selectedPlace != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 56,
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
          bottom: 12,
          child: ElevatedButton.icon(
            onPressed:
                _isRequestingLocation ? null : () => _handleMyLocationTap(context),
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

      // Only show the consent dialog when permission isn't already granted.
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('위치 접근 동의'),
            content: const Text('현 위치를 알고 싶으면 동의해주세요.\n동의하십니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('동의'),
              ),
            ],
          ),
        );
        if (ok != true) return;
      }

      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.deniedForever) {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('권한 필요'),
            content: const Text('위치 권한이 영구적으로 거부되었습니다.\n설정에서 권한을 허용해주세요.'),
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
  const _StepsPermissionCard({required this.onGrant});  final VoidCallback onGrant;
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
