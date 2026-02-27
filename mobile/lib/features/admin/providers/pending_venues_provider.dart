import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/venue.dart';
import 'admin_provider_utils.dart';

class PendingVenuesState {
  final List<Venue> venues;
  final bool isLoading;
  final String? error;

  const PendingVenuesState({
    this.venues = const [],
    this.isLoading = false,
    this.error,
  });

  PendingVenuesState copyWith({
    List<Venue>? venues,
    bool? isLoading,
    String? error,
  }) {
    return PendingVenuesState(
      venues: venues ?? this.venues,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PendingVenuesNotifier extends Notifier<PendingVenuesState> {
  @override
  PendingVenuesState build() => const PendingVenuesState();

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(ApiEndpoints.adminPendingVenues);
      final venues = parseList<Venue>(response.data, Venue.fromJson);
      state = state.copyWith(venues: venues, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Mekanlar yüklenemedi.');
    }
  }

  Future<bool> approveVenue(String venueId, {String? note}) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.put(
        ApiEndpoints.adminApproveVenue(venueId),
        data: note != null ? {'note': note} : null,
      );
      state = state.copyWith(
        venues: state.venues.where((v) => v.id != venueId).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectVenue(String venueId, {String? note}) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.put(
        ApiEndpoints.adminRejectVenue(venueId),
        data: note != null ? {'note': note} : null,
      );
      state = state.copyWith(
        venues: state.venues.where((v) => v.id != venueId).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

final pendingVenuesProvider =
    NotifierProvider<PendingVenuesNotifier, PendingVenuesState>(
  PendingVenuesNotifier.new,
);
