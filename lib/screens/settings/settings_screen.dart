import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/settings/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_card.dart';
import '../../theme/app_spacing.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);

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
      data: (settings) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(settings.profile.nickname, style: AppTypography.bodyLarge),
        subtitle: Text(settings.profile.email, style: AppTypography.bodySmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/profile'),
      ),
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
            Text('연동', style: AppTypography.labelLarge),
            const SizedBox(height: AppSpacing.paddingSM),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.paddingMD),
              child: _SettingsTile(
                title: '연결 프로그램',
                onTap: () => context.push('/settings/connect'),
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

