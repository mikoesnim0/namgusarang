import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'payment_history_model.dart';

/// 결제 내역 (최신순, 최대 50건)
final paymentHistoryProvider =
    FutureProvider<List<PaymentHistoryEvent>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const [];

  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('payment_history')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .get();

  return snapshot.docs
      .map((doc) => PaymentHistoryEvent.fromFirestore(doc.id, doc.data()))
      .toList();
});
