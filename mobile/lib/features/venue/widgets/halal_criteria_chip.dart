import 'package:flutter/material.dart';

import '../../../core/models/venue.dart';
import '../../../core/theme/app_theme.dart';

class HalalCriteriaChip extends StatelessWidget {
  final HalalCriteria criteria;

  const HalalCriteriaChip({super.key, required this.criteria});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDescription(context),
      child: Chip(
        avatar: Icon(
          _iconForCriteria(criteria.key),
          size: 16,
          color: AppTheme.primary,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(criteria.name),
            if (criteria.description != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
            ],
          ],
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  void _showDescription(BuildContext context) {
    final description = criteria.description;
    if (description == null || description.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_iconForCriteria(criteria.key), color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(criteria.name, style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  IconData _iconForCriteria(String key) {
    switch (key) {
      case 'halal_certified':
        return Icons.verified_outlined;
      case 'known_owner':
        return Icons.store_outlined;
      case 'no_boycott_products':
        return Icons.block_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }
}

class HalalCriteriaChips extends StatelessWidget {
  final List<HalalCriteria> criteria;

  const HalalCriteriaChips({super.key, required this.criteria});

  @override
  Widget build(BuildContext context) {
    if (criteria.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: criteria.map((c) => HalalCriteriaChip(criteria: c)).toList(),
    );
  }
}
