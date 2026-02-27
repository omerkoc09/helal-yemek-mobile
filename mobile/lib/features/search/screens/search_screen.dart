import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../venue/widgets/venue_card.dart';
import '../providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ara')),
      body: Column(
        children: [
          // Arama kutusu
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Şehir veya mekan ara...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchProvider.notifier).search('');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                ref.read(searchProvider.notifier).search(value);
                setState(() {}); // suffixIcon güncellemesi için
              },
            ),
          ),

          // İçerik
          Expanded(
            child: searchState.query.isEmpty
                ? _buildPopularCities()
                : _buildSearchResults(searchState),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularCities() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const Text(
          'Popüler Şehirler',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: popularCities.map((city) {
            return ActionChip(
              avatar: const Icon(Icons.location_city, size: 18),
              label: Text(city),
              onPressed: () => context.push('/city/${Uri.encodeComponent(city)}'),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchResults(SearchState searchState) {
    if (searchState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchState.error != null) {
      return Center(
        child: Text(
          searchState.error!,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    if (searchState.venues.isEmpty) {
      return const Center(
        child: Text(
          'Sonuç bulunamadı.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: searchState.venues.length,
      itemBuilder: (context, index) =>
          VenueCard(venue: searchState.venues[index]),
    );
  }
}
