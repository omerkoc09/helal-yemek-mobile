import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/venue.dart';
import '../../../core/theme/app_theme.dart';
import '../../venue/widgets/venue_card.dart';
import '../providers/home_provider.dart';
import '../providers/venue_filter_provider.dart';
import '../providers/venue_list_filter_provider.dart';
import '../widgets/sort_bottom_sheet.dart';
import '../widgets/venue_list_filter_sheet.dart';

enum AllVenuesType { nearby, popular, city }

class AllVenuesScreen extends ConsumerStatefulWidget {
  final AllVenuesType type;

  const AllVenuesScreen({super.key, required this.type});

  @override
  ConsumerState<AllVenuesScreen> createState() => _AllVenuesScreenState();
}

class _AllVenuesScreenState extends ConsumerState<AllVenuesScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(_fetch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _fetch() {
    final notifier = ref.read(homeProvider.notifier);
    switch (widget.type) {
      case AllVenuesType.nearby:
        notifier.fetchNearbyAll();
      case AllVenuesType.popular:
        notifier.fetchPopularAll();
      case AllVenuesType.city:
        notifier.fetchCityAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeProvider);
    final filterState = ref.watch(venueListFilterProvider(widget.type));
    final filterNotifier =
        ref.read(venueListFilterProvider(widget.type).notifier);

    final isLoading = switch (widget.type) {
      AllVenuesType.nearby => state.isLoadingNearby,
      AllVenuesType.popular => state.isLoadingPopular,
      AllVenuesType.city => state.isLoadingCity,
    };
    final sourceVenues = switch (widget.type) {
      AllVenuesType.nearby => state.nearbyVenues,
      AllVenuesType.popular => state.popularVenues,
      AllVenuesType.city => state.cityVenues,
    };
    final title = switch (widget.type) {
      AllVenuesType.nearby => 'Şehirdeki Restoranlar',
      AllVenuesType.popular => 'Popüler Restoranlar',
      AllVenuesType.city => 'Şehirdeki Restoranlar',
    };

    final venues = filterState.apply(sourceVenues);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                if (!isLoading && sourceVenues.isNotEmpty)
                  Text(
                    '${venues.length} restoran',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (!isLoading && sourceVenues.isNotEmpty) ...[
            _SearchField(
              controller: _searchController,
              onChanged: filterNotifier.setSearchQuery,
              onClear: () {
                _searchController.clear();
                filterNotifier.setSearchQuery('');
              },
            ),
            _ActionsRow(
              sortLabel: _sortLabel(filterState.sort),
              filterLabel: _filterLabel(filterState.activeFilterCount),
              onSort: () async {
                final selected = await showVenueSortBottomSheet(
                  context,
                  current: filterState.sort,
                  locationAvailable: !state.locationDenied,
                );
                if (selected != null) filterNotifier.setSort(selected);
              },
              onFilter: () => showVenueListFilterSheet(
                context,
                type: widget.type,
                availableCities: _availableCities(sourceVenues),
              ),
            ),
          ],
          Expanded(
            child: _body(
              isLoading: isLoading,
              locationDenied: state.locationDenied,
              sourceVenues: sourceVenues,
              venues: venues,
              filterState: filterState,
              filterNotifier: filterNotifier,
            ),
          ),
        ],
      ),
    );
  }

  /// Popüler listesi yarıçap sınırı olmadan geldiği için birden fazla şehir
  /// içerebilir; şehir filtresinin seçenekleri bu listeden türetilir.
  List<String> _availableCities(List<Venue> venues) {
    final cities = venues.map((v) => v.city).where((c) => c.isNotEmpty).toSet();
    final sorted = cities.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  Widget _body({
    required bool isLoading,
    required bool locationDenied,
    required List<Venue> sourceVenues,
    required List<Venue> venues,
    required VenueListFilterState filterState,
    required VenueListFilterNotifier filterNotifier,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (locationDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_off,
                size: 48,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Yakınınızdaki mekanları görmek için konum izni gerekiyor.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    if (sourceVenues.isEmpty) {
      return const Center(
        child: Text(
          'Yakınınızda mekan bulunamadı.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
      );
    }

    // Kaynak liste dolu ama arama/filtre sonrası boş kaldıysa,
    // kullanıcıya çıkış yolu sun.
    if (venues.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Aramanıza uyan restoran bulunamadı.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  filterNotifier.clearAll();
                },
                child: const Text('Aramayı ve filtreleri temizle'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        top: 8,
        bottom: 8 + AppTheme.bottomNavClearance,
      ),
      itemCount: venues.length,
      itemBuilder: (_, i) => VenueCard(venue: venues[i]),
    );
  }

  String _sortLabel(VenueSortOption sort) {
    switch (sort) {
      case VenueSortOption.none:
        return 'Sırala';
      case VenueSortOption.alphabetical:
        return 'Sırala: Alfabetik';
      case VenueSortOption.rating:
        return 'Sırala: Puan';
      case VenueSortOption.distance:
        return 'Sırala: Yakınlık';
      case VenueSortOption.reviewCount:
        return 'Sırala: Yorum sayısı';
    }
  }

  String _filterLabel(int count) {
    if (count == 0) return 'Filtrele';
    return 'Filtrele · $count';
  }
}

class _SearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: widget.controller,
        onChanged: (value) {
          widget.onChanged(value);
          setState(() {}); // temizle ikonunu güncellemek için
        },
        decoration: InputDecoration(
          hintText: 'Bu listede ara (mekan, mutfak, ilçe)',
          hintStyle:
              const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () {
                    widget.onClear();
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  final String sortLabel;
  final String filterLabel;
  final VoidCallback onSort;
  final VoidCallback onFilter;

  const _ActionsRow({
    required this.sortLabel,
    required this.filterLabel,
    required this.onSort,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      minimumSize: const Size(0, 39),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onSort,
              style: style,
              icon: const Icon(Icons.sort, size: 18),
              label: Text(
                sortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onFilter,
              style: style,
              icon: const Icon(Icons.tune, size: 18),
              label: Text(
                filterLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
