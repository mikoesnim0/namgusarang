import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/profile_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_card.dart';

class PersonalInfoScreen extends ConsumerWidget {
  const PersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(personalStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('개인 정보')),
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
              _RowItem(
                label: '총 쿠폰 사용',
                value: '${stats.totalCouponsUsed}회',
              ),
              const Divider(height: 20),
              _RowItem(
                label: '총 걸음 수',
                value: '${_comma(stats.totalSteps)}보',
              ),
              const Divider(height: 20),
              _RowItem(
                label: '총 이동 거리',
                value: '${stats.totalDistanceKm} km',
              ),
              const Divider(height: 20),
              _RowItem(
                label: '총 소모 칼로리',
                value: '${_comma(stats.totalCaloriesKcal)} kcal',
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
  const _RowItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTypography.bodyMedium)),
        Text(value, style: AppTypography.bodyMedium),
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

