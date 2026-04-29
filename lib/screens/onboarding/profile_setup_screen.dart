import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/settings/settings_model.dart';
import '../../features/settings/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_input.dart';
import '../../widgets/app_snackbar.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key, this.from});

  final String? from;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  Gender? _gender;
  bool _didHydrate = false;

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  String? _validateHeight(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return null; // 선택사항
    final n = int.tryParse(v);
    if (n == null || n < 80 || n > 230) return '키는 80~230cm 범위로 입력해주세요';
    return null;
  }

  String? _validateWeight(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return null; // 선택사항
    final n = int.tryParse(v);
    if (n == null || n < 20 || n > 250) return '몸무게는 20~250kg 범위로 입력해주세요';
    return null;
  }

  void _skip() {
    final next = (widget.from?.trim().isNotEmpty == true) ? widget.from! : '/home';
    context.go(next);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      context.showAppSnackBar('로그인이 필요합니다');
      return;
    }

    final gender = _gender;
    final heightRaw = _heightController.text.trim();
    final weightRaw = _weightController.text.trim();
    final heightCm = int.tryParse(heightRaw);
    final weightKg = int.tryParse(weightRaw);

    try {
      await ref.read(usersRepositoryProvider).updateProfile(
            uid: user.uid,
            gender: gender?.name,
            heightCm: heightCm,
            weightKg: weightKg,
          );

      // Keep local settings in sync (best-effort).
      if (gender != null) {
        final current = ref.read(settingsControllerProvider).valueOrNull;
        if (current != null) {
          final next = current.profile.copyWith(gender: gender);
          await ref.read(settingsControllerProvider.notifier).updateProfile(next);
        }
      }
    } catch (e) {
      if (!mounted) return;
      context.showAppSnackBar('저장에 실패했습니다. 네트워크 상태를 확인해주세요.');
      return;
    }

    if (!mounted) return;
    final next = (widget.from?.trim().isNotEmpty == true) ? widget.from! : '/home';
    context.go(next);
  }

  @override
  Widget build(BuildContext context) {
    final userDoc = ref.watch(currentUserDocProvider).valueOrNull;

    if (!_didHydrate) {
      _didHydrate = true;
      final rawGender = (userDoc?['gender'] as String?)?.trim();
      _gender = Gender.values.where((g) => g.name == rawGender).firstOrNull;
      final h = userDoc?['heightCm'];
      final w = userDoc?['weightKg'];
      if (h is num) _heightController.text = h.round().toString();
      if (w is num) _weightController.text = w.round().toString();
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.gray50,
        appBar: AppBar(
          title: const Text('정보 설정'),
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: _skip,
              child: const Text('건너뛰기'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: AppTheme.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.paddingMD),
                  margin: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('맞춤 추천을 위한 정보 (선택)', style: AppTypography.h5),
                      const SizedBox(height: 8),
                      Text(
                        '성별·키·몸무게 정보를 입력하시면 걸음 수 기반 칼로리를 '
                        '더 정확하게 추정할 수 있습니다.\n'
                        '입력하지 않아도 앱을 이용할 수 있으며, 언제든 설정에서 변경 가능합니다.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.paddingMD),
                  margin: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('성별 (선택)', style: AppTypography.labelMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _GenderChip(
                            label: '남성',
                            selected: _gender == Gender.male,
                            onTap: () => setState(() => _gender = Gender.male),
                          ),
                          _GenderChip(
                            label: '여성',
                            selected: _gender == Gender.female,
                            onTap: () => setState(() => _gender = Gender.female),
                          ),
                          _GenderChip(
                            label: '기타',
                            selected: _gender == Gender.other,
                            onTap: () => setState(() => _gender = Gender.other),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppInput(
                        label: '키 (cm) (선택)',
                        placeholder: '예: 170',
                        controller: _heightController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: _validateHeight,
                      ),
                      const SizedBox(height: 12),
                      AppInput(
                        label: '몸무게 (kg) (선택)',
                        placeholder: '예: 65',
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: _validateWeight,
                        onSubmitted: (_) => _submit(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: '저장하고 시작하기',
                  isFullWidth: true,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary100 : AppColors.gray100;
    final fg = selected ? AppColors.primary900 : AppColors.textSecondary;
    final border = selected ? AppColors.primary500 : AppColors.border;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: border),
        ),
        child: Text(label, style: AppTypography.labelMedium.copyWith(color: fg)),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

