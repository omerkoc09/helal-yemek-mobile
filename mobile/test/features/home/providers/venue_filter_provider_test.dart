import 'package:flutter_test/flutter_test.dart';
import 'package:caiz_mi/core/models/venue.dart';
import 'package:caiz_mi/features/home/providers/venue_filter_provider.dart';

Venue _v({
  required String id,
  required String name,
  double? rating,
  int reviewCount = 0,
  double? distance,
  List<int> cuisineIds = const [],
}) {
  return Venue(
    id: id,
    name: name,
    city: 'Istanbul',
    latitude: 0,
    longitude: 0,
    addedBy: 'u',
    status: 'approved',
    avgRating: rating,
    reviewCount: reviewCount,
    distance: distance,
    categories: [
      for (final cid in cuisineIds)
        FoodCategory(
          id: cid,
          key: 'k$cid',
          name: 'c$cid',
        ),
    ],
  );
}

void main() {
  final a = _v(id: 'a', name: 'Zeta', rating: 4.8, reviewCount: 50, distance: 1500, cuisineIds: [1]);
  final b = _v(id: 'b', name: 'alpha', rating: 4.2, reviewCount: 10, distance: 300, cuisineIds: [2]);
  final c = _v(id: 'c', name: 'Beta', rating: 3.9, reviewCount: 200, distance: 900, cuisineIds: [1, 2]);
  final d = _v(id: 'd', name: 'Gamma', rating: null, reviewCount: 0, distance: null, cuisineIds: [3]);
  final all = [a, b, c, d];

  VenueFilterState base() => VenueFilterState(allCityVenues: all);

  test('no filters + sort none returns original order', () {
    final result = applyVenueFilterPipeline(base());
    expect(result.map((v) => v.id).toList(), ['a', 'b', 'c', 'd']);
  });

  test('alphabetical sort is case-insensitive', () {
    final state = base().copyWith(sort: VenueSortOption.alphabetical);
    final result = applyVenueFilterPipeline(state);
    expect(result.map((v) => v.id).toList(), ['b', 'c', 'd', 'a']);
  });

  test('rating sort puts null/zero last', () {
    final state = base().copyWith(sort: VenueSortOption.rating);
    final result = applyVenueFilterPipeline(state);
    expect(result.first.id, 'a');
    expect(result.last.id, 'd');
  });

  test('distance sort puts null last', () {
    final state = base().copyWith(sort: VenueSortOption.distance);
    final result = applyVenueFilterPipeline(state);
    expect(result.map((v) => v.id).toList(), ['b', 'c', 'a', 'd']);
  });

  test('reviewCount sort DESC', () {
    final state = base().copyWith(sort: VenueSortOption.reviewCount);
    final result = applyVenueFilterPipeline(state);
    expect(result.first.id, 'c');
  });

  test('cuisine filter keeps OR-matches', () {
    final state = base().copyWith(selectedCuisineIds: {2});
    final result = applyVenueFilterPipeline(state);
    expect(result.map((v) => v.id).toSet(), {'b', 'c'});
  });

  test('distance filter drops nulls and over-threshold', () {
    final state = base().copyWith(distanceFilter: DistanceFilter.under1km);
    final result = applyVenueFilterPipeline(state);
    expect(result.map((v) => v.id).toSet(), {'b', 'c'});
  });

  test('rating filter 4.0+ drops reviewCount==0 and below threshold', () {
    final state = base().copyWith(ratingFilter: RatingFilter.above40);
    final result = applyVenueFilterPipeline(state);
    expect(result.map((v) => v.id).toSet(), {'a', 'b'});
  });

  test('combined: cuisines=[1] + above40 + under2km + alphabetical', () {
    final state = base().copyWith(
      selectedCuisineIds: {1},
      distanceFilter: DistanceFilter.under2km,
      ratingFilter: RatingFilter.above40,
      sort: VenueSortOption.alphabetical,
    );
    final result = applyVenueFilterPipeline(state);
    expect(result.map((v) => v.id).toList(), ['a']);
  });

  test('activeFilterCount counts cuisine/distance/rating only', () {
    final state = base().copyWith(
      sort: VenueSortOption.rating,
      selectedCuisineIds: {1},
      distanceFilter: DistanceFilter.under1km,
      ratingFilter: RatingFilter.all,
    );
    expect(state.activeFilterCount, 2);
  });
}
