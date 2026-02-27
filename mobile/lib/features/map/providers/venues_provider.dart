import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/venue.dart';
import '../../../core/utils/location_service.dart';

// Konum provider
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final userLocationProvider = FutureProvider<Position>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  return locationService.getCurrentPosition();
});

// Venues state
class VenuesState {
  final List<Venue> venues;
  final bool isLoading;
  final String? error;

  const VenuesState({
    this.venues = const [],
    this.isLoading = false,
    this.error,
  });

  VenuesState copyWith({
    List<Venue>? venues,
    bool? isLoading,
    String? error,
  }) {
    return VenuesState(
      venues: venues ?? this.venues,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class VenuesNotifier extends Notifier<VenuesState> {
  double? _lastLat;
  double? _lastLng;
  DateTime? _lastFetchTime;

  static const _cacheDuration = Duration(minutes: 5);
  static const _minDistanceMeters = 500.0;

  @override
  VenuesState build() => const VenuesState();

  bool _shouldFetch(double latitude, double longitude, {bool force = false}) {
    if (force) return true;
    if (_lastLat == null || _lastLng == null || _lastFetchTime == null) return true;
    if (DateTime.now().difference(_lastFetchTime!) > _cacheDuration) return true;

    // Basit mesafe hesabı (metre)
    final dLat = (latitude - _lastLat!) * 111320;
    final dLng = (longitude - _lastLng!) * 111320 * 0.7; // ~cos(41°)
    final distance = (dLat * dLat + dLng * dLng);
    return distance > _minDistanceMeters * _minDistanceMeters;
  }

  Future<void> fetchNearbyVenues({
    required double latitude,
    required double longitude,
    double radius = 5000,
    bool force = false,
  }) async {
    if (!_shouldFetch(latitude, longitude, force: force)) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        ApiEndpoints.venues,
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
          'radius': radius,
        },
      );

      final data = response.data;
      final List<dynamic> venueList =
          data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);

      final venues = venueList
          .map((json) => Venue.fromJson(json as Map<String, dynamic>))
          .toList();

      _lastLat = latitude;
      _lastLng = longitude;
      _lastFetchTime = DateTime.now();

      state = state.copyWith(venues: venues, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Mekanlar yüklenemedi. Lütfen tekrar deneyin.',
      );
    }
  }

  Future<void> fetchCityVenues(String city) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        ApiEndpoints.venues,
        queryParameters: {'city': city},
      );

      final data = response.data;
      final List<dynamic> venueList =
          data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);

      final venues = venueList
          .map((json) => Venue.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(venues: venues, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Mekanlar yüklenemedi. Lütfen tekrar deneyin.',
      );
    }
  }
}

final venuesProvider = NotifierProvider<VenuesNotifier, VenuesState>(
  VenuesNotifier.new,
);
