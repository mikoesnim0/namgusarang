import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final couponsStreamProvider = StreamProvider<List<Coupon>>((ref) {
  // MVP: read from a shared collection. Later we should scope by userId.
  final q = FirebaseFirestore.instance.collection('coupons');
  return q.snapshots().map((snap) {
    return snap.docs.map((d) => _couponFromDoc(d)).toList();
  });
});

final placeCouponsProvider = StreamProvider.family<List<Coupon>, String>((
  ref,
  placeId,
) {
  final q = FirebaseFirestore.instance
      .collection('coupons')
      .where('placeId', isEqualTo: placeId);
  return q.snapshots().map((snap) {
    return snap.docs.map((d) => _couponFromDoc(d)).toList();
  });
});

final visibleCouponsProvider = Provider<AsyncValue<List<Coupon>>>((ref) {
  final couponsAsync = ref.watch(couponsStreamProvider);
  final filter = ref.watch(couponFilterProvider);
  final sort = ref.watch(couponSortProvider);

  return couponsAsync.whenData((coupons) {
    Iterable<Coupon> filtered = coupons;
    switch (filter) {
      case CouponFilter.all:
        break;
      case CouponFilter.active:
        filtered = filtered.where((c) => c.status == CouponStatus.active);
      case CouponFilter.used:
        filtered = filtered.where((c) => c.status == CouponStatus.used);
      case CouponFilter.expired:
        filtered = filtered.where((c) => c.status == CouponStatus.expired);
    }

    final list = filtered.toList();
    switch (sort) {
      case CouponSort.expiresSoon:
        list.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
      case CouponSort.expiresLate:
        list.sort((a, b) => b.expiresAt.compareTo(a.expiresAt));
      case CouponSort.title:
        list.sort((a, b) => a.title.compareTo(b.title));
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

  static bool isValidCode(String code) {
    if (code.length != 6) return false;
    for (final c in code.codeUnits) {
      if (c < 48 || c > 57) return false;
    }
    return true;
  }

  Future<bool> redeem({
    required String couponId,
    required String inputCode,
  }) async {
    if (!isValidCode(inputCode)) return false;

    final ref = _db.collection('coupons').doc(couponId);
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

Coupon _couponFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
  final data = d.data();
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

  return Coupon(
    id: d.id,
    title: (data['title'] as String?)?.trim() ?? '',
    description: (data['description'] as String?)?.trim() ?? '',
    verificationCode: (data['verificationCode'] as String?)?.trim() ?? '',
    placeId: (data['placeId'] as String?)?.trim() ?? '',
    placeName: (data['placeName'] as String?)?.trim() ?? '',
    status: status,
    expiresAt: tsToDate(data['expiresAt']),
  );
}
