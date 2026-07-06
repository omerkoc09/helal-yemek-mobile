import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../food_discovery/providers/food_discovery_provider.dart';
import '../../guide/providers/guide_provider.dart';

/// Arama kutusu odaklandığında ve sorgu boşken gösterilen 3 sütunlu kategori grid'i.
class CategoryGrid extends ConsumerWidget {
  const CategoryGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(foodCategoriesProvider);

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const SizedBox.shrink(),
      data: (categories) {
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.8,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return _CategoryGridItem(
              categoryId: category.id,
              categoryKey: category.key,
              labelTr: category.name,
              imageUrl: category.imageUrl,
              onTap: () {
                ref
                    .read(foodDiscoveryProvider.notifier)
                    .selectCategory(category.id, category.name);
                context.go('/food-discovery');
              },
            );
          },
        );
      },
    );
  }
}

class _CategoryGridItem extends StatelessWidget {
  final int categoryId;
  final String categoryKey;
  final String labelTr;
  final String? imageUrl;
  final VoidCallback onTap;

  const _CategoryGridItem({
    required this.categoryId,
    required this.categoryKey,
    required this.labelTr,
    this.imageUrl,
    required this.onTap,
  });

  Widget _categoryImage() {
    Widget assetFallback() => Image.asset(
      'assets/images/categories/$categoryKey.png',
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: AppTheme.background,
        child: const Icon(
          Icons.restaurant_outlined,
          color: AppTheme.textSecondary,
          size: 28,
        ),
      ),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return assetFallback();

    return Image.network(
      imageUrl!,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => assetFallback(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: _categoryImage(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Text(
                labelTr,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
