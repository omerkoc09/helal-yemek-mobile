import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/venue.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../guide/providers/guide_provider.dart';
import '../../venue/models/venue_detail_preview.dart';
import '../data/recent_searches_store.dart';
import '../models/search_suggestion.dart';
import '../providers/search_provider.dart';
import '../providers/search_sources_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final list = await ref.read(recentSearchesStoreProvider).load();
    if (!mounted) return;
    setState(() => _recentSearches = list);
  }

  /// Terimi son aramalara kaydeder ve sonuç sayfasına gider.
  Future<void> _openResults(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;

    final updated = await ref.read(recentSearchesStoreProvider).add(trimmed);
    if (!mounted) return;
    setState(() => _recentSearches = updated);

    context.push('${AppRoutes.searchResults}?q=${Uri.encodeComponent(trimmed)}');
  }

  void _openVenue(Venue venue) {
    context.push(
      '/venue/${venue.id}',
      extra: VenueDetailPreview(name: venue.name, city: venue.locationLabel),
    );
  }

  Future<void> _clearRecentSearches() async {
    await ref.read(recentSearchesStoreProvider).clear();
    if (!mounted) return;
    setState(() => _recentSearches = []);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    // Öneri kaynakları — çekilemezse o tip öneriler sessizce atlanır.
    final categories = ref.watch(foodCategoriesProvider).value ?? const [];
    final cities = ref.watch(searchCitiesProvider).value ?? const [];

    final suggestions = buildSuggestions(
      query: searchState.query,
      categories: categories,
      cities: cities,
      venues: searchState.venues,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Mekan, şehir veya kategori ara...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(searchProvider.notifier).search('');
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  ref.read(searchProvider.notifier).search(value);
                  setState(() {}); // suffixIcon güncellemesi için
                },
                onSubmitted: _openResults,
              ),
            ),
            Expanded(
              child: searchState.query.trim().isEmpty
                  ? _RecentSearchesView(
                      terms: _recentSearches,
                      onTap: _openResults,
                      onClear: _clearRecentSearches,
                    )
                  : _SuggestionsView(
                      suggestions: suggestions,
                      isLoading: searchState.isLoading,
                      onSelect: (suggestion) {
                        if (suggestion.type == SuggestionType.venue) {
                          final venue = searchState.venues.firstWhere(
                            (v) => v.id == suggestion.venueId,
                          );
                          _openVenue(venue);
                        } else {
                          _openResults(suggestion.label);
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Arama kutusu boşken gösterilen son aramalar listesi.
class _RecentSearchesView extends StatelessWidget {
  final List<String> terms;
  final ValueChanged<String> onTap;
  final VoidCallback onClear;

  const _RecentSearchesView({
    required this.terms,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (terms.isEmpty) {
      return const Center(
        child: Text(
          'Mekan, şehir veya kategori ara',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Son aramalar',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              TextButton(onPressed: onClear, child: const Text('Temizle')),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: terms.length,
            itemBuilder: (context, index) => ListTile(
              leading: const Icon(Icons.history, color: AppTheme.textSecondary),
              title: Text(terms[index]),
              onTap: () => onTap(terms[index]),
            ),
          ),
        ),
      ],
    );
  }
}

/// Yazarken düşen öneri listesi.
class _SuggestionsView extends StatelessWidget {
  final List<SearchSuggestion> suggestions;
  final bool isLoading;
  final ValueChanged<SearchSuggestion> onSelect;

  const _SuggestionsView({
    required this.suggestions,
    required this.isLoading,
    required this.onSelect,
  });

  IconData _iconFor(SuggestionType type) => switch (type) {
        SuggestionType.category => Icons.restaurant_menu,
        SuggestionType.city => Icons.place_outlined,
        SuggestionType.venue => Icons.storefront_outlined,
      };

  String _labelFor(SearchSuggestion suggestion) => switch (suggestion.type) {
        SuggestionType.category => 'Kategori',
        SuggestionType.city => 'Şehir',
        SuggestionType.venue => suggestion.subtitle == null
            ? 'Mekan'
            : 'Mekan · ${suggestion.subtitle}',
      };

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      if (isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Center(
        child: Text(
          'Öneri bulunamadı. Aramak için Enter\'a basın.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return ListTile(
          leading: Icon(_iconFor(suggestion.type), color: AppTheme.textSecondary),
          title: Text(suggestion.label),
          subtitle: Text(
            _labelFor(suggestion),
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () => onSelect(suggestion),
        );
      },
    );
  }
}
