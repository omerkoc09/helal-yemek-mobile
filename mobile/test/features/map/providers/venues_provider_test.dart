import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:itimat/core/api/api_client.dart';
import 'package:itimat/core/auth/auth_provider.dart';
import 'package:itimat/features/map/providers/venues_provider.dart';

class MockApiClient extends Mock implements ApiClient {}

Response<dynamic> _ok(dynamic data) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: ''),
    );

DioException _err() => DioException(requestOptions: RequestOptions(path: ''));

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
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(RequestOptions(path: '')));

  setUp(() {
    mockApi = MockApiClient();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(mockApi)],
    );
  });
  tearDown(() => container.dispose());

  VenuesNotifier notifier() => container.read(venuesProvider.notifier);
  VenuesState state() => container.read(venuesProvider);

  void stubOk(List<Map<String, dynamic>> venues) {
    when(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => _ok({'data': venues}));
  }

  group('fetchNearbyVenues — parse', () {
    test('başarılı yanıt venues state\'e yazılır', () async {
      stubOk([_venue('v1', 'Kafe A'), _venue('v2', 'Kafe B')]);

      await notifier().fetchNearbyVenues(latitude: 41.0, longitude: 29.0);

      expect(state().venues.length, 2);
      expect(state().venues.first.name, 'Kafe A');
      expect(state().isLoading, isFalse);
    });

    test('düz liste yanıtı ({data} olmadan) da parse edilir', () async {
      when(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok([_venue('v1', 'Tek Kafe')]));

      await notifier().fetchNearbyVenues(latitude: 41.0, longitude: 29.0);

      expect(state().venues.single.name, 'Tek Kafe');
    });

    test('API hatasında error set edilir', () async {
      when(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenThrow(_err());

      await notifier().fetchNearbyVenues(latitude: 41.0, longitude: 29.0);

      expect(state().error, isNotNull);
      expect(state().isLoading, isFalse);
    });
  });

  group('_shouldFetch — cache ve mesafe (fetchNearbyVenues üzerinden)', () {
    test('ilk çağrı her zaman fetch eder', () async {
      stubOk([_venue('v1', 'A')]);
      await notifier().fetchNearbyVenues(latitude: 41.0, longitude: 29.0);
      verify(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')))
          .called(1);
    });

    test('500m içinde ikinci çağrı fetch ETMEZ (cache)', () async {
      stubOk([_venue('v1', 'A')]);
      await notifier().fetchNearbyVenues(latitude: 41.0, longitude: 29.0);

      // ~10m kayma (0.0001° ≈ 11m) — eşik altında, yeni istek olmamalı.
      await notifier().fetchNearbyVenues(latitude: 41.0001, longitude: 29.0);

      verify(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')))
          .called(1); // toplam hâlâ 1
    });

    test('500m ötesinde ikinci çağrı yeniden fetch eder', () async {
      stubOk([_venue('v1', 'A')]);
      await notifier().fetchNearbyVenues(latitude: 41.0, longitude: 29.0);

      // ~0.01° ≈ 1.1km kuzey — eşik üstü, yeni istek olmalı.
      await notifier().fetchNearbyVenues(latitude: 41.01, longitude: 29.0);

      verify(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')))
          .called(2);
    });

    test('force: true aynı konumda bile yeniden fetch eder', () async {
      stubOk([_venue('v1', 'A')]);
      await notifier().fetchNearbyVenues(latitude: 41.0, longitude: 29.0);

      await notifier().fetchNearbyVenues(
        latitude: 41.0,
        longitude: 29.0,
        force: true,
      );

      verify(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')))
          .called(2);
    });
  });

  group('fetchCityVenues', () {
    test('şehir mekanlarını yükler', () async {
      stubOk([_venue('v1', 'Şehir Kafe')]);

      await notifier().fetchCityVenues('İstanbul');

      expect(state().venues.single.name, 'Şehir Kafe');
      expect(state().isLoading, isFalse);
    });

    test('hata durumunda error set edilir', () async {
      when(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenThrow(_err());

      await notifier().fetchCityVenues('İstanbul');

      expect(state().error, isNotNull);
      expect(state().isLoading, isFalse);
    });
  });
}
