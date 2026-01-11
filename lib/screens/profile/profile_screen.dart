import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/settings/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final nickname = settings?.profile.nickname ?? '닉네임';
    final email = settings?.profile.email ?? 'abcd@gmail.com';

    return Scaffold(
      appBar: AppBar(
        title: const Text('마이'),
        actions: [
          IconButton(
            tooltip: '설정',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppTheme.screenPadding,
        child: Column(
          children: [
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.paddingMD),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.gray200,
                  child: Icon(Icons.person, color: AppColors.textSecondary),
                ),
                title: Text(nickname, style: AppTypography.bodyLarge),
                subtitle: Text(email, style: AppTypography.bodySmall),
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.paddingMD),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.assignment_ind_outlined),
                    title: Text('개인 정보', style: AppTypography.bodyLarge),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/profile/info'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_outlined),
                    title: Text('알림', style: AppTypography.bodyLarge),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/notifications'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

