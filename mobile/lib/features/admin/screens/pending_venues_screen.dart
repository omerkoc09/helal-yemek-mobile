import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/admin_provider.dart';

class PendingVenuesScreen extends ConsumerStatefulWidget {
  const PendingVenuesScreen({super.key});

  @override
  ConsumerState<PendingVenuesScreen> createState() =>
      _PendingVenuesScreenState();
}

class _PendingVenuesScreenState extends ConsumerState<PendingVenuesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pendingVenuesProvider.notifier).fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pendingVenuesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bekleyen Mekanlar'),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(PendingVenuesState state) {
    if (state.isLoading && state.venues.isEmpty) {
      return const LoadingIndicator();
    }

    if (state.error != null && state.venues.isEmpty) {
      return ErrorRetryWidget(
        message: state.error!,
        onRetry: () => ref.read(pendingVenuesProvider.notifier).fetch(),
      );
    }

    if (state.venues.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: AppTheme.primary),
            SizedBox(height: 16),
            Text(
              'Bekleyen mekan yok',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Tüm mekanlar incelendi.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(pendingVenuesProvider.notifier).fetch(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.venues.length,
        itemBuilder: (context, index) {
          final venue = state.venues[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: InkWell(
              onTap: () => context.push('/admin/venue/${venue.id}'),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 16, color: AppTheme.textSecondary),
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
                    if (venue.criteria.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: venue.criteria.map((c) {
                          return Chip(
                            label: Text(c.labelTr,
                                style: const TextStyle(fontSize: 11)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (venue.createdAt != null)
                      Text(
                        'Eklenme: ${_formatDate(venue.createdAt!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
