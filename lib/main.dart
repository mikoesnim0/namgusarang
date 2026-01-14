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
    // NOTE:
    // Firebase Apple App ID는 macOS에서도 ':ios:' 형태로 보일 수 있습니다.
    // 문자열 패턴만으로 "misconfiguration"을 단정하면 macOS에서 Firebase init 자체를 막게 되므로,
    // 여기서는 단순 경고만 남기고 실제 성공/실패는 init/auth 결과로 판단합니다.
    if (macosAppId.isNotEmpty && macosAppId == DefaultFirebaseOptions.ios.appId) {
      debugPrint(
        'Firebase misconfiguration: macOS is using an iOS GOOGLE_APP_ID ($macosAppId). '
        'This can be OK if you intentionally share the same Firebase app across Apple platforms. '
        'If macOS auth fails (CONFIGURATION_NOT_FOUND), re-run flutterfire configure and create/select a macOS app.',
      );
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
      title: 'Walker홀릭',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
