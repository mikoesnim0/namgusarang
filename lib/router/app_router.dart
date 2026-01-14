import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../screens/auth/auth_screens.dart';
import '../screens/coupons/coupons_screen.dart';
import '../screens/friends/friends_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/personal_info_screen.dart';
import '../screens/settings/connect_program_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import '../screens/settings/profile_settings_screen.dart';
import '../screens/settings/settings_screen.dart';
import 'main_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final loc = state.matchedLocation;
    final isAuthRoute = loc == '/' || loc == '/login' || loc == '/signup';

    final isFirebaseReady = Firebase.apps.isNotEmpty;
    final isSignedIn =
        isFirebaseReady && FirebaseAuth.instance.currentUser != null;

    // 보호 라우트: 로그인 안 돼있으면 무조건 로그인 화면으로
    if (!isSignedIn && !isAuthRoute) return '/login';

    // 요구사항: 로그인 상태여도 /login, /signup 접근 허용 (자동 홈 리다이렉트 금지)
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => MainShell(
        navigationShell: navigationShell,
      ),
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
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/friends',
              builder: (context, state) => const FriendsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/my',
      builder: (context, state) => const SettingsScreen(),
      routes: [
        GoRoute(
          path: 'info',
          builder: (context, state) => const PersonalInfoScreen(),
        ),
        GoRoute(
          path: 'profile',
          builder: (context, state) => const ProfileSettingsScreen(),
        ),
        GoRoute(
          path: 'notifications',
          builder: (context, state) => const NotificationSettingsScreen(),
        ),
        GoRoute(
          path: 'connect',
          builder: (context, state) => const ConnectProgramScreen(),
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

