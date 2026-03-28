import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/venue.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/map_launcher.dart';
import '../../../shared/widgets/star_rating_widget.dart';
import '../../venue/widgets/halal_criteria_chip.dart';
import '../../venue/widgets/venue_status_badge.dart';

void showVenueBottomSheet(BuildContext context, Venue venue) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _VenueBottomSheetContent(venue: venue),
  );
}

class _VenueBottomSheetContent extends StatelessWidget {
  final Venue venue;

  const _VenueBottomSheetContent({required this.venue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Fotoğraf + bilgi
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fotoğraf
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: venue.photos.isNotEmpty
                      ? Image.network(
                          venue.photos.first.url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _photoPlaceholder(),
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
                    Text(
                      venue.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      venue.address,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (venue.avgRating != null)
                      Row(
                        children: [
                          StarRatingWidget(
                              rating: venue.avgRating!, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${venue.avgRating!.toStringAsFixed(1)} (${venue.reviewCount})',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Statü badge
          VenueStatusBadge(status: venue.status),
          const SizedBox(height: 12),

          // Helal kriterleri
          if (venue.criteria.isNotEmpty) ...[
            HalalCriteriaChips(criteria: venue.criteria),
            const SizedBox(height: 16),
          ],

          // Butonlar
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/venue/${venue.id}');
                  },
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Detay'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    MapLauncher.openDirections(
                      latitude: venue.latitude,
                      longitude: venue.longitude,
                      label: venue.name,
                      googlePlaceId: venue.googlePlaceId,
                    );
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text('Yol Tarifi'),
                ),
              ),
            ],
          ),
          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
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
}
