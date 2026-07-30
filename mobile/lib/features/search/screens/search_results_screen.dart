import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../venue/widgets/venue_card.dart';
import '../providers/search_results_provider.dart';

/// "Terim için sonuçlar" sayfası — kategori, şehir, ilçe veya ad eşleşen
/// mekanların tek birleşik listesi.
class SearchResultsScreen extends ConsumerWidget {
  final String term;

  const SearchResultsScreen({super.key, required this.term});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchResultsProvider(term));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$term" için sonuçlar',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            resultsAsync.maybeWhen(
              data: (venues) => Text(
                '${venues.length} mekan bulundu',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      body: resultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _ErrorView(
          onRetry: () => ref.read(searchResultsProvider(term).notifier).retry(),
        ),
        data: (venues) {
          if (venues.isEmpty) return _EmptyView(term: term);
          return ListView.builder(
            padding: const EdgeInsets.only(
              top: 8,
              bottom: 8 + AppTheme.bottomNavClearance,
            ),
            itemCount: venues.length,
            itemBuilder: (context, index) => VenueCard(venue: venues[index]),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Arama başarısız oldu.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String term;

  const _EmptyView({required this.term});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '"$term" için sonuç bulunamadı',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Farklı bir kelime veya şehir deneyin',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
