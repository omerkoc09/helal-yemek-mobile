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

          // 3 modlu radio seçimi
          _buildModeOption(
            context,
            value: 'all',
            groupValue: state.foodHalalMode,
            title: 'Tüm Yemekler Caiz',
            subtitle: 'Mekandaki tüm yemekler caizdir',
            icon: Icons.restaurant_menu,
            onChanged: (v) => notifier.setFoodHalalMode(v!),
          ),
          const SizedBox(height: 8),
          _buildModeOption(
            context,
            value: 'except',
            groupValue: state.foodHalalMode,
            title: 'Şunlar Hariç Caiz',
            subtitle: 'Bazı malzemeler hariç tüm yemekler caiz',
            icon: Icons.remove_circle_outline,
            onChanged: (v) => notifier.setFoodHalalMode(v!),
          ),
          const SizedBox(height: 8),
          _buildModeOption(
            context,
            value: 'selected',
            groupValue: state.foodHalalMode,
            title: 'Belirli Yemekler Caiz',
            subtitle: 'Kategorilere göre seçim yapın',
            icon: Icons.checklist,
            onChanged: (v) => notifier.setFoodHalalMode(v!),
          ),

          const SizedBox(height: 16),

          // Except modu: sakıncalı ürün girişi
          if (state.foodHalalMode == 'except') ...[
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Caiz olmayan malzemeler',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...state.excludedProducts.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ExcludedProductField(
                  key: ValueKey('excluded_${entry.key}'),
                  initialValue: entry.value,
                  hintText: entry.key == 0 ? 'örn. kaşar' : 'Malzeme adı',
                  onChanged: (v) =>
                      notifier.updateExcludedProduct(entry.key, v),
                  onRemove: state.excludedProducts.length > 1
                      ? () => notifier.removeExcludedProduct(entry.key)
                      : null,
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => notifier.addExcludedProduct(''),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Malzeme ekle'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Kategori seçimi: tüm modlarda gösterilir
          ...[
            const Divider(),
            const SizedBox(height: 8),
            Text(
              state.foodHalalMode == 'selected'
                  ? 'Kategorilere göre seçin:'
                  : 'Bu mekanda sunulan yemekleri seçin:',
              style: const TextStyle(
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

  Widget _buildModeOption(
    BuildContext context, {
    required String value,
    required String groupValue,
    required String title,
    required String subtitle,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primary.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppTheme.primary
              : AppTheme.textSecondary.withValues(alpha: 0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        secondary: Icon(
          icon,
          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
        ),
        activeColor: AppTheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Stateful widget ile TextEditingController yönetimi — cursor jumping önlenir.
class _ExcludedProductField extends StatefulWidget {
  final String initialValue;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onRemove;

  const _ExcludedProductField({
    super.key,
    required this.initialValue,
    required this.hintText,
    required this.onChanged,
    this.onRemove,
  });

  @override
  State<_ExcludedProductField> createState() => _ExcludedProductFieldState();
}

class _ExcludedProductFieldState extends State<_ExcludedProductField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              hintText: widget.hintText,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        if (widget.onRemove != null)
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onRemove,
            color: Colors.red.shade400,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }
}
