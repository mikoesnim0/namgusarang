import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cloud_functions/cloud_functions.dart';

import '../../features/coupons/coupon_model.dart';
import '../../features/coupons/coupons_provider.dart';
import '../../features/home/home_model.dart';
import '../../features/home/home_provider.dart';
import '../../features/settings/settings_provider.dart';
import '../../features/auth/auth_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_snackbar.dart';

class CouponsScreen extends ConsumerStatefulWidget {
  const CouponsScreen({super.key});

  @override
  ConsumerState<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends ConsumerState<CouponsScreen> {
  late final TextEditingController _searchController;
  bool _didMarkSeen = false;
  String? _placeIdFilter;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uriPlaceId = GoRouterState.of(context).uri.queryParameters['placeId'];
    if (uriPlaceId != _placeIdFilter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _placeIdFilter = uriPlaceId);
      });
    }

    final couponsAsync = ref.watch(visibleCouponsProvider);
    final filter = ref.watch(couponFilterProvider);
    final sort = ref.watch(couponSortProvider);
    final query = ref.watch(couponSearchQueryProvider);
    final lastSeenAsync = ref.watch(couponsLastSeenAtProvider);
    final lastSeenAt =
        lastSeenAsync.valueOrNull ?? DateTime.fromMillisecondsSinceEpoch(0);
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

    if (!_didMarkSeen && authUser != null) {
      _didMarkSeen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ref
            .read(couponsSeenRepositoryProvider)
            .setLastSeenNow(authUser.uid);
        ref.invalidate(couponsLastSeenAtProvider);
      });
    }

    if (_searchController.text != query) {
      _searchController.value = _searchController.value.copyWith(
        text: query,
        selection: TextSelection.fromPosition(
          TextPosition(offset: query.length),
        ),
        composing: TextRange.empty,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: AppColors.gray50,
        appBar: AppBar(
          // 쿠폰함 상단의 '<' 버튼은 제거하고, 뒤로가기는 홈으로 이동합니다.
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
                          child: Icon(
                            Icons.person,
                            color: AppColors.textSecondary,
                          ),
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
                Align(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [const Text('쿠폰함')],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: couponsAsync.maybeWhen(
                    data: (coupons) {
                      final activeCount = coupons
                          .where((c) => c.status == CouponStatus.active)
                          .length;
                      return Text(
                        '$activeCount개',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Column(
        children: [
          // Full-width header background to avoid right-side gray gap.
          Container(
            width: double.infinity,
            color: Colors.white,
            child: Padding(
              padding: AppTheme.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: AppColors.textHint.withValues(alpha: 0.6),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            textAlignVertical: TextAlignVertical.center,
                            style: AppTypography.bodyMedium,
                            decoration: InputDecoration(
                              hintText: '쿠폰 검색 (업체명/쿠폰명)',
                              hintStyle: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textHint.withValues(alpha: 0.5),
                              ),
                              border: InputBorder.none,
                              filled: false,
                              fillColor: Colors.transparent,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            onChanged: (v) =>
                                ref
                                        .read(
                                          couponSearchQueryProvider.notifier,
                                        )
                                        .state =
                                    v,
                          ),
                        ),
                        if (query.trim().isNotEmpty)
                          GestureDetector(
                            onTap: () =>
                                ref
                                        .read(
                                          couponSearchQueryProvider.notifier,
                                        )
                                        .state =
                                    '',
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.gray300,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
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
          ),
          const Divider(height: 1),
          Expanded(
            child: couponsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.paddingMD),
                  child: Text('쿠폰 로드 실패: $e', textAlign: TextAlign.center),
                ),
              ),
              data: (coupons) {
                final placeId = _placeIdFilter?.trim();
                final visible = (placeId == null || placeId.isEmpty)
                    ? coupons
                    : coupons.where((c) => c.placeId == placeId).toList();

                return ListView.separated(
                  padding: AppTheme.screenPadding.copyWith(bottom: 120),
                  itemCount:
                      visible.length +
                      ((placeId == null || placeId.isEmpty) ? 0 : 1),
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, idx) {
                    if (placeId != null && placeId.isNotEmpty && idx == 0) {
                      return AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.paddingMD,
                          vertical: AppSpacing.paddingSM,
                        ),
                        margin: EdgeInsets.zero,
                        child: Row(
                          children: [
                            const Icon(Icons.store, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '이 업체 쿠폰만 보기',
                                style: AppTypography.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.go('/coupons'),
                              child: const Text('해제'),
                            ),
                          ],
                        ),
                      );
                    }

                    final c =
                        visible[(placeId != null && placeId.isNotEmpty)
                            ? idx - 1
                            : idx];
                    final isNew =
                        lastSeenAsync.hasValue &&
                        c.status == CouponStatus.active &&
                        c.createdAt != null &&
                        c.createdAt!.isAfter(lastSeenAt);

                    return _CouponTicketCard(
                      coupon: c,
                      isNew: isNew,
                      onTap: () => context.push('/coupons/${c.id}'),
                      onUse: c.isActive
                          ? () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => _RedeemSheet(coupon: c),
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _CouponTicketCard extends StatelessWidget {
  const _CouponTicketCard({
    required this.coupon,
    required this.isNew,
    required this.onTap,
    required this.onUse,
  });

  final Coupon coupon;
  final bool isNew;
  final VoidCallback onTap;
  final VoidCallback? onUse;

  String _fmt(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  @override
  Widget build(BuildContext context) {
    final isActive = coupon.status == CouponStatus.active;
    final stripLabel = switch (coupon.status) {
      CouponStatus.active => '사용하기',
      CouponStatus.used => '사용완료',
      CouponStatus.expired => '만료',
    };

    final baseColor = isActive ? Colors.white : AppColors.gray200;
    final stripGradient = isActive
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.brandTeal, AppColors.brandSky],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.gray300, AppColors.gray400],
          );

    final titleColor = isActive ? AppColors.textPrimary : AppColors.gray500;
    final subColor = isActive ? AppColors.textSecondary : AppColors.gray500;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        // Keep the design's minimum height, but allow the card to grow if text
        // becomes taller (prevents "BOTTOM OVERFLOWED" debug stripes).
        constraints: const BoxConstraints(minHeight: 118),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: 14),
              Container(
                width: 54,
                height: 54,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.gray200 : AppColors.gray300,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.store,
                  color: isActive ? AppColors.gray600 : AppColors.gray500,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              coupon.placeName.trim().isEmpty
                                  ? '매장 상호명'
                                  : coupon.placeName.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                color: subColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isNew) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusFull,
                                ),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                'NEW',
                                style: AppTypography.labelSmall.copyWith(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        coupon.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.h4.copyWith(
                          fontSize: 20,
                          color: titleColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        coupon.description.trim().isEmpty
                            ? '만 원 이상 구매시 사용 가능'
                            : coupon.description.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: subColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_fmt(coupon.expiresAt)}까지 유효 · 매장에 쿠폰 제시',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: subColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 84,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onUse,
                    child: Ink(
                      decoration: BoxDecoration(gradient: stripGradient),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isActive
                                  ? Icons.check_box_outlined
                                  : Icons.lock_outline,
                              color: Colors.white.withValues(
                                alpha: isActive ? 1 : 0.85,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              stripLabel,
                              textAlign: TextAlign.center,
                              style: AppTypography.labelMedium.copyWith(
                                color: Colors.white.withValues(
                                  alpha: isActive ? 1 : 0.85,
                                ),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

  Future<void> _submit() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _error = '로그인이 필요합니다';
        _code = '';
      });
      return;
    }

    final code = _code;
    // PRD 02/08: 쿠폰 사용 검증은 서버(redeemCoupon)가 수행하고
    // coupon_usage 컬렉션에 redeemed 이벤트 로그를 남긴다.
    // 실패 시 failed_code_attempts 에 자동 기록되어 Admin 이상거래 화면에서 확인 가능.
    String? failReason;
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
      await functions.httpsCallable('redeemCoupon').call<Map<Object?, Object?>>({
        'couponId': widget.coupon.id,
        'code': code,
      });
    } on FirebaseFunctionsException catch (e) {
      // 서버는 message 에 "쿠폰 사용 실패: {reason}" 형태로 내려준다.
      final msg = e.message ?? '';
      if (msg.contains('expired')) {
        failReason = 'expired';
      } else if (msg.contains('already_used')) {
        failReason = 'already_used';
      } else if (msg.contains('wrong_code')) {
        failReason = 'wrong_code';
      } else if (msg.contains('not_found')) {
        failReason = 'not_found';
      } else if (msg.contains('not_active')) {
        failReason = 'not_active';
      } else {
        failReason = 'unknown';
      }
    }

    if (failReason == null) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ref
          .read(homeControllerProvider.notifier)
          .completeMission(MissionType.coupon);
      context.showAppSnackBar('쿠폰이 사용 처리되었습니다');
      return;
    }

    final errorMsg = switch (failReason) {
      'expired' => '만료된 쿠폰입니다',
      'already_used' => '이미 사용된 쿠폰입니다',
      'wrong_code' => '코드가 올바르지 않습니다',
      'not_active' => '사용할 수 없는 쿠폰입니다',
      'not_found' => '쿠폰을 찾을 수 없습니다',
      _ => '코드가 올바르지 않습니다 (6자리 숫자)',
    };

    setState(() {
      _error = errorMsg;
      _code = '';
    });
  }

  void _append(int digit) {
    if (_code.length >= 6) return;
    setState(() {
      _error = null;
      _code = '$_code$digit';
    });
    if (_code.length == 6) {
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
          Text('매장에서 6자리 인증 코드를 입력해주세요.', style: AppTypography.bodySmall),
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
          _Keypad(onDigit: _append, onBackspace: _backspace, onClear: _clear),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandTeal : Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: selected ? AppColors.brandTeal : AppColors.gray300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
      children: List.generate(6, (i) {
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
          child: Text(filled ? chars[i] : '', style: AppTypography.h3),
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
    Widget btn({required Widget child, required VoidCallback onPressed}) {
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
