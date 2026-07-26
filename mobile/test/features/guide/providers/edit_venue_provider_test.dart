import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:caiz_mi/core/api/api_client.dart';
import 'package:caiz_mi/core/api/api_endpoints.dart';
import 'package:caiz_mi/core/auth/auth_provider.dart';
import 'package:caiz_mi/features/guide/providers/guide_provider.dart';

class MockApiClient extends Mock implements ApiClient {}

Response<dynamic> _ok(dynamic data) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: ''),
    );

DioException _err() => DioException(requestOptions: RequestOptions(path: ''));

// Mevcut mekanı düzenleme akışının (EditVenueNotifier) tam JSON gövdesi.
Map<String, dynamic> _venueJson() => {
      'id': 'v1',
      'name': 'Eski Kafe',
      'city': 'İstanbul',
      'latitude': 41.0,
      'longitude': 29.0,
      'added_by': 'u1',
      'notes': 'eski not',
      'food_halal_mode': 'except',
      'excluded_products': ['Jelatin'],
      'trust_criteria': [
        {'id': 1, 'key': 'no_alcohol', 'name': 'Alkol yok'},
        {'id': 2, 'key': 'trust_meat', 'name': 'Güvenilir et'},
      ],
      'food_items': [
        {'id': 10, 'category_id': 1, 'key': 'doner', 'name': 'Döner'},
        {'id': 11, 'category_id': 1, 'key': 'kebap', 'name': 'Kebap'},
      ],
    };

void main() {
  late MockApiClient mockApi;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(RequestOptions(path: '')));

  setUp(() {
    mockApi = MockApiClient();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(mockApi)],
    );
  });
  tearDown(() => container.dispose());

  EditVenueNotifier notifier() => container.read(editVenueProvider.notifier);
  EditVenueState state() => container.read(editVenueProvider);

  group('loadVenue', () {
    test('mevcut mekanı yükler ve kriter/yemek ID\'lerini map\'ler', () async {
      when(() => mockApi.get(ApiEndpoints.venueDetail('v1')))
          .thenAnswer((_) async => _ok(_venueJson()));

      await notifier().loadVenue('v1');

      final s = state();
      expect(s.isLoadingVenue, isFalse);
      expect(s.name, 'Eski Kafe');
      expect(s.city, 'İstanbul');
      expect(s.notes, 'eski not');
      // Kriter ve yemek ID'leri düz liste olarak map'lenmeli.
      expect(s.selectedCriteriaIds, [1, 2]);
      expect(s.selectedFoodItemIds, [10, 11]);
      expect(s.foodHalalMode, 'except');
      expect(s.excludedProducts, ['Jelatin']);
    });

    // Not: Backend venue detail'i düz obje olarak döner (venue_query_handler.go:141
    // `c.JSON(venue)`), liste uçları gibi {data:...} sarmalı DEĞİL. loadVenue'daki
    // {data:...} açma dalı bu uç için ölü kod; düz obje yolu test edilir.
    // Konum düzenlemesi EditVenue'dan kaldırıldı (konum = mekan kimliği), bu
    // yüzden latitude/longitude yüklenmez; yalnız düzenlenebilir alanlar yüklenir.
    test('düzenlenebilir alanlar yüklenir', () async {
      when(() => mockApi.get(ApiEndpoints.venueDetail('v1')))
          .thenAnswer((_) async => _ok(_venueJson()));

      await notifier().loadVenue('v1');

      expect(state().foodHalalMode, 'except');
      expect(state().selectedFoodItemIds, [10, 11]);
    });

    test('hata durumunda error set edilir', () async {
      when(() => mockApi.get(ApiEndpoints.venueDetail('v1'))).thenThrow(_err());

      await notifier().loadVenue('v1');

      expect(state().error, isNotNull);
      expect(state().isLoadingVenue, isFalse);
    });
  });

  group('submit', () {
    test('boş sakıncalı ürünler filtrelenir, konum GÖNDERİLMEZ', () async {
      when(() => mockApi.get(ApiEndpoints.venueDetail('v1')))
          .thenAnswer((_) async => _ok(_venueJson()));
      await notifier().loadVenue('v1');

      // ['Jelatin'] üzerine boş bir tane daha ekle.
      notifier().addExcludedProduct('   ');

      Map<String, dynamic>? sentData;
      when(() => mockApi.put(any(), data: any(named: 'data')))
          .thenAnswer((invocation) async {
        sentData = invocation.namedArguments[const Symbol('data')]
            as Map<String, dynamic>;
        return _ok({});
      });

      await notifier().submit();

      expect(state().isSuccess, isTrue);
      // Boş ürün filtrelenmeli, sadece 'Jelatin' gitmeli.
      expect(sentData!['excluded_products'], ['Jelatin']);
      // Konum düzenlemesi kaldırıldığından PUT gövdesinde konum alanları OLMAMALI;
      // backend gönderilmeyen konumu korur (venue update handler'ı *float64 kabul eder).
      expect(sentData!.containsKey('latitude'), isFalse);
      expect(sentData!.containsKey('longitude'), isFalse);
      expect(sentData!.containsKey('google_place_id'), isFalse);
    });

    test('hata durumunda isSuccess false + error set', () async {
      when(() => mockApi.get(ApiEndpoints.venueDetail('v1')))
          .thenAnswer((_) async => _ok(_venueJson()));
      await notifier().loadVenue('v1');
      when(() => mockApi.put(any(), data: any(named: 'data'))).thenThrow(_err());

      await notifier().submit();

      expect(state().isSuccess, isFalse);
      expect(state().error, isNotNull);
    });
  });

  group('seçim ve halalMode', () {
    test('toggleCriteria ekler/çıkarır', () {
      notifier().toggleCriteria(7);
      expect(state().selectedCriteriaIds, contains(7));
      notifier().toggleCriteria(7);
      expect(state().selectedCriteriaIds, isNot(contains(7)));
    });

    test('toggleFoodItem ekler/çıkarır', () {
      notifier().toggleFoodItem(10);
      notifier().toggleFoodItem(11);
      expect(state().selectedFoodItemIds, [10, 11]);
      notifier().toggleFoodItem(10);
      expect(state().selectedFoodItemIds, [11]);
    });

    test('setFoodHalalMode except dışına çıkınca excluded temizlenir', () {
      notifier().setFoodHalalMode('except');
      expect(state().excludedProducts, ['']);
      notifier().updateExcludedProduct(0, 'Alkol');
      notifier().setFoodHalalMode('all');
      expect(state().excludedProducts, isEmpty);
    });
  });

  group('MyVenuesNotifier.fetchMyVenues', () {
    test('mekan listesini yükler', () async {
      when(() => mockApi.get(ApiEndpoints.guideMyVenues)).thenAnswer((_) async =>
          _ok({
            'data': [_venueJson()]
          }));

      await container.read(myVenuesProvider.notifier).fetchMyVenues();

      final s = container.read(myVenuesProvider);
      expect(s.venues.length, 1);
      expect(s.venues.first.name, 'Eski Kafe');
      expect(s.isLoading, isFalse);
    });

    test('hata durumunda error set edilir', () async {
      when(() => mockApi.get(ApiEndpoints.guideMyVenues)).thenThrow(_err());

      await container.read(myVenuesProvider.notifier).fetchMyVenues();

      expect(container.read(myVenuesProvider).error, isNotNull);
    });
  });
}
