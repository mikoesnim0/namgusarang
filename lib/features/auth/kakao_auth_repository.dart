import 'package:cloud_functions/cloud_functions.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

class KakaoAuthRepository {
  static const _region = 'asia-northeast3';

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: _region);

  Future<String> signInAndGetFirebaseToken() async {
    // 1) Kakao login (Talk -> Web fallback)
    OAuthToken kakaoToken;
    if (await isKakaoTalkInstalled()) {
      kakaoToken = await UserApi.instance.loginWithKakaoTalk();
    } else {
      kakaoToken = await UserApi.instance.loginWithKakaoAccount();
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

