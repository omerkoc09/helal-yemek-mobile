import '../../../core/models/venue.dart';
import '../../guide/data/turkish_cities.dart';

/// Öneri satırının tipi — ikon, alt başlık ve tıklama davranışını belirler.
enum SuggestionType { category, city, venue }

/// Arama kutusunun altında gösterilen tek bir öneri satırı.
class SearchSuggestion {
  final SuggestionType type;
  final String label;

  /// Yalnızca [SuggestionType.venue] için dolu; tıklanınca detaya gidilir.
  final String? venueId;

  /// Satırın altında gösterilecek ek bilgi (mekan önerilerinde şehir).
  final String? subtitle;

  const SearchSuggestion({
    required this.type,
    required this.label,
    this.venueId,
    this.subtitle,
  });

  @override
  bool operator ==(Object other) =>
      other is SearchSuggestion &&
      other.type == type &&
      other.label == label &&
      other.venueId == venueId &&
      other.subtitle == subtitle;

  @override
  int get hashCode => Object.hash(type, label, venueId, subtitle);
}

const int _maxCategorySuggestions = 3;
const int _maxCitySuggestions = 3;
const int _maxVenueSuggestions = 5;

/// Sorguya göre öneri listesini üretir: önce kategoriler, sonra şehirler,
/// sonra mekanlar. Eşleşme Türkçe karakter duyarsızdır ([normalizeTr]).
///
/// [categories] ve [cities] istemcide cache'lenen tam listelerdir; [venues]
/// ise arama isteğinden dönen mekan adaylarıdır. Mekanlar da isim üzerinden
/// Türkçe duyarsız olarak yeniden filtrelenir ki eşleşmeyen bir mekan listede
/// kalmasın; yalnızca sayı sınırı için değil, eşleşme için de kontrol edilir.
List<SearchSuggestion> buildSuggestions({
  required String query,
  required List<FoodCategory> categories,
  required List<String> cities,
  required List<Venue> venues,
}) {
  final normalized = normalizeTr(query);
  if (normalized.isEmpty) return [];

  final suggestions = <SearchSuggestion>[];

  for (final category in categories) {
    if (suggestions.length >= _maxCategorySuggestions) break;
    if (normalizeTr(category.name).contains(normalized)) {
      suggestions.add(SearchSuggestion(
        type: SuggestionType.category,
        label: category.name,
      ));
    }
  }

  var cityCount = 0;
  for (final city in cities) {
    if (cityCount >= _maxCitySuggestions) break;
    if (normalizeTr(city).contains(normalized)) {
      suggestions.add(SearchSuggestion(
        type: SuggestionType.city,
        label: city,
      ));
      cityCount++;
    }
  }

  var venueCount = 0;
  for (final venue in venues) {
    if (venueCount >= _maxVenueSuggestions) break;
    if (normalizeTr(venue.name).contains(normalized)) {
      suggestions.add(SearchSuggestion(
        type: SuggestionType.venue,
        label: venue.name,
        venueId: venue.id,
        subtitle: venue.city,
      ));
      venueCount++;
    }
  }

  return suggestions;
}
