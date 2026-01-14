import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';

/// 스플래시 화면
/// 앱 시작 시 표시되는 첫 화면
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // 2초 후 로그인 화면으로 이동 (실제로는 인증 상태 확인 후 분기)
    Future.delayed(const Duration(seconds: 2), () async {
      if (mounted) {
        // Default: session 유지(=자동 로그인) UX
        // Dev/QA flags:
        // - FORCE_LOGIN_SCREEN=true: 로그인 화면만 강제(세션 유지)
        // - FORCE_SIGNOUT_ON_STARTUP=true: 시작 시 signOut + 로그인 화면 (디버그에서만 권장)
        //
        // Backward-compat: FORCE_LOGIN_ON_STARTUP=true 는 FORCE_LOGIN_SCREEN과 동일하게 취급.
        const forceLoginScreen = bool.fromEnvironment(
          'FORCE_LOGIN_SCREEN',
          defaultValue: false,
        );
        const forceSignOut = bool.fromEnvironment(
          'FORCE_SIGNOUT_ON_STARTUP',
          defaultValue: false,
        );
        const legacyForceLoginOnStartup = bool.fromEnvironment(
          'FORCE_LOGIN_ON_STARTUP',
          defaultValue: false,
        );

        if ((forceSignOut || forceLoginScreen || legacyForceLoginOnStartup) &&
            Firebase.apps.isNotEmpty) {
          if (forceSignOut && kDebugMode) {
            try {
              await FirebaseAuth.instance.signOut();
            } catch (_) {
              // ignore
            }
          }
          context.go('/login');
          return;
        }

        final isFirebaseReady = Firebase.apps.isNotEmpty;
        final isSignedIn =
            isFirebaseReady && FirebaseAuth.instance.currentUser != null;
        context.go(isSignedIn ? '/home' : '/login');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary500,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 앱 로고 (아이콘으로 임시 대체)
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.textOnPrimary,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusXL),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowMedium,
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.place,
                        size: 64,
                        color: AppColors.primary500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.paddingXL),
                    // 앱 이름
                    Text(
                      'Walker홀릭',
                      style: AppTypography.h1.copyWith(
                        color: AppColors.textOnPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.paddingSM),
                    // 슬로건
                    Text(
                      '걸으며 쿠폰을 얻고 사용해요',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textOnPrimary.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.paddingXXL),
                    // 버전 정보
                    Text(
                      'v1.0.0',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textOnPrimary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

