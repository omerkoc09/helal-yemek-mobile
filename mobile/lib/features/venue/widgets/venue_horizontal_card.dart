import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/venue.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/star_rating_widget.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../models/venue_detail_preview.dart';

class VenueHorizontalCard extends ConsumerWidget {
  final Venue venue;
  final double? width;

  const VenueHorizontalCard({super.key, required this.venue, this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoritesProvider).favoriteIds.contains(venue.id);

    return Container(
      width: width ?? 200,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(
            '/venue/${venue.id}',
            extra:
                VenueDetailPreview(name: venue.name, city: venue.locationLabel),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: venue.photos.isNotEmpty
                        ? Image.network(
                            venue.photos.first.url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _FavButton(venue: venue, isFav: isFav),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
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
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (venue.avgRating != null) ...[
                          const SizedBox(width: 6),
                          StarRatingWidget(rating: venue.avgRating!, size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

class _FavButton extends ConsumerWidget {
  final Venue venue;
  final bool isFav;

  const _FavButton({required this.venue, required this.isFav});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(favoritesProvider.notifier).toggleFavorite(venue),
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
          size: 17,
          color: isFav ? Colors.red : Colors.grey.shade700,
        ),
      ),
    );
  }
}
