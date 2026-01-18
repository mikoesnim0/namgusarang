import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_providers.dart';
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
    final userDoc = ref.watch(currentUserDocProvider).valueOrNull;
    final authUser = ref.watch(authStateProvider).valueOrNull;

    final docNickname = (userDoc?['nickname'] as String?)?.trim();
    final docEmail = (userDoc?['email'] as String?)?.trim();
    final authNickname = authUser?.displayName?.trim();
    final authEmail = authUser?.email?.trim();
    final settingsNickname = settings?.profile.nickname.trim();
    final settingsEmail = settings?.profile.email.trim();

    final nickname = (docNickname?.isNotEmpty == true)
        ? docNickname!
        : (authNickname?.isNotEmpty == true)
            ? authNickname!
            : (settingsNickname?.isNotEmpty == true)
                ? settingsNickname!
                : '닉네임';

    final email = (docEmail?.isNotEmpty == true)
        ? docEmail!
        : (authEmail?.isNotEmpty == true)
            ? authEmail!
            : (settingsEmail?.isNotEmpty == true)
                ? settingsEmail!
                : '이메일';

    return Scaffold(
      appBar: AppBar(
        title: const Text('마이'),
        actions: [
          IconButton(
            tooltip: '설정',
            onPressed: () => context.push('/my'),
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
                    title: Text('내 정보 보기', style: AppTypography.bodyLarge),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/my/info'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_outlined),
                    title: Text('알림', style: AppTypography.bodyLarge),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/my/notifications'),
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
