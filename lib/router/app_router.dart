import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../screens/auth/auth_screens.dart';
import '../screens/coupons/coupon_detail_screen.dart';
import '../screens/coupons/coupons_screen.dart';
import '../screens/friends/friend_requests_screen.dart';
import '../screens/friends/friends_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/map/naver_map_debug_screen.dart';
import '../screens/profile/personal_info_screen.dart';
import '../screens/settings/connect_program_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import '../screens/settings/profile_settings_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/onboarding/profile_setup_screen.dart';
import '../screens/walker/walker_tracking_screen.dart';
import 'main_shell.dart';

CustomTransitionPage<void> _slidePage({required Widget child, LocalKey? key}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    final loc = state.matchedLocation;
    final isAuthRoute = loc == '/' || loc == '/login' || loc == '/signup';
    final isOnboardingRoute = loc.startsWith('/onboarding');

    final isFirebaseReady = Firebase.apps.isNotEmpty;
    final isSignedIn =
        isFirebaseReady && FirebaseAuth.instance.currentUser != null;

    // 보호 라우트: 로그인 안 돼있으면 무조건 로그인 화면으로
    if (!isSignedIn && !isAuthRoute) return '/login';

    // First-login gating: require body profile setup for kcal estimation.
    if (isSignedIn &&
        !isAuthRoute &&
        !isOnboardingRoute &&
        isFirebaseReady) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final data = snap.data() ?? const <String, dynamic>{};
        final gender = (data['gender'] as String?)?.trim() ?? '';
        final height = data['heightCm'];
        final weight = data['weightKg'];

        final hasHeight = height is num && height > 0;
        final hasWeight = weight is num && weight > 0;
        final hasGender = gender.isNotEmpty;

        if (!hasGender || !hasHeight || !hasWeight) {
          final from = Uri.encodeComponent(loc);
          return '/onboarding/profile?from=$from';
        }
      } catch (_) {
        // If profile check fails, don't block navigation (avoid locking users out).
      }
    }

    // 요구사항: 로그인 상태여도 /login, /signup 접근 허용 (자동 홈 리다이렉트 금지)
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
    GoRoute(
      path: '/onboarding/profile',
      pageBuilder: (context, state) {
        final from = state.uri.queryParameters['from'];
        final decodedFrom =
            (from != null && from.isNotEmpty) ? Uri.decodeComponent(from) : null;
        return _slidePage(
          key: state.pageKey,
          child: ProfileSetupScreen(from: decodedFrom),
        );
      },
    ),
    GoRoute(
      path: '/walker',
      pageBuilder: (context, state) =>
          _slidePage(key: state.pageKey, child: const WalkerTrackingScreen()),
    ),
    GoRoute(
      path: '/map',
      pageBuilder: (context, state) =>
          _slidePage(key: state.pageKey, child: const NaverMapDebugScreen()),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/coupons',
              builder: (context, state) => const CouponsScreen(),
              routes: [
                GoRoute(
                  path: ':couponId',
                  pageBuilder: (context, state) {
                    final id = state.pathParameters['couponId'] ?? '';
                    return _slidePage(
                      key: state.pageKey,
                      child: CouponDetailScreen(couponId: id),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/friends',
              builder: (context, state) => const FriendsScreen(),
              routes: [
                GoRoute(
                  path: 'requests',
                  builder: (context, state) => const FriendRequestsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/my',
      pageBuilder: (context, state) =>
          _slidePage(key: state.pageKey, child: const SettingsScreen()),
      routes: [
        GoRoute(
          path: 'info',
          pageBuilder: (context, state) =>
              _slidePage(key: state.pageKey, child: const PersonalInfoScreen()),
        ),
        GoRoute(
          path: 'profile',
          pageBuilder: (context, state) => _slidePage(
            key: state.pageKey,
            child: const ProfileSettingsScreen(),
          ),
        ),
        GoRoute(
          path: 'notifications',
          pageBuilder: (context, state) => _slidePage(
            key: state.pageKey,
            child: const NotificationSettingsScreen(),
          ),
        ),
        GoRoute(
          path: 'connect',
          pageBuilder: (context, state) => _slidePage(
            key: state.pageKey,
            child: const ConnectProgramScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      redirect: (context, state) => '/my',
      routes: [
        // kept only for backward-compat (redirected). All settings live under `/my/*`.
      ],
    ),
  ],
  errorBuilder: (context, state) => _RouterErrorScreen(error: state.error),
);

class _RouterErrorScreen extends StatelessWidget {
  const _RouterErrorScreen({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('라우팅 오류')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(error?.toString() ?? 'Unknown routing error'),
      ),
    );
  }
}
