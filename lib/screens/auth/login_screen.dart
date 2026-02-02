import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../features/auth/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/widgets.dart';

/// 로그인 화면
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  Future<void> _handleKakaoLogin() async {
    await ref.read(authControllerProvider.notifier).signInWithKakao();
  }

  Future<void> _handleGoogleLogin() async {
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
  }

  Future<void> _handleAppleLogin() async {
    await ref.read(authControllerProvider.notifier).signInWithApple();
  }

  void _navigateToSignup() {
    // Avoid carrying password around if the user goes to signup.
    _passwordController.clear();
    context.push('/signup');
  }

  @override
  Widget build(BuildContext context) {
    // Listen in build (Riverpod constraint) to avoid stale reads / races.
    ref.listen<AsyncValue<void>>(authControllerProvider, (prev, next) {
      next.whenOrNull(
        data: (_) {
          if (!mounted) return;
          _passwordController.clear();
          context.go('/home');
        },
        error: (e, st) {
          if (!mounted) return;
          final msg = friendlyAuthError(e);
          context.showAppSnackBar(msg);
        },
      );
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    const kakaoKey = String.fromEnvironment(
      'KAKAO_NATIVE_APP_KEY',
      defaultValue: '',
    );
    final isKakaoSupported =
        (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) &&
        kakaoKey.isNotEmpty;
    final isGoogleSupported =
        kIsWeb || defaultTargetPlatform != TargetPlatform.macOS;
    final isAppleSupported =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppTheme.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.paddingXXL),

                // 로고 & 타이틀
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary50,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusLG,
                          ),
                        ),
                        child: const Icon(
                          Icons.place,
                          size: 48,
                          color: AppColors.primary500,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.paddingLG),
                      Text('Walker홀릭', style: AppTypography.h2),
                      const SizedBox(height: AppSpacing.paddingSM),
                      Text(
                        '걸으며 쿠폰을 얻고 사용해요',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.paddingXXL),

                // 이메일 입력
                AppInput(
                  label: '이메일',
                  placeholder: 'example@email.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '이메일을 입력해주세요';
                    }
                    if (!value.contains('@')) {
                      return '올바른 이메일 형식이 아닙니다';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.paddingMD),

                // 비밀번호 입력
                AppPasswordInput(
                  label: '비밀번호',
                  placeholder: '비밀번호를 입력하세요',
                  controller: _passwordController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호를 입력해주세요';
                    }
                    if (value.length < 6) {
                      return '비밀번호는 최소 6자 이상이어야 합니다';
                    }
                    return null;
                  },
                  onSubmitted: (_) => _handleLogin(),
                ),

                const SizedBox(height: AppSpacing.paddingXL),

                // 로그인 버튼
                AppButton(
                  text: '로그인',
                  onPressed: _handleLogin,
                  isLoading: isLoading,
                  isFullWidth: true,
                ),

                const SizedBox(height: AppSpacing.paddingMD),

                // 구분선
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.paddingMD,
                      ),
                      child: Text(
                        '또는',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: AppSpacing.paddingMD),

                // 카카오 로그인
                KakaoLoginButton(
                  onPressed: isKakaoSupported ? _handleKakaoLogin : null,
                  isLoading: isLoading,
                ),
                const SizedBox(height: AppSpacing.paddingMD),

                // Google 로그인
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: (isGoogleSupported && !isLoading)
                        ? () {
                            _handleGoogleLogin();
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.paddingSM,
                        horizontal: AppSpacing.paddingMD,
                      ),
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.gray200),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMD,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/google_g.svg',
                          width: 18,
                          height: 18,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: AppSpacing.paddingSM),
                        Text('Google로 계속하기', style: AppTypography.bodyMedium),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.paddingMD),

                // Apple 로그인 (iOS/macOS only)
                if (isAppleSupported)
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: Opacity(
                      opacity: (!isLoading) ? 1 : 0.5,
                      child: SignInWithAppleButton(
                        onPressed: () {
                          if (isLoading) return;
                          _handleAppleLogin();
                        },
                        style: SignInWithAppleButtonStyle.black,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMD,
                        ),
                        text: 'Apple로 계속하기',
                      ),
                    ),
                  ),
                if (!isKakaoSupported) ...[
                  const SizedBox(height: AppSpacing.paddingSM),
                  Text(
                    defaultTargetPlatform == TargetPlatform.macOS
                        ? 'macOS에서는 카카오 로그인이 지원되지 않습니다. (Android/iOS에서 테스트해주세요)'
                        : '카카오 키가 설정되지 않았습니다. `--dart-define=KAKAO_NATIVE_APP_KEY=...`로 실행해주세요.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (!isGoogleSupported) ...[
                  const SizedBox(height: AppSpacing.paddingSM),
                  Text(
                    'macOS에서는 Google 로그인이 지원되지 않습니다. (iOS/Android에서 테스트해주세요)',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (!isAppleSupported) const SizedBox.shrink(),

                const SizedBox(height: AppSpacing.paddingXL),

                // 회원가입 링크
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '계정이 없으신가요?',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: _navigateToSignup,
                      child: const Text('회원가입'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
