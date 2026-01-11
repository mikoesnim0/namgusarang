import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_model.dart';
import '../../features/home/home_provider.dart';
import '../../features/settings/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
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
    final nickname = settingsAsync.valueOrNull?.profile.nickname ?? '닉네임';

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingHorizontal,
          vertical: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(
              bottom: false,
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    onTap: () => context.go('/profile'),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.gray200,
                          child: Icon(Icons.person, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        Text(nickname, style: AppTypography.labelLarge),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Column(
                    children: [
                      Text(home.cycle.roundTitle, style: AppTypography.labelLarge),
                      Text(
                        '종료까지 ${home.cycle.daysLeft}일',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '설정',
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 상단 배너 (회차 + D-day)
            AppCard(
              variant: CardVariant.elevated,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.paddingMD,
                vertical: AppSpacing.paddingSM,
              ),
              child: RichText(
                text: TextSpan(
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  children: [
                    const TextSpan(text: '이번 미션 종료까지 '),
                    TextSpan(
                      text: '${home.cycle.daysLeft}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: '일 남았어요!'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.paddingMD),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('오늘의 걸음 수', style: AppTypography.labelLarge),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${home.todaySteps}', style: AppTypography.h2),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('보', style: AppTypography.bodyMedium),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        ref.read(homeControllerProvider.notifier).resetToday(),
                    child: const Text('리셋'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 체크포인트 (1~10)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: home.milestones.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final n = home.milestones[idx];
                        final filledCount = (home.progress * 10).floor();
                        final filled = idx < filledCount;
                        return _CircleStep(text: '$n', filled: filled);
                      },
                    ),
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
                  Text('오늘의 미션', style: AppTypography.labelLarge),
                  const SizedBox(height: AppSpacing.paddingSM),
                  Text(home.mission.title, style: AppTypography.bodyLarge),
                  const SizedBox(height: AppSpacing.paddingSM),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
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

            // 오늘 할 일 (3~5개 미션 리스트)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('오늘 할 일', style: AppTypography.labelLarge),
                  const SizedBox(height: AppSpacing.paddingSM),
                  for (var i = 0; i < home.missions.length; i++) ...[
                    _MissionTile(m: home.missions[i]),
                    if (i != home.missions.length - 1) const Divider(height: 16),
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
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary100,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(color: AppColors.primary900),
      ),
    );
  }
}

class _CircleStep extends StatelessWidget {
  const _CircleStep({required this.text, required this.filled});

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

class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.m});

  final MissionItem m;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            m.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: m.isCompleted ? AppColors.primary500 : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              m.title,
              style: AppTypography.bodyMedium.copyWith(
                decoration: m.isCompleted ? TextDecoration.lineThrough : null,
                color:
                    m.isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ),
          _Pill(text: m.badge),
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

