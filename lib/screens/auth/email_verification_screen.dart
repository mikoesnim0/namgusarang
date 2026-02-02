import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/auth_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_snackbar.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key, this.from});

  final String? from;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _sending = false;
  bool _checking = false;
  DateTime? _lastSentAt;

  bool get _canResend {
    final last = _lastSentAt;
    if (last == null) return true;
    return DateTime.now().difference(last) > const Duration(seconds: 30);
  }

  Future<void> _resend() async {
    if (_sending) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!_canResend) {
      context.showAppSnackBar('잠시 후 다시 시도해주세요.');
      return;
    }

    setState(() => _sending = true);
    try {
      await user.sendEmailVerification();
      _lastSentAt = DateTime.now();
      if (!mounted) return;
      context.showAppSnackBar('인증 메일을 다시 보냈습니다.');
    } catch (e) {
      if (!mounted) return;
      context.showAppSnackBar(friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _refreshAndContinue() async {
    if (_checking) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _checking = true);
    try {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed?.emailVerified != true) {
        if (!mounted) return;
        context.showAppSnackBar('아직 인증이 확인되지 않았습니다. 메일함을 확인해주세요.');
        return;
      }
      if (!mounted) return;
      final next =
          (widget.from?.trim().isNotEmpty == true) ? widget.from! : '/home';
      context.go(next);
    } catch (e) {
      if (!mounted) return;
      context.showAppSnackBar(friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openMailApp() async {
    // iOS has no official "open inbox" URL; `mailto:` is the safest cross-platform nudge.
    final uri = Uri(scheme: 'mailto', path: '');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        context.showAppSnackBar('메일 앱을 열 수 없습니다.');
      }
    } catch (_) {
      if (mounted) context.showAppSnackBar('메일 앱을 열 수 없습니다.');
    }
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final email = authUser?.email?.trim() ?? '';

    // If user got verified in the background, auto-advance.
    if (authUser?.emailVerified == true) {
      unawaited(() async {
        final next = (widget.from?.trim().isNotEmpty == true)
            ? widget.from!
            : '/home';
        if (mounted) context.go(next);
      }());
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.gray50,
        appBar: AppBar(
          title: const Text('이메일 인증'),
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: AppTheme.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.paddingMD),
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('계정 보호를 위해 인증이 필요해요', style: AppTypography.h5),
                    const SizedBox(height: 8),
                    Text(
                      '가입하신 이메일로 인증 메일을 보냈습니다.\n'
                      '메일함에서 인증을 완료한 뒤 “인증 완료 확인”을 눌러주세요.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('이메일: $email', style: AppTypography.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                text: '인증 완료 확인',
                isLoading: _checking,
                isFullWidth: true,
                onPressed: _refreshAndContinue,
              ),
              const SizedBox(height: 8),
              AppButton(
                text: '인증 메일 다시 보내기',
                variant: ButtonVariant.outline,
                isLoading: _sending,
                isFullWidth: true,
                onPressed: _resend,
              ),
              const SizedBox(height: 8),
              AppButton(
                text: '메일 앱 열기',
                variant: ButtonVariant.text,
                isFullWidth: true,
                onPressed: _openMailApp,
              ),
              const SizedBox(height: 12),
              AppButton(
                text: '로그아웃',
                variant: ButtonVariant.outline,
                isFullWidth: true,
                onPressed: _signOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

