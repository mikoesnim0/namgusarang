import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // no-op: controller only runs when actions are invoked
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
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
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
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
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
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
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(firebaseAuthRepositoryProvider).signOut();
    });
  }
}

String friendlyAuthError(Object error) {
  if (error is FirebaseException) {
    return error.message ?? error.code;
  }
  if (kDebugMode) {
    return error.toString();
  }
  return '로그인에 실패했습니다. 잠시 후 다시 시도해주세요.';
}

