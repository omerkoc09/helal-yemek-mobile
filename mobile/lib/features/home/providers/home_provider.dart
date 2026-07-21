import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/venue.dart';
import '../../../core/utils/location_service.dart';

class HomeState {
  final List<Venue> nearbyVenues;
  final List<Venue> popularVenues;
  final List<Venue> cityVenues;
  final String? cityName; // geocoding'den gelen şehir adı (ör. "İstanbul")
  final bool isLoadingNearby;
  final bool isLoadingPopular;
  final bool isLoadingCity;
  final bool locationDenied;
  final String? searchQuery;
  final List<Venue> searchResults;
  final bool isSearching;

  const HomeState({
    this.nearbyVenues = const [],
    this.popularVenues = const [],
    this.cityVenues = const [],
    this.cityName,
    this.isLoadingNearby = false,
    this.isLoadingPopular = false,
    this.isLoadingCity = false,
    this.locationDenied = false,
    this.searchQuery,
    this.searchResults = const [],
    this.isSearching = false,
  });

  HomeState copyWith({
    List<Venue>? nearbyVenues,
    List<Venue>? popularVenues,
    List<Venue>? cityVenues,
    String? cityName,
    bool? isLoadingNearby,
    bool? isLoadingPopular,
    bool? isLoadingCity,
    bool? locationDenied,
    String? searchQuery,
    List<Venue>? searchResults,
    bool? isSearching,
  }) {
    return HomeState(
      nearbyVenues: nearbyVenues ?? this.nearbyVenues,
      popularVenues: popularVenues ?? this.popularVenues,
      cityVenues: cityVenues ?? this.cityVenues,
      cityName: cityName ?? this.cityName,
      isLoadingNearby: isLoadingNearby ?? this.isLoadingNearby,
      isLoadingPopular: isLoadingPopular ?? this.isLoadingPopular,
      isLoadingCity: isLoadingCity ?? this.isLoadingCity,
      locationDenied: locationDenied ?? this.locationDenied,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
    );
  }

  bool get hasSearchQuery => searchQuery != null && searchQuery!.isNotEmpty;
}

class HomeNotifier extends Notifier<HomeState> {
  @override
  HomeState build() => const HomeState();

  Future<void> fetchFeed({int limit = 10}) async {
    state = state.copyWith(
      isLoadingNearby: true,
      isLoadingPopular: true,
      isLoadingCity: true,
    );

    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();
      final lat = position.latitude;
      final lng = position.longitude;

      // Geocoding ile şehir adını çek
      String? city;
      try {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          // administrativeArea = il (İstanbul, Ankara…), locality = ilçe (Fatih, Kadıköy…)
          // Şehir bazlı sorgu için il seviyesini kullanıyoruz.
          city = placemarks.first.administrativeArea ?? placemarks.first.locality;
        }
      } catch (_) {
        // geocoding başarısız — city null kalır, city slider gösterilmez
      }

      final apiClient = ref.read(apiClientProvider);

      // Şehirdeki en yakın limit mekanı ve popülerleri paralel çek
      final futures = <Future>[];
      if (city != null && city.isNotEmpty) {
        futures.add(apiClient.get(
          ApiEndpoints.venues,
          queryParameters: {'city': city, 'lat': lat, 'lng': lng, 'limit': limit},
        ));
      } else {
        futures.add(Future.value(null));
      }
      futures.add(apiClient.get(
        ApiEndpoints.venuesPopular,
        queryParameters: {'lat': lat, 'lng': lng, 'radius': 10000, 'limit': limit},
      ));

      final results = await Future.wait(futures);

      List<Venue> _parse(dynamic data) {
        if (data == null) return [];
        final raw = data is Map<String, dynamic> ? data['data'] : data;
        return (raw as List? ?? [])
            .map((j) => Venue.fromJson(j as Map<String, dynamic>))
            .toList();
      }

