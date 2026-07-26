import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/guide_provider.dart';

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
            'Mutfaklar',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bu mekanın sunduğu mutfakları seçin.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          // 2 modlu radio seçimi
          _buildModeOption(
            context,
            value: 'all',
            groupValue: state.foodHalalMode,
            title: 'Tüm Mutfaklar Tavsiye Edilir',
            subtitle: 'Sunduğu tüm mutfaklar tavsiye edilir',
            icon: Icons.restaurant_menu,
            onChanged: (v) => notifier.setFoodHalalMode(v!),
          ),
          const SizedBox(height: 8),
          _buildModeOption(
            context,
            value: 'except',
            groupValue: state.foodHalalMode,
            title: 'Şunlar Hariç Tavsiye Edilir',
            subtitle: 'Bazı ürünler hariç sunduğu mutfaklar tavsiye edilir',
            icon: Icons.remove_circle_outline,
            onChanged: (v) => notifier.setFoodHalalMode(v!),
          ),

          const SizedBox(height: 16),

          // Except modu: sakıncalı ürün girişi
          if (state.foodHalalMode == 'except') ...[
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Tavsiye edilmeyen ürünler',
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
                  hintText: entry.key == 0 ? 'örn. kaşar' : 'Ürün adı',
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
                label: const Text('Ürün ekle'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Mutfak seçimi: her iki modda da gösterilir
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Sunulan mutfakları seçin:',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text('Mutfaklar yüklenemedi.'),
            data: (categories) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((category) {
                  final isSelected =
                      state.selectedCategoryIds.contains(category.id);
                  return FilterChip(
                    label: Text(category.name),
                    selected: isSelected,
                    onSelected: (_) => notifier.toggleCategory(category.id),
                    selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.primary,
                    avatar: isSelected ? null : const Icon(Icons.add, size: 18),
                  );
                }).toList(),
              );
            },
          ),
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
