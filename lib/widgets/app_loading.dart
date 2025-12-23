import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// 로딩 인디케이터 컴포넌트
class AppLoading extends StatelessWidget {
  final bool isFullScreen;
  final Color? color;
  final double? size;
  final String? message;

  const AppLoading({
    super.key,
    this.isFullScreen = false,
    this.color,
    this.size,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final indicator = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size ?? 40,
          height: size ?? 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? AppColors.primary500,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.paddingMD),
          Text(
            message!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (isFullScreen) {
      return Container(
        color: AppColors.overlay,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.paddingXL),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            ),
            child: indicator,
          ),
        ),
      );
    }

    return Center(child: indicator);
  }
}

/// 인라인 로딩 (작은 크기)
class AppLoadingInline extends StatelessWidget {
  final Color? color;

  const AppLoadingInline({
    super.key,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? AppColors.primary500,
        ),
      ),
    );
  }
}

