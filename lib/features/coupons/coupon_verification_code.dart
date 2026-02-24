import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Deterministic 6-digit staff verification code.
///
/// Why deterministic?
/// - Same coupon template should have the same code for all users.
/// - Easy to reproduce without storing extra lookup tables.
///
/// IMPORTANT: This is *not* a security feature. Treat it as a staff-side PIN
/// used for "use coupon" confirmation only.
String stableCouponVerificationCode({
  required String placeId,
  required String title,
}) {
  final seed = '$placeId|$title';
  final bytes = sha1.convert(utf8.encode(seed)).bytes;

  // Use first 4 bytes as unsigned int.
  final value =
      (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  final code = (value.abs() % 1000000).toString().padLeft(6, '0');
  return code;
}

