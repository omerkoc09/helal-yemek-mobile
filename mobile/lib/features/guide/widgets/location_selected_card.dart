import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class LocationSelectedCard extends StatelessWidget {
  final double latitude;
  final double longitude;
  final VoidCallback onEdit;

  const LocationSelectedCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'Konum Seçildi',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enlem: ${latitude.toStringAsFixed(6)}\nBoylam: ${longitude.toStringAsFixed(6)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
              label: const Text('Konumu Değiştir'),
            ),
          ),
        ],
      ),
    );
  }
}
