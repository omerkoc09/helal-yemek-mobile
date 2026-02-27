import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/venue.dart';

class SearchState {
  final List<Venue> venues;
  final bool isLoading;
  final String? error;
  final String query;

  const SearchState({
    this.venues = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
  });

  SearchState copyWith({
    List<Venue>? venues,
    bool? isLoading,
    String? error,
    String? query,
  }) {
    return SearchState(
      venues: venues ?? this.venues,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
    );
  }
}

class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() => const SearchState();

  Timer? _debounce;

  void search(String query) {
    state = state.copyWith(query: query);

    _debounce?.cancel();
    if (query.trim().isEmpty) {
      state = state.copyWith(venues: [], isLoading: false, error: null);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        ApiEndpoints.venues,
        queryParameters: {'q': query},
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
        error: 'Arama başarısız oldu.',
      );
    }
  }
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);

const popularCities = [
  'İstanbul',
  'Londra',
  'Dubai',
  'Kuala Lumpur',
  'Paris',
  'Berlin',
  'Amsterdam',
  'Barselona',
  'Roma',
  'Tokyo',
];
