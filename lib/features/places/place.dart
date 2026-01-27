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
    this.hasCoupons = false,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final String address;
  final String category;
  final String openingHours;
  final String naverPlaceUrl;
  final bool isActive;
  final bool hasCoupons;

  factory Place.fromMap(String id, Map<String, dynamic> data) {
    double asDouble(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    return Place(
      id: id,
      name: (data['name'] as String?)?.trim() ?? '',
      lat: asDouble(data['lat']),
      lng: asDouble(data['lng']),
      address: (data['address'] as String?)?.trim() ?? '',
      category: (data['category'] as String?)?.trim() ?? '',
      openingHours: (data['openingHours'] as String?)?.trim() ?? '',
      naverPlaceUrl: (data['naverPlaceUrl'] as String?)?.trim() ?? '',
      isActive: (data['isActive'] as bool?) ?? true,
      hasCoupons: (data['hasCoupons'] as bool?) ?? false,
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
    'hasCoupons': hasCoupons,
  };
}
