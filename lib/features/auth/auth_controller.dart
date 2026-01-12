import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hangookji_namgu/firebase_options.dart';
import 'auth_providers.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthUnavailableException implements Exception {
  const AuthUnavailableException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // no-op: controller only runs when actions are invoked
  }

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
    } catch (e, st) {
      // Always log full details so we can debug native/Firebase issues (esp. on macOS).
      debugPrint('AuthController error: $e');
      if (e is FirebaseAuthException) {
        debugPrint('FirebaseAuthException(code=${e.code}, message=${e.message})');
      } else if (e is FirebaseException) {
        debugPrint('FirebaseException(plugin=${e.plugin}, code=${e.code}, message=${e.message})');
      }
      debugPrintStack(stackTrace: st);
      state = AsyncError(e, st);
    }
  }

  void _ensureFirebaseReady() {
    // macOS가 iOS App ID로 구성된 상태면(현재 케이스) Firebase Auth가 항상
    // CONFIGURATION_NOT_FOUND -> internal-error 로 실패합니다.
    // 이 경우는 "설정 미완료"로 취급하고 auth flow 자체를 막아버리는 게 UX/디버깅 모두 낫습니다.
    if (defaultTargetPlatform == TargetPlatform.macOS &&
        DefaultFirebaseOptions.macos.appId.contains(':ios:')) {
      throw const AuthUnavailableException(
        'macOS Firebase 설정이 iOS App ID로 되어있어 로그인/회원가입을 비활성화했습니다. '
        '`flutterfire configure --platforms=macos`로 macOS 앱을 등록/동기화해서 '
        'GOOGLE_APP_ID가 `...:macos:...`로 나오게 한 뒤 다시 시도해주세요.',
      );
    }
    if (Firebase.apps.isEmpty) {
      throw const AuthUnavailableException(
        'Firebase가 초기화되지 않았습니다. (macOS는 `macos/Runner/GoogleService-Info.plist` 추가 후 다시 실행하세요)',
      );
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _run(() async {
      _ensureFirebaseReady();
      final auth = ref.read(firebaseAuthRepositoryProvider);
      final users = ref.read(usersRepositoryProvider);

      final cred = await auth.signInWithEmail(email: email, password: password);
      final user = cred.user;
      if (user == null) throw StateError('FirebaseAuth returned null user');

      await users.upsertOnAuth(user: user, email: email);
    });
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String nickname,
    required String birthdate,
    required String gender,
  }) async {
    await _run(() async {
      _ensureFirebaseReady();
      final auth = ref.read(firebaseAuthRepositoryProvider);
      final users = ref.read(usersRepositoryProvider);

      final cred = await auth.signUpWithEmail(email: email, password: password);
      final user = cred.user;
      if (user == null) throw StateError('FirebaseAuth returned null user');

      await users.upsertOnAuth(user: user, email: email);
      await users.updateProfile(
        uid: user.uid,
        nickname: nickname,
        birthdate: birthdate,
        gender: gender,
      );
    });
  }

  Future<void> signInWithKakao() async {
    await _run(() async {
      _ensureFirebaseReady();
      final auth = ref.read(firebaseAuthRepositoryProvider);
      final kakao = ref.read(kakaoAuthRepositoryProvider);
      final users = ref.read(usersRepositoryProvider);

      final firebaseToken = await kakao.signInAndGetFirebaseToken();
      final cred = await auth.signInWithCustomToken(firebaseToken);
      final user = cred.user;
      if (user == null) throw StateError('FirebaseAuth returned null user');

      await users.upsertOnAuth(user: user, email: user.email);
    });
  }

  Future<void> signOut() async {
    await _run(() async {
      await ref.read(firebaseAuthRepositoryProvider).signOut();
    });
  }
}

String friendlyAuthError(Object error) {
  if (error is AuthUnavailableException) {
    return error.message;
  }
  if (error is FirebaseAuthException) {
    final msg = (error.message ?? '').trim();

    // 플랫폼 앱 등록/설정이 안 맞을 때 자주 보이는 케이스
    if (msg.contains('CONFIGURATION_NOT_FOUND')) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return 'Firebase 설정을 찾지 못했습니다. '
              'Android 앱(packageName)이 Firebase에 등록되어 있고 '
              '`android/app/google-services.json`가 현재 applicationId와 일치하는지 확인해주세요. '
              '가장 빠른 해결: `flutterfire configure --platforms=android` 실행 후 재빌드.';
        case TargetPlatform.iOS:
          return 'Firebase 설정을 찾지 못했습니다. '
              '`flutterfire configure --platforms=ios` 실행 후 '
              '`ios/Runner/GoogleService-Info.plist`가 최신인지 확인해주세요.';
        case TargetPlatform.macOS:
          return 'Firebase 설정을 찾지 못했습니다. '
              '`flutterfire configure --platforms=macos` 실행 후 '
              '`macos/Runner/GoogleService-Info.plist`가 최신인지 확인해주세요.';
        default:
          return 'Firebase 설정을 찾지 못했습니다. `flutterfire configure`로 설정을 동기화한 뒤 다시 시도해주세요.';
      }
    }

    // 일반적인 auth 에러는 "code + message"로 바로 진단 가능하게.
    if (msg.isNotEmpty) return '(${error.code}) $msg';
    return '(${error.code})';
  }
  if (error is FirebaseException) {
    final msg = (error.message ?? '').trim();
    if (msg.isNotEmpty) return '(${error.code}) $msg';
    return '(${error.code})';
  }
  if (kDebugMode) {
    // 너무 긴 네이티브 덤프가 UI로 노출되는 걸 방지
    final s = error.toString();
    return s.length > 200 ? s.substring(0, 200) : s;
  }
  return '로그인에 실패했습니다. 잠시 후 다시 시도해주세요.';
}

