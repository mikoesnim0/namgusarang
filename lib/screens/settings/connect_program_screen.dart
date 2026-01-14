import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class ConnectProgramScreen extends StatelessWidget {
  const ConnectProgramScreen({super.key});

  static const _supportEmail = 'support@namgusarang.app';
  static const _inviteLink = 'https://namgusarang.app/invite/ABC123';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('연결 프로그램')),
      body: SingleChildScrollView(
        padding: AppTheme.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('연결 프로그램', style: AppTypography.labelLarge),
                  const SizedBox(height: 8),
                  Text(
                    '메일/공유 같은 OS 기능을 통해 외부 앱과 연결합니다.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    text: '문의하기 (메일 열기)',
                    isFullWidth: true,
                    onPressed: () => _openMail(context),
                    icon: const Icon(Icons.mail_outline, size: 20),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    text: '초대 링크 공유하기',
                    variant: ButtonVariant.outline,
                    isFullWidth: true,
                    onPressed: () => _shareInvite(context),
                    icon: const Icon(Icons.ios_share, size: 20),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    text: '초대 링크 복사',
                    variant: ButtonVariant.outline,
                    isFullWidth: true,
                    onPressed: () => _copyInvite(context),
                    icon: const Icon(Icons.copy, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('연결된 프로그램', style: AppTypography.labelLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: const [
                      _ProgramIcon(label: 'Gmail', icon: Icons.mail),
                      _ProgramIcon(label: 'Outlook', icon: Icons.mail_outline),
                      _ProgramIcon(label: '캘린더', icon: Icons.calendar_month),
                      _ProgramIcon(label: '메시지', icon: Icons.message),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '※ 실제 “연결 상태”는 향후 백엔드/딥링크 정책 확정 후 저장합니다.',
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
    );
  }

  Future<void> _openMail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': '[Walker홀릭] 문의',
        'body': '문의 내용을 적어주세요.\n\n(앱 버전: v1.0.0)',
      },
    );

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메일 앱을 열 수 없습니다')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메일 앱 열기 실패')),
        );
      }
    }
  }

  Future<void> _shareInvite(BuildContext context) async {
    try {
      await Share.share('Walker홀릭 초대 링크: $_inviteLink');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공유 기능을 사용할 수 없습니다')),
        );
      }
    }
  }

  Future<void> _copyInvite(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _inviteLink));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초대 링크를 복사했습니다')),
      );
    }
  }
}

class _ProgramIcon extends StatelessWidget {
  const _ProgramIcon({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.labelSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

