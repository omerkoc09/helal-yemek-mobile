import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';

import 'package:caiz_mi/core/api/api_client.dart';
import 'package:caiz_mi/core/api/api_endpoints.dart';
import 'package:caiz_mi/core/auth/auth_provider.dart';
import 'package:caiz_mi/core/utils/location_service.dart';
import 'package:caiz_mi/features/home/providers/home_provider.dart';

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

// Testte kullanılacak sabit konum.
Position _pos({double lat = 41.0, double lng = 29.0}) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 1, 1),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );

void main() {
  late MockApiClient mockApi;
  late MockLocationService mockLoc;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(RequestOptions(path: '')));

  setUp(() {
    mockApi = MockApiClient();
    mockLoc = MockLocationService();
    container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(mockApi),
      locationServiceProvider.overrideWithValue(mockLoc),
    ]);
  });
  tearDown(() => container.dispose());

  HomeNotifier notifier() => container.read(homeProvider.notifier);
  HomeState state() => container.read(homeProvider);

  group('fetchFeed', () {
    test('konum + şehir başarılı: nearby (şehir) + popular yüklenir', () async {
      when(() => mockLoc.getCurrentPosition()).thenAnswer((_) async => _pos());
      when(() => mockLoc.getCityFromCoordinates(any(), any()))
          .thenAnswer((_) async => 'İstanbul');
      // İlk get = şehir (nearby), ikinci get = popular.
      when(() => mockApi.get(ApiEndpoints.venues,
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'data': [_venue('v1', 'Yakın')]}));
      when(() => mockApi.get(ApiEndpoints.venuesPopular,
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'data': [_venue('v2', 'Popüler')]}));

      await notifier().fetchFeed();

      final s = state();
      expect(s.cityName, 'İstanbul');
      expect(s.nearbyVenues.single.name, 'Yakın');
      expect(s.popularVenues.single.name, 'Popüler');
      expect(s.locationDenied, isFalse);
      expect(s.isLoadingNearby, isFalse);
    });

    test('geocoding şehri çözemezse nearby sorgusu atlanır, sadece popular gelir',
        () async {
      when(() => mockLoc.getCurrentPosition()).thenAnswer((_) async => _pos());
      // Şehir null → nearby için /venues çağrısı YAPILMAMALI.
      when(() => mockLoc.getCityFromCoordinates(any(), any()))
          .thenAnswer((_) async => null);
      when(() => mockApi.get(ApiEndpoints.venuesPopular,
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'data': [_venue('v2', 'Popüler')]}));

      await notifier().fetchFeed();

      final s = state();
      expect(s.cityName, isNull);
      expect(s.nearbyVenues, isEmpty);
      expect(s.popularVenues.single.name, 'Popüler');
      // Şehir sorgusu (/venues) hiç yapılmamalı.
      verifyNever(() => mockApi.get(ApiEndpoints.venues,
          queryParameters: any(named: 'queryParameters')));
    });

    test('konum reddedilirse locationDenied true olur', () async {
      when(() => mockLoc.getCurrentPosition())
          .thenThrow(const LocationServiceException('Konum izni reddedildi.'));

      await notifier().fetchFeed();

      final s = state();
      expect(s.locationDenied, isTrue);
      expect(s.isLoadingNearby, isFalse);
      expect(s.isLoadingPopular, isFalse);
      expect(s.isLoadingCity, isFalse);
    });

    test('beklenmedik hata loading bayraklarını düşürür, denied set etmez', () async {
      when(() => mockLoc.getCurrentPosition()).thenAnswer((_) async => _pos());
      when(() => mockLoc.getCityFromCoordinates(any(), any()))
          .thenAnswer((_) async => 'İstanbul');
      when(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      await notifier().fetchFeed();

      final s = state();
      expect(s.isLoadingNearby, isFalse);
      expect(s.isLoadingPopular, isFalse);
      expect(s.locationDenied, isFalse); // sadece LocationServiceException denied yapar
    });
  });
}
