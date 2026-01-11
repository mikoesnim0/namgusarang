import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/widgets.dart';
import '../../features/auth/auth_controller.dart';

/// 회원가입 화면
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _birthdateController = TextEditingController();
  
  String _selectedGender = '';
  bool _termsAgreed = false;
  bool _privacyAgreed = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nicknameController.dispose();
    _birthdateController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_termsAgreed || !_privacyAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('약관에 동의해주세요')),
      );
      return;
    }

    if (_selectedGender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('성별을 선택해주세요')),
      );
      return;
    }

    await ref.read(authControllerProvider.notifier).signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          nickname: _nicknameController.text.trim(),
          birthdate: _birthdateController.text.trim(),
          gender: _selectedGender,
        );
    final st = ref.read(authControllerProvider);
    st.whenOrNull(
      data: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입이 완료되었습니다!')),
        );
        context.go('/home');
      },
      error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyAuthError(e))),
      ),
    );
  }

  Future<void> _selectBirthdate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary500,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthdateController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppTheme.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.paddingLG),

                // 이메일
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

                // 비밀번호
                AppPasswordInput(
                  label: '비밀번호',
                  placeholder: '비밀번호 (최소 6자)',
                  controller: _passwordController,
                  hint: '영문, 숫자 포함 6자 이상',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호를 입력해주세요';
                    }
                    if (value.length < 6) {
                      return '비밀번호는 최소 6자 이상이어야 합니다';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.paddingMD),

                // 비밀번호 확인
                AppPasswordInput(
                  label: '비밀번호 확인',
                  placeholder: '비밀번호 재입력',
                  controller: _passwordConfirmController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호를 다시 입력해주세요';
                    }
                    if (value != _passwordController.text) {
                      return '비밀번호가 일치하지 않습니다';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.paddingMD),

                // 닉네임
                AppInput(
                  label: '닉네임',
                  placeholder: '사용할 닉네임',
                  controller: _nicknameController,
                  textInputAction: TextInputAction.next,
                  hint: '중복되지 않는 닉네임을 입력하세요',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '닉네임을 입력해주세요';
                    }
                    if (value.length < 2) {
                      return '닉네임은 최소 2자 이상이어야 합니다';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.paddingMD),

                // 생년월일
                AppInput(
                  label: '생년월일',
                  placeholder: '1990-01-01',
                  controller: _birthdateController,
                  readOnly: true,
                  onTap: _selectBirthdate,
                  suffixIcon: const Icon(Icons.calendar_today),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '생년월일을 선택해주세요';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.paddingMD),

                // 성별
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '성별',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.paddingSM),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: '남성',
                            variant: _selectedGender == 'male'
                                ? ButtonVariant.primary
                                : ButtonVariant.outline,
                            onPressed: () {
                              setState(() {
                                _selectedGender = 'male';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.paddingMD),
                        Expanded(
                          child: AppButton(
                            text: '여성',
                            variant: _selectedGender == 'female'
                                ? ButtonVariant.primary
                                : ButtonVariant.outline,
                            onPressed: () {
                              setState(() {
                                _selectedGender = 'female';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.paddingXL),

                // 약관 동의
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.paddingMD),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        title: const Text('서비스 이용약관 동의 (필수)'),
                        value: _termsAgreed,
                        onChanged: (value) {
                          setState(() {
                            _termsAgreed = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      CheckboxListTile(
                        title: const Text('개인정보 처리방침 동의 (필수)'),
                        value: _privacyAgreed,
                        onChanged: (value) {
                          setState(() {
                            _privacyAgreed = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.paddingXL),

                // 회원가입 버튼
                AppButton(
                  text: '회원가입',
                  onPressed: _handleSignup,
                  isLoading: isLoading,
                  isFullWidth: true,
                  size: ButtonSize.large,
                ),

                const SizedBox(height: AppSpacing.paddingLG),

                // 로그인 링크
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '이미 계정이 있으신가요?',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        context.pop();
                      },
                      child: const Text('로그인'),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.paddingXL),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

