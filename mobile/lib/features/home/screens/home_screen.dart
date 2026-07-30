import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/venue.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../guide/providers/guide_provider.dart';
import '../../search/data/recent_searches_store.dart';
import '../../search/models/search_suggestion.dart';
import '../../search/providers/search_sources_provider.dart';
import '../../search/widgets/suggestion_list.dart';
import '../../venue/models/venue_detail_preview.dart';
import '../../venue/widgets/venue_horizontal_card.dart';
import '../providers/home_provider.dart';
import '../providers/venue_filter_provider.dart';
import '../widgets/category_slider.dart';
import '../widgets/sort_bottom_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(homeProvider.notifier).fetchFeed());
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSortFromHome() async {
    final locationAvailable = !ref.read(homeProvider).locationDenied;
    final selected = await showVenueSortBottomSheet(
      context,
      current: VenueSortOption.none,
      locationAvailable: locationAvailable,
    );
    if (selected != null && mounted) {
      ref.read(venueFilterProvider.notifier).setSort(selected);
      if (mounted) context.push('/venues/filtered');
    }
  }

  /// Sonuç sayfasını açar ve terimi son aramalara kaydeder.
  Future<void> _openResults(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;

    await ref.read(recentSearchesStoreProvider).add(trimmed);
    if (!mounted) return;

    _focusNode.unfocus();
    context.push(
      '${AppRoutes.searchResults}?q=${Uri.encodeComponent(trimmed)}',
    );
  }

  /// İlçe önerisi — şehir+ilçe kesin filtresiyle sonuç sayfasına gider.
  Future<void> _openDistrictResults(String city, String district) async {
    await ref.read(recentSearchesStoreProvider).add('$city / $district');
    if (!mounted) return;

    _focusNode.unfocus();
    context.push(
      '${AppRoutes.searchResults}'
      '?city=${Uri.encodeComponent(city)}'
      '&district=${Uri.encodeComponent(district)}',
    );
  }

  /// Öneri satırı seçildiğinde tipine göre yönlendirir.
  void _handleSuggestion(SearchSuggestion suggestion) {
    switch (suggestion.type) {
      case SuggestionType.venue:
        final venue = _findSuggestedVenue(suggestion.venueId!);
        if (venue == null) return;
        _focusNode.unfocus();
        context.push(
          '/venue/${venue.id}',
          extra: VenueDetailPreview(name: venue.name, city: venue.locationLabel),
        );
      case SuggestionType.district:
        _openDistrictResults(suggestion.city!, suggestion.district!);
      case SuggestionType.category:
      case SuggestionType.city:
        _openResults(suggestion.label);
    }
  }

  /// Öneri satırındaki mekanı güncel öneri listesinden bulur.
  /// Liste tıklama anında değişmiş olabileceği için null-güvenli arama yapılır
  /// (firstWhere yerine) — bulunamazsa hiçbir şey yapılmaz.
  Venue? _findSuggestedVenue(String venueId) {
    for (final v in ref.read(homeProvider).searchResults) {
      if (v.id == venueId) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeProvider);
    final query = _searchController.text;

    final categories = ref.watch(foodCategoriesProvider).value ?? const [];
    final cities = ref.watch(searchCitiesProvider).value ?? const <String>[];
    final districts =
        ref.watch(searchDistrictsProvider).value ?? const <CityDistrict>[];

    final suggestions = buildSuggestions(
      query: query,
      categories: categories,
      cities: cities,
      districts: districts,
      venues: state.searchResults,
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _SearchBar(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: (q) {
                setState(() {});
                ref.read(homeProvider.notifier).search(q);
              },
              onClear: () {
                _searchController.clear();
                setState(() {});
                ref.read(homeProvider.notifier).clearSearch();
              },
              onSubmitted: (value) => _openResults(value),
            ),
            if (!_isFocused)
              _FilterActionsRow(
                onSort: _handleSortFromHome,
                onFilter: () => context.push('/venues/filter?fromHome=true'),
              ),
            Expanded(
              child: Stack(
                children: [
                  // Arka plan her zaman feed
                  _Feed(state: state),
                  // Aramaya yazı girilince karartma + öneri overlay'i
                  if (_isFocused && query.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => _focusNode.unfocus(),
                      child: Container(color: Colors.black.withValues(alpha: 0.35)),
                    ),
                    _SearchSuggestionsOverlay(
                      suggestions: suggestions,
                      isLoading: state.isSearching,
                      onSelect: _handleSuggestion,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: 'Restoran, mutfak veya yemek ara',
          hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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

/// Yazarken öneri listesini modal görünümünde gösteren overlay.
class _SearchSuggestionsOverlay extends StatelessWidget {
  final List<SearchSuggestion> suggestions;
  final bool isLoading;
  final ValueChanged<SearchSuggestion> onSelect;

  const _SearchSuggestionsOverlay({
    required this.suggestions,
    required this.isLoading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SuggestionList(
            suggestions: suggestions,
            isLoading: isLoading,
            onSelect: onSelect,
          ),
        ),
      ),
    );
  }
}

class _Feed extends ConsumerWidget {
  final HomeState state;

  const _Feed({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(homeProvider.notifier).fetchFeed(),
      color: AppTheme.primary,
      child: CustomScrollView(
        slivers: [
          if (state.locationDenied)
            SliverToBoxAdapter(child: _LocationBanner()),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 16, 0, 10),
              child: CategorySlider(),
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title:'Şehirdeki Restoranlar',
              onSeeAll: () => context.push('/venues/all?type=city'),
              child: _NearbySlider(state: state),
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Popüler Restoranlar',
              onSeeAll: () => context.push('/venues/all?type=popular'),
              child: _PopularSlider(state: state),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.bottomNavClearance)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;
  final Widget child;

  const _Section({
    required this.title,
    required this.onSeeAll,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onSeeAll,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.border, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _NearbySlider extends StatelessWidget {
  final HomeState state;

  const _NearbySlider({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingNearby) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.nearbyVenues.isEmpty) {
      return const _EmptySlot(message: 'Yakınınızda onaylı mekan bulunamadı.');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = MediaQuery.of(context).size.width - 16 - 80;
        return SizedBox(
          height: 220,
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 4),
            scrollDirection: Axis.horizontal,
            itemCount: state.nearbyVenues.length,
            itemBuilder: (_, i) =>
                VenueHorizontalCard(venue: state.nearbyVenues[i], width: cardWidth),
          ),
        );
      },
    );
  }
}

class _PopularSlider extends StatelessWidget {
  final HomeState state;

  const _PopularSlider({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingPopular) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.popularVenues.isEmpty) {
      return const _EmptySlot(message: 'Bu alanda henüz popüler mekan yok.');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = MediaQuery.of(context).size.width - 16 - 80;
        return SizedBox(
          height: 220,
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 4),
            scrollDirection: Axis.horizontal,
            itemCount: state.popularVenues.length,
            itemBuilder: (_, i) =>
                VenueHorizontalCard(venue: state.popularVenues[i], width: cardWidth),
          ),
        );
      },
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final String message;

  const _EmptySlot({required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
      ),
    );
  }
}

class _LocationBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off, color: Color(0xFFE65100), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Yakınınızdaki mekanları görmek için konum izni verin.',
              style: TextStyle(fontSize: 13, color: Color(0xFFE65100)),
            ),
          ),
          GestureDetector(
            onTap: () => ref.read(homeProvider.notifier).fetchFeed(),
            child: const Text(
              'İzin Ver',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterActionsRow extends StatelessWidget {
  final VoidCallback onSort;
  final VoidCallback onFilter;

  const _FilterActionsRow({required this.onSort, required this.onFilter});

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minimumSize: const Size(0, 39),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onSort,
              style: style,
              icon: const Icon(Icons.sort),
              label: const Text('Sırala'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onFilter,
              style: style,
              icon: const Icon(Icons.tune),
              label: const Text('Filtrele'),
            ),
          ),
        ],
      ),
    );
  }
}
