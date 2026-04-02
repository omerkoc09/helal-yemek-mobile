import 'package:flutter/material.dart';

import '../../../core/models/venue.dart';
import '../../../core/theme/app_theme.dart';

class FoodCategoryTile extends StatefulWidget {
  final FoodCategory category;
  final List<int> selectedItemIds;
  final ValueChanged<int> onToggleItem;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final ValueChanged<String> onAddCustom;

  const FoodCategoryTile({
    super.key,
    required this.category,
    required this.selectedItemIds,
    required this.onToggleItem,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onAddCustom,
  });

  @override
  State<FoodCategoryTile> createState() => _FoodCategoryTileState();
}

class _FoodCategoryTileState extends State<FoodCategoryTile> {
  bool _showCustomInput = false;
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  bool get _allSelected =>
      widget.category.items.isNotEmpty &&
      widget.selectedItemIds.length >= widget.category.items.length &&
      widget.category.items.every((i) => widget.selectedItemIds.contains(i.id));

  @override
  Widget build(BuildContext context) {
    final selectedCount = widget.selectedItemIds.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selectedCount > 0
              ? AppTheme.primary.withValues(alpha: 0.3)
              : AppTheme.textSecondary.withValues(alpha: 0.15),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/categories/${widget.category.key}.png',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Icon(
              Icons.restaurant_outlined,
              color: selectedCount > 0 ? AppTheme.primary : AppTheme.textSecondary,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.category.labelTr,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (selectedCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _allSelected ? 'Hepsi' : '$selectedCount',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        children: [
          // "Hepsi" checkbox
          CheckboxListTile(
            value: _allSelected,
            onChanged: (_) {
              if (_allSelected) {
                widget.onDeselectAll();
              } else {
                widget.onSelectAll();
              }
            },
            title: const Text(
              'Hepsi',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            activeColor: AppTheme.primary,
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          if (widget.category.items.isNotEmpty) const Divider(height: 1),

          // Her çeşit
          ...widget.category.items.map((item) {
            final isSelected = widget.selectedItemIds.contains(item.id);
            return CheckboxListTile(
              value: isSelected,
              onChanged: (_) => widget.onToggleItem(item.id),
              title: Text(item.labelTr),
              activeColor: AppTheme.primary,
              dense: true,
              contentPadding: EdgeInsets.zero,
            );
          }),

          const SizedBox(height: 4),

          // "+ Diğer" butonu
          if (_showCustomInput) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customController,
                    decoration: const InputDecoration(
                      hintText: 'Yeni çeşit adı',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: _submitCustomItem,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.check, color: AppTheme.primary),
                  onPressed: () => _submitCustomItem(_customController.text),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => setState(() {
                    _showCustomInput = false;
                    _customController.clear();
                  }),
                ),
              ],
            ),
          ] else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showCustomInput = true),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Diğer'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _submitCustomItem(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      widget.onAddCustom(trimmed);
      _customController.clear();
      setState(() => _showCustomInput = false);
    }
  }
}
