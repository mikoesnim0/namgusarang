import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/foods/food_equivalents.dart';
import '../../features/profile/profile_provider.dart';
import '../../features/steps/health_connect_backfill_controller.dart';
import '../../features/steps/daily_steps_history_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_card.dart';

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  late DateTime _month;
  int? _selectedDay;

  String _fmtDate(DateTime d) {
    final yy = (d.year % 100).toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yy.$mm.$dd';
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _selectedDay = now.day;

    // Best-effort: backfill this month from Health Connect (Android) so the
    // calendar is populated even if the app was not open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(healthConnectBackfillControllerProvider.notifier)
          .backfillMonth(_month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(personalStatsProvider);
    final cycleRange =
        '${_fmtDate(stats.cycleStart)}~${_fmtDate(stats.cycleEnd)}';
    final cycleFoodEq = suggestFoodEquivalentForKcal(stats.cycleCaloriesKcal);
    final totalFoodEq = suggestFoodEquivalentForKcal(stats.totalCaloriesKcal);

    final monthStepsAsync = ref.watch(monthlyDailyStepsProvider(_month));
    final monthSteps = monthStepsAsync.valueOrNull ?? const <int, int>{};

    return Scaffold(
      appBar: AppBar(title: const Text('내 정보 보기')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppTheme.screenPadding.add(
            const EdgeInsets.only(bottom: AppSpacing.paddingXXL),
          ),
          child: Column(
            children: [
              AppCard(
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
                    _RowItem(
                      label: '총 걸음 수',
                      value: '${_comma(stats.totalSteps)} 보',
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
                      trailingFooter: totalFoodEq == null
                          ? null
                          : _FoodEquivalentLine(totalFoodEq),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '※ 칼로리/거리 계산은 간단 계산으로 표시됩니다.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.paddingLG),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.paddingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('지난 걸음 수', style: AppTypography.h5),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _month = DateTime(
                                _month.year,
                                _month.month - 1,
                                1,
                              );
                              _selectedDay = null;
                            });
                            ref
                                .read(
                                  healthConnectBackfillControllerProvider
                                      .notifier,
                                )
                                .backfillMonth(_month);
                          },
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          '${_month.year}.${_month.month.toString().padLeft(2, '0')}',
                          style: AppTypography.bodyMedium,
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _month = DateTime(
                                _month.year,
                                _month.month + 1,
                                1,
                              );
                              _selectedDay = null;
                            });
                            ref
                                .read(
                                  healthConnectBackfillControllerProvider
                                      .notifier,
                                )
                                .backfillMonth(_month);
                          },
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _StepsCalendarGrid(
                      month: _month,
                      stepsByDay: monthSteps,
                      selectedDay: _selectedDay,
                      onSelectDay: (day) => setState(() => _selectedDay = day),
                    ),
                    const SizedBox(height: 10),
                    Builder(
                      builder: (context) {
                        final selectedDay = _selectedDay;
                        if (selectedDay == null) {
                          return Text(
                            '날짜를 선택하면 걸음 수가 표시됩니다.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          );
                        }
                        final steps = monthSteps[selectedDay];
                        final date = DateTime(
                          _month.year,
                          _month.month,
                          selectedDay,
                        );
                        return Row(
                          children: [
                            Text(
                              _fmtDate(date),
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              steps == null ? '-' : '${_comma(steps)} 보',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (monthStepsAsync.isLoading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                    if (monthStepsAsync.hasError) ...[
                      const SizedBox(height: 8),
                      Text(
                        '지난 걸음 수를 불러오지 못했습니다.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '※ 기록은 앱 실행 중 업데이트된 날짜 기준으로 저장됩니다.',
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
      ),
    );
  }
}

class _StepsCalendarGrid extends StatelessWidget {
  const _StepsCalendarGrid({
    required this.month,
    required this.stepsByDay,
    required this.selectedDay,
    required this.onSelectDay,
  });

  final DateTime month;
  final DailyStepsByDay stepsByDay;
  final int? selectedDay;
  final ValueChanged<int> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Sunday start. DateTime.weekday: Mon=1..Sun=7 → Sun => 0.
    final leading = first.weekday % 7;
    final totalCells = leading + daysInMonth;
    final rows = ((totalCells + 6) / 7).floor();
    final cellCount = rows * 7;

    const weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

    return Column(
      children: [
        Row(
          children: [
            for (final w in weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            // Slightly taller cells to avoid overflow on small screens.
            childAspectRatio: 0.92,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: cellCount,
          itemBuilder: (context, index) {
            final day = index - leading + 1;
            if (day < 1 || day > daysInMonth) {
              return const SizedBox.shrink();
            }

            final steps = stepsByDay[day];
            final isSelected = selectedDay == day;
            final isToday = _isSameYmd(
              DateTime.now(),
              DateTime(month.year, month.month, day),
            );

            final borderColor = isSelected
                ? AppColors.primary500
                : isToday
                ? AppColors.primary200
                : AppColors.border;
            final bgColor = isSelected ? AppColors.primary50 : Colors.white;

            return InkWell(
              onTap: () => onSelectDay(day),
              borderRadius: BorderRadius.circular(10),
              child: Ink(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Padding(
                  // Keep padding tight so the cell never overflows even on
                  // small screens / large accessibility text sizes.
                  padding: const EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 2,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$day',
                          textScaler: const TextScaler.linear(1.0),
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                      ),
                      if (steps != null && steps > 0) ...[
                        const SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _shortSteps(steps),
                            textScaler: const TextScaler.linear(1.0),
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              height: 1.0,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  static bool _isSameYmd(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _shortSteps(int steps) {
    // Keep the cell label compact to avoid overflows on small devices.
    // 7,000 -> "7k", 12,300 -> "12.3k"
    if (steps >= 1_000) {
      if (steps >= 10_000) {
        final v = (steps / 1000).toStringAsFixed(1);
        return '${v}k';
      }
      final v = (steps / 1000).round();
      return '${v}k';
    }
    return steps.toString();
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
