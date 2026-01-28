import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../features/places/place.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class PlaceInfoPopup extends StatelessWidget {
  const PlaceInfoPopup({
    super.key,
    required this.place,
    required this.coupons,
    required this.onClose,
  });

  final Place place;
  final List<String> coupons;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final hasAnyCoupons = coupons.isNotEmpty || place.hasCoupons;
    final bg = hasAnyCoupons ? const Color(0xFFFFF6D5) : Colors.white;

    return Material(
      color: bg,
      elevation: 3,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.paddingMD),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLarge,
                  ),
                ),
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Keep the popup compact: a single horizontal line of "meta chips"
            // so it never grows into 3+ lines and hides the map.
            SizedBox(
              height: 30,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (coupons.isNotEmpty)
                      _Chip(
                        text: '할인쿠폰 ${coupons.length}개',
                        variant: ChipVariant.highlight,
                        onTap: () {
                          onClose();
                          context.go(
                            '/coupons?placeId=${Uri.encodeComponent(place.id)}',
                          );
                        },
                      ),
                    if (coupons.isNotEmpty) const SizedBox(width: 6),
                    if (place.openingHours.trim().isNotEmpty)
                      _Chip(
                        text: '영업시간 ${place.openingHours.trim()}',
                      ),
                    if (place.openingHours.trim().isNotEmpty)
                      const SizedBox(width: 6),
                    if (place.naverPlaceUrl.trim().isNotEmpty)
                      TextButton(
                        onPressed: () async {
                          final uri = Uri.tryParse(place.naverPlaceUrl.trim());
                          if (uri == null) return;
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: AppColors.primary700,
                          backgroundColor: AppColors.gray100,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusFull),
                            side: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: const Text(
                          '네이버 연결',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    if (place.naverPlaceUrl.trim().isNotEmpty)
                      const SizedBox(width: 6),
                    if (place.category.trim().isNotEmpty)
                      _Chip(text: place.category.trim()),
                    if (place.category.trim().isNotEmpty) const SizedBox(width: 6),
                    if (place.address.trim().isNotEmpty)
                      _Chip(
                        text: place.address.trim(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    this.variant = ChipVariant.normal,
    this.onTap,
  });

  final String text;
  final ChipVariant variant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = switch (variant) {
      ChipVariant.highlight => const Color(0xFFFFE08A),
      _ => AppColors.gray100,
    };
    final fg = switch (variant) {
      ChipVariant.highlight => const Color(0xFF6B3A00),
      _ => AppColors.textSecondary,
    };
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelSmall.copyWith(color: fg),
      ),
    );

    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: child,
    );
  }
}

enum ChipVariant { normal, highlight }
