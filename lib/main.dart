import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';

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
      home: const HomePage(),
    );
  }
}

// 임시 홈 화면 (디자인 시스템 테스트용)
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('남구이야기'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.place,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            Text(
              '남구이야기',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '걸으며 쿠폰을 얻고 사용해요',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {},
              child: const Text('시작하기'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {},
              child: const Text('로그인'),
            ),
          ],
        ),
      ),
    );
  }
}
