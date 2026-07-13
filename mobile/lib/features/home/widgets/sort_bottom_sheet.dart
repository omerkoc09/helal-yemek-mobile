import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/venue_filter_provider.dart';

/// Shows the sort bottom sheet and returns the selected option, or null if dismissed.
/// The caller is responsible for acting on the returned selection (e.g. push results).
Future<VenueSortOption?> showVenueSortBottomSheet(
  BuildContext context, {
  required VenueSortOption current,
  required bool locationAvailable,
}) {
  return showModalBottomSheet<VenueSortOption>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SortBottomSheet(
      current: current,
      locationAvailable: locationAvailable,
    ),
  );
}

class _SortBottomSheet extends StatelessWidget {
  final VenueSortOption current;
  final bool locationAvailable;

  const _SortBottomSheet({
    required this.current,
    required this.locationAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Row(
              children: [
                const Text(
                  'Sırala',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _option(context, VenueSortOption.alphabetical, 'Alfabetik (A→Z)'),
          _option(context, VenueSortOption.rating, 'Puana göre (yüksekten düşüğe)'),
          _option(
            context,
            VenueSortOption.distance,
            'Yakınlığa göre (yakından uzağa)',
            disabled: !locationAvailable,
          ),
          _option(
            context,
            VenueSortOption.reviewCount,
            'Değerlendirme sayısına göre (çoktan aza)',
          ),
          const SizedBox(height: AppTheme.bottomNavClearance),
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context,
    VenueSortOption value,
    String label, {
    bool disabled = false,
  }) {
    return RadioListTile<VenueSortOption>(
      value: value,
      groupValue: current,
      activeColor: AppTheme.primary,
      title: Text(
        label,
        style: TextStyle(
          color: disabled ? AppTheme.textSecondary : AppTheme.textPrimary,
          fontSize: 15,
        ),
      ),
      onChanged: disabled ? null : (_) => Navigator.of(context).pop(value),
    );
  }
}
