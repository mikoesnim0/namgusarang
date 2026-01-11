import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/settings_model.dart';
import '../../features/settings/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_card.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: AppTheme.screenPadding,
          child: Text('설정 로딩 실패: $e', style: AppTypography.bodyMedium),
        ),
        data: (settings) {
          final n = settings.notifications;
          return SingleChildScrollView(
            padding: AppTheme.screenPadding,
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.paddingMD),
              child: Column(
                children: [
                  _ToggleRow(
                    title: '미션 관련 알림',
                    value: n.mission,
                    onChanged: (v) => ref
                        .read(settingsControllerProvider.notifier)
                        .updateNotifications(n.copyWith(mission: v)),
                  ),
                  const Divider(height: 1),
                  _ToggleRow(
                    title: '쿠폰 관련 알림',
                    value: n.coupon,
                    onChanged: (v) => ref
                        .read(settingsControllerProvider.notifier)
                        .updateNotifications(n.copyWith(coupon: v)),
                  ),
                  const Divider(height: 1),
                  _ToggleRow(
                    title: '이벤트/혜택 알림',
                    value: n.eventBenefit,
                    onChanged: (v) => ref
                        .read(settingsControllerProvider.notifier)
                        .updateNotifications(n.copyWith(eventBenefit: v)),
                  ),
                  const Divider(height: 1),
                  _ToggleRow(
                    title: '공지 알림',
                    value: n.notice,
                    onChanged: (v) => ref
                        .read(settingsControllerProvider.notifier)
                        .updateNotifications(n.copyWith(notice: v)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTypography.bodyLarge)),
        Switch(
          value: value,
          activeColor: AppColors.primary500,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

