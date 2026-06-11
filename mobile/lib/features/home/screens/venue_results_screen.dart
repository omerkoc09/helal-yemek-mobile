import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/venue.dart';
import '../../../core/theme/app_theme.dart';
import '../../venue/widgets/venue_card.dart';
import '../providers/venue_filter_provider.dart';
import '../widgets/sort_bottom_sheet.dart';

class VenueResultsScreen extends ConsumerStatefulWidget {
  const VenueResultsScreen({super.key});

  @override
  ConsumerState<VenueResultsScreen> createState() => _VenueResultsScreenState();
}

class _VenueResultsScreenState extends ConsumerState<VenueResultsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final state = ref.read(venueFilterProvider);
      if (state.allCityVenues.isEmpty && !state.isLoading) {
        ref.read(venueFilterProvider.notifier).fetchAllCityVenues();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(venueFilterProvider);
    final notifier = ref.read(venueFilterProvider.notifier);
    final results = state.filteredVenues;
    final locationAvailable = !state.locationDenied;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.selectedCity ?? state.cityName ?? 'Sonuçlar'),
            if (!state.isLoading)
              Text(
                '${results.length} restoran',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await showVenueSortBottomSheet(
                        context,
                        current: state.sort,
                        locationAvailable: locationAvailable,
                      );
                      if (selected != null) notifier.setSort(selected);
                    },
                    icon: const Icon(Icons.sort),
                    label: Text(_sortLabel(state.sort)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/venues/filter'),
                    icon: const Icon(Icons.tune),
                    label: Text(_filterLabel(state.activeFilterCount)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _body(state, results, notifier, context)),
        ],
      ),
    );
  }

  Widget _body(
    VenueFilterState state,
    List<Venue> results,
    VenueFilterNotifier notifier,
    BuildContext context,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.locationDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off,
                  size: 48, color: AppTheme.textSecondary),
              const SizedBox(height: 12),
              const Text(
                'Konum izni gerekiyor.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: notifier.fetchAllCityVenues,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }
    if (state.cityName == null && state.allCityVenues.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Şehir belirlenemedi.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: notifier.fetchAllCityVenues,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filtrelere uyan restoran bulunamadı.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: notifier.clearAll,
                child: const Text('Filtreleri Temizle'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      itemBuilder: (_, i) => VenueCard(venue: results[i]),
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
