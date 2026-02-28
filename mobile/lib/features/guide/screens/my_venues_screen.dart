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
      ref.read(myVenuesProvider.notifier).fetchMyVenues();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myVenuesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Mekanlarım'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Mekan Ekle',
            onPressed: () => context.push('/add-venue'),
          ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(MyVenuesState state) {
    if (state.isLoading && state.venues.isEmpty) {
      return const LoadingIndicator();
    }

    if (state.error != null && state.venues.isEmpty) {
      return ErrorRetryWidget(
        message: state.error!,
        onRetry: () => ref.read(myVenuesProvider.notifier).fetchMyVenues(),
      );
    }

    if (state.venues.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(myVenuesProvider.notifier).fetchMyVenues(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.venues.length,
        itemBuilder: (context, index) {
          return _MyVenueCard(venue: state.venues[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.store_outlined,
              size: 80,
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Henüz mekan eklemediniz',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Helal mekanları keşfeden diğer gezginlere yardımcı olmak için mekan ekleyin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/add-venue'),
              icon: const Icon(Icons.add),
              label: const Text('Mekan Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyVenueCard extends StatelessWidget {
  final Venue venue;

  const _MyVenueCard({required this.venue});

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
                  _StatusBadge(status: venue.status),
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
                      '${venue.address}, ${venue.city}',
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
                  if (venue.createdAt != null)
                    Text(
                      _formatDate(venue.createdAt!),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () =>
                        context.push('/venue/${venue.id}/edit'),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Düzenle'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'approved' => ('Onaylandı', AppTheme.primary, Icons.check_circle),
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
