import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hangookji_namgu/features/auth/auth_controller.dart';
import 'package:hangookji_namgu/features/auth/auth_providers.dart';
import '../../features/settings/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_card.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_colors.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final authUserAsync = ref.watch(authStateProvider);
    final userDocAsync = ref.watch(currentUserDocProvider);

    const appVersion = 'v1.0.0+1';

    final header = settingsAsync.when(
      loading: () => const ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('로딩중...'),
      ),
      error: (e, _) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('설정 로딩 실패'),
        subtitle: Text(e.toString()),
      ),
      data: (settings) {
        final authUser = authUserAsync.valueOrNull;
        final userDoc = userDocAsync.valueOrNull;
        final nickname =
            (userDoc?['nickname'] as String?)?.trim().isNotEmpty == true
                ? (userDoc?['nickname'] as String)
                : settings.profile.nickname;
        final email =
            (userDoc?['email'] as String?)?.trim().isNotEmpty == true
                ? (userDoc?['email'] as String)
                : (authUser?.email ?? settings.profile.email);

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(nickname, style: AppTypography.bodyLarge),
          subtitle: Text(email, style: AppTypography.bodySmall),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/profile'),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SingleChildScrollView(
        padding: AppTheme.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.paddingMD),
              child: header,
            ),
            const SizedBox(height: AppSpacing.paddingXL),
            Text('계정', style: AppTypography.labelLarge),
            const SizedBox(height: AppSpacing.paddingSM),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.paddingMD),
              child: Column(
                children: [
                  _SettingsTile(
                    title: '프로필',
                    onTap: () => context.push('/settings/profile'),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    title: '알림',
                    onTap: () => context.push('/settings/notifications'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.paddingXL),
            Text('정보', style: AppTypography.labelLarge),
            const SizedBox(height: AppSpacing.paddingSM),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.paddingMD),
              child: Column(
                children: [
                  _SettingsTile(
                    title: '서비스 이용 약관',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('약관 화면은 추후 연결됩니다.')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    title: '개인정보 처리 방침',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('개인정보 처리 방침 화면은 추후 연결됩니다.')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    title: '문의 하기',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('문의 기능은 추후 연결됩니다.')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    title: '탈퇴 하기',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('탈퇴 기능은 추후 연결됩니다.')),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.paddingXL),

            // 로그아웃 row (screenshot-like)
            AppCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('로그아웃'),
                      content: const Text('정말 로그아웃 하시겠어요?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('로그아웃'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;

                  await ref.read(authControllerProvider.notifier).signOut();
                  if (!context.mounted) return;
                  context.go('/login');
                },
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.paddingMD),
                  child: Row(
                    children: [
                      Text('로그아웃', style: AppTypography.bodyLarge),
                      const Spacer(),
                      Text(
                        appVersion,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: AppTypography.bodyLarge),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

