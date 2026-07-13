import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          if (searchState.query.isNotEmpty)
            Expanded(
              child: _buildSearchResults(searchState),
            ),
        ],
      ),
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
      padding: const EdgeInsets.only(
        top: 8,
        bottom: 8 + AppTheme.bottomNavClearance,
      ),
      itemCount: searchState.venues.length,
      itemBuilder: (context, index) =>
          VenueCard(venue: searchState.venues[index]),
    );
  }
}
