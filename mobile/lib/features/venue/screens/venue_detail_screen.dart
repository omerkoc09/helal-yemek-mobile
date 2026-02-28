import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/map_launcher.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/star_rating_widget.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../providers/venue_detail_provider.dart';
import '../widgets/add_review_sheet.dart';
import '../widgets/halal_criteria_chip.dart';
import '../widgets/venue_status_badge.dart';
import '../widgets/review_card.dart';
import '../widgets/venue_photo_gallery.dart';

class VenueDetailScreen extends ConsumerWidget {
  final String venueId;

  const VenueDetailScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueAsync = ref.watch(venueDetailProvider(venueId));
    final reviewsAsync = ref.watch(venueReviewsProvider(venueId));
    final favState = ref.watch(favoritesProvider);
    final authState = ref.watch(authProvider);

    return venueAsync.when(
      loading: () => const Scaffold(body: LoadingIndicator()),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorRetryWidget(
          message: 'Mekan detayı yüklenemedi.',
          onRetry: () => ref.invalidate(venueDetailProvider(venueId)),
        ),
      ),
      data: (venue) {
        final isFav = favState.favoriteIds.contains(venue.id);

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // AppBar + Fotoğraf galerisi
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    venue.name,
                    style: const TextStyle(fontSize: 16),
                  ),
                  background: VenuePhotoGallery(photos: venue.photos),
                ),
                actions: [
                  if (authState.isAuthenticated)
                    IconButton(
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? AppTheme.error : null,
                      ),
                      tooltip: isFav ? 'Favoriden Çıkar' : 'Favoriye Ekle',
                      onPressed: () => ref
                          .read(favoritesProvider.notifier)
                          .toggleFavorite(venue),
                    ),
                  IconButton(
                    icon: const Icon(Icons.directions),
                    tooltip: 'Yol Tarifi',
                    onPressed: () => MapLauncher.openDirections(
                      latitude: venue.latitude,
                      longitude: venue.longitude,
                      label: venue.name,
                    ),
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Durum badge'leri
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          VenueStatusBadge(status: venue.status),
                          if (venue.verifiedAt != null)
                            _VerifiedAtBadge(date: venue.verifiedAt!),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Puan
                      if (venue.avgRating != null)
                        Row(
                          children: [
                            StarRatingWidget(
                                rating: venue.avgRating!, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              venue.avgRating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${venue.reviewCount} yorum)',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      if (venue.avgRating != null) const SizedBox(height: 16),

                      // Adres
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        text:
                            '${venue.address}, ${venue.city}',
                      ),
                      const SizedBox(height: 16),

                      // Helal Kriterleri
                      if (venue.criteria.isNotEmpty) ...[
                        const Text(
                          'Helal Kriterleri',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        HalalCriteriaChips(criteria: venue.criteria),
                        const SizedBox(height: 16),
                      ],

                      // Caiz Yemekler
                      if (venue.allFoodHalal ||
                          venue.foodItems.isNotEmpty) ...[
                        const Text(
                          'Caiz Yemekler',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (venue.allFoodHalal)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.primary
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.restaurant_menu,
                                    size: 16, color: AppTheme.primary),
                                SizedBox(width: 6),
                                Text(
                                  'Tüm Yemekler Caiz',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: venue.foodItems
                                .map(
                                  (item) => Chip(
                                    label: Text(
                                      item.labelTr,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: AppTheme.primary
                                        .withValues(alpha: 0.08),
                                    side: BorderSide(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(height: 16),
                      ],

                      // Notlar
                      if (venue.notes != null && venue.notes!.isNotEmpty) ...[
                        const Text(
                          'Notlar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          venue.notes!,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Yorumlar başlığı
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Yorumlar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (authState.isAuthenticated)
                            TextButton.icon(
                              onPressed: () => showAddReviewSheet(
                                context,
                                venueId: venueId,
                              ),
                              icon: const Icon(Icons.rate_review_outlined,
                                  size: 18),
                              label: const Text('Yorum Yaz'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // Yorumlar listesi
              reviewsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: LoadingIndicator(),
                  ),
                ),
                error: (_, _) => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Yorumlar yüklenemedi.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ),
                data: (reviews) {
                  if (reviews.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Henüz yorum yapılmamış.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: reviews.length,
                      itemBuilder: (context, index) {
                        final review = reviews[index];
                        final isOwn =
                            review.userId == authState.user?.id;
                        return ReviewCard(
                          review: review,
                          isOwn: isOwn,
                          onEdit: isOwn
                              ? () => showAddReviewSheet(
                                    context,
                                    venueId: venueId,
                                    existingReview: review,
                                  )
                              : null,
                        );
                      },
                    ),
                  );
                },
              ),

              // Alt boşluk
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _VerifiedAtBadge extends StatelessWidget {
  final DateTime date;

  const _VerifiedAtBadge({required this.date});

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.textSecondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.update, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            'Son doğrulama: $formatted',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
