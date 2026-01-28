import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_providers.dart';
import 'coupon_model.dart';

enum CouponFilter {
  all,
  active,
  used,
  expired,
}

enum CouponSort {
  expiresSoon,
  expiresLate,
  title,
}

final couponFilterProvider = StateProvider<CouponFilter>((ref) {
  return CouponFilter.active;
});

final couponSortProvider = StateProvider<CouponSort>((ref) {
  return CouponSort.expiresSoon;
});

final couponSearchQueryProvider = StateProvider<String>((ref) => '');

final couponsSeenRepositoryProvider = Provider<CouponsSeenRepository>((ref) {
  return CouponsSeenRepository(prefs: SharedPreferences.getInstance());
});

final couponsLastSeenAtProvider = FutureProvider<DateTime>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return DateTime.fromMillisecondsSinceEpoch(0);
  final repo = ref.read(couponsSeenRepositoryProvider);
  return (await repo.getLastSeenAt(uid)) ?? DateTime.fromMillisecondsSinceEpoch(0);
});

final newCouponsCountProvider = Provider<int>((ref) {
  final lastSeenAsync = ref.watch(couponsLastSeenAtProvider);
  if (lastSeenAsync.isLoading) return 0; // avoid false-positive badge during init
  final lastSeen = lastSeenAsync.valueOrNull ?? DateTime.fromMillisecondsSinceEpoch(0);

  final coupons = ref.watch(couponsStreamProvider).valueOrNull ?? const <Coupon>[];
  return coupons.where((c) {
    if (c.status != CouponStatus.active) return false;
    final created = c.createdAt;
    if (created == null) return false;
    return created.isAfter(lastSeen);
  }).length;
});

final couponByIdProvider = StreamProvider.family<Coupon?, String>((ref, couponId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('coupons')
      .doc(couponId)
      .snapshots()
      .map((s) => s.data() == null ? null : _couponFromMap(s.id, s.data()!));
});

final couponsStreamProvider = StreamProvider<List<Coupon>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();

  // User-scoped coupons: /users/{uid}/coupons/{couponId}
  final q = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('coupons');

  return q.snapshots().map((snap) => snap.docs.map(_couponFromDoc).toList());
});

final placeCouponsProvider = StreamProvider.family<List<Coupon>, String>((
  ref,
  placeId,
) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();

  final q = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('coupons')
      .where('placeId', isEqualTo: placeId);

  return q.snapshots().map((snap) => snap.docs.map(_couponFromDoc).toList());
});

final visibleCouponsProvider = Provider<AsyncValue<List<Coupon>>>((ref) {
  final couponsAsync = ref.watch(couponsStreamProvider);
  final filter = ref.watch(couponFilterProvider);
  final sort = ref.watch(couponSortProvider);
  final q = ref.watch(couponSearchQueryProvider).trim().toLowerCase();

  return couponsAsync.whenData((coupons) {
    Iterable<Coupon> filtered = coupons;
    switch (filter) {
      case CouponFilter.all:
        break;
      case CouponFilter.active:
        filtered = filtered.where((c) => c.status == CouponStatus.active);
        break;
      case CouponFilter.used:
        filtered = filtered.where((c) => c.status == CouponStatus.used);
        break;
      case CouponFilter.expired:
        filtered = filtered.where((c) => c.status == CouponStatus.expired);
        break;
    }

    final list = filtered.toList();

    if (q.isNotEmpty) {
      list.retainWhere((c) {
        final hay = '${c.placeName} ${c.title} ${c.description}'.toLowerCase();
        return hay.contains(q);
      });
    }

    switch (sort) {
      case CouponSort.expiresSoon:
        list.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
        break;
      case CouponSort.expiresLate:
        list.sort((a, b) => b.expiresAt.compareTo(a.expiresAt));
        break;
      case CouponSort.title:
        list.sort((a, b) => a.title.compareTo(b.title));
        break;
    }
    return list;
  });
});

final couponsRepositoryProvider = Provider<CouponsRepository>((ref) {
  return CouponsRepository(FirebaseFirestore.instance);
});

class CouponsRepository {
  CouponsRepository(this._db);

  final FirebaseFirestore _db;
  static const _userCouponsSubcollection = 'coupons';

  Future<bool> issueCouponForUser({
    required String uid,
    required String couponId,
    required Map<String, dynamic> data,
  }) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection(_userCouponsSubcollection)
        .doc(couponId);

    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) return false;
      tx.set(ref, {
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  static bool isValidCode(String code) {
    if (code.length != 6) return false;
    for (final c in code.codeUnits) {
      if (c < 48 || c > 57) return false;
    }
    return true;
  }

  Future<bool> redeemForUser({
    required String uid,
    required String couponId,
    required String inputCode,
  }) async {
    if (!isValidCode(inputCode)) return false;

    final ref = _db
        .collection('users')
        .doc(uid)
        .collection(_userCouponsSubcollection)
        .doc(couponId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;

      final data = snap.data() as Map<String, dynamic>;
      final status = (data['status'] as String?) ?? 'active';
      final code = (data['verificationCode'] as String?) ?? '';
      if (status != 'active') return false;
      if (code != inputCode) return false;

      tx.update(ref, {
        'status': 'used',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }
}

class CouponsSeenRepository {
  CouponsSeenRepository({required Future<SharedPreferences> prefs}) : _prefs = prefs;

  final Future<SharedPreferences> _prefs;

  String _kLastSeenAt(String uid) => 'coupons.lastSeenAt.$uid';

  Future<DateTime?> getLastSeenAt(String uid) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_kLastSeenAt(uid));
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  Future<void> setLastSeenNow(String uid) async {
    final prefs = await _prefs;
    await prefs.setString(_kLastSeenAt(uid), DateTime.now().toIso8601String());
  }
}

Coupon _couponFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
  return _couponFromMap(d.id, d.data());
}

Coupon _couponFromMap(String id, Map<String, dynamic> data) {
  final statusRaw = (data['status'] as String?)?.trim().toLowerCase() ?? 'active';
  final status = switch (statusRaw) {
    'used' => CouponStatus.used,
    'expired' => CouponStatus.expired,
    _ => CouponStatus.active,
  };

  DateTime tsToDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now().add(const Duration(days: 7));
  }

  DateTime? tsToDateNullable(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  return Coupon(
    id: id,
    title: (data['title'] as String?)?.trim() ?? '',
    description: (data['description'] as String?)?.trim() ?? '',
    verificationCode: (data['verificationCode'] as String?)?.trim() ?? '',
    placeId: (data['placeId'] as String?)?.trim() ?? '',
    placeName: (data['placeName'] as String?)?.trim() ?? '',
    status: status,
    expiresAt: tsToDate(data['expiresAt']),
    createdAt: tsToDateNullable(data['createdAt']),
  );
}
