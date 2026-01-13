import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter/services.dart';

class KakaoAuthRepository {
  static const _region = 'asia-northeast3';
  static const _kakaoNativeKey =
      String.fromEnvironment('KAKAO_NATIVE_APP_KEY', defaultValue: '');

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: _region);

  Future<String> signInAndGetFirebaseToken() async {
    // kakao_flutter_sdk_user does NOT support macOS method channels.
    // On macOS this throws MissingPluginException (e.g. isKakaoTalkInstalled).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      throw UnsupportedError(
        'Kakao login is not supported on macOS. Use email login on macOS, and test Kakao login on Android/iOS.',
      );
    }

    // Ensure Kakao SDK is initialized (and configured) before any method-channel calls.
    // If this is not set, Kakao SDK can throw late-init errors internally.
    if (_kakaoNativeKey.isEmpty) {
      throw UnsupportedError(
        'KAKAO_NATIVE_APP_KEY is not set. Run with `--dart-define=KAKAO_NATIVE_APP_KEY=...` (or configure iOS/Android injection) before using Kakao login.',
      );
    }
    KakaoSdk.init(nativeAppKey: _kakaoNativeKey);

    // 1) Kakao login (Talk -> Account fallback)
    OAuthToken kakaoToken;
    try {
      if (await isKakaoTalkInstalled()) {
        kakaoToken = await UserApi.instance.loginWithKakaoTalk();
      } else {
        kakaoToken = await UserApi.instance.loginWithKakaoAccount();
      }
    } on MissingPluginException {
      // Defensive: if plugin wiring is missing on the current platform/build.
      throw UnsupportedError(
        'Kakao login is not supported on this platform/build.',
      );
    }

    // 2) Exchange Kakao accessToken -> Firebase custom token via Callable Function
    final callable = _functions.httpsCallable('authWithKakao');
    final res = await callable.call<Map<String, dynamic>>({
      'accessToken': kakaoToken.accessToken,
    });

    final data = res.data;
    final token = data['firebaseToken'];
    if (token is! String || token.isEmpty) {
      throw StateError('Invalid authWithKakao response: firebaseToken missing');
    }
    return token;
  }
}

