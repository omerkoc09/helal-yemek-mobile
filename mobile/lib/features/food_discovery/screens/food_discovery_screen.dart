import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../guide/providers/guide_provider.dart';
import '../../venue/widgets/venue_card.dart';
import '../providers/food_discovery_provider.dart';

class FoodDiscoveryScreen extends ConsumerWidget {
  const FoodDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(foodDiscoveryProvider);
    final notifier = ref.read(foodDiscoveryProvider.notifier);

    return PopScope(
      canPop: state.selectedCategoryId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state.selectedCategoryId != null) {
          notifier.clearSelection();
        }
      },
      child: Scaffold(
        body: state.selectedCategoryId == null
            ? _buildCategoryGrid(ref)
            : _buildVenueList(state, notifier),
      ),
    );
  }

  Widget _buildCategoryGrid(WidgetRef ref) {
    final categoriesAsync = ref.watch(foodCategoriesProvider);
    final notifier = ref.read(foodDiscoveryProvider.notifier);

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(
        child: Text(
          'Kategoriler yüklenemedi.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      ),
      data: (categories) {
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            16, 16, 16, 16 + AppTheme.bottomNavClearance,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return _CategoryCard(
              label: category.name,
              categoryKey: category.key,
              imageUrl: category.imageUrl,
              onTap: () =>
                  notifier.selectCategory(category.id, category.name),
            );
          },
        );
      },
    );
  }

  Widget _buildVenueList(FoodDiscoveryState state, FoodDiscoveryNotifier notifier) {
    return Column(
      children: [
        _CategoryHeader(
          label: state.selectedCategoryLabel ?? '',
          onBack: notifier.clearSelection,
        ),
        Expanded(child: _buildVenueListBody(state)),
      ],
    );
  }

  Widget _buildVenueListBody(FoodDiscoveryState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    if (state.venues.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Bu kategoride mekan bulunamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        top: 8,
        bottom: 8 + AppTheme.bottomNavClearance,
      ),
      itemCount: state.venues.length,
      itemBuilder: (context, index) =>
          VenueCard(venue: state.venues[index]),
    );
  }

}

class _CategoryHeader extends StatelessWidget {
  final String label;
  final VoidCallback onBack;

  const _CategoryHeader({required this.label, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            color: AppTheme.textPrimary,
            onPressed: onBack,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String label;
  final String categoryKey;
  final String? imageUrl;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.label,
    required this.categoryKey,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _categoryImage(),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryImage() {
    Widget assetFallback() => Image.asset(
      'assets/images/categories/$categoryKey.png',
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: AppTheme.primary.withValues(alpha: 0.1),
        child: const Icon(
          Icons.restaurant_menu,
          color: AppTheme.primary,
          size: 32,
        ),
      ),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return assetFallback();

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => assetFallback(),
    );
  }
}
