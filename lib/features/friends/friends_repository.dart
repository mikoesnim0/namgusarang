import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'friends_model.dart';

class FriendsRepository {
  FriendsRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _db = firestore,
        _functions = functions;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  static const _region = 'asia-northeast3';

  static FirebaseFunctions defaultFunctions() =>
      FirebaseFunctions.instanceFor(region: _region);

  Stream<List<Friend>> watchFriends({required String uid}) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('friends')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_friendFromDoc).toList());
  }

  Stream<List<FriendRequestIn>> watchIncomingRequests({required String uid}) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('friend_requests_in')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_requestInFromDoc).toList());
  }

  Stream<List<FriendRequestOut>> watchOutgoingRequests({required String uid}) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('friend_requests_out')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_requestOutFromDoc).toList());
  }

  Future<void> ensurePublicProfile() async {
    final callable = _functions.httpsCallable('ensurePublicProfile');
    await callable.call();
  }

  Future<void> sendRequestByNickname(String nickname) async {
    final callable = _functions.httpsCallable('sendFriendRequestByNickname');
    await callable.call({'nickname': nickname});
  }

  Future<void> sendRequestByInviteCode(String code) async {
    final callable = _functions.httpsCallable('sendFriendRequestByInviteCode');
    await callable.call({'code': code});
  }

  Future<void> acceptRequest({required String fromUid}) async {
    final callable = _functions.httpsCallable('acceptFriendRequest');
    await callable.call({'fromUid': fromUid});
  }

  Future<void> declineRequest({required String fromUid}) async {
    final callable = _functions.httpsCallable('declineFriendRequest');
    await callable.call({'fromUid': fromUid});
  }

  Future<void> cancelRequest({required String toUid}) async {
    final callable = _functions.httpsCallable('cancelFriendRequest');
    await callable.call({'toUid': toUid});
  }

  Future<void> removeFriend({required String friendUid}) async {
    final callable = _functions.httpsCallable('removeFriend');
    await callable.call({'friendUid': friendUid});
  }

  Future<void> changeNickname(String newNickname) async {
    final callable = _functions.httpsCallable('changeNickname');
    await callable.call({'nickname': newNickname});
  }
}

Friend _friendFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
  final data = d.data();
  DateTime tsToDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  return Friend(
    friendUid: (data['friendUid'] as String?)?.trim() ?? d.id,
    nickname: (data['friendNickname'] as String?)?.trim() ?? '',
    photoUrl: (data['friendPhotoUrl'] as String?)?.trim(),
    level: data['friendLevel'] is int ? data['friendLevel'] as int : null,
    profileIndex:
        data['friendProfileIndex'] is int ? data['friendProfileIndex'] as int : null,
    createdAt: tsToDate(data['createdAt']),
    snapshotAt: data['snapshotAt'] == null ? null : tsToDate(data['snapshotAt']),
    rewardWon: data['rewardWon'] is int ? data['rewardWon'] as int : null,
    totalSteps: data['totalSteps'] is int ? data['totalSteps'] as int : null,
    dailySteps: data['dailySteps'] is int ? data['dailySteps'] as int : null,
  );
}

FriendRequestIn _requestInFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
  final data = d.data();
  DateTime tsToDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  return FriendRequestIn(
    fromUid: (data['fromUid'] as String?)?.trim() ?? d.id,
    nickname: (data['fromNickname'] as String?)?.trim() ?? '',
    photoUrl: (data['fromPhotoUrl'] as String?)?.trim(),
    level: data['fromLevel'] is int ? data['fromLevel'] as int : null,
    profileIndex:
        data['fromProfileIndex'] is int ? data['fromProfileIndex'] as int : null,
    createdAt: tsToDate(data['createdAt']),
  );
}

FriendRequestOut _requestOutFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
  final data = d.data();
  DateTime tsToDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  return FriendRequestOut(
    toUid: (data['toUid'] as String?)?.trim() ?? d.id,
    nickname: (data['toNickname'] as String?)?.trim() ?? '',
    photoUrl: (data['toPhotoUrl'] as String?)?.trim(),
    createdAt: tsToDate(data['createdAt']),
  );
}

