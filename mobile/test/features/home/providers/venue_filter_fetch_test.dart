import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';

import 'package:caiz_mi/core/api/api_client.dart';
import 'package:caiz_mi/core/auth/auth_provider.dart';
import 'package:caiz_mi/core/utils/location_service.dart';
import 'package:caiz_mi/features/home/providers/venue_filter_provider.dart';

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

Position _pos() => Position(
      latitude: 41.0,
      longitude: 29.0,
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

  VenueFilterNotifier notifier() => container.read(venueFilterProvider.notifier);
  VenueFilterState state() => container.read(venueFilterProvider);

  group('fetchAllCityVenues', () {
    test('konumdan çözülen şehirle mekanlar yüklenir', () async {
      when(() => mockLoc.getCurrentPosition()).thenAnswer((_) async => _pos());
      when(() => mockLoc.getCityFromCoordinates(any(), any()))
          .thenAnswer((_) async => 'İstanbul');
      when(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'data': [_venue('v1', 'Kafe')]}));

      await notifier().fetchAllCityVenues();

      final s = state();
      expect(s.allCityVenues.single.name, 'Kafe');
      expect(s.cityName, 'İstanbul');
      expect(s.userLat, 41.0);
      expect(s.isLoading, isFalse);
    });

    test('selectedCity varsa geocoding çağrılmaz', () async {
      // setCity selectedCity'yi kurar ve fetchAllCityVenues'i tetikler.
      when(() => mockLoc.getCurrentPosition()).thenAnswer((_) async => _pos());
      when(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'data': []}));

      await notifier().setCity('Ankara');

      // Şehir zaten seçili → geocoding'e hiç gidilmemeli.
      verifyNever(() => mockLoc.getCityFromCoordinates(any(), any()));
      expect(state().isLoading, isFalse);
    });

    test('şehir hiç çözülemezse erken çıkar (API çağrısı yok)', () async {
      when(() => mockLoc.getCurrentPosition()).thenAnswer((_) async => _pos());
      when(() => mockLoc.getCityFromCoordinates(any(), any()))
          .thenAnswer((_) async => null);

      await notifier().fetchAllCityVenues();

      verifyNever(() => mockApi.get(any(),
          queryParameters: any(named: 'queryParameters')));
      expect(state().isLoading, isFalse);
    });

    test('konum reddedilirse locationDenied true olur', () async {
      when(() => mockLoc.getCurrentPosition())
          .thenThrow(const LocationServiceException('Konum izni reddedildi.'));

      await notifier().fetchAllCityVenues();

      expect(state().locationDenied, isTrue);
      expect(state().isLoading, isFalse);
    });
  });
}
