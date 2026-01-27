import 'package:cloud_firestore/cloud_firestore.dart';

import 'place.dart';

class PlacesRepository {
  PlacesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<Place>> watchActivePlaces({int limit = 200}) {
    return _firestore
        .collection('places')
        .where('isActive', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Place.fromMap(d.id, d.data()))
              .where((p) => p.name.isNotEmpty && p.lat != 0 && p.lng != 0)
              .toList(growable: false),
        );
  }
}
