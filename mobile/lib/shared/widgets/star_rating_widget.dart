import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Display mode: tek dolu yıldız + yanında ortalama puan.
/// Interactive mode: 5 yıldız seçimi (yorum yazma formu için).
class StarRatingWidget extends StatelessWidget {
  final double rating;
  final double size;
  final bool interactive;
  final ValueChanged<int>? onRatingChanged;

  const StarRatingWidget({
    super.key,
    required this.rating,
    this.size = 20,
    this.interactive = false,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (interactive) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final starValue = index + 1;
          IconData icon;
          if (rating >= starValue) {
            icon = Icons.star_rounded;
          } else if (rating >= starValue - 0.5) {
            icon = Icons.star_half_rounded;
          } else {
            icon = Icons.star_outline_rounded;
          }
          return GestureDetector(
            onTap: () => onRatingChanged?.call(starValue),
            child: Icon(icon, size: size, color: AppTheme.pinPending),
          );
        }),
      );
    }

    // Display mode: tek yıldız
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: size, color: AppTheme.pinPending),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: size * 0.75,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
