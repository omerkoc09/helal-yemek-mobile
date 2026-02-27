import 'package:flutter/material.dart';

import '../../../core/models/venue.dart';
import '../../../core/theme/app_theme.dart';

class HalalCriteriaChip extends StatelessWidget {
  final HalalCriteria criteria;

  const HalalCriteriaChip({super.key, required this.criteria});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        _iconForCriteria(criteria.key),
        size: 16,
        color: AppTheme.primary,
      ),
      label: Text(criteria.labelTr),
      visualDensity: VisualDensity.compact,
    );
  }

  IconData _iconForCriteria(String key) {
    switch (key) {
      case 'personel_experience':
        return Icons.person_outline;
      case 'halal_certified':
        return Icons.verified_outlined;
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
