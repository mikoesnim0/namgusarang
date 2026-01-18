import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class KakaoLoginButton extends StatelessWidget {
  const KakaoLoginButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.height = 48,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Material(
        color: AppColors.kakaoYellow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.kakaoLabel,
                        ),
                      ),
                    ),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.paddingMD,
                          ),
                          child: Image.asset(
                            'assets/icons/kakao_symbol.png',
                            width: 18,
                            height: 18,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.chat_bubble,
                              size: 18,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '카카오 로그인',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.kakaoLabel,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

