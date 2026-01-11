import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kakao SDK init (use --dart-define=KAKAO_NATIVE_APP_KEY=...)
  const kakaoKey =
      String.fromEnvironment('KAKAO_NATIVE_APP_KEY', defaultValue: '');
  if (kakaoKey.isNotEmpty) {
    KakaoSdk.init(nativeAppKey: kakaoKey);
  }

  // Firebase 초기화
  await _initFirebaseIfSupported();

  runApp(
    const ProviderScope(
      child: NamguApp(),
    ),
  );
}

Future<void> _initFirebaseIfSupported() async {
  // 현재 repo는 Android는 google-services.json이 있고,
  // iOS/macOS는 FlutterFire 옵션/플리스트가 없어서 초기화 시 크래시가 날 수 있음.
  // 그래서 Android/iOS에서만 시도하고, 실패해도 앱 부팅은 되게 둠.
  if (kIsWeb) return;

  final platform = defaultTargetPlatform;
  final isSupported =
      platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  if (!isSupported) return;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init skipped/failed: $e');
  }
}

class NamguApp extends StatelessWidget {
  const NamguApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '남구이야기',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
