import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/coupons/coupon_model.dart';
import '../../features/coupons/coupons_provider.dart';
import '../../features/settings/settings_provider.dart';
import '../../features/auth/auth_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class CouponsScreen extends ConsumerWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupons = ref.watch(visibleCouponsProvider);
    final filter = ref.watch(couponFilterProvider);
    final sort = ref.watch(couponSortProvider);
    final settingsAsync = ref.watch(settingsControllerProvider);
    final userDoc = ref.watch(currentUserDocProvider).valueOrNull;
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final settingsNickname = settingsAsync.valueOrNull?.profile.nickname;
    final docNickname = (userDoc?['nickname'] as String?)?.trim();
    final authNickname = authUser?.displayName?.trim();
    final nickname = (docNickname?.isNotEmpty == true)
        ? docNickname!
        : (authNickname?.isNotEmpty == true)
            ? authNickname!
            : (settingsNickname?.trim().isNotEmpty == true)
                ? settingsNickname!.trim()
                : '닉네임';

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  onTap: () => context.push('/my/info'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.gray200,
                        child:
                            Icon(Icons.person, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Align(
                alignment: Alignment.center,
                child: Text('쿠폰함'),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: AppTheme.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(
                      label: '전체',
                      selected: filter == CouponFilter.all,
                      onTap: () =>
                          ref.read(couponFilterProvider.notifier).state =
                              CouponFilter.all,
                    ),
                    _Chip(
                      label: '사용 가능',
                      selected: filter == CouponFilter.active,
                      onTap: () =>
                          ref.read(couponFilterProvider.notifier).state =
                              CouponFilter.active,
                    ),
                    _Chip(
                      label: '사용 완료',
                      selected: filter == CouponFilter.used,
                      onTap: () =>
                          ref.read(couponFilterProvider.notifier).state =
                              CouponFilter.used,
                    ),
                    _Chip(
                      label: '만료',
                      selected: filter == CouponFilter.expired,
                      onTap: () =>
                          ref.read(couponFilterProvider.notifier).state =
                              CouponFilter.expired,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('정렬', style: AppTypography.labelMedium),
                    const SizedBox(width: 8),
                    DropdownButton<CouponSort>(
                      value: sort,
                      items: const [
                        DropdownMenuItem(
                          value: CouponSort.expiresSoon,
                          child: Text('만료 임박'),
                        ),
                        DropdownMenuItem(
                          value: CouponSort.expiresLate,
                          child: Text('만료 여유'),
                        ),
                        DropdownMenuItem(
                          value: CouponSort.title,
                          child: Text('이름'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        ref.read(couponSortProvider.notifier).state = v;
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: AppTheme.screenPadding.copyWith(bottom: 120),
              itemCount: coupons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final c = coupons[idx];
                return AppCard(
                  padding: const EdgeInsets.all(AppSpacing.paddingMD),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary100,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                        ),
                        child: Icon(
                          Icons.confirmation_number,
                          color:
                              c.isActive ? AppColors.primary700 : AppColors.gray500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child:
                                      Text(c.title, style: AppTypography.bodyLarge),
                                ),
                                _StatusBadge(status: c.status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(c.description, style: AppTypography.bodySmall),
                            const SizedBox(height: 8),
                            Text(
                              '만료: ${_formatDate(c.expiresAt)}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    text: c.isActive ? '사용하기' : '사용 불가',
                                    variant: c.isActive
                                        ? ButtonVariant.primary
                                        : ButtonVariant.outline,
                                    isFullWidth: true,
                                    onPressed: c.isActive
                                        ? () => showModalBottomSheet<void>(
                                              context: context,
                                              isScrollControlled: true,
                                              builder: (_) =>
                                                  _RedeemSheet(coupon: c),
                                            )
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final CouponStatus status;

  @override
  Widget build(BuildContext context) {
    final (text, bg, fg) = switch (status) {
      CouponStatus.active => ('사용 가능', AppColors.primary100, AppColors.primary900),
      CouponStatus.used => ('사용 완료', AppColors.gray100, AppColors.gray800),
      CouponStatus.expired => ('만료', AppColors.gray100, AppColors.gray800),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(text, style: AppTypography.labelSmall.copyWith(color: fg)),
    );
  }
}

class _RedeemSheet extends ConsumerStatefulWidget {
  const _RedeemSheet({required this.coupon});

  final Coupon coupon;

  @override
  ConsumerState<_RedeemSheet> createState() => _RedeemSheetState();
}

class _RedeemSheetState extends ConsumerState<_RedeemSheet> {
  String? _error;
  String _code = '';

  void _submit() {
    final code = _code;
    final ok = ref.read(couponsControllerProvider.notifier).redeem(
          couponId: widget.coupon.id,
          inputCode: code,
        );

    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('쿠폰이 사용 처리되었습니다')),
      );
      return;
    }

    setState(() {
      _error = '코드가 올바르지 않습니다 (4자리 숫자)';
      _code = '';
    });
  }

  void _append(int digit) {
    if (_code.length >= 4) return;
    setState(() {
      _error = null;
      _code = '$_code$digit';
    });
    if (_code.length == 4) {
      // Auto-submit feels close to kiosk-style UX
      _submit();
    }
  }

  void _backspace() {
    if (_code.isEmpty) return;
    setState(() {
      _error = null;
      _code = _code.substring(0, _code.length - 1);
    });
  }

  void _clear() {
    setState(() {
      _error = null;
      _code = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.paddingMD,
        right: AppSpacing.paddingMD,
        top: AppSpacing.paddingMD,
        bottom: bottom + AppSpacing.paddingMD,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.coupon.title, style: AppTypography.h4),
          const SizedBox(height: 8),
          Text(
            '매장에서 4자리 인증 코드를 입력해주세요.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: 12),
          _PinRow(code: _code),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: 12),
          _Keypad(
            onDigit: _append,
            onBackspace: _backspace,
            onClear: _clear,
          ),
          const SizedBox(height: 8),
          AppButton(
            text: '닫기',
            variant: ButtonVariant.text,
            isFullWidth: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary100 : AppColors.gray100,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: selected ? AppColors.primary900 : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PinRow extends StatelessWidget {
  const _PinRow({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final chars = code.split('');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < chars.length;
        return Container(
          width: 44,
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            border: Border.all(
              color: filled ? AppColors.primary500 : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Text(
            filled ? chars[i] : '',
            style: AppTypography.h3,
          ),
        );
      }),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    Widget btn({
      required Widget child,
      required VoidCallback onPressed,
    }) {
      return InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      );
    }

    return Column(
      children: [
        for (final row in const [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                for (final n in row) ...[
                  Expanded(
                    child: btn(
                      child: Text('$n', style: AppTypography.h4),
                      onPressed: () => onDigit(n),
                    ),
                  ),
                  if (n != row.last) const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: btn(
                child: Text('전체삭제', style: AppTypography.bodyMedium),
                onPressed: onClear,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: btn(
                child: Text('0', style: AppTypography.h4),
                onPressed: () => onDigit(0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: btn(
                child: const Icon(Icons.backspace_outlined),
                onPressed: onBackspace,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
