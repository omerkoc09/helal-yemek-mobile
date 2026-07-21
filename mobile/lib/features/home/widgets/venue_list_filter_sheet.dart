import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../guide/providers/guide_provider.dart';
import '../providers/venue_filter_provider.dart';
import '../providers/venue_list_filter_provider.dart';
import '../screens/all_venues_screen.dart';

/// Liste sayfalarına özel filtre panelini açar.
/// Seçimler doğrudan [venueListFilterProvider] üzerine yazılır; global
/// filtre akışı ([venueFilterProvider]) etkilenmez.
Future<void> showVenueListFilterSheet(
  BuildContext context, {
  required AllVenuesType type,
  required List<String> availableCities,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _VenueListFilterSheet(
      type: type,
      availableCities: availableCities,
    ),
  );
}

class _VenueListFilterSheet extends ConsumerWidget {
  final AllVenuesType type;
  final List<String> availableCities;

  const _VenueListFilterSheet({
    required this.type,
    required this.availableCities,
  });

  /// Şehir seçimi yalnızca popüler listesinde anlamlı: o liste yarıçap
  /// sınırı olmadan geldiği için birden fazla şehir içerebilir.
  bool get _showCityFilter => type == AllVenuesType.popular;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(venueListFilterProvider(type));
    final notifier = ref.read(venueListFilterProvider(type).notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 1.0,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            // Panel tam ekrana kadar açılabildiği için başlık status bar'ın
            // altında kalmamalı.
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                child: Row(
                  children: [
                    const Text(
                      'Filtrele',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (state.activeFilterCount > 0)
                      TextButton(
                        onPressed: notifier.clearFilters,
                        child: const Text('Temizle'),
                      ),
                    IconButton(
                      icon:
                          const Icon(Icons.close, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  if (_showCityFilter) ...[
                    const _SectionHeader(title: 'Şehir'),
                    _cityTile(context, state, notifier, null, 'Tümü'),
                    ...availableCities.map(
                      (city) => _cityTile(context, state, notifier, city, city),
                    ),
                    const Divider(),
                  ],
                  const _SectionHeader(title: 'Mutfaklar'),
                  _CuisineSection(type: type),
                  const Divider(),
                  const _SectionHeader(title: 'Restoran uzaklığı'),
                  _distanceTile(state, notifier, DistanceFilter.all, 'Tümü'),
                  _distanceTile(
                      state, notifier, DistanceFilter.under500m, '0.5 km ve altı'),
                  _distanceTile(
                      state, notifier, DistanceFilter.under1km, '1 km ve altı'),
                  _distanceTile(
                      state, notifier, DistanceFilter.under2km, '2 km ve altı'),
                  const Divider(),
                  const _SectionHeader(title: 'Puan ortalaması'),
                  _ratingTile(state, notifier, RatingFilter.all, 'Tümü'),
                  _ratingTile(state, notifier, RatingFilter.above40, '4.0 ve üzeri'),
                  _ratingTile(state, notifier, RatingFilter.above45, '4.5 ve üzeri'),
                ],
              ),
            ),
            // Yüzen alt navigasyon barı bu panelin üstünde durduğu için,
            // "Uygula" butonu nav barın toplam yüksekliği kadar yukarı alınır.
            // Nav bar cihazın alt güvenli alanının da üstünde yüzdüğünden
            // (home indicator), o boşluk da hesaba katılır.
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16 +
                    AppTheme.bottomNavClearance +
                    MediaQuery.of(context).viewPadding.bottom,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Uygula'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cityTile(
    BuildContext context,
    VenueListFilterState state,
    VenueListFilterNotifier notifier,
    String? value,
    String label,
  ) {
    return RadioListTile<String?>(
      value: value,
      groupValue: state.selectedCity,
      activeColor: AppTheme.primary,
      title: Text(label),
      onChanged: (_) => notifier.setCity(value),
    );
  }

  Widget _distanceTile(
    VenueListFilterState state,
    VenueListFilterNotifier notifier,
    DistanceFilter value,
    String label,
  ) {
    return RadioListTile<DistanceFilter>(
      value: value,
      groupValue: state.distanceFilter,
      activeColor: AppTheme.primary,
      title: Text(label),
      onChanged: (v) => v != null ? notifier.setDistanceFilter(v) : null,
    );
  }

  Widget _ratingTile(
    VenueListFilterState state,
    VenueListFilterNotifier notifier,
    RatingFilter value,
    String label,
  ) {
    return RadioListTile<RatingFilter>(
      value: value,
      groupValue: state.ratingFilter,
      activeColor: AppTheme.primary,
      title: Text(label),
      onChanged: (v) => v != null ? notifier.setRatingFilter(v) : null,
    );
  }
}

class _CuisineSection extends ConsumerWidget {
  final AllVenuesType type;

  const _CuisineSection({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(foodCategoriesProvider);
    final selected = ref.watch(venueListFilterProvider(type)).selectedCuisineIds;
    final notifier = ref.read(venueListFilterProvider(type).notifier);

    return categoriesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Mutfaklar yüklenemedi.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(foodCategoriesProvider),
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
      data: (categories) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((cat) {
            final isSelected = selected.contains(cat.id);
            return FilterChip(
              label: Text(cat.name),
              selected: isSelected,
              selectedColor: AppTheme.primary.withValues(alpha: 0.15),
              checkmarkColor: AppTheme.primary,
              onSelected: (checked) {
                final next = {...selected};
                if (checked) {
                  next.add(cat.id);
                } else {
                  next.remove(cat.id);
                }
                notifier.setCuisines(next);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
