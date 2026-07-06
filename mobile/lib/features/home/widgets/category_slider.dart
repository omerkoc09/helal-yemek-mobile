import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../food_discovery/providers/food_discovery_provider.dart';
import '../../guide/providers/guide_provider.dart';

class _CategoryItem {
  final int id;
  final String key;
  final String labelTr;
  final String? imageUrl;

  const _CategoryItem({
    required this.id,
    required this.key,
    required this.labelTr,
    this.imageUrl,
  });
}

class CategorySlider extends ConsumerWidget {
  const CategorySlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(foodCategoriesProvider);

    return categoriesAsync.when(
      loading: () => const SizedBox(
        height: 110,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (categories) {
        final items = categories
            .map((c) => _CategoryItem(id: c.id, key: c.key, labelTr: c.name, imageUrl: c.imageUrl))
            .toList();

        return SizedBox(
          height: 110,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _CategoryCard(item: item);
            },
          ),
        );
      },
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  final _CategoryItem item;

  const _CategoryCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref
            .read(foodDiscoveryProvider.notifier)
            .selectCategory(item.id, item.labelTr);
        // FoodDiscoveryScreen'e yönlendir
        context.go('/food-discovery');
      },
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Fotoğraf veya ikon fallback
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: SizedBox(
                height: 66,
                width: double.infinity,
                child: _categoryImage(item.key, item.imageUrl),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    item.labelTr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryImage(String key, String? imageUrl) {
    Widget assetFallback() => Image.asset(
      'assets/images/categories/$key.png',
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: AppTheme.primary.withValues(alpha: 0.1),
        child: const Icon(
          Icons.restaurant_menu,
          color: AppTheme.primary,
          size: 28,
        ),
      ),
    );

    if (imageUrl == null || imageUrl.isEmpty) return assetFallback();

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => assetFallback(),
    );
  }
}
