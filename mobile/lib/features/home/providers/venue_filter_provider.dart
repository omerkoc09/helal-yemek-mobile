import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/venue.dart';
import '../../../core/utils/location_service.dart';

enum VenueSortOption {
  none,
  alphabetical,
  rating,
  distance,
  reviewCount,
}

enum DistanceFilter {
  all,
  under500m,
  under1km,
  under2km,
}

enum RatingFilter {
  all,
  above40,
  above45,
}

const Object _sentinel = Object();

class VenueFilterState {
  final List<Venue> allCityVenues;
  final bool isLoading;
  final bool locationDenied;
  final String? cityName;       // geocoding'den otomatik
  final String? selectedCity;   // kullanıcı seçimi (null = mevcut konum)
  final double? userLat;
  final double? userLng;

  final VenueSortOption sort;
  final Set<int> selectedCuisineIds;
  final DistanceFilter distanceFilter;
  final RatingFilter ratingFilter;

  const VenueFilterState({
    this.allCityVenues = const [],
    this.isLoading = false,
    this.locationDenied = false,
    this.cityName,
    this.selectedCity,
    this.userLat,
    this.userLng,
    this.sort = VenueSortOption.none,
    this.selectedCuisineIds = const {},
    this.distanceFilter = DistanceFilter.all,
    this.ratingFilter = RatingFilter.all,
  });

  VenueFilterState copyWith({
    List<Venue>? allCityVenues,
    bool? isLoading,
    bool? locationDenied,
    String? cityName,
    Object? selectedCity = _sentinel,
    double? userLat,
    double? userLng,
    VenueSortOption? sort,
    Set<int>? selectedCuisineIds,
    DistanceFilter? distanceFilter,
    RatingFilter? ratingFilter,
  }) {
    return VenueFilterState(
      allCityVenues: allCityVenues ?? this.allCityVenues,
      isLoading: isLoading ?? this.isLoading,
      locationDenied: locationDenied ?? this.locationDenied,
      cityName: cityName ?? this.cityName,
      selectedCity: selectedCity == _sentinel
          ? this.selectedCity
          : selectedCity as String?,
      userLat: userLat ?? this.userLat,
      userLng: userLng ?? this.userLng,
      sort: sort ?? this.sort,
      selectedCuisineIds: selectedCuisineIds ?? this.selectedCuisineIds,
      distanceFilter: distanceFilter ?? this.distanceFilter,
      ratingFilter: ratingFilter ?? this.ratingFilter,
    );
  }

  int get activeFilterCount {
    var count = 0;
    if (selectedCity != null) count++;
    if (selectedCuisineIds.isNotEmpty) count++;
    if (distanceFilter != DistanceFilter.all) count++;
    if (ratingFilter != RatingFilter.all) count++;
    return count;
  }

  String? get effectiveCity => selectedCity ?? cityName;

  List<Venue> get filteredVenues => applyVenueFilterPipeline(this);
}

/// Pure function — applies cuisine/distance/rating filters then sorts.
/// Exposed top-level so it can be unit-tested without constructing a notifier.
List<Venue> applyVenueFilterPipeline(VenueFilterState state) {
  return filterAndSortVenues(
    state.allCityVenues,
    sort: state.sort,
    selectedCuisineIds: state.selectedCuisineIds,
    distanceFilter: state.distanceFilter,
    ratingFilter: state.ratingFilter,
  );
}

