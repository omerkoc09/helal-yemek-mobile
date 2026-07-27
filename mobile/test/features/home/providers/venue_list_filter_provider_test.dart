import 'package:flutter_test/flutter_test.dart';
import 'package:itimat/core/models/venue.dart';
import 'package:itimat/features/home/providers/venue_filter_provider.dart';
import 'package:itimat/features/home/providers/venue_list_filter_provider.dart';

Venue _v({
  required String id,
  required String name,
  String city = 'Istanbul',
  double? rating,
  int reviewCount = 0,
  double? distance,
  List<int> cuisineIds = const [],
}) {
  return Venue(
    id: id,
    name: name,
    city: city,
    latitude: 0,
    longitude: 0,
    addedBy: 'u',
    status: 'approved',
    avgRating: rating,
    reviewCount: reviewCount,
    distance: distance,
    categories: [
      for (final cid in cuisineIds)
        FoodCategory(id: cid, key: 'k$cid', name: 'c$cid'),
    ],
  );
}

void main() {
  final kebapci = _v(
      id: 'a', name: 'Kebapçı Ali', rating: 4.8, reviewCount: 50, distance: 1500, cuisineIds: [1]);
  final pideci = _v(
      id: 'b', name: 'Pideci Veli', rating: 4.2, reviewCount: 10, distance: 300, cuisineIds: [2]);
  final kebapSaray = _v(
      id: 'c', name: 'KEBAP Saray', rating: 3.9, reviewCount: 200, distance: 900, cuisineIds: [1, 2]);
  final ankaraVenue = _v(
      id: 'd', name: 'Ankara Sofrası', city: 'Ankara', rating: 4.6, reviewCount: 30, distance: 90000, cuisineIds: [3]);
  final all = [kebapci, pideci, kebapSaray, ankaraVenue];

  group('nameQuery', () {
    test('matches case-insensitively as a substring', () {
      final result = filterAndSortVenues(all,
          sort: VenueSortOption.none, nameQuery: 'kebap');
      expect(result.map((v) => v.id).toSet(), {'a', 'c'});
    });

    test('empty/whitespace query returns everything', () {
      final result = filterAndSortVenues(all,
          sort: VenueSortOption.none, nameQuery: '   ');
      expect(result.length, 4);
    });

    test('non-matching query returns empty', () {
      final result = filterAndSortVenues(all,
          sort: VenueSortOption.none, nameQuery: 'sushi');
      expect(result, isEmpty);
    });

    test('combines with filters and sort', () {
      final result = filterAndSortVenues(
        all,
        sort: VenueSortOption.alphabetical,
        selectedCuisineIds: {1},
        nameQuery: 'kebap',
      );
      // Both match cuisine 1 and "kebap"; alphabetical: "KEBAP Saray" < "Kebapçı Ali"
      expect(result.map((v) => v.id).toList(), ['c', 'a']);
    });
  });

  group('VenueListFilterState.apply', () {
    test('defaults return the source list unchanged', () {
      const state = VenueListFilterState();
      expect(state.apply(all).map((v) => v.id).toList(), ['a', 'b', 'c', 'd']);
    });

    test('search query filters by name', () {
      const state = VenueListFilterState(searchQuery: 'pide');
      expect(state.apply(all).map((v) => v.id).toList(), ['b']);
    });

    test('city filter scopes to the selected city', () {
      const state = VenueListFilterState(selectedCity: 'Ankara');
      expect(state.apply(all).map((v) => v.id).toList(), ['d']);
    });

    test('city filter is case-insensitive', () {
      const state = VenueListFilterState(selectedCity: 'ankara');
      expect(state.apply(all).map((v) => v.id).toList(), ['d']);
    });

    test('null city keeps every city', () {
      const state = VenueListFilterState();
      expect(state.apply(all).length, 4);
    });

    test('activeFilterCount counts cuisine/distance/rating/city, not search/sort', () {
      const state = VenueListFilterState(
        searchQuery: 'kebap',
        sort: VenueSortOption.rating,
        selectedCuisineIds: {1},
        selectedCity: 'Ankara',
      );
      expect(state.activeFilterCount, 2);
    });

    test('hasAnyFilter is true when only a search query is set', () {
      const state = VenueListFilterState(searchQuery: 'kebap');
      expect(state.activeFilterCount, 0);
      expect(state.hasAnyFilter, isTrue);
    });

    test('hasAnyFilter is false for a pristine state', () {
      expect(const VenueListFilterState().hasAnyFilter, isFalse);
    });
  });
}
