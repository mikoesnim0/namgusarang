import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/auth_providers.dart';
import 'friends_model.dart';
import 'friends_repository.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return FriendsRepository(
    firestore: FirebaseFirestore.instance,
    functions: FriendsRepository.defaultFunctions(),
  );
});

final friendsStreamProvider = StreamProvider<List<Friend>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref.read(friendsRepositoryProvider).watchFriends(uid: uid);
});

final incomingFriendRequestsStreamProvider = StreamProvider<List<FriendRequestIn>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref.read(friendsRepositoryProvider).watchIncomingRequests(uid: uid);
});

final outgoingFriendRequestsStreamProvider = StreamProvider<List<FriendRequestOut>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref.read(friendsRepositoryProvider).watchOutgoingRequests(uid: uid);
});

final incomingFriendRequestsCountProvider = Provider<int>((ref) {
  final list = ref.watch(incomingFriendRequestsStreamProvider).valueOrNull;
  return list?.length ?? 0;
});

final inviteInfoProvider = Provider<InviteInfo>((ref) {
  final userDoc = ref.watch(currentUserDocProvider).valueOrNull;
  final code = (userDoc?['friendInviteCode'] as String?)?.trim() ?? '';

  final shareText = code.isEmpty
      ? 'Walker홀릭에서 같이 걸어요!'
      : 'Walker홀릭에서 같이 걸어요!\n\n초대코드: $code\n(앱에서 친구목록 → 초대코드로 추가)';

  return InviteInfo(code: code, shareText: shareText);
});

