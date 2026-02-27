import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../map/providers/venues_provider.dart';
import '../widgets/venue_card.dart';

class CityVenuesScreen extends ConsumerStatefulWidget {
  final String city;

  const CityVenuesScreen({super.key, required this.city});

  @override
  ConsumerState<CityVenuesScreen> createState() => _CityVenuesScreenState();
}

class _CityVenuesScreenState extends ConsumerState<CityVenuesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(venuesProvider.notifier).fetchCityVenues(widget.city);
    });
  }

  @override
  Widget build(BuildContext context) {
    final venuesState = ref.watch(venuesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.city)),
      body: _buildBody(venuesState),
    );
  }

  Widget _buildBody(VenuesState venuesState) {
    if (venuesState.isLoading) {
      return const LoadingIndicator();
    }

    if (venuesState.error != null) {
      return ErrorRetryWidget(
        message: venuesState.error!,
        onRetry: () =>
            ref.read(venuesProvider.notifier).fetchCityVenues(widget.city),
      );
    }

    if (venuesState.venues.isEmpty) {
      return const Center(
        child: Text(
          'Bu şehirde henüz mekan eklenmemiş.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: venuesState.venues.length,
      itemBuilder: (context, index) =>
          VenueCard(venue: venuesState.venues[index]),
    );
  }
}
