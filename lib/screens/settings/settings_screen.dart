import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_info.dart';

import 'package:hangookji_namgu/features/auth/auth_controller.dart';
import 'package:hangookji_namgu/features/auth/auth_providers.dart';
import '../../features/settings/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_card.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_snackbar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _supportEmail = 'doyakmin@gmail.com';

  Future<void> _launchExternal(
    BuildContext context, {
    required String title,
    required String url,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      context.showAppSnackBar('링크를 열 수 없습니다.');
    }
  }

  Future<void> _openSupportMail(
    BuildContext context, {
    required String appVersion,
    required String uid,
  }) async {
    final subject = '[Walker홀릭] 문의';
    final body = '문의 내용을 적어주세요.\n\n앱 UID: $uid\n앱 버전: $appVersion';
    // Some email clients show `+` literally when the URI uses `application/x-www-form-urlencoded`.
    // Build a query string using percent-encoding (`%20`) instead.
    final uri = Uri.parse(
      'mailto:$_supportEmail'
      '?subject=${Uri.encodeQueryComponent(subject)}'
      '&body=${Uri.encodeQueryComponent(body)}',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        context.showAppSnackBar('메일 앱을 열 수 없습니다');
      }
    } catch (_) {
      if (context.mounted) {
        context.showAppSnackBar('메일 앱 열기 실패');
      }
    }
  }

  Future<void> _showDeleteAccountDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
        title: Row(
          children: [
            const Expanded(child: Text('계정 삭제(탈퇴)')),
            IconButton(
              tooltip: '닫기',
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: const Text(
          'Walker홀릭 서비스에서 탈퇴하면 모든 데이터가 삭제되며 복구할 수 없습니다.\n\n정말 탈퇴하시겠어요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '탈퇴하기',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) return;
      await user.delete();
      if (!context.mounted) return;
      context.go('/login');
    } catch (e) {
      if (!context.mounted) return;
      context.showAppSnackBar('계정 삭제 실패: 재로그인 후 다시 시도해주세요.');
    }
  }

  String _authProviderLabel(dynamic authUser) {
    try {
      final providers =
          (authUser?.providerData as List?)?.cast<dynamic>() ?? [];
      final ids = providers
          .map((p) => p.providerId?.toString())
          .whereType<String>();
      if (ids.contains('google.com')) return '구글로그인';
      if (ids.contains('apple.com')) return '애플로그인';
      if (ids.contains('password')) return '이메일';
      // Kakao via custom token can vary by setup (custom/oidc/etc). Keep a safe fallback.
      if (ids.any((id) => id.contains('kakao'))) return '카카오로그인';
    } catch (_) {
      // ignore
    }
    return '로그인';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final authUserAsync = ref.watch(authStateProvider);
    final userDocAsync = ref.watch(currentUserDocProvider);

    const appVersion = AppInfo.versionLabel;
    final uid = authUserAsync.valueOrNull?.uid ?? '(unknown)';

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
        final photoUrl =
            (userDoc?['photoUrl'] as String?)?.trim() ??
                authUser?.photoURL?.trim() ??
                '';
        final hasPhoto = photoUrl.isNotEmpty;
        final authDisplayName = authUser?.displayName?.trim();
        final authEmail = authUser?.email?.trim();
        final nickname =
            (userDoc?['nickname'] as String?)?.trim().isNotEmpty == true
            ? (userDoc?['nickname'] as String)
            : (authDisplayName?.isNotEmpty == true
                  ? authDisplayName!
                  : settings.profile.nickname);
        final email = (userDoc?['email'] as String?)?.trim().isNotEmpty == true
            ? (userDoc?['email'] as String)
            : (authEmail?.isNotEmpty == true
                  ? authEmail!
                  : settings.profile.email);
        final providerLabel = _authProviderLabel(authUser);

        return InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          onTap: () => context.push('/my/info'),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.gray200,
                backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                child: hasPhoto
                    ? null
                    : const Icon(Icons.person, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nickname, style: AppTypography.bodyLarge),
                    const SizedBox(height: 2),
                    Text(
                      email.trim().isEmpty ? '이메일 미제공' : email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                providerLabel,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('마이'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppTheme.screenPadding.add(
            const EdgeInsets.only(bottom: AppSpacing.paddingXXL),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.paddingMD),
                margin: EdgeInsets.zero,
                child: header,
              ),
              const SizedBox(height: AppSpacing.paddingXL),
              Text('계정', style: AppTypography.labelLarge),
              const SizedBox(height: AppSpacing.paddingSM),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.paddingMD),
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsTile(
                      title: '프로필',
                      onTap: () => context.push('/my/profile'),
                    ),
                    const Divider(height: 1),
                    _SettingsTile(
                      title: '알림',
                      onTap: () => context.push('/my/notifications'),
                    ),
                    const Divider(height: 1),
                    _SettingsTile(
                      title: '구독 관리',
                      onTap: () => context.push('/my/subscription'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.paddingXL),
              Text('정보', style: AppTypography.labelLarge),
              const SizedBox(height: AppSpacing.paddingSM),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.paddingMD),
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsTile(
                      title: '서비스 이용 약관',
                      onTap: () {
                        _launchExternal(
                          context,
                          title: '서비스 이용 약관',
                          url: 'https://doyakmin.com/news/terms-of-service',
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _SettingsTile(
                      title: '개인정보 처리 방침',
                      onTap: () {
                        _launchExternal(
                          context,
                          title: '개인정보 처리 방침',
                          url: 'https://doyakmin.com/news/privacy-policy',
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _SettingsTile(
                      title: '문의 하기',
                      subtitle: 'UID: $uid',
                      onTap: () {
                        _openSupportMail(
                          context,
                          appVersion: appVersion,
                          uid: uid,
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _SettingsTile(
                      title: '계정 삭제 요청(탈퇴)',
                      onTap: () => _showDeleteAccountDialog(context, ref),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.paddingXL),

              // 로그아웃 row (screenshot-like)
              AppCard(
                padding: EdgeInsets.zero,
                margin: EdgeInsets.zero,
                child: InkWell(
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
                        title: Row(
                          children: [
                            const Expanded(child: Text('로그아웃')),
                            IconButton(
                              tooltip: '닫기',
                              onPressed: () =>
                                  Navigator.of(context).pop(false),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
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
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: AppTypography.bodyLarge),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
