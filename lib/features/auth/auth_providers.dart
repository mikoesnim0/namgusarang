import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Firestore user doc for the currently signed-in user (or null).
final currentUserDocProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((s) => s.data());
});

