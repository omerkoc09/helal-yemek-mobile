import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/venue.dart';
import 'admin_provider_utils.dart';

class AllVenuesState {
  final List<Venue> venues;
  final bool isLoading;
  final String? error;

  const AllVenuesState({
    this.venues = const [],
    this.isLoading = false,
    this.error,
  });

  AllVenuesState copyWith({
    List<Venue>? venues,
    bool? isLoading,
    String? error,
  }) {
    return AllVenuesState(
      venues: venues ?? this.venues,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AllVenuesNotifier extends Notifier<AllVenuesState> {
  @override
  AllVenuesState build() => const AllVenuesState();

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(ApiEndpoints.adminVenues);
      final venues = parseList<Venue>(response.data, Venue.fromJson);
      state = state.copyWith(venues: venues, isLoading: false);
    } catch (e) {
      debugPrint('AllVenues fetch error: $e');
      state = state.copyWith(
        isLoading: false,
        error: extractErrorMessage(e, 'Mekanlar yüklenemedi.'),
      );
    }
  }

  Future<bool> updateVenue(String venueId, Map<String, dynamic> data) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.put(ApiEndpoints.adminVenue(venueId), data: data);
    } catch (e) {
      debugPrint('UpdateVenue error: $e');
      return false;
    }
    // Listeyi arka planda yenile, başarısız olsa bile güncelleme başarılı sayılır
    try {
      await fetch();
    } catch (_) {}
    return true;
  }

  Future<bool> deleteVenue(String venueId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.delete(ApiEndpoints.adminVenue(venueId));
      state = state.copyWith(
        venues: state.venues.where((v) => v.id != venueId).toList(),
      );
      return true;
    } catch (e) {
      debugPrint('DeleteVenue error: $e');
      return false;
    }
  }
}

final allVenuesProvider =
    NotifierProvider<AllVenuesNotifier, AllVenuesState>(
  AllVenuesNotifier.new,
);
