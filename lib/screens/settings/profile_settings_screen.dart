import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';

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
import '../../widgets/app_snackbar.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nicknameController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;

  Gender? _gender;
  bool _didHydrate = false;
  bool _isPhotoFlowInProgress = false;
  bool _isUploadingPhoto = false;

  String _friendlyUploadError(Object error) {
    if (error is FirebaseException) {
      // firebase_storage uses `FirebaseException` with plugin="firebase_storage"
      final code = error.code.trim();
      return switch (code) {
        'unauthorized' || 'permission-denied' =>
          '저장소 권한이 없어서 업로드할 수 없어요.',
        'invalid-argument' => '업로드 요청이 올바르지 않아요. (메타데이터 설정 문제)',
        'canceled' => '업로드가 취소되었습니다.',
        'unknown' => '업로드 중 알 수 없는 오류가 발생했어요.',
        'object-not-found' =>
          '저장소에서 파일을 찾을 수 없어요. 잠시 후 다시 시도해주세요.',
        _ => '업로드 실패: $code',
      };
    }
    return '프로필 사진 업로드에 실패했습니다.';
  }

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
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
    final heightCm = int.tryParse(_heightController.text.trim());
    final weightKg = int.tryParse(_weightController.text.trim());
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
          heightCm: heightCm,
          weightKg: weightKg,
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
        context.showAppSnackBar('프로필 저장 실패: $e');
      }
      return;
    }

    if (mounted) {
      context.showAppSnackBar('저장되었습니다');
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_isPhotoFlowInProgress) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      context.showAppSnackBar('로그인이 필요합니다');
      return;
    }

    setState(() => _isPhotoFlowInProgress = true);
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (picked == null) return;

      final originalBytes = await XFile(picked.path).readAsBytes();
      if (!mounted) return;

      final croppedBytes = await Navigator.of(context).push<Uint8List?>(
        MaterialPageRoute(
          builder: (context) => _InlineCropScreen(imageBytes: originalBytes),
          fullscreenDialog: true,
        ),
      );
      if (!mounted) return;
      if (croppedBytes == null) return;

      setState(() => _isUploadingPhoto = true);
      final storage = FirebaseStorage.instance;
      final storageRef = storage.ref()
          .child('users')
          .child(user.uid)
          .child('profile.png');

      await storageRef.putData(
        croppedBytes,
        SettableMetadata(
          contentType: 'image/png',
        ),
      );

      // Use the SDK-provided download URL.
      // NOTE: Do NOT set `firebaseStorageDownloadTokens` from the client.
      // It is reserved and will cause HTTP 400.
      final url = await storageRef.getDownloadURL();

      await ref.read(usersRepositoryProvider).updateProfile(
            uid: user.uid,
            photoUrl: url,
          );
      try {
        await user.updatePhotoURL(url);
      } catch (_) {
        // ignore
      }

      // Keep `public_users` in sync for friend UI (best-effort).
      try {
        await ref.read(friendsRepositoryProvider).ensurePublicProfile();
      } catch (_) {
        // ignore
      }

      if (!mounted) return;
      context.showAppSnackBar('프로필 사진이 변경되었습니다');
    } catch (e) {
      if (!mounted) return;
      context.showAppSnackBar(_friendlyUploadError(e));
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
          _isPhotoFlowInProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final userDoc = ref.watch(currentUserDocProvider).valueOrNull;
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final photoUrl =
        (userDoc?['photoUrl'] as String?)?.trim() ??
            authUser?.photoURL?.trim() ??
            '';
    final hasPhoto = photoUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('프로필')),
      bottomNavigationBar: settingsAsync.whenOrNull(
        data: (settings) {
          final p = settings.profile;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.paddingLG,
                AppSpacing.paddingSM,
                AppSpacing.paddingLG,
                AppSpacing.paddingMD,
              ),
              child: AppButton(
                text: '저장',
                isFullWidth: true,
                onPressed: () => _save(p),
              ),
            ),
          );
        },
      ),
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
            final docHeight = userDoc?['heightCm'];
            final docWeight = userDoc?['weightKg'];

            _nicknameController.text =
                (docNickname?.isNotEmpty == true) ? docNickname! : p.nickname;

            _gender = _parseGender(docGender) ?? p.gender;
            if (docHeight is num) _heightController.text = docHeight.round().toString();
            if (docWeight is num) _weightController.text = docWeight.round().toString();
            _didHydrate = true;
          }
          final birthYear = (userDoc?['birthdate'] as String?)?.trim() ?? '';
          final birthYearLabel = birthYear.isNotEmpty ? '$birthYear년' : '미설정';
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
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.gray200,
                          backgroundImage:
                              hasPhoto ? NetworkImage(photoUrl) : null,
                          child: hasPhoto
                              ? null
                              : const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: AppColors.textSecondary,
                                ),
                        ),
                        if (_isUploadingPhoto)
                          const Positioned.fill(
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusFull),
                            onTap: _pickAndUploadPhoto,
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
                        AppInput(
                          label: '키 (cm)',
                          placeholder: '예: 170',
                          controller: _heightController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            final value = int.tryParse((v ?? '').trim());
                            if (value == null) return '키(cm)를 입력해주세요';
                            if (value < 80 || value > 230) return '키는 80~230cm 범위';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.paddingMD),
                        AppInput(
                          label: '몸무게 (kg)',
                          placeholder: '예: 65',
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            final value = int.tryParse((v ?? '').trim());
                            if (value == null) return '몸무게(kg)를 입력해주세요';
                            if (value < 20 || value > 250) return '몸무게는 20~250kg 범위';
                            return null;
                          },
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
                                      context.showAppSnackBar(
                                        '인증 메일을 보냈습니다. 메일함을 확인해주세요.',
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InlineCropScreen extends StatefulWidget {
  const _InlineCropScreen({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_InlineCropScreen> createState() => _InlineCropScreenState();
}

class _InlineCropScreenState extends State<_InlineCropScreen> {
  final _controller = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('프로필 사진 편집'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (canPop) Navigator.of(context).pop(null);
          },
        ),
        actions: [
          TextButton(
            onPressed: _isCropping
                ? null
                : () {
                    setState(() => _isCropping = true);
                    _controller.crop();
                  },
            child: const Text('완료'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Crop(
                controller: _controller,
                image: widget.imageBytes,
                onCropped: (result) {
                  if (!mounted) return;
                  setState(() => _isCropping = false);
                  switch (result) {
                    case CropSuccess(:final croppedImage):
                      Navigator.of(context).pop(croppedImage);
                      break;
                    case CropFailure(:final cause):
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('이미지 자르기 실패: $cause')),
                      );
                      Navigator.of(context).pop(null);
                      break;
                  }
                },
                withCircleUi: true,
                aspectRatio: 1,
                baseColor: Colors.white,
                maskColor: Colors.black.withValues(alpha: 0.35),
                radius: 0,
              ),
            ),
            if (_isCropping)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
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
          initialValue: value,
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
