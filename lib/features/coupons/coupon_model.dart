enum CouponStatus {
  active,
  used,
  expired,
}

class Coupon {
  const Coupon({
    required this.id,
    required this.title,
    required this.description,
    required this.verificationCode,
    required this.placeId,
    required this.placeName,
    required this.status,
    required this.expiresAt,
  });

  final String id;
  final String title;
  final String description;
  final String verificationCode; // 6 digits
  final String placeId;
  final String placeName;
  final CouponStatus status;
  final DateTime expiresAt;

  bool get isActive => status == CouponStatus.active;

  Coupon copyWith({CouponStatus? status}) {
    return Coupon(
      id: id,
      title: title,
      description: description,
      verificationCode: verificationCode,
      placeId: placeId,
      placeName: placeName,
      status: status ?? this.status,
      expiresAt: expiresAt,
    );
  }
}
