import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/venue.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/star_rating_widget.dart';
import '../../favorites/providers/favorites_provider.dart';
import 'halal_criteria_chip.dart';
import 'venue_badge_chip.dart';

class VenueCard extends ConsumerWidget {
  final Venue venue;

  const VenueCard({super.key, required this.venue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoritesProvider).favoriteIds.contains(venue.id);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: () => context.push('/venue/${venue.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Büyük fotoğraf alanı
            Stack(
              children: [
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: venue.photos.isNotEmpty
                      ? Image.network(
                          venue.photos.first.url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _photoPlaceholder(),
                        )
                      : _photoPlaceholder(),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => ref
                        .read(favoritesProvider.notifier)
                        .toggleFavorite(venue),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        size: 19,
                        color: isFav ? Colors.red : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Bilgi alanı
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          venue.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (venue.avgRating != null) ...[
                        const SizedBox(width: 8),
                        StarRatingWidget(rating: venue.avgRating!, size: 15),
                      ],
                      const SizedBox(width: 6),
                      VenueBadgeChip(badge: venue.badge, compact: true),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (venue.criteria.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    HalalCriteriaChips(criteria: venue.criteria),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: AppTheme.background,
      child: const Center(
        child: Icon(Icons.restaurant_outlined,
            color: AppTheme.textSecondary, size: 48),
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];
    if (venue.categoriesStr != null) parts.add(venue.categoriesStr!);
    if (venue.distance != null) parts.add(_formatDistance(venue.distance!));
    if (venue.district != null && venue.district!.isNotEmpty) parts.add(venue.district!);
    return parts.join(' • ');
  }

  String _formatDistance(double meters) {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
