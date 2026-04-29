/// PRD 01_가맹점_관리: 상점은 4가지 운영 상태를 갖는다.
/// - active: 정상 운영중. 지도 노출 + 쿠폰 사용 가능.
/// - paused: 임시중지. 지도에는 보이나 쿠폰 사용 불가.
/// - inactive: 비활성. 지도에서 숨김. 관리자 화면에서만 보임.
/// - terminated: 종료. 과거 사용내역만 남고 앱에서 완전히 숨김.
enum StoreStatus {
  active,
  paused,
  inactive,
  terminated;

  static StoreStatus fromRaw(dynamic raw) {
    final s = (raw as String?)?.trim().toLowerCase();
    switch (s) {
      case 'active':
      case '운영중':
        return StoreStatus.active;
      case 'paused':
      case '임시중지':
        return StoreStatus.paused;
      case 'inactive':
      case '비활성':
        return StoreStatus.inactive;
      case 'terminated':
      case '종료':
        return StoreStatus.terminated;
      default:
        return StoreStatus.active;
    }
  }

  /// 지도에 마커로 표시할지.
  bool get isVisibleOnMap =>
      this == StoreStatus.active || this == StoreStatus.paused;

  /// 쿠폰 사용이 가능한지. 임시중지 / 비활성 / 종료 는 사용 불가.
  bool get isCouponRedeemable => this == StoreStatus.active;
}

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.address = '',
    this.category = '',
    this.openingHours = '',
    this.naverPlaceUrl = '',
    this.isActive = true,
    this.status = StoreStatus.active,
    this.hasCoupons = false,
    this.useCode = '',
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final String address;
  final String category;
  final String openingHours;
  final String naverPlaceUrl;
  // 하위 호환: 기존 코드가 isActive 를 참조하므로 유지한다.
  // 신규 코드는 [status] 를 사용할 것.
  final bool isActive;
  final StoreStatus status;
  final bool hasCoupons;
  final String useCode;

  bool get isVisibleOnMap => status.isVisibleOnMap && isActive;
  bool get isCouponRedeemable => status.isCouponRedeemable && isActive;

  factory Place.fromMap(String id, Map<String, dynamic> data) {
    double asDouble(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    // 신규 문서는 status 문자열을 갖고, 레거시 문서는 isActive(bool)만 갖는다.
    final hasStatusField = (data['status'] as String?)?.trim().isNotEmpty == true;
    final rawActive = (data['isActive'] as bool?) ?? true;
    final status = hasStatusField
        ? StoreStatus.fromRaw(data['status'])
        : (rawActive ? StoreStatus.active : StoreStatus.inactive);

    return Place(
      id: id,
      name: (data['name'] as String?)?.trim() ?? '',
      lat: asDouble(data['lat']),
      lng: asDouble(data['lng']),
      address: (data['address'] as String?)?.trim() ?? '',
      category: (data['category'] as String?)?.trim() ?? '',
      openingHours: (data['openingHours'] as String?)?.trim() ?? '',
      naverPlaceUrl: (data['naverPlaceUrl'] as String?)?.trim() ?? '',
      isActive: rawActive && status != StoreStatus.inactive && status != StoreStatus.terminated,
      status: status,
      hasCoupons: (data['hasCoupons'] as bool?) ?? false,
      useCode: (data['useCode'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'lat': lat,
    'lng': lng,
    'address': address,
    'category': category,
    'openingHours': openingHours,
    'naverPlaceUrl': naverPlaceUrl,
    'isActive': isActive,
    'status': status.name,
    'hasCoupons': hasCoupons,
  };
}
