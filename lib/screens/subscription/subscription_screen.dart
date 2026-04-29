import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/subscription/subscription_model.dart';
import '../../features/subscription/subscription_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_snackbar.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  static const _packageName = 'com.doyakmin.hangookji.namgu';
  static const _productId = 'premium_monthly';
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(subscriptionStatusProvider);
    final purchaseAsync = ref.watch(subscriptionPurchaseProvider);
    final isLoading =
        purchaseAsync.valueOrNull == SubscriptionPurchaseState.loading ||
            purchaseAsync.isLoading;

    ref.listen(subscriptionPurchaseProvider, (prev, next) {
      if (next.valueOrNull == SubscriptionPurchaseState.success) {
        context.showAppSnackBar('프리미엄 구독이 활성화되었습니다!');
        ref.read(subscriptionPurchaseProvider.notifier).resetError();
      } else if (next.hasError) {
        final msg = next.error?.toString() ?? '구독 처리 중 오류가 발생했습니다.';
        context.showAppSnackBar(msg);
        ref.read(subscriptionPurchaseProvider.notifier).resetError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('구독 관리'),
        leading: const BackButton(),
      ),
      body: status.isPremium
          ? _PremiumActiveBody(status: status, onManage: _openStoreSubscriptions)
          : _FreeBody(
              isLoading: isLoading,
              agreed: _agreed,
              onAgreeTap: () => setState(() => _agreed = !_agreed),
              onSubscribe: () =>
                  ref.read(subscriptionPurchaseProvider.notifier).subscribe(),
              onRestore: () =>
                  ref.read(subscriptionPurchaseProvider.notifier).restorePurchases(),
            ),
    );
  }

  Future<void> _openStoreSubscriptions() async {
    final Uri uri;
    if (Platform.isIOS) {
      uri = Uri.parse('https://apps.apple.com/account/subscriptions');
    } else {
      uri = Uri.parse(
        'https://play.google.com/store/account/subscriptions'
        '?sku=$_productId&package=$_packageName',
      );
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      context.showAppSnackBar('스토어를 열 수 없습니다.');
    }
  }
}

// ---------------------------------------------------------------------------
// 무료 상태 본문
// ---------------------------------------------------------------------------

class _FreeBody extends StatelessWidget {
  const _FreeBody({
    required this.isLoading,
    required this.agreed,
    required this.onAgreeTap,
    required this.onSubscribe,
    required this.onRestore,
  });

