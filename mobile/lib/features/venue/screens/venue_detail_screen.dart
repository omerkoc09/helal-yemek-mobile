import 'package:dio/dio.dart';
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
import '../providers/direction_tracking_provider.dart';
import '../providers/venue_detail_provider.dart';
import '../widgets/add_review_sheet.dart';
import '../widgets/report_venue_sheet.dart';
import '../widgets/venue_status_badge.dart';
import '../widgets/review_card.dart';
import '../widgets/venue_photo_gallery.dart';
import '../widgets/venue_badge_chip.dart';
import '../widgets/trust_criteria_badge.dart';
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
                          icon: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.black,
                          ),
                          tooltip: 'Bildir',
                          onPressed: () => showReportVenueSheet(
                            context,
                            venueId: venueId,
                          ),
                        ),
                      ),
                    ),
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
                        onPressed: () {
                          trackDirectionClick(ref, venue.id);
                          MapLauncher.openDirections(
                            latitude: venue.latitude,
                            longitude: venue.longitude,
                            label: venue.name,
                            googlePlaceId: venue.googlePlaceId,
                          );
                        },
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          VenueStatusBadge(status: venue.status),
                          if (venue.verifiedAt != null)
                            _VerifiedAtBadge(date: venue.verifiedAt!),
                        ],
                      ),
                      const SizedBox(height: 8),
                      VenueBadgeChip(badge: venue.badge, compact: false),
                      const SizedBox(height: 4),
                      Text(
                        _trustSentence(venue.confirmationCount),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Puan
                      if (venue.avgRating != null)
                        Row(
                          children: [
                            StarRatingWidget(
                                rating: venue.avgRating!, size: 22),
                            const SizedBox(width: 6),
                            Text(
                              '(${venue.reviewCount} yorum)',
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      if (venue.avgRating != null) const SizedBox(height: 16),

                      // Adres
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        text: venue.district != null && venue.district!.isNotEmpty
                            ? '${venue.district}, ${venue.city}'
                            : venue.city,
                      ),
                      const SizedBox(height: 16),

                      // Güven kriterleri — API'den gelen rozetler.
                      if (venue.trustCriteria.isNotEmpty) ...[
                        const Text(
                          'Güven Kriterleri',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TrustCriteriaBadges(criteria: venue.trustCriteria),
                        const SizedBox(height: 16),
                      ],

                      // Mutfaklar
                      if (venue.categories.isNotEmpty ||
                          venue.foodHalalMode == 'except') ...[
                        const Text(
                          'Mutfaklar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // "Hariç tutulanlar" — yalnızca except modunda ve
                        // ürün listesi doluyken düz bir alt-başlık altında.
                        if (venue.foodHalalMode == 'except' &&
                            venue.excludedProducts.isNotEmpty) ...[
                          const _CuisineSubheading(
                            'Sakıncalı Ürünler',
                          ),
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
                                      color:
                                          Colors.red.withValues(alpha: 0.2),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // "Tavsiye edilenler" — kategori chip'leri (yeşil).
                        if (venue.categories.isNotEmpty) ...[
                          const _CuisineSubheading('Tavsiye edilenler'),
                          const SizedBox(height: 8),
                          _VenueCuisines(categories: venue.categories),
                        ],
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

              // Rehber onay (confirm) bölümü
              SliverToBoxAdapter(
                child: _ConfirmVenueButton(
                  venueId: venue.id,
                  addedBy: venue.addedBy,
                  status: venue.status,
                  confirmedByMe: venue.confirmedByMe ?? false,
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

  /// Rozetin altında gösterilen güven cümlesi. Doğrulayan sayısına göre değişir;
  /// tazelik burada tekrarlanmaz (mevcut "Son doğrulama" rozeti onu gösterir).
  String _trustSentence(int confirmationCount) {
    if (confirmationCount <= 0) {
      return 'Bu mekan topluluğa açık, henüz doğrulanmadı.';
    }
    return '$confirmationCount yerel rehber güvenilir buldu.';
  }
}

class _VenueCuisines extends StatelessWidget {
  final List<FoodCategory> categories;

  const _VenueCuisines({required this.categories});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: categories.map((category) {
        return Chip(
          label: Text(
            category.name,
            style: const TextStyle(fontSize: 12),
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          backgroundColor: AppTheme.pinApproved.withValues(alpha: 0.08),
          side: BorderSide(
            color: AppTheme.pinApproved.withValues(alpha: 0.2),
          ),
        );
      }).toList(),
    );
  }
}

/// Mutfaklar bölümündeki düz alt-başlık (ör. "Tavsiye edilenler").
class _CuisineSubheading extends StatelessWidget {
  final String text;

  const _CuisineSubheading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
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
          'Bu mekanın hâlâ güven kriterlerini karşıladığını onaylıyor musunuz?'),
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
          label: const Text('Güven Kriterlerini Doğrula'),
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

class _ConfirmVenueButton extends ConsumerStatefulWidget {
  final String venueId;
  final String addedBy;
  final String status;
  final bool confirmedByMe;

  const _ConfirmVenueButton({
    required this.venueId,
    required this.addedBy,
    required this.status,
    required this.confirmedByMe,
  });

  @override
  ConsumerState<_ConfirmVenueButton> createState() =>
      _ConfirmVenueButtonState();
}

class _ConfirmVenueButtonState extends ConsumerState<_ConfirmVenueButton> {
  bool _isLoading = false;
  // Başarılı doğrulama sonrası, detay yeniden yüklenmeden önce butonu anında gizle.
  bool _justConfirmed = false;

  Future<void> _confirmVenue() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(ApiEndpoints.venueConfirm(widget.venueId));
      if (!mounted) return;
      setState(() => _justConfirmed = true);
      ref.invalidate(venueDetailProvider(widget.venueId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Doğrulamanız kaydedildi, teşekkürler!'),
          backgroundColor: Colors.green,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? (e.response!.data['error']?.toString() ?? 'Doğrulama başarısız')
          : 'Doğrulama başarısız';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentUserId = authState.user?.id;
    if (currentUserId == null ||
        authState.isTraveler ||
        currentUserId == widget.addedBy ||
        widget.status != 'approved' ||
        widget.confirmedByMe ||
        _justConfirmed) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Doğrulamadan önce mekanın bilgilerinin (konum, ad, güven kriterleri) '
            'doğru olduğundan emin olun. Bir hata varsa düzeltme öner veya rapor et.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _confirmVenue,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.how_to_reg),
              label: const Text('Doğruluyorum'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
