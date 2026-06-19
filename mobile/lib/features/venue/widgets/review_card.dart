import 'package:flutter/material.dart';

import '../../../core/models/review.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/star_rating_widget.dart';

class ReviewCard extends StatelessWidget {
  final Review review;
  final bool isOwn;
  final VoidCallback? onEdit;

  const ReviewCard({
    super.key,
    required this.review,
    this.isOwn = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  backgroundImage: review.userAvatar != null
                      ? NetworkImage(review.userAvatar!)
                      : null,
                  child: review.userAvatar == null
                      ? Text(
                          (review.userName ?? '?')[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName ?? 'Kullanıcı',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (review.createdAt != null)
                        Text(
                          _formatDate(review.createdAt!),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                StarRatingWidget(rating: review.rating.toDouble(), size: 16),
                if (isOwn && onEdit != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onEdit,
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                review.comment!,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