  final bool isLoading;
  final bool agreed;
  final VoidCallback onAgreeTap;
  final VoidCallback onSubscribe;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _HeroSection(),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.lg, AppSpacing.md, 0,
            ),
            child: const _PriceCard(),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, 0,
            ),
            child: _AgreementRow(agreed: agreed, onTap: onAgreeTap),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0,
            ),
            child: _NoticeSection(),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm,
            ),
            child: _SubscribeButton(
              isLoading: isLoading,
              enabled: agreed,
              onTap: onSubscribe,
            ),
          ),

          Center(
            child: TextButton(
              onPressed: isLoading ? null : onRestore,
              child: Text(
                '이전 구매 복원',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              '구독은 확인 시 Apple 계정에 청구되며, 현재 기간이 끝나기 '
              '최소 24시간 전에 자동 갱신을 해제하지 않으면 자동으로 갱신됩니다. '
              '구독은 구매 후 계정 설정에서 관리 및 해지할 수 있습니다.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textHint,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          const _LegalLinks(),

          Center(
            child: TextButton(
              onPressed: () => context.push('/my/subscription/history'),
              child: Text(
                '결제 내역',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 히어로 섹션
// ---------------------------------------------------------------------------

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, AppSpacing.xl, 28, 36),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary50, AppColors.surfaceVariant],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Text(
            '프리미엄 구독',
            style: AppTypography.h4.copyWith(
              color: AppColors.primary700,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '걷는 만큼 더 큰 혜택을 받아보세요',
                style: AppTypography.h5.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.eco_outlined,
                size: 20,
                color: AppColors.primary500,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              children: [
                const TextSpan(text: '월 '),
                TextSpan(
                  text: '990원',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const TextSpan(text: '으로 10일 미션\n쿠폰 금액이 '),
                TextSpan(
                  text: '3배로 늘어',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.primary600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: '납니다.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 가격 + 혜택 카드
// ---------------------------------------------------------------------------

class _PriceCard extends StatelessWidget {
  const _PriceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '월 ',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '1,990원',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textDisabled,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppColors.textDisabled,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '990원',
                style: AppTypography.h2.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '최대 4,500원 혜택',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.primary600,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BenefitCheck(text: '10일 미션 쿠폰 500원 → 1,500원'),
                SizedBox(height: 10),
                _BenefitCheck(text: '매달 3회차 미션 참여 가능'),
                SizedBox(height: 10),
                _BenefitCheck(text: '구독 기간 동안 자동 적용'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitCheck extends StatelessWidget {
  const _BenefitCheck({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 20,
          color: AppColors.primary500,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 이용약관 동의 행
// ---------------------------------------------------------------------------

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({required this.agreed, required this.onTap});

  final bool agreed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: agreed,
                      onChanged: (_) => onTap(),
                      activeColor: AppColors.primary500,
                      side: const BorderSide(
                          color: AppColors.border, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '프리미엄 구독 이용약관 (필수)',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => context.push('/my/subscription/terms'),
          icon: const Icon(
            Icons.chevron_right,
            color: AppColors.textSecondary,
          ),
          tooltip: '이용약관 보기',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 유의사항 (접을 수 있는 형태)
// ---------------------------------------------------------------------------

class _NoticeSection extends StatelessWidget {
  const _NoticeSection();

  static const _notes = [
    '프리미엄 구독은 매달 결제일 기준으로 자동 갱신됩니다.',
    '프로모션가 혜택이 종료되면 정상가로 결제됩니다. (정상가 결제 시 별도 동의 예정)',
    '해지 시 다음 결제일부터 자동 종료되며, 이미 결제된 기간 동안은 혜택을 이용할 수 있습니다.',
    '쿠폰 사용을 포함하여 어떤 혜택도 사용하지 않았을 때만 즉시 해지할 수 있습니다.',
    '구독 기간이 종료되면 프리미엄 혜택(1,500원 쿠폰, 월 3회차 미션 기회)은 자동으로 중단됩니다.',
    '구독 기간 내 제공되는 미션 회차는 이월되어 자동 적용됩니다.',
    '쿠폰은 상점별 사용 조건(최소 구매 금액 등)에 따라 적용됩니다.',
    '쿠폰은 발급일 기준 30일 이내 사용 가능하며, 유효기간 경과 시 자동 소멸됩니다.',
    '부정 사용(비정상적 걸음 수 조작 등)이 확인될 경우 혜택이 제한될 수 있습니다.',
    '결제 및 환불은 앱 스토어의 정책을 따릅니다.',
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        title: Text(
          '프리미엄 구독 유의사항',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textHint,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconColor: AppColors.textHint,
        collapsedIconColor: AppColors.textHint,
        children: _notes
            .map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '· ',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        note,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textHint,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 법적 링크 (Privacy Policy + Terms of Use)
// ---------------------------------------------------------------------------

class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    final linkStyle = AppTypography.bodySmall.copyWith(
      color: AppColors.textHint,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.textHint,
      fontSize: 11,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => launchUrl(
            Uri.parse('https://doyakmin.com/privacy'),
            mode: LaunchMode.inAppBrowserView,
          ),
          child: Text('개인정보처리방침', style: linkStyle),
        ),
        Text(
          ' | ',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textHint,
            fontSize: 11,
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => launchUrl(
            Uri.parse('https://www.apple.com/legal/macapps/stdeula/'),
            mode: LaunchMode.inAppBrowserView,
          ),
          child: Text('이용약관(EULA)', style: linkStyle),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 구독 버튼
// ---------------------------------------------------------------------------

class _SubscribeButton extends StatelessWidget {
  const _SubscribeButton({
    required this.isLoading,
    required this.enabled,
    required this.onTap,
  });

  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.buttonHeightLG,
      child: FilledButton(
        onPressed: (isLoading || !enabled) ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: enabled ? AppColors.brandTeal : AppColors.gray300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          ),
          disabledBackgroundColor: AppColors.gray200,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                '프리미엄 구독하기 · 월 990원',
                style: AppTypography.bodyLarge.copyWith(
                  color: enabled ? Colors.white : AppColors.textHint,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 프리미엄 활성 상태 본문
// ---------------------------------------------------------------------------

class _PremiumActiveBody extends StatelessWidget {
  const _PremiumActiveBody({
    required this.status,
    required this.onManage,
  });

  final SubscriptionStatus status;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final isReferral = status.source == SubscriptionSource.referral;
    final nextPayDate = status.expiresAt != null
        ? DateFormat('yyyy.MM.dd').format(status.expiresAt!)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 구독 상태 배지 + 정보
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 4, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary50,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.eco_outlined,
                        size: 16,
                        color: AppColors.primary600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isReferral ? '초대 혜택 이용 중' : '프리미엄 구독 중',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.primary700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 6),
                if (nextPayDate != null)
                  Text(
                    '다음 결제일 : $nextPayDate',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '남은 회차 : ${status.missionsPerMonth}회',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 6),

          // ── 이번 달 혜택 현황
          _InfoCard(
            title: '이번 달 혜택 현황',
            children: const [
              _CheckItem(text: '프리미엄 쿠폰 1,500원 × 2회 지급 완료'),
              SizedBox(height: AppSpacing.sm),
              _CheckItem(text: '남은 미션 회차 : 1회'),
              SizedBox(height: AppSpacing.sm),
              _CheckItem(text: '누적 혜택 금액 : 3,000원'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 6),

          // ── 프리미엄 혜택
          _InfoCard(
            title: '프리미엄 혜택',
            children: const [
              _CheckItem(text: '10일 미션 3회 참여'),
              SizedBox(height: AppSpacing.sm),
              _CheckItem(text: '쿠폰 1,500원 지급'),
              SizedBox(height: AppSpacing.sm),
              _CheckItem(text: '자동 적용 중'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 6),

          // ── 관리 메뉴 타일
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              children: [
                if (!isReferral)
                  _ManageTile(
                    icon: Icons.credit_card_outlined,
                    label: '결제수단 변경',
                    onTap: onManage,
                  ),
                if (!isReferral)
                  const Divider(height: 1, indent: 52),
                _ManageTile(
                  icon: Icons.description_outlined,
                  label: '이용약관 보기',
                  onTap: () => context.push('/my/subscription/terms'),
                ),
                const Divider(height: 1, indent: 52),
                _ManageTile(
                  icon: Icons.receipt_long_outlined,
                  label: '이전 결제 내역',
                  onTap: () => context.push('/my/subscription/history'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          const _NoticeSection(),
          const SizedBox(height: AppSpacing.md),

          if (!isReferral)
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: onManage,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  ),
                  side: const BorderSide(color: AppColors.gray300),
                ),
                child: Text(
                  '구독 해지 예약하기',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 정보 카드 (제목 + 내용)
// ---------------------------------------------------------------------------

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 6),
          ...children,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 프리미엄 관리 타일
// ---------------------------------------------------------------------------

class _ManageTile extends StatelessWidget {
  const _ManageTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 6,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm + 6),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 체크 아이템
// ---------------------------------------------------------------------------

class _CheckItem extends StatelessWidget {
  const _CheckItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.check_rounded,
          size: 18,
          color: AppColors.primary600,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
