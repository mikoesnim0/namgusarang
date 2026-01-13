import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreUsersRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  Future<void> upsertOnAuth({
    required User user,
    required String? email,
  }) async {
    final ref = _userRef(user.uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);

      final now = FieldValue.serverTimestamp();
      if (!snap.exists) {
        tx.set(ref, {
          'uid': user.uid,
          'email': email ?? user.email,
          'createdAt': now,
          'lastLogin': now,
          'totalSteps': 0,
          'todaySteps': 0,
          'friendInviteCode': _generateInviteCode(),
        }, SetOptions(merge: true));
      } else {
        tx.set(ref, {
          'uid': user.uid,
          'email': email ?? user.email,
          'lastLogin': now,
        }, SetOptions(merge: true));
      }
    });
  }

  Future<void> updateProfile({
    required String uid,
    String? nickname,
    String? birthdate,
    String? gender,
  }) async {
    final ref = _userRef(uid);
    final update = <String, dynamic>{};
    if (nickname != null) update['nickname'] = nickname;
    if (birthdate != null) update['birthdate'] = birthdate;
    if (gender != null) update['gender'] = gender;

    if (update.isEmpty) return;
    await ref.set(update, SetOptions(merge: true));
  }

  /// Best-effort uniqueness check (NOT race-free).
  /// For strict uniqueness, enforce via a server-side transaction (e.g. nickname index collection).
  Future<bool> isNicknameAvailable(
    String nickname, {
    String? ignoreUid,
  }) async {
    final q = await _db
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return true;
    if (ignoreUid == null) return false;
    return q.docs.first.id == ignoreUid;
  }

  static String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }
}