      state = state.copyWith(
        nearbyVenues: _parse(results[0]?.data),
        popularVenues: _parse(results[1].data),
        cityName: city,
        isLoadingNearby: false,
        isLoadingPopular: false,
        isLoadingCity: false,
        locationDenied: false,
      );
    } on LocationServiceException {
      state = state.copyWith(
        isLoadingNearby: false,
        isLoadingPopular: false,
        isLoadingCity: false,
        locationDenied: true,
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingNearby: false,
        isLoadingPopular: false,
        isLoadingCity: false,
      );
    }
  }

  Future<void> fetchAllNearby() => fetchFeed(limit: 0);
  Future<void> fetchAllPopular() => fetchFeed(limit: 0);

  Future<void> fetchCityAll() async {
    state = state.copyWith(isLoadingCity: true);
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();
      final lat = position.latitude;
      final lng = position.longitude;

      String? city = state.cityName;
      if (city == null || city.isEmpty) {
        try {
          final placemarks = await placemarkFromCoordinates(lat, lng);
          if (placemarks.isNotEmpty) city = placemarks.first.administrativeArea ?? placemarks.first.locality;
        } catch (_) {}
      }
      if (city == null || city.isEmpty) {
        state = state.copyWith(isLoadingCity: false);
        return;
      }

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        ApiEndpoints.venues,
        queryParameters: {'city': city, 'lat': lat, 'lng': lng, 'limit': 0},
      );
      final data = response.data;
      final list = data is Map<String, dynamic>
          ? (data['data'] as List? ?? [])
          : (data as List? ?? []);
      state = state.copyWith(
        cityVenues: list
            .map((j) => Venue.fromJson(j as Map<String, dynamic>))
            .toList(),
        cityName: city,
        isLoadingCity: false,
      );
    } on LocationServiceException {
      state = state.copyWith(isLoadingCity: false, locationDenied: true);
    } catch (_) {
      state = state.copyWith(isLoadingCity: false);
    }
  }

  Future<void> fetchNearbyAll() async {
    state = state.copyWith(isLoadingNearby: true);
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        ApiEndpoints.venuesNearby,
        queryParameters: {
          'lat': position.latitude,
          'lng': position.longitude,
          'radius': 10000,
          'limit': 0,
        },
      );
      final data = response.data;
      final list = data is Map<String, dynamic>
          ? (data['data'] as List? ?? [])
          : (data as List? ?? []);
      state = state.copyWith(
        nearbyVenues: list.map((j) => Venue.fromJson(j as Map<String, dynamic>)).toList(),
        isLoadingNearby: false,
        locationDenied: false,
      );
    } on LocationServiceException {
      state = state.copyWith(isLoadingNearby: false, locationDenied: true);
    } catch (_) {
      state = state.copyWith(isLoadingNearby: false);
    }
  }

  Future<void> fetchPopularAll() async {
    state = state.copyWith(isLoadingPopular: true);
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        ApiEndpoints.venuesPopular,
        queryParameters: {
          'lat': position.latitude,
          'lng': position.longitude,
          // radius=0 → yarıçap sınırı yok: konumu uzak olan mekanlar da listeye
          // girer. lat/lng mesafe hesabı ve yakınlığa göre sıralama için gerekli.
          'radius': 0,
          'limit': 0,
        },
      );
      final data = response.data;
      final list = data is Map<String, dynamic>
          ? (data['data'] as List? ?? [])
          : (data as List? ?? []);
      state = state.copyWith(
        popularVenues: list.map((j) => Venue.fromJson(j as Map<String, dynamic>)).toList(),
        isLoadingPopular: false,
        locationDenied: false,
      );
    } on LocationServiceException {
      state = state.copyWith(isLoadingPopular: false, locationDenied: true);
    } catch (_) {
      state = state.copyWith(isLoadingPopular: false);
    }
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(
        searchQuery: '',
        searchResults: [],
        isSearching: false,
      );
      return;
    }

    state = state.copyWith(searchQuery: query, isSearching: true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        '/venues',
        queryParameters: {'q': query},
      );
      final data = response.data;
      final list = data is Map<String, dynamic>
          ? (data['data'] as List? ?? [])
          : (data as List? ?? []);
      state = state.copyWith(
        searchResults: list.map((j) => Venue.fromJson(j as Map<String, dynamic>)).toList(),
        isSearching: false,
      );
    } catch (_) {
      state = state.copyWith(isSearching: false, searchResults: []);
    }
  }

  void clearSearch() {
    state = state.copyWith(
      searchQuery: '',
      searchResults: [],
      isSearching: false,
    );
  }
}

final homeProvider = NotifierProvider<HomeNotifier, HomeState>(
  HomeNotifier.new,
);
