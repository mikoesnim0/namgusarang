import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hangookji_namgu/features/auth/auth_providers.dart';
import 'package:hangookji_namgu/features/friends/friends_provider.dart';
import '../../features/settings/settings_model.dart';
import '../../features/settings/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_colors.dart';
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

  Gender? _gender;
  bool _didHydrate = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
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
      gender: _gender ?? current.gender,
    );
    await ref.read(settingsControllerProvider.notifier).updateProfile(next);

    // Also sync to Firestore user profile (so signup/profile reflect real user data).
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user != null) {
        final users = ref.read(usersRepositoryProvider);
        final nickname = next.nickname.trim();
        await users.updateProfile(
          uid: user.uid,
          nickname: nickname,
          gender: next.gender.name,
        );

        // Keep `public_users` in sync for friend search (best-effort).
        try {
          await ref.read(friendsRepositoryProvider).ensurePublicProfile();
        } catch (_) {
          // ignore: do not block profile save
        }
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
            final docGender = userDoc?['gender'] as String?;

            _nicknameController.text =
                (docNickname?.isNotEmpty == true) ? docNickname! : p.nickname;

            _gender = _parseGender(docGender) ?? p.gender;
            _didHydrate = true;
          }
          final birthYear = (userDoc?['birthdate'] as String?)?.trim() ?? '';
          final birthYearLabel = birthYear.isNotEmpty ? '${birthYear}년' : '미설정';
          final email = (authUser?.email?.trim().isNotEmpty == true)
              ? authUser!.email!.trim()
              : ((userDoc?['email'] as String?)?.trim().isNotEmpty == true
                  ? (userDoc?['email'] as String)
                  : p.email);
          final emailVerified = authUser?.emailVerified ?? false;
          final hasEmail = email.trim().isNotEmpty;
          return SingleChildScrollView(
            padding: AppTheme.screenPadding,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        const CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.gray200,
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusFull),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('프로필 사진 업로드는 추후 제공됩니다.'),
                                ),
                              );
                            },
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.primary500,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.paddingLG),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.paddingMD),
                    margin: EdgeInsets.zero,
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
                          label: '연령대',
                          placeholder: '출생연도',
                          initialValue: birthYearLabel,
                          readOnly: true,
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
                  const SizedBox(height: AppSpacing.paddingMD),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.paddingMD),
                    margin: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('이메일', style: AppTypography.labelMedium),
                        const SizedBox(height: AppSpacing.paddingSM),
                        Text(
                          hasEmail ? email : '이메일 미제공',
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.paddingSM),
                        if (hasEmail)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  emailVerified
                                      ? '인증 완료'
                                      : '이메일 인증이 필요합니다',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: emailVerified
                                        ? AppColors.primary500
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (!emailVerified)
                                TextButton(
                                  onPressed: () async {
                                    final user = ref
                                        .read(authStateProvider)
                                        .valueOrNull;
                                    if (user == null) return;
                                    await user.sendEmailVerification();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '인증 메일을 보냈습니다. 메일함을 확인해주세요.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('인증 메일 보내기'),
                                ),
                            ],
                          )
                        else
                          Text(
                            '이메일이 연결되어 있지 않습니다.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
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
