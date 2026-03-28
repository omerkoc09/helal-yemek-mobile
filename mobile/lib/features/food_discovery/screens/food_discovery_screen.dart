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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.selectedCategoryLabel ?? 'Ne Yesem?',
        ),
        leading: state.selectedCategoryId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => notifier.clearSelection(),
              )
            : null,
      ),
      body: state.selectedCategoryId == null
          ? _buildCategoryGrid(ref)
          : _buildVenueList(state),
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
          padding: const EdgeInsets.all(16),
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
              label: category.labelTr,
              icon: _categoryIcon(category.key),
              onTap: () =>
                  notifier.selectCategory(category.id, category.labelTr),
            );
          },
        );
      },
    );
  }

  Widget _buildVenueList(FoodDiscoveryState state) {
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
            'Bu kategoride yakınınızda mekan bulunamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.venues.length,
      itemBuilder: (context, index) =>
          VenueCard(venue: state.venues[index]),
    );
  }

  IconData _categoryIcon(String key) {
    switch (key) {
      case 'doner':
        return Icons.kebab_dining;
      case 'tost':
        return Icons.bakery_dining;
      case 'borek':
        return Icons.breakfast_dining;
      case 'pide_lahmacun':
        return Icons.local_pizza;
      case 'pizza':
        return Icons.local_pizza_outlined;
      case 'kofte':
        return Icons.lunch_dining;
      case 'cig_kofte':
        return Icons.set_meal;
      case 'tatli':
        return Icons.cake;
      case 'tantuni':
        return Icons.fastfood;
      case 'tavuk':
        return Icons.restaurant;
      case 'corba':
        return Icons.soup_kitchen;
      case 'kebap':
        return Icons.kebab_dining;
      case 'balik':
        return Icons.set_meal;
      case 'dondurma':
        return Icons.icecream;
      default:
        return Icons.restaurant_menu;
    }
  }
}

class _CategoryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: AppTheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
