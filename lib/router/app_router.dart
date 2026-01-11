import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth/auth_screens.dart';
import '../screens/coupons/coupons_screen.dart';
import '../screens/friends/friends_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/personal_info_screen.dart';
import '../screens/settings/connect_program_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import '../screens/settings/profile_settings_screen.dart';
import '../screens/settings/settings_screen.dart';
import 'main_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/',
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
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'info',
                  builder: (context, state) => const PersonalInfoScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
      routes: [
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

