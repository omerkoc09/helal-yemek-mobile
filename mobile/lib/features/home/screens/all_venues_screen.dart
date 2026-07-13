import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../venue/widgets/venue_card.dart';
import '../providers/home_provider.dart';

enum AllVenuesType { nearby, popular, city }

class AllVenuesScreen extends ConsumerStatefulWidget {
  final AllVenuesType type;

  const AllVenuesScreen({super.key, required this.type});

  @override
  ConsumerState<AllVenuesScreen> createState() => _AllVenuesScreenState();
}

class _AllVenuesScreenState extends ConsumerState<AllVenuesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (widget.type == AllVenuesType.nearby) {
        ref.read(homeProvider.notifier).fetchNearbyAll();
      } else if (widget.type == AllVenuesType.popular) {
        ref.read(homeProvider.notifier).fetchPopularAll();
      } else {
        ref.read(homeProvider.notifier).fetchCityAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeProvider);
    final isLoading = switch (widget.type) {
      AllVenuesType.nearby => state.isLoadingNearby,
      AllVenuesType.popular => state.isLoadingPopular,
      AllVenuesType.city => state.isLoadingCity,
    };
    final venues = switch (widget.type) {
      AllVenuesType.nearby => state.nearbyVenues,
      AllVenuesType.popular => state.popularVenues,
      AllVenuesType.city => state.cityVenues,
    };
    final title = switch (widget.type) {
      AllVenuesType.nearby => 'Şehirdeki Restoranlar',
      AllVenuesType.popular => 'Popüler Restoranlar',
      AllVenuesType.city => 'Şehirdeki Restoranlar',
    };

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (_) {
                if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.locationDenied) {
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
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (widget.type == AllVenuesType.nearby) {
                                ref
                                    .read(homeProvider.notifier)
                                    .fetchNearbyAll();
                              } else if (widget.type == AllVenuesType.popular) {
                                ref
                                    .read(homeProvider.notifier)
                                    .fetchPopularAll();
                              } else {
                                ref.read(homeProvider.notifier).fetchCityAll();
                              }
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (venues.isEmpty) {
                  return Center(
                    child: Text(
                      'Yakınınızda mekan bulunamadı.',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
