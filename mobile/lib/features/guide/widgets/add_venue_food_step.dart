import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/guide_provider.dart';
import 'food_category_tile.dart';

class AddVenueFoodStep extends ConsumerWidget {
  const AddVenueFoodStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(foodCategoriesProvider);
    final state = ref.watch(addVenueProvider);
    final notifier = ref.read(addVenueProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Caiz Yemekler',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bu mekanda caiz olan yemekleri seçin.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          // "Tüm Yemekler Caiz" seçeneği
          Container(
            decoration: BoxDecoration(
              color: state.allFoodSelected
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: state.allFoodSelected
                    ? AppTheme.primary
                    : AppTheme.textSecondary.withValues(alpha: 0.2),
                width: state.allFoodSelected ? 2 : 1,
              ),
            ),
            child: CheckboxListTile(
              value: state.allFoodSelected,
              onChanged: (_) => notifier.toggleAllFood(),
              title: const Text(
                'Tüm Yemekler Caiz',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: const Text(
                'Mekandaki tüm yemekler caizdir',
                style: TextStyle(fontSize: 12),
              ),
              secondary: Icon(
                Icons.restaurant_menu,
                color: state.allFoodSelected
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
              ),
              activeColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (!state.allFoodSelected) ...[
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'veya kategorilere göre seçin:',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),

            categoriesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Text('Yemek kategorileri yüklenemedi.'),
              data: (categories) {
                return Column(
                  children: categories.map((category) {
                    return FoodCategoryTile(
                      category: category,
                      selectedItemIds:
                          state.selectedFoodItemIds[category.id] ?? [],
                      onToggleItem: (itemId) =>
                          notifier.toggleFoodItem(category.id, itemId),
                      onSelectAll: () => notifier.selectAllInCategory(
                        category.id,
                        category.items.map((i) => i.id).toList(),
                      ),
                      onDeselectAll: () =>
                          notifier.deselectAllInCategory(category.id),
                      onAddCustom: (label) =>
                          notifier.addCustomFoodItem(category.id, label),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
