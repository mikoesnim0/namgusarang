import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthUnavailableException implements Exception {
  const AuthUnavailableException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthActionException implements Exception {
  const AuthActionException({
    required this.action,
    required this.cause,
  });

  final String action;
  final Object cause;

  @override
  String toString() => 'AuthActionException(action=$action, cause=$cause)';
}

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // no-op: controller only runs when actions are invoked
  }

  Future<void> _run(String actionName, Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
    } catch (e, st) {
      // Always log full details so we can debug native/Firebase issues (esp. on macOS).
      debugPrint('AuthController error (action=$actionName): $e');
      if (e is FirebaseAuthException) {
        debugPrint('FirebaseAuthException(code=${e.code}, message=${e.message})');
      } else if (e is FirebaseException) {
        debugPrint('FirebaseException(plugin=${e.plugin}, code=${e.code}, message=${e.message})');
      }
      debugPrintStack(stackTrace: st);
      state = AsyncError(AuthActionException(action: actionName, cause: e), st);
    }
  }

  void _ensureFirebaseReady() {
    if (Firebase.apps.isEmpty) {
      throw const AuthUnavailableException(
        'Firebase가 초기화되지 않았습니다. (main.dart에서 Firebase.initializeApp이 성공해야 합니다)',
      );
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _run('login/email', () async {
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
    await _run('signup/email', () async {
      _ensureFirebaseReady();
      final auth = ref.read(firebaseAuthRepositoryProvider);
      final users = ref.read(usersRepositoryProvider);

      final trimmedNickname = nickname.trim();
      if (trimmedNickname.isEmpty) {
        throw const AuthUnavailableException('닉네임을 입력해주세요.');
      }
      final available = await users.isNicknameAvailable(trimmedNickname);
      if (!available) {
        throw const AuthUnavailableException('이미 사용 중인 닉네임입니다. 다른 닉네임을 선택해주세요.');
      }

      final cred = await auth.signUpWithEmail(email: email, password: password);
      final user = cred.user;
      if (user == null) throw StateError('FirebaseAuth returned null user');

      await users.upsertOnAuth(user: user, email: email);
      await users.updateProfile(
        uid: user.uid,
        nickname: trimmedNickname,
        birthdate: birthdate,
        gender: gender,
      );
    });
  }

  Future<void> signInWithKakao() async {
    await _run('login/kakao', () async {
      _ensureFirebaseReady();
      final auth = ref.read(firebaseAuthRepositoryProvider);
      final kakao = ref.read(kakaoAuthRepositoryProvider);
      final users = ref.read(usersRepositoryProvider);

      final result = await kakao.signInAndGetFirebaseToken();
      final cred = await auth.signInWithCustomToken(result.firebaseToken);
      final user = cred.user;
      if (user == null) throw StateError('FirebaseAuth returned null user');

      await users.upsertOnAuth(user: user, email: result.kakaoEmail ?? user.email);
      await users.updateProfile(
        uid: user.uid,
        nickname: result.kakaoNickname,
        photoUrl: result.kakaoPhotoURL,
      );
    });
  }

  Future<void> signOut() async {
    await _run('signout', () async {
      await ref.read(firebaseAuthRepositoryProvider).signOut();
    });
  }
}

String debugAuthErrorDetails(Object error, StackTrace? stackTrace) {
  Object e = error;
  final action = (e is AuthActionException) ? e.action : null;
  if (e is AuthActionException) e = e.cause;

  final lines = <String>[
    if (action != null) 'action: $action',
    'type: ${e.runtimeType}',
  ];

  if (e is FirebaseAuthException) {
    lines.addAll([
      'firebaseAuth.code: ${e.code}',
      'firebaseAuth.message: ${e.message}',
      'firebaseAuth.email: ${e.email}',
      'firebaseAuth.credential: ${e.credential}',
    ]);
  } else if (e is FirebaseException) {
    lines.addAll([
      'firebase.plugin: ${e.plugin}',
      'firebase.code: ${e.code}',
      'firebase.message: ${e.message}',
    ]);
    if (e is FirebaseFunctionsException) {
      lines.add('firebase.details: ${e.details}');
    }
  } else {
    lines.add('message: $e');
  }

  if (stackTrace != null) {
    lines.add('');
    lines.add('stack:');
    lines.add(stackTrace.toString());
  }
  return lines.join('\n');
}

String friendlyAuthError(Object error) {
  if (error is AuthActionException) {
    // Prefix with action label so we know where it came from.
    return '[${error.action}] ${friendlyAuthError(error.cause)}';
  }
  if (error is UnsupportedError) {
    return error.message ?? error.toString();
  }
  if (error is AuthUnavailableException) {
    return error.message;
  }
  if (error is FirebaseAuthException) {
    final msg = (error.message ?? '').trim();

    if (error.code == 'invalid-credential') {
      return '이메일/비밀번호가 올바르지 않습니다. (raw: ${error.code}${msg.isNotEmpty ? ', $msg' : ''})';
    }
    if (error.code == 'keychain-error') {
      return 'macOS Keychain 접근 오류로 인증 정보를 저장하지 못했습니다. '
          '`macos/Runner/DebugProfile.entitlements`/`Release.entitlements`에 keychain-access-groups 설정 후 '
          '`flutter clean` 후 재실행해보세요. (raw: ${error.code}${msg.isNotEmpty ? ', $msg' : ''})';
    }

    // 플랫폼 앱 등록/설정이 안 맞을 때 자주 보이는 케이스
    if (msg.contains('CONFIGURATION_NOT_FOUND')) {
      final raw = ' (raw: ${error.code}${msg.isNotEmpty ? ', $msg' : ''})';
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return 'Firebase 설정을 찾지 못했습니다. '
              'Android 앱(packageName)이 Firebase에 등록되어 있고 '
              '`android/app/google-services.json`가 현재 applicationId와 일치하는지 확인해주세요. '
              '가장 빠른 해결: `flutterfire configure --platforms=android` 실행 후 재빌드.'
              '$raw';
        case TargetPlatform.iOS:
          return 'Firebase 설정을 찾지 못했습니다. '
              '`flutterfire configure --platforms=ios` 실행 후 '
              '`ios/Runner/GoogleService-Info.plist`가 최신인지 확인해주세요.'
              '$raw';
        case TargetPlatform.macOS:
          return 'Firebase 설정을 찾지 못했습니다. '
              'macOS는 iOS와 별도 앱 등록이 필요한 경우가 많습니다. '
              '`macos-bundle-id=${"com.doyakmin.hangookji.namgu.macos"}`로 새 앱을 만들도록 '
              '`flutterfire configure --platforms=macos --macos-bundle-id=com.doyakmin.hangookji.namgu.macos` 실행 후 '
              '`macos/Runner/GoogleService-Info.plist`가 최신인지 확인해주세요.'
              '$raw';
        default:
          return 'Firebase 설정을 찾지 못했습니다. `flutterfire configure`로 설정을 동기화한 뒤 다시 시도해주세요.$raw';
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

