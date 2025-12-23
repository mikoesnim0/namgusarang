import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'screens/auth/auth_screens.dart';

void main() {
  runApp(
    const ProviderScope(
      child: NamguApp(),
    ),
  );
}

class NamguApp extends StatelessWidget {
  const NamguApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '남구이야기',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // 라우트 설정
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
      },
    );
  }
}
