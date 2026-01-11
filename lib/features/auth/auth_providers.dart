import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_auth_repository.dart';
import 'firestore_users_repository.dart';
import 'kakao_auth_repository.dart';

final firebaseAuthRepositoryProvider = Provider<FirebaseAuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final kakaoAuthRepositoryProvider = Provider<KakaoAuthRepository>((ref) {
  return KakaoAuthRepository();
});

final usersRepositoryProvider = Provider<FirestoreUsersRepository>((ref) {
  return FirestoreUsersRepository();
});

