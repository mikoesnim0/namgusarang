import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/foods/food_equivalents.dart';
import '../../features/steps/background_steps_controller.dart';
import '../../features/steps/step_metrics.dart';
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
    final permissionAsync = ref.watch(stepsPermissionStatusProvider);
    final availableAsync = ref.watch(stepsAvailabilityProvider);
    final hcAvailableAsync = ref.watch(healthConnectAvailabilityProvider);
    final hcPermittedAsync = ref.watch(healthConnectPermissionProvider);
    // Keep kcal consistent with Home/Profile (slow walking coefficient).
    // Walker monitor currently doesn't load user profile, so use a reasonable default.
    final kcal = StepMetrics.kcalFromSteps(steps: steps, weightKg: 70);
    final eq = suggestFoodEquivalentForKcal(kcal);
    final progress = math.min(steps / _dailyGoal, 1.0);

    final statusText = stepsAsync.when(
      data: (_) => 'ACTIVE',
      loading: () => 'WAITING',
      error: (_, __) => 'ERROR',
    );

    final permissionText = permissionAsync.when(
      data: (v) => v.name,
      loading: () => 'loading',
      error: (_, __) => 'error',
    );

    final availableText = availableAsync.when(
      data: (v) => v ? 'available' : 'not_available',
      loading: () => 'loading',
      error: (_, __) => 'error',
    );

    final hcAvailableText = hcAvailableAsync.when(
      data: (v) => v ? 'available' : 'not_available',
      loading: () => 'loading',
      error: (_, __) => 'error',
    );

    final hcPermittedText = hcPermittedAsync.when(
      data: (v) => v ? 'granted' : 'denied',
      loading: () => 'loading',
      error: (_, __) => 'error',
    );

    final backgroundStepsAsync = ref.watch(backgroundStepsControllerProvider);
    final backgroundStepsRunning = backgroundStepsAsync.valueOrNull ?? false;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

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
        child: SingleChildScrollView(
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
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.paddingSM),
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMD,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '진단',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'sensor: $availableText · permission: $permissionText · stream: $statusText',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'health connect: $hcAvailableText · hc permission: $hcPermittedText',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (availableText == 'not_available') ...[
                            const SizedBox(height: 6),
                            Text(
                              '에뮬레이터/일부 기기에서는 만보기 센서가 없어서 걸음수가 오르지 않습니다. 가능하면 실제 기기에서 테스트해주세요.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (stepsAsync.hasError) ...[
                            const SizedBox(height: 6),
                            Text(
                              'error: ${stepsAsync.error}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
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
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.paddingMD),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text('백그라운드 측정', style: AppTypography.labelLarge),
                              const Spacer(),
                              Switch(
                                value: backgroundStepsRunning,
                                onChanged:
                                    (!isAndroid ||
                                        backgroundStepsAsync.isLoading)
                                    ? null
                                    : (v) => ref
                                          .read(
                                            backgroundStepsControllerProvider
                                                .notifier,
                                          )
                                          .setEnabled(v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isAndroid
                                ? '켜면 앱이 백그라운드여도 알림에 오늘 걸음수가 표시됩니다.'
                                : 'iOS에서는 백그라운드 알림 표시를 지원하지 않습니다.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.paddingMD),
                    AppButton(
                      text: '걸음 권한 요청',
                      variant: ButtonVariant.outline,
                      isFullWidth: true,
                      onPressed: () {
                        ref.read(stepsRepositoryProvider).requestPermission();
                      },
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      text: 'Health Connect 권한 요청',
                      variant: ButtonVariant.outline,
                      isFullWidth: true,
                      onPressed: () async {
                        await ref
                            .read(healthConnectStepsRepositoryProvider)
                            .requestStepsPermission();
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
              const SizedBox(height: AppSpacing.paddingLG),
            ],
          ),
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
