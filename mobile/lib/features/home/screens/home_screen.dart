import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../venue/widgets/venue_card.dart';
import '../../venue/widgets/venue_horizontal_card.dart';
import '../providers/home_provider.dart';
import '../widgets/category_grid.dart';
import '../widgets/category_slider.dart';

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeProvider);
    final isGuide = ref.watch(authProvider).isGuide;
    final query = _searchController.text;

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
            ),
            Expanded(
              child: Stack(
                children: [
                  // Arka plan her zaman feed
                  _Feed(state: state),
                  // Arama odaklanınca karartma + dropdown
                  if (_isFocused) ...[
                    GestureDetector(
                      onTap: () => _focusNode.unfocus(),
                      child: Container(color: Colors.black.withValues(alpha: 0.35)),
                    ),
                    if (query.isEmpty)
                      _CategoryDropdown(onDismiss: () => _focusNode.unfocus())
                    else
                      _SearchResultsOverlay(
                        state: state,
                        onDismiss: () => _focusNode.unfocus(),
                      ),
                  ],
                  if (isGuide && !_isFocused)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: FloatingActionButton(
                        onPressed: () => context.push('/add-venue'),
                        shape: const CircleBorder(),
                        child: const Icon(Icons.add_location_alt, size: 26),
                      ),
                    ),
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

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
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

/// Arama odaklanınca sayfanın üstünde inline kart olarak açılan mutfaklar dropdown'ı.
class _CategoryDropdown extends StatelessWidget {
  final VoidCallback onDismiss;

  const _CategoryDropdown({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  'Mutfaklar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: const CategoryGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sorgu varken sonuçları inline kart olarak gösteren overlay.
class _SearchResultsOverlay extends StatelessWidget {
  final HomeState state;
  final VoidCallback onDismiss;

  const _SearchResultsOverlay({
    required this.state,
    required this.onDismiss,
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
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (state.isSearching) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            '"${state.searchQuery}" için sonuç bulunamadı.',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.searchResults.length,
      itemBuilder: (_, i) => VenueCard(venue: state.searchResults[i]),
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
          SliverToBoxAdapter(
            child: _Section(
              title: 'Mutfaklar',
              onSeeAll: () => context.go('/food-discovery'),
              child: const CategorySlider(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onSeeAll,
                child: const Text(
                  'Tümünü Gör',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
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
        height: 190,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.nearbyVenues.isEmpty) {
      return const _EmptySlot(message: 'Yakınınızda onaylı mekan bulunamadı.');
    }
    return SizedBox(
      height: 190,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: state.nearbyVenues.length,
        itemBuilder: (_, i) => VenueHorizontalCard(venue: state.nearbyVenues[i]),
      ),
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
        height: 190,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.popularVenues.isEmpty) {
      return const _EmptySlot(message: 'Bu alanda henüz popüler mekan yok.');
    }
    return SizedBox(
      height: 190,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: state.popularVenues.length,
        itemBuilder: (_, i) => VenueHorizontalCard(venue: state.popularVenues[i]),
      ),
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
