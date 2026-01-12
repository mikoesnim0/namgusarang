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
  // Android/iOS/macOS에서 Firebase를 초기화합니다.
  // macOS에서 plist 기반(implicit) 초기화는 설정 불일치로 "CONFIGURATION_NOT_FOUND"를 유발할 수 있어,
  // FlutterFire가 생성한 options를 항상 사용합니다.
  if (kIsWeb) return;

  final platform = defaultTargetPlatform;
  final isSupported =
      platform == TargetPlatform.android ||
      platform == TargetPlatform.iOS ||
      platform == TargetPlatform.macOS;
  if (!isSupported) return;

  // Quick sanity check: macOS에서 iOS App ID를 쓰면 Auth에서 CONFIGURATION_NOT_FOUND(HTTP 400)로 터집니다.
  // (지금 프로젝트가 딱 이 케이스: firebase_options.dart의 macos.appId가 ...:ios:... 인 상태)
  if (platform == TargetPlatform.macOS) {
    final macosAppId = DefaultFirebaseOptions.macos.appId;
    if (macosAppId.contains(':ios:')) {
      debugPrint(
        'Firebase misconfiguration: macOS is using an iOS GOOGLE_APP_ID ($macosAppId). '
        'Run flutterfire configure with macOS enabled and ensure macOS GOOGLE_APP_ID is ...:macos:...',
      );
      // Intentionally skip Firebase init on macOS in this misconfigured state to avoid
      // runtime auth calls failing with CONFIGURATION_NOT_FOUND/internal-error.
      return;
    }
  }

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
