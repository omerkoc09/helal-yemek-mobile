import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/map_launcher.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../venue/providers/venue_detail_provider.dart';
import '../../venue/widgets/halal_criteria_chip.dart';
import '../../venue/widgets/venue_photo_gallery.dart';
import '../widgets/venue_review_actions.dart';

class VenueReviewScreen extends ConsumerWidget {
  final String venueId;

  const VenueReviewScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueAsync = ref.watch(venueDetailProvider(venueId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mekan İnceleme'),
      ),
      body: venueAsync.when(
        loading: () => const LoadingIndicator(),
        error: (_, _) => ErrorRetryWidget(
          message: 'Mekan detayı yüklenemedi.',
          onRetry: () => ref.invalidate(venueDetailProvider(venueId)),
        ),
        data: (venue) {
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fotoğraflar
                      if (venue.photos.isNotEmpty)
                        SizedBox(
                          height: 220,
                          child: VenuePhotoGallery(photos: venue.photos),
                        ),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ad
                            Text(
                              venue.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Adres
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 20, color: AppTheme.textSecondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    venue.district != null && venue.district!.isNotEmpty
                                        ? '${venue.district}\n${venue.city}'
                                        : venue.city,
                                    style: const TextStyle(
                                        fontSize: 14, height: 1.4),
                                  ),
                                ),
                              ],
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
                              if (venue.foodHalalMode == 'all')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.1),
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
                              else if (venue.foodHalalMode == 'except') ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange
                                        .withValues(alpha: 0.1),
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
                                        'Caiz olmayan malzemeler',
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
                                              style: const TextStyle(
                                                  fontSize: 12),
                                            ),
                                            avatar: Icon(Icons.close,
                                                size: 14,
                                                color:
                                                    Colors.red.shade400),
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            visualDensity:
                                                VisualDensity.compact,
                                            backgroundColor: Colors.red
                                                .withValues(alpha: 0.08),
                                            side: BorderSide(
                                              color: Colors.red
                                                  .withValues(alpha: 0.2),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ] else
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: venue.foodItems
                                      .map(
                                        (item) => Chip(
                                          label: Text(
                                            item.labelTr,
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize
                                                  .shrinkWrap,
                                          visualDensity:
                                              VisualDensity.compact,
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

                            // Ekleyen / Eklenme tarihi
                            const Divider(height: 32),
                            _InfoRow(
                              icon: Icons.person_outline,
                              label: 'Ekleyen',
                              value: venue.addedByName ?? venue.addedBy,
                            ),
                            const SizedBox(height: 8),
                            if (venue.createdAt != null)
                              _InfoRow(
                                icon: Icons.calendar_today_outlined,
                                label: 'Eklenme tarihi',
                                value: _formatDate(venue.createdAt!),
                              ),
                            const Divider(height: 32),

                            // Notlar
                            if (venue.notes != null &&
                                venue.notes!.isNotEmpty) ...[
                              const Text(
                                'Guide Notu',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.background,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  venue.notes!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Konum bilgisi - Google Maps'e yönlendiren link
                            InkWell(
                              onTap: () async {
                                await MapLauncher.openLocation(
                                  latitude: venue.latitude,
                                  longitude: venue.longitude,
                                  googlePlaceId: venue.googlePlaceId,
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.textSecondary
                                      .withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        size: 18, color: AppTheme.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${venue.latitude.toStringAsFixed(5)}, ${venue.longitude.toStringAsFixed(5)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.primary,
                                          fontFamily: 'monospace',
                                          decoration:
                                              TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.open_in_new,
                                        size: 16, color: AppTheme.primary),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Durum bazlı butonlar
              VenueReviewActions(venueId: venueId, venue: venue),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

String _formatDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  '
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

