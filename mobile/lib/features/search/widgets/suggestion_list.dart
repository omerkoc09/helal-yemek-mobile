import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/search_suggestion.dart';

/// Arama kutusunun altında gösterilen öneri listesi.
///
/// Hem arama sekmesi (SearchScreen) hem ana sayfadaki arama overlay'i tarafından
/// kullanılır; iki ekranın öneri görünümü ayrışmasın diye tek yerde tutulur.
class SuggestionList extends StatelessWidget {
  final List<SearchSuggestion> suggestions;
  final bool isLoading;
  final ValueChanged<SearchSuggestion> onSelect;

  /// Öneri yokken gösterilecek metin. Verilmezse varsayılan ipucu kullanılır.
  final String? emptyHint;

  const SuggestionList({
    super.key,
    required this.suggestions,
    required this.isLoading,
    required this.onSelect,
    this.emptyHint,
  });

  IconData _iconFor(SuggestionType type) => switch (type) {
        SuggestionType.category => Icons.restaurant_menu,
        SuggestionType.district => Icons.map_outlined,
        SuggestionType.city => Icons.place_outlined,
        SuggestionType.venue => Icons.storefront_outlined,
      };

  String _labelFor(SearchSuggestion suggestion) => switch (suggestion.type) {
        SuggestionType.category => 'Kategori',
        SuggestionType.district => 'İlçe',
        SuggestionType.city => 'Şehir',
        SuggestionType.venue => suggestion.subtitle == null
            ? 'Mekan'
            : 'Mekan · ${suggestion.subtitle}',
      };

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      if (isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyHint ?? 'Öneri bulunamadı. Aramak için Enter\'a basın.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return ListTile(
          leading: Icon(_iconFor(suggestion.type), color: AppTheme.textSecondary),
          title: Text(
            suggestion.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _labelFor(suggestion),
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () => onSelect(suggestion),
        );
      },
    );
  }
}
