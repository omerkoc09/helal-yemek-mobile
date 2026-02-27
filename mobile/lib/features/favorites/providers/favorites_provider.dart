import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/venue.dart';

class FavoritesState {
  final List<Venue> venues;
  final Set<String> favoriteIds;
  final bool isLoading;
  final String? error;

  const FavoritesState({
    this.venues = const [],
    this.favoriteIds = const {},
    this.isLoading = false,
    this.error,
  });

  FavoritesState copyWith({
    List<Venue>? venues,
    Set<String>? favoriteIds,
    bool? isLoading,
    String? error,
  }) {
    return FavoritesState(
      venues: venues ?? this.venues,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class FavoritesNotifier extends Notifier<FavoritesState> {
  @override
  FavoritesState build() => const FavoritesState();

  Future<void> fetchFavorites() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(ApiEndpoints.favorites);

      final data = response.data;
      final List<dynamic> venueList = data is Map<String, dynamic>
          ? (data['data'] as List? ?? [])
          : (data as List? ?? []);

      final venues = venueList
          .map((json) => Venue.fromJson(json as Map<String, dynamic>))
          .toList();

      final ids = venues.map((v) => v.id).toSet();

      state = state.copyWith(
        venues: venues,
        favoriteIds: ids,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Favoriler yüklenemedi.',
      );
    }
  }

  Future<void> toggleFavorite(Venue venue) async {
    final isFavorite = state.favoriteIds.contains(venue.id);
    final apiClient = ref.read(apiClientProvider);

    // Optimistic update
    final updatedIds = Set<String>.from(state.favoriteIds);
    final updatedVenues = List<Venue>.from(state.venues);

    if (isFavorite) {
      updatedIds.remove(venue.id);
      updatedVenues.removeWhere((v) => v.id == venue.id);
    } else {
      updatedIds.add(venue.id);
      updatedVenues.insert(0, venue);
    }

    state = state.copyWith(favoriteIds: updatedIds, venues: updatedVenues);

    try {
      if (isFavorite) {
        await apiClient.delete(ApiEndpoints.favorite(venue.id));
      } else {
        await apiClient.post(ApiEndpoints.favorite(venue.id));
      }
    } catch (e) {
      // Rollback on failure
      await fetchFavorites();
    }
  }

  bool isFavorite(String venueId) => state.favoriteIds.contains(venueId);
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, FavoritesState>(FavoritesNotifier.new);
