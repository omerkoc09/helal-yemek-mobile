import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/venue.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/map_launcher.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/star_rating_widget.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../guide/providers/guide_provider.dart';
import '../providers/venue_detail_provider.dart';
import '../widgets/add_review_sheet.dart';
import '../widgets/halal_criteria_chip.dart';
import '../widgets/report_venue_sheet.dart';
import '../widgets/venue_status_badge.dart';
import '../widgets/review_card.dart';
import '../widgets/venue_photo_gallery.dart';
import '../widgets/verify_button_visibility.dart';

class VenueDetailScreen extends ConsumerWidget {
  final String venueId;

  const VenueDetailScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueAsync = ref.watch(venueDetailProvider(venueId));
    final reviewsAsync = ref.watch(venueReviewsProvider(venueId));
    final favState = ref.watch(favoritesProvider);
    final authState = ref.watch(authProvider);
    final categoriesAsync = ref.watch(foodCategoriesProvider);

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
                backgroundColor: Colors.white,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    venue.name,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 4),
                      ],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      VenuePhotoGallery(photos: venue.photos),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.65),
                            ],
                            stops: const [0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  if (authState.isAuthenticated)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          icon: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? AppTheme.error : Colors.black,
                          ),
                          tooltip: isFav ? 'Favoriden Çıkar' : 'Favoriye Ekle',
                          onPressed: () => ref
                              .read(favoritesProvider.notifier)
                              .toggleFavorite(venue),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        icon: const Icon(Icons.directions, color: Colors.black),
                        tooltip: 'Yol Tarifi',
                        onPressed: () => MapLauncher.openDirections(
                          latitude: venue.latitude,
                          longitude: venue.longitude,
                          label: venue.name,
                          address: '${venue.address}, ${venue.city}',
                          googlePlaceId: venue.googlePlaceId,
                        ),
                      ),
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
                      Row(
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              VenueStatusBadge(status: venue.status),
                              if (venue.verifiedAt != null)
                                _VerifiedAtBadge(date: venue.verifiedAt!),
                            ],
                          ),
                          const Spacer(),
                          if (authState.isAuthenticated)
                            TextButton.icon(
                              onPressed: () => showReportVenueSheet(
                                context,
                                venueId: venueId,
                              ),
                              icon: const Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: Colors.amber,
                              ),
                              label: const Text(
                                'Bildir',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor:
                                    Colors.amber.withValues(alpha: 0.12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: Colors.amber.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                            ),
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
                      if (venue.foodHalalMode == 'all' ||
                          venue.foodHalalMode == 'except' ||
                          venue.foodItems.isNotEmpty) ...[
                        const Text(
                          'Caiz Yemekler',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (venue.foodHalalMode == 'all') ...[
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
                          ),
                          if (venue.foodItems.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _FoodCategoryDropdowns(
                              foodItems: venue.foodItems,
                              categoriesAsync: categoriesAsync,
                            ),
                          ],
                        ] else if (venue.foodHalalMode == 'except') ...[
                          // "Caiz olmayan malzemeler" başlığı
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.orange
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber,
                                    size: 16, color: Colors.orange),
                                SizedBox(width: 6),
                                Text(
                                  'Şunlar Hariç Her Şey Caiz',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (venue.excludedProducts.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: venue.excludedProducts
                                  .map(
                                    (product) => Chip(
                                      label: Text(
                                        product,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor:
                                          Colors.red.withValues(alpha: 0.08),
                                      side: BorderSide(
                                        color: Colors.red
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ] else if (venue.foodItems.isNotEmpty)
                          _FoodCategoryDropdowns(
                            foodItems: venue.foodItems,
                            categoriesAsync: categoriesAsync,
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

              // Rehber doğrulama butonu
              SliverToBoxAdapter(
                child: _VerifyVenueButton(
                  venueId: venue.id,
                  addedBy: venue.addedBy,
                  status: venue.status,
                  verificationDueAt: venue.verificationDueAt,
                ),
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

class _FoodCategoryDropdowns extends StatelessWidget {
  final List<FoodItem> foodItems;
  final AsyncValue<List<FoodCategory>> categoriesAsync;

  const _FoodCategoryDropdowns({
    required this.foodItems,
    required this.categoriesAsync,
  });

  @override
  Widget build(BuildContext context) {
    // Kategori id -> label eşlemesi
    final categoryLabels = categoriesAsync.maybeWhen(
      data: (cats) => {for (final c in cats) c.id: c.labelTr},
      orElse: () => <int, String>{},
    );

    // Yemekleri kategoriye göre grupla
    final grouped = <int, List<FoodItem>>{};
    for (final item in foodItems) {
      grouped.putIfAbsent(item.categoryId, () => []).add(item);
    }

    return Column(
      children: grouped.entries.map((entry) {
        final catLabel = categoryLabels[entry.key] ?? 'Kategori ${entry.key}';
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text(
              catLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            iconColor: AppTheme.textSecondary,
            collapsedIconColor: AppTheme.textSecondary,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: entry.value.map((item) {
                  return Chip(
                    label: Text(
                      item.labelTr,
                      style: const TextStyle(fontSize: 12),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                    side: BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
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

class _VerifyVenueButton extends ConsumerStatefulWidget {
  final String venueId;
  final String addedBy;
  final String status;
  final DateTime? verificationDueAt;

  const _VerifyVenueButton({
    required this.venueId,
    required this.addedBy,
    required this.status,
    this.verificationDueAt,
  });

  @override
  ConsumerState<_VerifyVenueButton> createState() => _VerifyVenueButtonState();
}

class _VerifyVenueButtonState extends ConsumerState<_VerifyVenueButton> {
  bool _isLoading = false;

  Future<void> _verify() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mekan Doğrulama'),
        content: const Text(
          'Bu mekanın hâlâ helal kriterlerini karşıladığını onaylıyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Doğrula'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.put(ApiEndpoints.venueVerify(widget.venueId), data: {});
      if (!mounted) return;
      ref.invalidate(venueDetailProvider(widget.venueId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mekan başarıyla doğrulandı'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doğrulama başarısız, tekrar deneyin')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authProvider).user?.id;
    if (!shouldShowVerifyButton(currentUserId, widget.addedBy, widget.status,
        verificationDueAt: widget.verificationDueAt)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _verify,
          icon: _isLoading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.verified_outlined),
          label: const Text('Helal Kriterlerini Doğrula'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}
