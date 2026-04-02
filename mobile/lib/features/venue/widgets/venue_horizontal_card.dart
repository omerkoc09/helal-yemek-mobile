import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/venue.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/star_rating_widget.dart';

class VenueHorizontalCard extends StatelessWidget {
  final Venue venue;

  const VenueHorizontalCard({super.key, required this.venue});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/venue/${venue.id}'),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fotoğraf
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: venue.photos.isNotEmpty
                    ? Image.network(
                        venue.photos.first.url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            // Bilgi
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          venue.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (venue.isApproved)
                        const Icon(Icons.verified,
                            size: 13, color: AppTheme.primary),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (venue.avgRating != null) ...[
                        StarRatingWidget(rating: venue.avgRating!, size: 11),
                        const SizedBox(width: 2),
                        Text(
                          venue.avgRating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (venue.distance != null)
                        Text(
                          _formatDistance(venue.distance!),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  if (venue.categoriesStr != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      venue.categoriesStr!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.background,
      child: const Center(
        child: Icon(Icons.restaurant_outlined,
            color: AppTheme.textSecondary, size: 32),
      ),
    );
  }

  String _formatDistance(double meters) {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
