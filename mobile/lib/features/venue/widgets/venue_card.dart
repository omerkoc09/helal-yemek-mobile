import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/venue.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/star_rating_widget.dart';
import 'halal_criteria_chip.dart';

class VenueCard extends StatelessWidget {
  final Venue venue;

  const VenueCard({super.key, required this.venue});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => context.push('/venue/${venue.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fotoğraf
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: venue.photos.isNotEmpty
                      ? Image.network(
                          venue.photos.first.url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _photoPlaceholder(),
                        )
                      : _photoPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              // Bilgi
              Expanded(
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
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (venue.isDoubleVerified)
                          const Icon(Icons.verified,
                              size: 18, color: AppTheme.primary),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      venue.address,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (venue.avgRating != null) ...[
                          StarRatingWidget(
                              rating: venue.avgRating!, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '(${venue.reviewCount})',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (venue.distance != null)
                          Text(
                            _formatDistance(venue.distance!),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    if (venue.criteria.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      HalalCriteriaChips(criteria: venue.criteria),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: AppTheme.background,
      child: const Icon(Icons.restaurant_outlined,
          color: AppTheme.textSecondary),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
