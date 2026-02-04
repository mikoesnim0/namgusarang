import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_debug_log.dart';

class FirestoreUsersRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  /// Creates/updates `users/{uid}` on auth, but does NOT overwrite user-chosen fields
  /// (e.g. nickname) once they exist.
  Future<void> ensureProfileOnAuth({
    required User user,
    String? email,
    String? nickname,
    String? photoUrl,
  }) async {
    authDebugLog('users.ensureProfileOnAuth start', {
      'uid': user.uid,
      'email': (email ?? user.email) ?? '',
      if (nickname != null) 'nickname': nickname,
      if (photoUrl != null) 'photoUrl': photoUrl,
    });

    final ref = _userRef(user.uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();

      String? existingNickname = (data?['nickname'] as String?)?.trim();
      String? existingEmail = (data?['email'] as String?)?.trim();
      String? existingPhotoUrl = (data?['photoUrl'] as String?)?.trim();

      final now = FieldValue.serverTimestamp();
      final candidateEmail = (email ?? user.email)?.trim();
      final candidateNickname = nickname?.trim();
      final candidatePhotoUrl = photoUrl?.trim();

      final update = <String, dynamic>{
        'uid': user.uid,
        'lastLogin': now,
      };

      if (!snap.exists) {
        update.addAll({
          'createdAt': now,
          'totalSteps': 0,
          'todaySteps': 0,
          'friendInviteCode': _generateInviteCode(),
        });
      }

      if ((existingEmail == null || existingEmail.isEmpty) &&
          candidateEmail != null &&
          candidateEmail.isNotEmpty) {
        update['email'] = candidateEmail;
      }

      if ((existingNickname == null || existingNickname.isEmpty) &&
          candidateNickname != null &&
          candidateNickname.isNotEmpty) {
        update['nickname'] = candidateNickname;
      }

      if ((existingPhotoUrl == null || existingPhotoUrl.isEmpty) &&
          candidatePhotoUrl != null &&
          candidatePhotoUrl.isNotEmpty) {
        update['photoUrl'] = candidatePhotoUrl;
      }

      tx.set(ref, update, SetOptions(merge: true));
    });

    try {
      final snap = await ref.get();
      authDebugLog('users.ensureProfileOnAuth done', {
        'uid': user.uid,
        'docExists': snap.exists,
        'nickname': (snap.data()?['nickname'] ?? '').toString(),
        'email': (snap.data()?['email'] ?? '').toString(),
      });
    } catch (e) {
      authDebugLog('users.ensureProfileOnAuth done (readback failed)', {
        'uid': user.uid,
        'error': e.toString(),
      });
    }
  }

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
    int? heightCm,
    int? weightKg,
  }) async {
    authDebugLog('users.updateProfile start', {
      'uid': uid,
      if (nickname != null) 'nickname': nickname,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (birthdate != null) 'birthdate': birthdate,
      if (ageRange != null) 'ageRange': ageRange,
      if (gender != null) 'gender': gender,
      if (heightCm != null) 'heightCm': heightCm,
      if (weightKg != null) 'weightKg': weightKg,
    });
    final ref = _userRef(uid);
    final update = <String, dynamic>{};
    final trimmedNickname = nickname?.trim();
    final trimmedPhotoUrl = photoUrl?.trim();
    if (trimmedNickname != null && trimmedNickname.isNotEmpty) {
      update['nickname'] = trimmedNickname;
    }
    if (trimmedPhotoUrl != null && trimmedPhotoUrl.isNotEmpty) {
      update['photoUrl'] = trimmedPhotoUrl;
    }
    if (birthdate != null) update['birthdate'] = birthdate;
    if (ageRange != null) update['ageRange'] = ageRange;
    if (gender != null) update['gender'] = gender;
    if (heightCm != null) update['heightCm'] = heightCm;
    if (weightKg != null) update['weightKg'] = weightKg;

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

  static String _yyyyMmDd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Ensures cycle fields exist, and rolls to the next cycle when 10 days pass.
  ///
  /// Fields used in `users/{uid}`:
  /// - `cycleStartDate` (String, yyyy-MM-dd)
  /// - `cycleIndex` (int, 1..)
  /// - `cycleCompletedDays` (List<int>)
  /// - `cycleFailedDays` (List<int>)
  /// - `lastCycleCheckDate` (String, yyyy-MM-dd) to avoid repeated writes per day.
  Future<void> ensureCycleReady({required String uid}) async {
    final ref = _userRef(uid);
    final today = DateTime.now();
    final todayStr = _yyyyMmDd(today);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? const <String, dynamic>{};

      final lastCheck = (data['lastCycleCheckDate'] as String?)?.trim();
      if (lastCheck == todayStr) return;

      final startStr = (data['cycleStartDate'] as String?)?.trim();
      final startDate =
          (startStr != null && startStr.isNotEmpty) ? DateTime.tryParse(startStr) : null;
      final currentIndex = (data['cycleIndex'] is num)
          ? (data['cycleIndex'] as num).round()
          : 1;

      DateTime effectiveStart = startDate ?? DateTime(today.year, today.month, today.day);
      int effectiveIndex = currentIndex <= 0 ? 1 : currentIndex;
      final completedRaw = (data['cycleCompletedDays'] as List?) ?? const [];
      final failedRaw = (data['cycleFailedDays'] as List?) ?? const [];

      // Day index is 1-based within the cycle.
      int dayIndex = today
              .difference(DateTime(effectiveStart.year, effectiveStart.month, effectiveStart.day))
              .inDays +
          1;

      // If cycle ended, roll forward to a fresh cycle starting today.
      if (dayIndex > 10) {
        effectiveIndex += 1;
        effectiveStart = DateTime(today.year, today.month, today.day);
        // Reset per-cycle lists. (We don't carry forward failures/completions.)
        tx.set(
          ref,
          {
            'cycleStartDate': _yyyyMmDd(effectiveStart),
            'cycleIndex': effectiveIndex,
            'cycleCompletedDays': const <int>[],
            'cycleFailedDays': const <int>[],
            'lastCycleCheckDate': todayStr,
          },
          SetOptions(merge: true),
        );
        dayIndex = 1;
        return;
      }

      final completed = completedRaw
          .map((e) => (e is num) ? e.round() : int.tryParse(e.toString()))
          .whereType<int>()
          .where((d) => d >= 1 && d <= 10)
          .toSet();
      final failed = failedRaw
          .map((e) => (e is num) ? e.round() : int.tryParse(e.toString()))
          .whereType<int>()
          .where((d) => d >= 1 && d <= 10)
          .toSet();

      // Auto-mark past days as failed if they were never completed.
      // This also fills gaps if the user didn't open the app for a few days.
      if (dayIndex > 1) {
        for (var d = 1; d <= dayIndex - 1 && d <= 10; d++) {
          if (!completed.contains(d) && !failed.contains(d)) {
            failed.add(d);
          }
        }
      }

      tx.set(
        ref,
        {
          'cycleStartDate': _yyyyMmDd(effectiveStart),
          'cycleIndex': effectiveIndex,
          'cycleCompletedDays': completed.toList()..sort(),
          'cycleFailedDays': failed.toList()..sort(),
          'lastCycleCheckDate': todayStr,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> markCycleDayCompleted({
    required String uid,
    required int dayIndex,
  }) async {
    if (dayIndex < 1 || dayIndex > 10) return;
    final ref = _userRef(uid);
    await ref.set(
      {
        'cycleCompletedDays': FieldValue.arrayUnion([dayIndex]),
        // If it was previously marked failed (e.g. device time issues), fix it.
        'cycleFailedDays': FieldValue.arrayRemove([dayIndex]),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> markIntroSeen({required String uid}) async {
    final ref = _userRef(uid);
    await ref.set(
      {
        'introSeen': true,
        'introSeenAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
