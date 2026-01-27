import 'package:flutter/material.dart';

import '../features/places/place.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class PlaceInfoPopup extends StatelessWidget {
  const PlaceInfoPopup({
    super.key,
    required this.place,
    required this.onClose,
  });

  final Place place;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.paddingMD),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLarge,
                  ),
                  if (place.address.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      place.address.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (place.category.trim().isNotEmpty || place.hasCoupons) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (place.category.trim().isNotEmpty)
                          _Chip(text: place.category.trim()),
                        if (place.hasCoupons) const _Chip(text: '쿠폰 가능'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
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
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

