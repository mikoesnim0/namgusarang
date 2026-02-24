import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hangookji_namgu/features/auth/auth_providers.dart';
import 'package:hangookji_namgu/features/notifications/push_notifications_provider.dart';
import 'package:hangookji_namgu/features/settings/settings_model.dart';
import 'package:hangookji_namgu/features/settings/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/gradient_switch.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _didInitialSync = false;

  Future<void> _syncTopics(
    NotificationSettings settings, {
    bool requestPermission = true,
  }) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '(unknown)';
    await ref
        .read(pushNotificationsServiceProvider)
        .syncTopics(
          settings: settings,
          uid: uid,
          requestPermission: requestPermission,
        );
  }

  Future<void> _savePrefsToFirestore({
    required String uid,
    required NotificationSettings settings,
  }) async {
    if (uid.trim().isEmpty || uid == '(unknown)') return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'notificationPrefs': {
            'mission': settings.mission,
            'coupon': settings.coupon,
            'eventBenefit': settings.eventBenefit,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Best-effort: Firestore rules may block this in some environments.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didInitialSync) return;
    final settings = ref.read(settingsControllerProvider).valueOrNull;
    if (settings == null) return;

    _didInitialSync = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Do not pop OS permission prompt just by entering this screen.
        await _syncTopics(settings.notifications, requestPermission: false);
      } catch (_) {
        // ignore: best effort
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('알림')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('알림 설정을 불러올 수 없어요.\n$e')),
        data: (settings) {
          final n = settings.notifications;

          Future<void> updateAndSync(NotificationSettings next) async {
            final uid =
                ref.read(authStateProvider).valueOrNull?.uid ?? '(unknown)';
            await ref
                .read(settingsControllerProvider.notifier)
                .updateNotifications(next);

            await _savePrefsToFirestore(uid: uid, settings: next);

            try {
              await _syncTopics(next, requestPermission: true);
            } catch (_) {
              if (!context.mounted) return;
              context.showAppSnackBar('푸시 알림 설정에 실패했어요.');
            }
          }

          return SingleChildScrollView(
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
                            value: n.mission,
                            onChanged: (v) => updateAndSync(
                              n.copyWith(mission: v),
                            ),
                          ),
                          const Divider(height: 1),
                          _ToggleRow(
                            title: '쿠폰 관련 알림',
                            value: n.coupon,
                            onChanged: (v) => updateAndSync(
                              n.copyWith(coupon: v),
                            ),
                          ),
                          const Divider(height: 1),
                          _ToggleRow(
                            title: '이벤트 / 혜택 알림',
                            value: n.eventBenefit,
                            onChanged: (v) => updateAndSync(
                              n.copyWith(eventBenefit: v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.paddingXL),
                      _Section(
                        title: '이메일',
                        children: [
                          _ToggleRow(
                            title: '이벤트 / 혜택 알림',
                            value: n.notice,
                            onChanged: (v) async {
                              // Email marketing is not auto-sent by Firebase; we only store consent for now.
                              await ref
                                  .read(settingsControllerProvider.notifier)
                                  .updateNotifications(n.copyWith(notice: v));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.paddingXL),
                      Text('기타', style: AppTypography.labelLarge),
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
          );
        },
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
        Text(title, style: AppTypography.labelLarge),
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
      height: 58,
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
          GradientSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
