import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/venue.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/guide_provider.dart';

class MyVenuesScreen extends ConsumerStatefulWidget {
  const MyVenuesScreen({super.key});

  @override
  ConsumerState<MyVenuesScreen> createState() => _MyVenuesScreenState();
}

class _MyVenuesScreenState extends ConsumerState<MyVenuesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(myVenuesProvider.notifier).fetchMyVenues(),
      ref.read(myConfirmationsProvider.notifier).fetchMyConfirmations(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final added = ref.watch(myVenuesProvider);
    final confirmed = ref.watch(myConfirmationsProvider);

    return Scaffold(
      body: _buildBody(added, confirmed),
    );
  }

  Widget _buildBody(MyVenuesState added, MyVenuesState confirmed) {
    final isEmpty = added.venues.isEmpty && confirmed.venues.isEmpty;

    // İlk yükleme: her iki liste de boşken tek bir gösterge yeterli.
    if ((added.isLoading || confirmed.isLoading) && isEmpty) {
      return const LoadingIndicator();
    }

    // Hata yalnızca gösterilecek hiçbir şey yokken tam ekran olur; aksi halde
    // eldeki listeyi göstermeye devam ederiz.
    if (added.error != null && confirmed.error != null && isEmpty) {
      return ErrorRetryWidget(
        message: added.error!,
        onRetry: _refresh,
      );
    }

    if (isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: _buildOverallEmptyState(),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          _SectionHeader(
            title: 'Eklediğim Mekanlar',
            count: added.venues.length,
            topPadding: 16,
          ),
          if (added.venues.isEmpty)
            const _SectionEmpty(message: 'Henüz mekan eklemediniz.')
          else
            SliverList.builder(
              itemCount: added.venues.length,
              itemBuilder: (context, index) => _MyVenueCard(
                venue: added.venues[index],
                trailing: _EditButton(venue: added.venues[index]),
              ),
            ),
          _SectionHeader(
            title: 'Doğruladığım Mekanlar',
            count: confirmed.venues.length,
            topPadding: 24,
          ),
          if (confirmed.venues.isEmpty)
            const _SectionEmpty(
              message: 'Henüz bir mekan doğrulamadınız.',
            )
          else
            SliverList.builder(
              itemCount: confirmed.venues.length,
              itemBuilder: (context, index) {
                final venue = confirmed.venues[index];
                return _MyVenueCard(
                  venue: venue,
                  showStatusBadge: false,
                  subtitle: venue.confirmedAt != null
                      ? '${_formatDate(venue.confirmedAt!)} tarihinde doğruladınız'
                      : null,
                );
              },
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 8 + AppTheme.bottomNavClearance),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 64),
        Icon(
          Icons.store_outlined,
          size: 80,
          color: AppTheme.textSecondary.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 16),
        const Text(
          'Henüz mekan eklemediniz',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Güvenilir mekanları keşfeden diğer gezginlere yardımcı olmak için mekan ekleyin.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            onPressed: () => context.push('/add-venue'),
            icon: const Icon(Icons.add),
            label: const Text('Mekan Ekle'),
          ),
        ),
      ],
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final double topPadding;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topPadding, 16, 8),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  final String message;

  const _SectionEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Her iki bölümde de kullanılan ortak mekan kartı. Bölüme özgü aksiyon
/// [trailing] ile verilir (doğrulanan mekanlarda yoktur — geri çekme yalnızca
/// mekan detay ekranındadır); doğrulanan kartta statü rozeti yerine [subtitle]
/// (doğrulama tarihi) gösterilir.
class _MyVenueCard extends StatelessWidget {
  final Venue venue;
  final Widget? trailing;
  final bool showStatusBadge;
  final String? subtitle;

  const _MyVenueCard({
    required this.venue,
    this.trailing,
    this.showStatusBadge = true,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => context.push('/venue/${venue.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                  if (showStatusBadge) _StatusBadge(status: venue.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      venue.district != null && venue.district!.isNotEmpty
                          ? '${venue.district}, ${venue.city}'
                          : venue.city,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (venue.isRejected && venue.rejectionNote != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 18, color: AppTheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          venue.rejectionNote!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.error,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (subtitle != null)
                    Expanded(
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else ...[
                    if (venue.createdAt != null)
                      Text(
                        _formatDate(venue.createdAt!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    const Spacer(),
                  ],
                  ?trailing,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  final Venue venue;

  const _EditButton({required this.venue});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => context.push('/venue/${venue.id}/edit'),
      icon: const Icon(Icons.edit_outlined, size: 16),
      label: const Text('Düzenle'),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontSize: 13),
      ),
    );
  }
}


class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'approved' => ('Onaylandı', AppTheme.pinApproved, Icons.check_circle),
      'rejected' => ('Reddedildi', AppTheme.error, Icons.cancel),
      _ => ('Onay Bekliyor', AppTheme.pinPending, Icons.hourglass_empty),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
