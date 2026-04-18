import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/venue_filter_provider.dart';

class VenueFilterScreen extends ConsumerWidget {
  const VenueFilterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(venueFilterProvider);
    final notifier = ref.read(venueFilterProvider.notifier);
    final locationAvailable = !state.locationDenied;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Filtrele'),
        actions: [
          TextButton(
            onPressed: notifier.clearAll,
            child: const Text(
              'Temizle',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          if (!locationAvailable)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFB74D)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.location_off, color: Color(0xFFE65100), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Mesafe filtresi için konum izni gerekiyor.',
                      style: TextStyle(fontSize: 13, color: Color(0xFFE65100)),
                    ),
                  ),
                ],
              ),
            ),

          const _SectionHeader(title: 'Sırala'),
          _sortRadio(notifier, state.sort, VenueSortOption.none, 'Seçili değil'),
          _sortRadio(notifier, state.sort, VenueSortOption.alphabetical, 'Alfabetik'),
          _sortRadio(notifier, state.sort, VenueSortOption.rating, 'Puana göre'),
          _sortRadio(
            notifier,
            state.sort,
            VenueSortOption.distance,
            'Yakınlığa göre',
            disabled: !locationAvailable,
          ),
          _sortRadio(notifier, state.sort, VenueSortOption.reviewCount,
              'Değerlendirme sayısına göre'),

          const Divider(),
          const _SectionHeader(title: 'Mutfaklar'),
          ListTile(
            title: const Text('Mutfaklar'),
            subtitle: Text(_cuisinesSubtitle(state)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final result = await context
                  .push<Set<int>>('/venues/filter/cuisines');
              if (result != null) {
                notifier.setCuisines(result);
              }
            },
          ),

          const Divider(),
          const _SectionHeader(title: 'Restoran uzaklığı'),
          _distanceRadio(notifier, state.distanceFilter, DistanceFilter.all, 'Tümü'),
          _distanceRadio(notifier, state.distanceFilter, DistanceFilter.under500m,
              '0.5 km ve altı',
              disabled: !locationAvailable),
          _distanceRadio(notifier, state.distanceFilter, DistanceFilter.under1km,
              '1 km ve altı',
              disabled: !locationAvailable),
          _distanceRadio(notifier, state.distanceFilter, DistanceFilter.under2km,
              '2 km ve altı',
              disabled: !locationAvailable),

          const Divider(),
          const _SectionHeader(title: 'Puan ortalaması'),
          _ratingRadio(notifier, state.ratingFilter, RatingFilter.all, 'Tümü'),
          _ratingRadio(notifier, state.ratingFilter, RatingFilter.above40,
              '4.0 ve üzeri'),
          _ratingRadio(notifier, state.ratingFilter, RatingFilter.above45,
              '4.5 ve üzeri'),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (GoRouter.of(context).canPop()) {
                  context.pop();
                } else {
                  context.push('/venues/filtered');
                }
              },
              child: const Text('Uygula'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sortRadio(
    VenueFilterNotifier n,
    VenueSortOption current,
    VenueSortOption value,
    String label, {
    bool disabled = false,
  }) {
    return RadioListTile<VenueSortOption>(
      value: value,
      groupValue: current,
      activeColor: AppTheme.primary,
      title: Text(
        label,
        style: TextStyle(
          color: disabled ? AppTheme.textSecondary : AppTheme.textPrimary,
        ),
      ),
      onChanged: disabled ? null : (v) => v != null ? n.setSort(v) : null,
    );
  }

  Widget _distanceRadio(
    VenueFilterNotifier n,
    DistanceFilter current,
    DistanceFilter value,
    String label, {
    bool disabled = false,
  }) {
    return RadioListTile<DistanceFilter>(
      value: value,
      groupValue: current,
      activeColor: AppTheme.primary,
      title: Text(
        label,
        style: TextStyle(
          color: disabled ? AppTheme.textSecondary : AppTheme.textPrimary,
        ),
      ),
      onChanged: disabled ? null : (v) => v != null ? n.setDistanceFilter(v) : null,
    );
  }

  Widget _ratingRadio(
    VenueFilterNotifier n,
    RatingFilter current,
    RatingFilter value,
    String label,
  ) {
    return RadioListTile<RatingFilter>(
      value: value,
      groupValue: current,
      activeColor: AppTheme.primary,
      title: Text(label),
      onChanged: (v) => v != null ? n.setRatingFilter(v) : null,
    );
  }

  String _cuisinesSubtitle(VenueFilterState state) {
    if (state.selectedCuisineIds.isEmpty) return 'Hepsi';
    final count = state.selectedCuisineIds.length;
    return '$count mutfak seçili';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}
