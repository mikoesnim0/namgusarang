import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hangookji_namgu/features/auth/auth_providers.dart';
import '../../features/settings/settings_model.dart';
import '../../features/settings/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_input.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nicknameController;
  late final TextEditingController _emailController;

  AgeRange? _ageRange;
  Gender? _gender;
  bool _didHydrate = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  AgeRange? _parseAgeRange(String? raw) {
    if (raw == null) return null;
    for (final v in AgeRange.values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  Gender? _parseGender(String? raw) {
    if (raw == null) return null;
    for (final v in Gender.values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  Future<void> _save(ProfileSettings current) async {
    if (!_formKey.currentState!.validate()) return;
    final next = current.copyWith(
      nickname: _nicknameController.text.trim(),
      email: _emailController.text.trim(),
      ageRange: _ageRange ?? current.ageRange,
      gender: _gender ?? current.gender,
    );
    await ref.read(settingsControllerProvider.notifier).updateProfile(next);

    // Also sync to Firestore user profile (so signup/profile reflect real user data).
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user != null) {
        final users = ref.read(usersRepositoryProvider);
        final nickname = next.nickname.trim();
        final available = await users.isNicknameAvailable(
          nickname,
          ignoreUid: user.uid,
        );
        if (!available) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('이미 사용 중인 닉네임입니다. 다른 닉네임을 선택해주세요.')),
            );
          }
          return;
        }
        await users.updateProfile(
          uid: user.uid,
          nickname: nickname,
          gender: next.gender.name,
          ageRange: next.ageRange.name,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로필 저장 실패: $e')),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장되었습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final userDoc = ref.watch(currentUserDocProvider).valueOrNull;
    final authUser = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('프로필')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: AppTheme.screenPadding,
          child: Text('설정 로딩 실패: $e', style: AppTypography.bodyMedium),
        ),
        data: (settings) {
          final p = settings.profile;
          if (!_didHydrate) {
            final docNickname = (userDoc?['nickname'] as String?)?.trim();
            final docEmail = (userDoc?['email'] as String?)?.trim();
            final docAgeRange = userDoc?['ageRange'] as String?;
            final docGender = userDoc?['gender'] as String?;

            _nicknameController.text =
                (docNickname?.isNotEmpty == true) ? docNickname! : p.nickname;
            _emailController.text = (docEmail?.isNotEmpty == true)
                ? docEmail!
                : (authUser?.email?.trim().isNotEmpty == true
                    ? authUser!.email!.trim()
                    : p.email);

            _ageRange = _parseAgeRange(docAgeRange) ?? p.ageRange;
            _gender = _parseGender(docGender) ?? p.gender;
            _didHydrate = true;
          }
          return SingleChildScrollView(
            padding: AppTheme.screenPadding,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.paddingMD),
                    child: Column(
                      children: [
                        AppInput(
                          label: '닉네임',
                          placeholder: '닉네임을 입력해주세요.',
                          controller: _nicknameController,
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return '닉네임을 입력해주세요';
                            if (value.length < 2) return '닉네임은 2자 이상';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.paddingMD),
                        AppInput(
                          label: '이메일',
                          placeholder: 'abcd@gmail.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return '이메일을 입력해주세요';
                            if (!value.contains('@')) return '올바른 이메일 형식이 아닙니다';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.paddingMD),
                        _DropdownRow<AgeRange>(
                          label: '연령대',
                          value: _ageRange ?? p.ageRange,
                          items: AgeRange.values,
                          itemLabel: (v) => switch (v) {
                            AgeRange.teen => '10대',
                            AgeRange.twenties => '20대',
                            AgeRange.thirties => '30대',
                            AgeRange.forties => '40대',
                            AgeRange.fiftiesPlus => '50대+',
                          },
                          onChanged: (v) => setState(() => _ageRange = v),
                        ),
                        const SizedBox(height: AppSpacing.paddingMD),
                        _DropdownRow<Gender>(
                          label: '성별',
                          value: _gender ?? p.gender,
                          items: Gender.values,
                          itemLabel: (v) => switch (v) {
                            Gender.male => '남성',
                            Gender.female => '여성',
                            Gender.other => '기타',
                          },
                          onChanged: (v) => setState(() => _gender = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.paddingXL),
                  AppButton(
                    text: '저장',
                    isFullWidth: true,
                    onPressed: () => _save(p),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelMedium),
        const SizedBox(height: AppSpacing.paddingSM),
        DropdownButtonFormField<T>(
          value: value,
          decoration: const InputDecoration(),
          items: items
              .map(
                (v) => DropdownMenuItem<T>(
                  value: v,
                  child: Text(itemLabel(v)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

