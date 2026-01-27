import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'place.dart';
import 'places_repository.dart';

final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  return PlacesRepository();
});

final activePlacesProvider = StreamProvider.autoDispose<List<Place>>((ref) {
  return ref.watch(placesRepositoryProvider).watchActivePlaces();
});
