import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/widgets.dart';
import '../../features/auth/auth_controller.dart';

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

    await ref.read(authControllerProvider.notifier).signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    final st = ref.read(authControllerProvider);
    st.whenOrNull(
      data: (_) => context.go('/home'),
      error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyAuthError(e))),
      ),
    );
  }

  Future<void> _handleKakaoLogin() async {
    await ref.read(authControllerProvider.notifier).signInWithKakao();
    final st = ref.read(authControllerProvider);
    st.whenOrNull(
      data: (_) => context.go('/home'),
      error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyAuthError(e))),
      ),
    );
  }

  void _navigateToSignup() {
    context.push('/signup');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

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
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLG),
                        ),
                        child: const Icon(
                          Icons.place,
                          size: 48,
                          color: AppColors.primary500,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.paddingLG),
                      Text(
                        '남구이야기',
                        style: AppTypography.h2,
                      ),
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
                AppButton(
                  text: '카카오로 로그인',
                  onPressed: _handleKakaoLogin,
                  variant: ButtonVariant.secondary,
                  isLoading: isLoading,
                  isFullWidth: true,
                  icon: const Icon(Icons.chat_bubble, size: 20),
                ),

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

