import 'package:cloud_firestore/cloud_firestore.dart';

import 'place.dart';

class PlacesRepository {
  PlacesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// PRD 01: 지도에 노출할 상점은 status 가 active 또는 paused 인 것만.
  /// 레거시 문서 호환을 위해 isActive 필터는 유지하지 않고, 클라이언트에서
  /// [Place.isVisibleOnMap] 으로 2차 필터링한다.
  Stream<List<Place>> watchActivePlaces({int limit = 200}) {
    return _firestore
        .collection('places')
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Place.fromMap(d.id, d.data()))
              .where((p) =>
                  p.name.isNotEmpty &&
                  p.lat != 0 &&
                  p.lng != 0 &&
                  p.isVisibleOnMap)
              .toList(growable: false),
        );
  }
}
