import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/venue.dart';
import '../../../core/utils/location_service.dart';

/// Sonuç sayfasının sorgusu: ya serbest metin (term) ya da şehir+ilçe çifti.
///
/// Family provider anahtarı olarak kullanıldığı için değer eşitliği ZORUNLU;
/// aksi halde her rebuild yeni provider örneği yaratır ve fetch döngüsü oluşur.
class SearchQuery {
  final String? term;
  final String? city;
  final String? district;

  const SearchQuery.text(String this.term)
      : city = null,
        district = null;

  const SearchQuery.cityDistrict({
    required String this.city,
    required String this.district,
  }) : term = null;

  /// Başlıkta gösterilecek etiket.
  String get label => term ?? '$city / $district';

  @override
  bool operator ==(Object other) =>
      other is SearchQuery &&
      other.term == term &&
      other.city == city &&
      other.district == district;

  @override
  int get hashCode => Object.hash(term, city, district);
}

/// Belirli bir arama sorgusu (serbest metin ya da şehir+ilçe) için sonuçları
/// çeker.
///
/// Konum best-effort alınır: izin yoksa veya hata olursa lat/lng gönderilmez,
/// backend sıralamayı puana düşürür. Konum hatası arama akışını bozmaz.
///
/// Not: Riverpod 3.2.1'de `FamilyAsyncNotifier` diye bir taban sınıf yok.
/// Family provider'lar `AsyncNotifierProvider.family<NotifierT, StateT, ArgT>`
/// builder'ı ile, notifier'ın kendisi `NotifierT Function(ArgT arg)` alan bir
/// factory üzerinden oluşturuluyor. Bu yüzden sorgu `arg` adında sihirli
/// bir alan yerine constructor parametresi olarak taşınıyor — tıpkı
/// `venue_list_filter_provider.dart`'taki `VenueListFilterNotifier(this.type)`
/// örneğinde olduğu gibi.
class SearchResultsNotifier extends AsyncNotifier<List<Venue>> {
  SearchResultsNotifier(this.query);

  /// Bu notifier'ın bağlı olduğu sorgu.
  final SearchQuery query;

  @override
  Future<List<Venue>> build() => _fetch(query);

  Future<List<Venue>> _fetch(SearchQuery query) async {
    final queryParameters = <String, dynamic>{};
    if (query.term != null) {
      queryParameters['q'] = query.term;
    } else {
      queryParameters['city'] = query.city;
      queryParameters['district'] = query.district;
    }

    try {
      final position =
          await ref.read(locationServiceProvider).getCurrentPosition();
      queryParameters['lat'] = position.latitude;
      queryParameters['lng'] = position.longitude;
    } catch (_) {
      // Konum alınamadı — mesafesiz aramaya devam edilir.
    }

    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get(
      ApiEndpoints.venues,
      queryParameters: queryParameters,
    );

    final data = response.data;
    final List<dynamic> venueList = data is Map<String, dynamic>
        ? (data['data'] as List? ?? [])
        : (data as List? ?? []);

    return venueList
        .map((json) => Venue.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Hata sonrası "Tekrar dene" için.
  Future<void> retry() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch(query));
  }
}

// `isAutoDispose: true` şart: aksi halde her arama sorgusu için notifier ve
// çektiği List<Venue> (fotoğraf + kategorilerle) uygulama oturumu boyunca
// canlı kalır. Sonuç: (1) aynı sorgu farklı bir konumdan veya yeni mekan
// onaylandıktan sonra tekrar arandığında build() yeniden çalışmaz, kullanıcı
// bayat sonuçları (eski konuma göre sıralanmış) görür — pull-to-refresh yok,
// uygulamayı yeniden başlatmadan kurtuluş yok; (2) her farklı sorgu için
// ayrı bir notifier+liste sızıntı gibi birikir (sınırsız bellek büyümesi).
// Riverpod 3.2.1'de family provider'larda isAutoDispose varsayılanı false'tur
// (bkz. AsyncNotifierProviderFamilyBuilder.call, lib/src/builder.dart) —
// bu yüzden burada açıkça true verilmesi gerekiyor. LÜTFEN KALDIRMAYIN.
final searchResultsProvider = AsyncNotifierProvider.family<
    SearchResultsNotifier, List<Venue>, SearchQuery>(
  SearchResultsNotifier.new,
  isAutoDispose: true,
);
