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
      'criteria': [
        {'id': 1, 'key': 'no_alcohol', 'name': 'Alkol yok'},
        {'id': 2, 'key': 'halal_meat', 'name': 'Helal et'},
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
    test('coğrafi ve helal alanları da yüklenir', () async {
      when(() => mockApi.get(ApiEndpoints.venueDetail('v1')))
          .thenAnswer((_) async => _ok(_venueJson()));

      await notifier().loadVenue('v1');

      expect(state().latitude, 41.0);
      expect(state().longitude, 29.0);
      expect(state().selectedFoodItemIds, [10, 11]);
    });

    test('hata durumunda error set edilir', () async {
      when(() => mockApi.get(ApiEndpoints.venueDetail('v1'))).thenThrow(_err());

      await notifier().loadVenue('v1');

      expect(state().error, isNotNull);
      expect(state().isLoadingVenue, isFalse);
    });
  });

  group('setCoordinates', () {
    // ⚠️ BUG (kaynak): setCoordinates place_id'yi geçersizleştirmek için
    // copyWith(googlePlaceId: null) çağırır (guide_provider.dart:656, yorumu da
    // "koordinat manuel değişince place_id geçersiz olur" der) — AMA
    // EditVenueState.copyWith'te `googlePlaceId ?? this.googlePlaceId` null'ı yok
    // sayar, ESKİ place_id korunur. Kullanıcı konumu elle taşırsa yanlış (eski)
    // google_place_id submit'e gider. Aynı hata AddVenueState.copyWith'te de var.
    // Bu test şu an MEVCUT (hatalı) davranışı sabitler; kaynak düzeltilince
    // beklenti `isNull`'a çevrilmeli.
    test('koordinat değişir; place_id ŞU AN korunur (BUG — düzeltilince null olmalı)',
        () async {
      when(() => mockApi.get(ApiEndpoints.venueDetail('v1')))
          .thenAnswer((_) async => _ok(_venueJson()));
      await notifier().loadVenue('v1');
      await notifier().parseMapsLink(
        'https://www.google.com/maps/place/Kafe/data=!1sChIJabc!8m2!3d41.0!4d29.0',
      );
      expect(state().googlePlaceId, 'ChIJabc');

      notifier().setCoordinates(latitude: 40.0, longitude: 28.0);

      // Koordinat doğru güncelleniyor.
      expect(state().latitude, 40.0);
      expect(state().longitude, 28.0);
      // BUG nedeniyle place_id null OLMUYOR — mevcut davranış sabitleniyor.
      expect(state().googlePlaceId, 'ChIJabc');
    });
  });

  group('parseMapsLink', () {
    test('boş link false döner, hata set etmez', () async {
      final ok = await notifier().parseMapsLink('   ');
      expect(ok, isFalse);
      expect(state().isParsingLink, isFalse);
      expect(state().error, isNull);
    });

    test('geçersiz link false + hata mesajı', () async {
      final ok = await notifier().parseMapsLink('https://example.com');
      expect(ok, isFalse);
      expect(state().error, isNotNull);
    });

    test('geçerli link koordinat + place_id çıkarır', () async {
      final ok = await notifier().parseMapsLink(
        'https://www.google.com/maps/place/Kafe/data=!1sChIJxyz!8m2!3d41.5!4d29.5',
      );
      expect(ok, isTrue);
      expect(state().latitude, 41.5);
      expect(state().longitude, 29.5);
      expect(state().googlePlaceId, 'ChIJxyz');
      expect(state().isParsingLink, isFalse);
    });
  });

  group('submit', () {
    test('boş sakıncalı ürünler gönderilmeden filtrelenir', () async {
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
