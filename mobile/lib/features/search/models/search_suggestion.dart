import '../../../core/models/venue.dart';
import '../../guide/data/turkish_cities.dart';

/// Şehir/ilçe çifti — arama önerilerinde "İstanbul / Fatih" olarak gösterilir.
class CityDistrict {
  final String city;
  final String district;

  const CityDistrict({required this.city, required this.district});

  /// Öneri satırında gösterilen etiket.
  String get label => '$city / $district';

  factory CityDistrict.fromJson(Map<String, dynamic> json) => CityDistrict(
        city: json['city'] as String? ?? '',
        district: json['district'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is CityDistrict && other.city == city && other.district == district;

  @override
  int get hashCode => Object.hash(city, district);
}

/// Öneri satırının tipi — ikon, alt başlık ve tıklama davranışını belirler.
enum SuggestionType { category, district, city, venue }

/// Arama kutusunun altında gösterilen tek bir öneri satırı.
class SearchSuggestion {
  final SuggestionType type;
  final String label;

  /// Yalnızca [SuggestionType.venue] için dolu; tıklanınca detaya gidilir.
  final String? venueId;

  /// Satırın altında gösterilecek ek bilgi (mekan önerilerinde şehir).
  final String? subtitle;

  /// Yalnızca [SuggestionType.district] için dolu; sonuç sayfası şehir+ilçe
  /// kesin filtresi uygulayabilsin diye taşınır.
  final String? city;
  final String? district;

  const SearchSuggestion({
    required this.type,
    required this.label,
    this.venueId,
    this.subtitle,
    this.city,
    this.district,
  });

  @override
  bool operator ==(Object other) =>
      other is SearchSuggestion &&
      other.type == type &&
      other.label == label &&
      other.venueId == venueId &&
      other.subtitle == subtitle &&
      other.city == city &&
      other.district == district;

  @override
  int get hashCode =>
      Object.hash(type, label, venueId, subtitle, city, district);
}

const int _maxCategorySuggestions = 3;
const int _maxDistrictSuggestions = 3;
const int _maxCitySuggestions = 3;
const int _maxVenueSuggestions = 5;

/// Sorguya göre öneri listesini üretir: önce kategoriler, sonra ilçeler,
/// sonra şehirler, sonra mekanlar. Eşleşme Türkçe karakter duyarsızdır
/// ([normalizeTr]).
///
/// [categories], [districts] ve [cities] istemcide cache'lenen tam
/// listelerdir — ilçe önerileri de bu listeler üzerinden istemcide lokal
/// eşlenir; [venues] ise arama isteğinden dönen mekanlardır (zaten sunucuda
/// isim/şehir/ilçe/kategori adına göre eşleşmiş olduğu için burada yeniden
/// filtrelenmez, yalnızca sayısı sınırlanır).
List<SearchSuggestion> buildSuggestions({
  required String query,
  required List<FoodCategory> categories,
  required List<String> cities,
  required List<CityDistrict> districts,
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

  var districtCount = 0;
  for (final cd in districts) {
    if (districtCount >= _maxDistrictSuggestions) break;
    // Hem ilçe adı hem "Şehir / İlçe" birlikte aranır: "fatih" de,
    // "istanbul fatih" de eşleşsin.
    if (normalizeTr(cd.district).contains(normalized) ||
        normalizeTr(cd.label).contains(normalized)) {
      suggestions.add(SearchSuggestion(
        type: SuggestionType.district,
        label: cd.label,
        city: cd.city,
        district: cd.district,
      ));
      districtCount++;
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

  for (final venue in venues.take(_maxVenueSuggestions)) {
    suggestions.add(SearchSuggestion(
      type: SuggestionType.venue,
      label: venue.name,
      venueId: venue.id,
      subtitle: venue.city,
    ));
  }

  return suggestions;
}
