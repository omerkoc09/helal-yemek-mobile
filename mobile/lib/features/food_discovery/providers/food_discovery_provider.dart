import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/venue.dart';

class FoodDiscoveryState {
  final int? selectedCategoryId;
  final String? selectedCategoryLabel;
  final List<Venue> venues;
  final bool isLoading;
  final String? error;

  const FoodDiscoveryState({
    this.selectedCategoryId,
    this.selectedCategoryLabel,
    this.venues = const [],
    this.isLoading = false,
    this.error,
  });

  FoodDiscoveryState copyWith({
    int? selectedCategoryId,
    String? selectedCategoryLabel,
    List<Venue>? venues,
    bool? isLoading,
    String? error,
  }) {
    return FoodDiscoveryState(
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      selectedCategoryLabel:
          selectedCategoryLabel ?? this.selectedCategoryLabel,
      venues: venues ?? this.venues,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class FoodDiscoveryNotifier extends Notifier<FoodDiscoveryState> {
  @override
  FoodDiscoveryState build() => const FoodDiscoveryState();

  Future<void> selectCategory(int categoryId, String label) async {
    state = FoodDiscoveryState(
      selectedCategoryId: categoryId,
      selectedCategoryLabel: label,
      isLoading: true,
    );

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        ApiEndpoints.venuesByCategory(categoryId),
      );

      final data = response.data;
      final List<dynamic> venueList = data is Map<String, dynamic>
          ? (data['data'] as List? ?? [])
          : (data as List? ?? []);

      final venues = venueList
          .map((json) => Venue.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(venues: venues, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Mekanlar yüklenemedi: $e',
      );
    }
  }

  void clearSelection() {
    state = const FoodDiscoveryState();
  }
}

final foodDiscoveryProvider =
    NotifierProvider<FoodDiscoveryNotifier, FoodDiscoveryState>(
  FoodDiscoveryNotifier.new,
);
