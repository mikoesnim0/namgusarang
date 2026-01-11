import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  void _hydrate(ProfileSettings p) {
    _nicknameController.text = p.nickname;
    _emailController.text = p.email;
    _ageRange ??= p.ageRange;
    _gender ??= p.gender;
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장되었습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);

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
          _hydrate(p);
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

