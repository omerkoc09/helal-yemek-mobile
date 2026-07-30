import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:itimat/core/api/api_client.dart';
import 'package:itimat/core/auth/auth_provider.dart';
import 'package:itimat/core/utils/location_service.dart';
import 'package:itimat/features/search/providers/search_results_provider.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockLocationService extends Mock implements LocationService {}

Response<dynamic> _ok(dynamic data) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: ''),
    );

Map<String, dynamic> _venue(String id, String name) => {
      'id': id,
      'name': name,
      'city': 'İstanbul',
      'latitude': 41.0,
      'longitude': 29.0,
      'added_by': 'u1',
    };

void main() {
  late MockApiClient mockApi;
  late MockLocationService mockLoc;

  setUpAll(() => registerFallbackValue(RequestOptions(path: '')));

  setUp(() {
    mockApi = MockApiClient();
    mockLoc = MockLocationService();
    // Konum best-effort: testte sade tutmak için her zaman hata fırlatsın,
    // provider bunu yutup lat/lng olmadan aramaya devam etmeli.
    when(() => mockLoc.getCurrentPosition())
        .thenThrow(const LocationServiceException('Konum izni reddedildi.'));
    when(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => _ok({'data': [_venue('v1', 'Döner Ustası')]}));
  });

  test(
    'son dinleyici kaldırılıp container tekrar okunduğunda arama TEKRAR fetch edilir '
    '(auto-dispose olmazsa provider canlı kalır ve bayat sonucu döndürür)',
    () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(mockApi),
        locationServiceProvider.overrideWithValue(mockLoc),
      ]);
      addTearDown(container.dispose);

      const query = SearchQuery.text('döner');

      // İlk okuma: dinleyici ekle, build() tamamlanana kadar bekle.
      final sub1 = container.listen(
        searchResultsProvider(query),
        (_, _) {},
        fireImmediately: true,
      );
      await container.read(searchResultsProvider(query).future);
      sub1.close();

      // Sonuçlar ekranından çıkıldığında son dinleyici de kapanmış olur.
      // Auto-dispose devredeyse provider burada tamamen yok edilir.
      // Riverpod, dinleyicisiz auto-dispose provider'ları senkron değil,
      // bir sonraki mikrotask'ta temizler; bu yüzden bir tık bekliyoruz.
      await Future<void>.delayed(Duration.zero);

      // Aynı terimle tekrar arama: provider hâlâ canlıysa (auto-dispose
      // yoksa) build() bir daha çalışmaz ve API ikinci kez çağrılmaz.
      final sub2 = container.listen(
        searchResultsProvider(query),
        (_, _) {},
        fireImmediately: true,
      );
      await container.read(searchResultsProvider(query).future);
      sub2.close();

      verify(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')))
          .called(2);
    },
  );

  test('SearchQuery değer eşitliği uygular (family anahtarı olarak güvenli)', () {
    expect(
      const SearchQuery.text('döner'),
      const SearchQuery.text('döner'),
    );
    expect(
      const SearchQuery.cityDistrict(city: 'İstanbul', district: 'Fatih'),
      const SearchQuery.cityDistrict(city: 'İstanbul', district: 'Fatih'),
    );
    expect(
      const SearchQuery.text('döner'),
      isNot(const SearchQuery.text('kebap')),
    );
    expect(
      const SearchQuery.cityDistrict(city: 'İstanbul', district: 'Fatih'),
      isNot(const SearchQuery.cityDistrict(city: 'Trabzon', district: 'Fatih')),
    );
  });
}
