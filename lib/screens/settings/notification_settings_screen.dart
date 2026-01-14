import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_card.dart';
import '../../widgets/gradient_switch.dart';

@immutable
class _NotificationSettingsState {
  const _NotificationSettingsState({
    required this.appPushMission,
    required this.appPushCoupon,
    required this.appPushEventBenefit,
    required this.emailEventBenefit,
  });

  final bool appPushMission;
  final bool appPushCoupon;
  final bool appPushEventBenefit;
  final bool emailEventBenefit;

  _NotificationSettingsState copyWith({
    bool? appPushMission,
    bool? appPushCoupon,
    bool? appPushEventBenefit,
    bool? emailEventBenefit,
  }) {
    return _NotificationSettingsState(
      appPushMission: appPushMission ?? this.appPushMission,
      appPushCoupon: appPushCoupon ?? this.appPushCoupon,
      appPushEventBenefit: appPushEventBenefit ?? this.appPushEventBenefit,
      emailEventBenefit: emailEventBenefit ?? this.emailEventBenefit,
    );
  }
}

class _NotificationSettingsController extends StateNotifier<_NotificationSettingsState> {
  _NotificationSettingsController()
      : super(const _NotificationSettingsState(
          appPushMission: true,
          appPushCoupon: false,
          appPushEventBenefit: true,
          emailEventBenefit: true,
        ));

  void setAppPushMission(bool v) => state = state.copyWith(appPushMission: v);
  void setAppPushCoupon(bool v) => state = state.copyWith(appPushCoupon: v);
  void setAppPushEventBenefit(bool v) =>
      state = state.copyWith(appPushEventBenefit: v);
  void setEmailEventBenefit(bool v) => state = state.copyWith(emailEventBenefit: v);
}

final _notificationSettingsProvider = StateNotifierProvider.autoDispose<
    _NotificationSettingsController, _NotificationSettingsState>((ref) {
  return _NotificationSettingsController();
});

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(_notificationSettingsProvider);
    final c = ref.read(_notificationSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('알림')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: AppTheme.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Section(
                    title: '앱 푸시',
                    children: [
                      _ToggleRow(
                        title: '미션 관련 알림',
                        value: s.appPushMission,
                        onChanged: c.setAppPushMission,
                      ),
                      const Divider(height: 1),
                      _ToggleRow(
                        title: '쿠폰 관련 알림',
                        value: s.appPushCoupon,
                        onChanged: c.setAppPushCoupon,
                      ),
                      const Divider(height: 1),
                      _ToggleRow(
                        title: '이벤트 / 혜택 알림',
                        value: s.appPushEventBenefit,
                        onChanged: c.setAppPushEventBenefit,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.paddingXL),
                  _Section(
                    title: '이메일',
                    children: [
                      _ToggleRow(
                        title: '이벤트 / 혜택 알림',
                        value: s.emailEventBenefit,
                        onChanged: c.setEmailEventBenefit,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.paddingXL),
                  Text(
                    '기타',
                    style: AppTypography.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.paddingSM),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.paddingMD),
                    child: Text(
                      '추후 추가될 알림 설정이 이곳에 표시됩니다.',
                      style: AppTypography.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: AppTypography.labelLarge,
        ),
        const SizedBox(height: AppSpacing.paddingSM),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.paddingMD),
          child: Column(children: children),
        ),
      ],
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
    return SizedBox(
      height: 58, // Figma-ish row height
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GradientSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

