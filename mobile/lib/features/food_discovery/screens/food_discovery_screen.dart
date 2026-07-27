import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../venue/widgets/venue_card.dart';
import '../providers/food_discovery_provider.dart';

/// Bir mutfak kategorisindeki mekanları listeler. Ekrana her zaman kategori
/// seçilmiş olarak girilir (ana sayfadaki grid ve slider önce
/// [FoodDiscoveryNotifier.selectCategory] çağırır), bu yüzden ekranın kendi
/// kategori ızgarası yoktur: geri gidince ana sayfaya dönülür.
class FoodDiscoveryScreen extends ConsumerWidget {
  const FoodDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(foodDiscoveryProvider);

    // Sistem geri hareketi (Android tuşu / iOS kaydırma) da ana sayfaya
    // gitmeli: ekrana context.go ile gelindiği için pop edilecek bir sayfa yok.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToHome(context, ref);
      },
      child: Scaffold(
        body: Column(
          children: [
            _CategoryHeader(
              label: state.selectedCategoryLabel ?? '',
              onBack: () => _backToHome(context, ref),
            ),
            Expanded(child: _buildVenueListBody(state)),
          ],
        ),
      ),
    );
  }

  /// Seçimi temizleyip ana sayfaya döner. Temizlik önemli: aksi halde ekrana
  /// tekrar girildiğinde bir önceki kategorinin sonuçları anlık görünürdü.
  void _backToHome(BuildContext context, WidgetRef ref) {
    ref.read(foodDiscoveryProvider.notifier).clearSelection();
    context.go(AppRoutes.home);
  }

  Widget _buildVenueListBody(FoodDiscoveryState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    if (state.venues.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Bu kategoride mekan bulunamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        top: 8,
        bottom: 8 + AppTheme.bottomNavClearance,
      ),
      itemCount: state.venues.length,
      itemBuilder: (context, index) =>
          VenueCard(venue: state.venues[index]),
    );
  }

}

class _CategoryHeader extends StatelessWidget {
  final String label;
  final VoidCallback onBack;

  const _CategoryHeader({required this.label, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            color: AppTheme.textPrimary,
            onPressed: onBack,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
