import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class VenueStatusBadge extends StatelessWidget {
  final String status;

  const VenueStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isApproved = status == 'approved';
    final color = isApproved ? AppTheme.pinApproved : AppTheme.pinPending;
    final icon = isApproved ? Icons.check_circle : Icons.help_outline;
    final label = isApproved ? 'Onaylandı' : 'Onay Bekliyor';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
