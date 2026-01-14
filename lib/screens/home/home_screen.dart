import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_model.dart';
import '../../features/home/home_provider.dart';
import '../../features/settings/settings_provider.dart';
import '../../features/auth/auth_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _HomeHeader(
            nickname: nickname,
            roundTitle: home.cycle.roundTitle,
            daysLeft: home.cycle.daysLeft,
            onProfileTap: () => context.go('/my'),
            onSettingsTap: () => context.push('/settings'),
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
                  _DaysLeftCard(daysLeft: home.cycle.daysLeft),
                  const SizedBox(height: 12),
                  _SuccessDaysCard(
                    milestones: home.milestones,
                    completed: home.completedMilestones,
                  ),
                  const SizedBox(height: 12),
                  _TodayStepsCard(
                    steps: home.todaySteps,
                    goalSteps: home.mission.goalSteps,
                    remainingSteps: home.remainingSteps,
                    progress: home.progress,
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.paddingMD),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('오늘의 미션', style: AppTypography.labelLarge),
                        const SizedBox(height: AppSpacing.paddingSM),
                        Text(home.mission.title, style: AppTypography.bodyLarge),
                        const SizedBox(height: AppSpacing.paddingSM),
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
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
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.paddingMD),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.nickname,
    required this.roundTitle,
    required this.daysLeft,
    required this.onProfileTap,
    required this.onSettingsTap,
  });

  final String nickname;
  final String roundTitle;
  final int daysLeft;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.brandTeal,
            AppColors.brandSky,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingHorizontal,
            vertical: 12,
          ),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                onTap: onProfileTap,
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.gray200,
                      child:
                          Icon(Icons.person, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      nickname,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Column(
                children: [
                  Text(
                    roundTitle,
                    style: AppTypography.h5.copyWith(
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                  Text(
                    '티켓 리셋까지 ${daysLeft}일',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                tooltip: '설정',
                onPressed: onSettingsTap,
                icon: const Icon(Icons.settings, color: AppColors.textOnPrimary),
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
  });

  final List<int> milestones;
  final List<int> completed;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('성공한 날', style: AppTypography.labelLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: milestones.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final n = milestones[idx];
                final filled = completed.contains(n);
                return _SuccessDayCircle(text: '$n', filled: filled);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessDayCircle extends StatelessWidget {
  const _SuccessDayCircle({required this.text, required this.filled});

  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppColors.primary500 : AppColors.gray100,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(
          color: filled ? AppColors.textOnPrimary : AppColors.textSecondary,
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
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text('오늘의 걸음 수', style: AppTypography.labelLarge),
          ),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: SizedBox(
              height: 14,
              child: Stack(
                children: [
                  Container(color: AppColors.gray100),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.primary500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${_comma(steps)}보',
                style: AppTypography.bodySmall,
              ),
              const Spacer(),
              Text(
                '목표 ${_comma(goalSteps)}보 · ${_percent(progress)}%',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
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
            color: m.isCompleted ? AppColors.primary500 : AppColors.textSecondary,
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