/// Ortak filtreleme/sıralama boru hattı — herhangi bir mekan listesi üzerinde
/// çalışır, bir state nesnesine bağlı değildir. Hem global filtre akışı hem de
/// liste sayfalarının kendi bağımsız filtreleri bunu kullanır.
///
/// [nameQuery] verilirse önce isim araması uygulanır (büyük/küçük harf duyarsız).
List<Venue> filterAndSortVenues(
  List<Venue> venues, {
  required VenueSortOption sort,
  Set<int> selectedCuisineIds = const {},
  DistanceFilter distanceFilter = DistanceFilter.all,
  RatingFilter ratingFilter = RatingFilter.all,
  String nameQuery = '',
}) {
  Iterable<Venue> list = venues;

  final query = nameQuery.trim().toLowerCase();
  if (query.isNotEmpty) {
    list = list.where((v) => v.name.toLowerCase().contains(query));
  }

  if (selectedCuisineIds.isNotEmpty) {
    list = list.where((v) {
      for (final item in v.foodItems) {
        if (selectedCuisineIds.contains(item.categoryId)) return true;
      }
      return false;
    });
  }

  if (distanceFilter != DistanceFilter.all) {
    final threshold = switch (distanceFilter) {
      DistanceFilter.under500m => 500.0,
      DistanceFilter.under1km => 1000.0,
      DistanceFilter.under2km => 2000.0,
      DistanceFilter.all => double.infinity,
    };
    list = list.where((v) => v.distance != null && v.distance! < threshold);
  }

  if (ratingFilter != RatingFilter.all) {
    final minRating = ratingFilter == RatingFilter.above40 ? 4.0 : 4.5;
    list = list.where((v) =>
        v.reviewCount > 0 &&
        v.avgRating != null &&
        v.avgRating! >= minRating);
  }

  final result = list.toList();

  switch (sort) {
    case VenueSortOption.none:
      break;
    case VenueSortOption.alphabetical:
      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case VenueSortOption.rating:
      result.sort((a, b) {
        final ar = (a.reviewCount > 0 ? a.avgRating : null) ?? -1;
        final br = (b.reviewCount > 0 ? b.avgRating : null) ?? -1;
        return br.compareTo(ar);
      });
    case VenueSortOption.distance:
      result.sort((a, b) {
        final ad = a.distance ?? double.infinity;
        final bd = b.distance ?? double.infinity;
        return ad.compareTo(bd);
      });
    case VenueSortOption.reviewCount:
      result.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
  }

  return result;
}

class VenueFilterNotifier extends Notifier<VenueFilterState> {
  @override
  VenueFilterState build() => const VenueFilterState();

  Future<void> fetchAllCityVenues() async {
    state = state.copyWith(isLoading: true, locationDenied: false);

    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();
      final lat = position.latitude;
      final lng = position.longitude;

      // selectedCity varsa onu kullan, yoksa geocoding'den al
      String? city = state.selectedCity;
      if (city == null || city.isEmpty) {
        try {
          final placemarks = await placemarkFromCoordinates(lat, lng);
          if (placemarks.isNotEmpty) {
            city = placemarks.first.administrativeArea ?? placemarks.first.locality;
          }
        } catch (_) {}
      }

      if (city == null || city.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        ApiEndpoints.venues,
        queryParameters: {
          'city': city,
          'lat': lat,
          'lng': lng,
          'limit': 0,
        },
      );

      final data = response.data;
      final raw = data is Map<String, dynamic> ? data['data'] : data;
      final venues = (raw as List? ?? [])
          .map((j) => Venue.fromJson(j as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        allCityVenues: venues,
        cityName: state.selectedCity == null ? city : state.cityName,
        userLat: lat,
        userLng: lng,
        isLoading: false,
      );
    } on LocationServiceException {
      state = state.copyWith(isLoading: false, locationDenied: true);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> setCity(String city) async {
    state = state.copyWith(selectedCity: city, allCityVenues: []);
    await fetchAllCityVenues();
  }

  Future<void> clearCity() async {
    state = state.copyWith(selectedCity: null, allCityVenues: []);
    await fetchAllCityVenues();
  }

  void setSort(VenueSortOption value) => state = state.copyWith(sort: value);
  void setCuisines(Set<int> value) =>
      state = state.copyWith(selectedCuisineIds: value);
  void setDistanceFilter(DistanceFilter value) =>
      state = state.copyWith(distanceFilter: value);
  void setRatingFilter(RatingFilter value) =>
      state = state.copyWith(ratingFilter: value);

  void clearAll() {
    state = state.copyWith(
      sort: VenueSortOption.none,
      selectedCuisineIds: const {},
      distanceFilter: DistanceFilter.all,
      ratingFilter: RatingFilter.all,
      selectedCity: null,
    );
  }
}

final venueFilterProvider =
    NotifierProvider.autoDispose<VenueFilterNotifier, VenueFilterState>(
  VenueFilterNotifier.new,
);

final citiesProvider = FutureProvider<List<String>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get(ApiEndpoints.venuesCities);
  final data = response.data;
  final list = data is Map<String, dynamic>
      ? (data['data'] as List? ?? [])
      : (data as List? ?? []);
  return list.cast<String>();
});
