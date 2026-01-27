import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/foods/food_equivalents.dart';
import '../../features/steps/steps_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class WalkerTrackingScreen extends ConsumerWidget {
  const WalkerTrackingScreen({super.key});

  static const _dailyGoal = 5000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepsAsync = ref.watch(todayStepsProvider);
    final steps = stepsAsync.value ?? 0;
    final kcal = (steps * 0.023).round();
    final eq = suggestFoodEquivalentForKcal(kcal);
    final progress = math.min(steps / _dailyGoal, 1.0);

    final statusText = stepsAsync.when(
      data: (_) => 'ACTIVE',
      loading: () => 'WAITING',
      error: (_, __) => 'ERROR',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Walker 측정 모니터'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.paddingMD),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.paddingMD),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary100,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusFull,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.paddingMD,
                          vertical: AppSpacing.paddingXS,
                        ),
                        child: Text(
                          statusText,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primary500,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$kcal kcal',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.paddingMD),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Walked',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _comma(steps),
                        style: AppTypography.h4.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.paddingXS),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '오늘 목표 ${_dailyGoal}걸음',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(1)}%',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary500,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.paddingMD),
                  LinearProgressIndicator(
                    value: progress,
                    color: AppColors.primary500,
                    backgroundColor: AppColors.gray200,
                    minHeight: 8,
                  ),
                  const SizedBox(height: AppSpacing.paddingMD),
                  if (eq != null) ...[
                    Row(
                      children: [
                        Image.asset(
                          eq.food.iconAssetPath,
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.restaurant,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            eq.formatLabel(),
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.paddingMD),
                  ],
                  AppButton(
                    text: '걸음 권한 요청',
                    variant: ButtonVariant.outline,
                    isFullWidth: true,
                    onPressed: () {
                      ref.read(stepsRepositoryProvider).requestPermission();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.paddingMD),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('실시간 로그', style: AppTypography.labelLarge),
                  const SizedBox(height: AppSpacing.paddingSM),
                  Text(
                    '앱을 켜두면 걸음 카운터가 지속적으로 값을 내보냅니다. 걸음을 계속 걸으면 “Walked” 숫자가 오른다는 것을 확인하실 수 있습니다.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _comma(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final idx = text.length - i;
      buffer.write(text[i]);
      if (idx > 1 && idx % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }
}
