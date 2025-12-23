import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// 공통 카드 컴포넌트
/// variant: elevated, outlined, flat
class AppCard extends StatelessWidget {
  final Widget child;
  final CardVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final double? elevation;

  const AppCard({
    super.key,
    required this.child,
    this.variant = CardVariant.outlined,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Padding(
      padding: padding ??
          const EdgeInsets.all(AppSpacing.paddingMD),
      child: child,
    );

    Widget card;

    switch (variant) {
      case CardVariant.elevated:
        card = Card(
          elevation: elevation ?? 4,
          color: color ?? AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          ),
          margin: margin ?? const EdgeInsets.all(AppSpacing.marginSM),
          child: cardContent,
        );
        break;

      case CardVariant.outlined:
        card = Card(
          elevation: 0,
          color: color ?? AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
          margin: margin ?? const EdgeInsets.all(AppSpacing.marginSM),
          child: cardContent,
        );
        break;

      case CardVariant.flat:
        card = Container(
          decoration: BoxDecoration(
            color: color ?? AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          ),
          margin: margin ?? const EdgeInsets.all(AppSpacing.marginSM),
          child: cardContent,
        );
        break;
    }

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        child: card,
      );
    }

    return card;
  }
}

enum CardVariant {
  elevated,
  outlined,
  flat,
}

