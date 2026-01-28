import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/coupons/coupon_model.dart';
import '../../features/coupons/coupons_provider.dart';
import '../../features/places/place.dart';
import '../../features/places/places_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class CouponDetailScreen extends ConsumerWidget {
  const CouponDetailScreen({super.key, required this.couponId});

  final String couponId;

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couponAsync = ref.watch(couponByIdProvider(couponId));
    final places = ref.watch(activePlacesProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('쿠폰 상세'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/coupons');
            }
          },
        ),
      ),
      body: couponAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.paddingMD),
            child: Text('쿠폰 로드 실패: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (c) {
          if (c == null) {
            return const Center(child: Text('쿠폰을 찾을 수 없습니다.'));
          }

          Place? place;
          for (final p in places) {
            if (p.id == c.placeId) {
              place = p;
              break;
            }
          }

          final statusText = switch (c.status) {
            CouponStatus.active => '사용 가능',
            CouponStatus.used => '사용 완료',
            CouponStatus.expired => '만료',
          };

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.paddingMD),
                  margin: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.placeName.trim().isEmpty ? '업체' : c.placeName.trim(),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(c.title, style: AppTypography.h4),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gray100,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusFull),
                            ),
                            child: Text(
                              statusText,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(c.description, style: AppTypography.bodySmall),
                      const SizedBox(height: 12),
                      Text(
                        '만료: ${_formatDate(c.expiresAt)}',
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
                      Text('인증 코드', style: AppTypography.labelLarge),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMD),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Center(
                          child: Text(
                            c.verificationCode,
                            style: AppTypography.h3.copyWith(
                              letterSpacing: 2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        text: '지도에서 업체 보기',
                        variant: ButtonVariant.primary,
                        isFullWidth: true,
                        onPressed: () => context.go(
                          '/map?placeId=${Uri.encodeComponent(c.placeId)}',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (place != null &&
                    (place.openingHours.trim().isNotEmpty ||
                        place.naverPlaceUrl.trim().isNotEmpty))
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.paddingMD),
                    margin: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('업체 정보', style: AppTypography.labelLarge),
                        if (place.openingHours.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '영업시간: ${place.openingHours.trim()}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (place.naverPlaceUrl.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            place.naverPlaceUrl.trim(),
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.primary700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
