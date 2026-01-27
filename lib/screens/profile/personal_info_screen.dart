import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/foods/food_equivalents.dart';
import '../../features/profile/profile_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_card.dart';

class PersonalInfoScreen extends ConsumerWidget {
  const PersonalInfoScreen({super.key});

  String _fmtDate(DateTime d) {
    final yy = (d.year % 100).toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yy.$mm.$dd';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(personalStatsProvider);
    final cycleRange =
        '${_fmtDate(stats.cycleStart)}~${_fmtDate(stats.cycleEnd)}';
    final cycleFoodEq = suggestFoodEquivalentForKcal(stats.cycleCaloriesKcal);
    final totalFoodEq = suggestFoodEquivalentForKcal(stats.totalCaloriesKcal);

    return Scaffold(
      appBar: AppBar(title: const Text('내 정보 보기')),
      body: SingleChildScrollView(
        padding: AppTheme.screenPadding,
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.paddingMD),
          child: Column(
            children: [
              _RowItem(
                label: '쿠폰으로 아낀 금액',
                value: '${_comma(stats.totalCouponSavingsWon)}원',
              ),
              const Divider(height: 20),
              _RowItem(label: '총 쿠폰 사용', value: '${stats.totalCouponsUsed}회'),
              const Divider(height: 20),
              _RowItem(
                label: '이번 회차 걸음 수',
                subtitle: cycleRange,
                value: '${_comma(stats.cycleSteps)} 보',
              ),
              const Divider(height: 20),
              _RowItem(
                label: '이번 회차 소모 칼로리',
                subtitle: cycleRange,
                value: '${_comma(stats.cycleCaloriesKcal)} kcal',
                trailingFooter: cycleFoodEq == null
                    ? null
                    : _FoodEquivalentLine(cycleFoodEq),
              ),
              const Divider(height: 20),
              _RowItem(label: '총 걸음 수', value: '${_comma(stats.totalSteps)} 보'),
              const Divider(height: 20),
              _RowItem(label: '총 이동 거리', value: '${stats.totalDistanceKm} km'),
              const Divider(height: 20),
              _RowItem(
                label: '총 소모 칼로리',
                value: '${_comma(stats.totalCaloriesKcal)} kcal',
                trailingFooter: totalFoodEq == null
                    ? null
                    : _FoodEquivalentLine(totalFoodEq),
              ),
              const SizedBox(height: 8),
              Text(
                '※ 현재는 더미 데이터/간단 계산으로 표시됩니다.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  const _RowItem({
    required this.label,
    required this.value,
    this.subtitle,
    this.trailingFooter,
  });

  final String label;
  final String value;
  final String? subtitle;
  final Widget? trailingFooter;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.bodyMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value, style: AppTypography.bodyMedium),
            if (trailingFooter != null) ...[
              const SizedBox(height: 6),
              trailingFooter!,
            ],
          ],
        ),
      ],
    );
  }
}

class _FoodEquivalentLine extends StatelessWidget {
  const _FoodEquivalentLine(this.result);

  final FoodEquivalentResult result;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          result.food.iconAssetPath,
          width: 16,
          height: 16,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.restaurant,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          result.formatLabel(),
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

String _comma(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final idx = s.length - i;
    buf.write(s[i]);
    if (idx > 1 && idx % 3 == 1) buf.write(',');
  }
  return buf.toString();
}
