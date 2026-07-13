import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../venue/widgets/venue_card.dart';
import '../providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(favoritesProvider.notifier).fetchFavorites(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoritesProvider);

    return Scaffold(
      body: _buildBody(state),
    );
  }

  Widget _buildBody(FavoritesState state) {
    if (state.isLoading && state.venues.isEmpty) {
      return const LoadingIndicator();
    }

    if (state.error != null && state.venues.isEmpty) {
      return ErrorRetryWidget(
        message: state.error!,
        onRetry: () => ref.read(favoritesProvider.notifier).fetchFavorites(),
      );
    }

    if (state.venues.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text(
              'Henüz favori mekanınız yok.',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Beğendiğiniz mekanları favorilere ekleyin.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(favoritesProvider.notifier).fetchFavorites(),
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: 8,
          bottom: 8 + AppTheme.bottomNavClearance,
        ),
        itemCount: state.venues.length,
        itemBuilder: (context, index) => Dismissible(
          key: ValueKey(state.venues[index].id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: AppTheme.error,
            child: const Icon(Icons.favorite_border, color: Colors.white),
          ),
          onDismissed: (_) {
            ref
                .read(favoritesProvider.notifier)
                .toggleFavorite(state.venues[index]);
          },
          child: VenueCard(venue: state.venues[index]),
        ),
      ),
    );
  }
}
