import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_debug_log.dart';

class FirestoreUsersRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  Future<void> upsertOnAuth({
    required User user,
    required String? email,
  }) async {
    authDebugLog('users.upsertOnAuth start', {
      'uid': user.uid,
      'email': (email ?? user.email) ?? '',
    });
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
    try {
      final snap = await ref.get();
      authDebugLog('users.upsertOnAuth done', {
        'uid': user.uid,
        'docExists': snap.exists,
        'nickname': (snap.data()?['nickname'] ?? '').toString(),
        'email': (snap.data()?['email'] ?? '').toString(),
      });
    } catch (e) {
      authDebugLog('users.upsertOnAuth done (readback failed)', {
        'uid': user.uid,
        'error': e.toString(),
      });
    }
  }

  Future<void> updateProfile({
    required String uid,
    String? nickname,
    String? photoUrl,
    String? birthdate,
    String? ageRange,
    String? gender,
  }) async {
    authDebugLog('users.updateProfile start', {
      'uid': uid,
      if (nickname != null) 'nickname': nickname,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (birthdate != null) 'birthdate': birthdate,
      if (ageRange != null) 'ageRange': ageRange,
      if (gender != null) 'gender': gender,
    });
    final ref = _userRef(uid);
    final update = <String, dynamic>{};
    if (nickname != null) update['nickname'] = nickname;
    if (photoUrl != null) update['photoUrl'] = photoUrl;
    if (birthdate != null) update['birthdate'] = birthdate;
    if (ageRange != null) update['ageRange'] = ageRange;
    if (gender != null) update['gender'] = gender;

    if (update.isEmpty) return;
    await ref.set(update, SetOptions(merge: true));
    authDebugLog('users.updateProfile done', {'uid': uid});
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

