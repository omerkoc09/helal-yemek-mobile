import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/venue.dart';
import '../screens/all_venues_screen.dart';
import 'venue_filter_provider.dart';

const Object _sentinel = Object();

/// Liste sayfalarının (Şehirdeki / Popüler Restoranlar) kendi bağımsız
/// arama + filtre + sıralama durumu. Global [venueFilterProvider] akışından
/// ayrıdır: bir sayfadaki seçim diğerini veya ana Filtrele akışını etkilemez.
class VenueListFilterState {
  final String searchQuery;
  final VenueSortOption sort;
  final Set<int> selectedCuisineIds;
  final DistanceFilter distanceFilter;
  final RatingFilter ratingFilter;

  /// Yalnızca popüler listesinde anlamlı — popüler listesi yarıçap sınırı
  /// olmadan geldiği için şehre göre süzme imkânı sunar.
  final String? selectedCity;

  const VenueListFilterState({
    this.searchQuery = '',
    this.sort = VenueSortOption.none,
    this.selectedCuisineIds = const {},
    this.distanceFilter = DistanceFilter.all,
    this.ratingFilter = RatingFilter.all,
    this.selectedCity,
  });

  VenueListFilterState copyWith({
    String? searchQuery,
    VenueSortOption? sort,
    Set<int>? selectedCuisineIds,
    DistanceFilter? distanceFilter,
    RatingFilter? ratingFilter,
    Object? selectedCity = _sentinel,
  }) {
    return VenueListFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      sort: sort ?? this.sort,
      selectedCuisineIds: selectedCuisineIds ?? this.selectedCuisineIds,
      distanceFilter: distanceFilter ?? this.distanceFilter,
      ratingFilter: ratingFilter ?? this.ratingFilter,
      selectedCity: selectedCity == _sentinel
          ? this.selectedCity
          : selectedCity as String?,
    );
  }

  /// Filtrele butonunun rozetinde gösterilen aktif filtre sayısı.
  /// Arama ve sıralama buna dahil değildir; onların kendi göstergesi var.
  int get activeFilterCount {
    var count = 0;
    if (selectedCuisineIds.isNotEmpty) count++;
    if (distanceFilter != DistanceFilter.all) count++;
    if (ratingFilter != RatingFilter.all) count++;
    if (selectedCity != null) count++;
    return count;
  }

  bool get hasAnyFilter => activeFilterCount > 0 || searchQuery.trim().isNotEmpty;

  /// Verilen listeye arama + filtre + sıralamayı uygular.
  List<Venue> apply(List<Venue> venues) {
    final scoped = selectedCity == null
        ? venues
        : venues
            .where((v) => v.city.toLowerCase() == selectedCity!.toLowerCase())
            .toList();

    return filterAndSortVenues(
      scoped,
      sort: sort,
      selectedCuisineIds: selectedCuisineIds,
      distanceFilter: distanceFilter,
      ratingFilter: ratingFilter,
      nameQuery: searchQuery,
    );
  }
}

class VenueListFilterNotifier extends Notifier<VenueListFilterState> {
  /// Hangi liste sayfasına ait olduğunu belirtir. State bu argümana göre
  /// ayrıştığı için notifier içinde ayrıca kullanılmasına gerek yoktur.
  final AllVenuesType type;

  VenueListFilterNotifier(this.type);

  @override
  VenueListFilterState build() => const VenueListFilterState();

  void setSearchQuery(String value) =>
      state = state.copyWith(searchQuery: value);

  void setSort(VenueSortOption value) => state = state.copyWith(sort: value);

  void setCuisines(Set<int> value) =>
      state = state.copyWith(selectedCuisineIds: value);

  void setDistanceFilter(DistanceFilter value) =>
      state = state.copyWith(distanceFilter: value);

  void setRatingFilter(RatingFilter value) =>
      state = state.copyWith(ratingFilter: value);

  void setCity(String? value) => state = state.copyWith(selectedCity: value);

  /// Filtreleri temizler; arama metni korunur (kullanıcı yazdığını kaybetmesin).
  void clearFilters() {
    state = state.copyWith(
      selectedCuisineIds: const {},
      distanceFilter: DistanceFilter.all,
      ratingFilter: RatingFilter.all,
      selectedCity: null,
    );
  }

  void clearAll() => state = const VenueListFilterState();
}

/// Sayfa tipi başına ayrı state tutar — Şehirdeki ve Popüler listeleri
/// birbirinden bağımsız filtrelenir.
final venueListFilterProvider = NotifierProvider.family<VenueListFilterNotifier,
    VenueListFilterState, AllVenuesType>(
  VenueListFilterNotifier.new,
);

