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

Map<String, dynamic> _confirmedVenueJson({String id = 'v1'}) => {
      'id': id,
      'name': 'Doğruladığım Kafe',
      'city': 'İstanbul',
      'latitude': 41.0,
      'longitude': 29.0,
      'added_by': 'someone-else',
      'status': 'approved',
      'confirmed_at': '2026-03-12T10:00:00Z',
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

  MyConfirmationsNotifier notifier() =>
      container.read(myConfirmationsProvider.notifier);
  MyVenuesState state() => container.read(myConfirmationsProvider);

  group('fetchMyConfirmations', () {
    test('doğrulanan mekanları yükler ve confirmed_at\'i çözer', () async {
      when(() => mockApi.get(ApiEndpoints.guideMyConfirmations))
          .thenAnswer((_) async => _ok([_confirmedVenueJson()]));

      await notifier().fetchMyConfirmations();

      expect(state().isLoading, false);
      expect(state().error, isNull);
      expect(state().venues, hasLength(1));
      expect(state().venues.first.id, 'v1');
      expect(state().venues.first.confirmedAt, isNotNull);
      expect(state().venues.first.confirmedAt!.year, 2026);
    });

    test('hata durumunda mesaj set eder', () async {
      when(() => mockApi.get(ApiEndpoints.guideMyConfirmations))
          .thenThrow(_err());

      await notifier().fetchMyConfirmations();

      expect(state().isLoading, false);
      expect(state().error, isNotNull);
      expect(state().venues, isEmpty);
    });
  });

  group('revokeConfirmation', () {
    test('DELETE çağırır, true döner ve listeyi yeniler', () async {
      when(() => mockApi.delete(ApiEndpoints.venueConfirm('v1')))
          .thenAnswer((_) async => _ok({'status': 'unconfirmed'}));
      // Geri çekmeden sonra liste boş döner.
      when(() => mockApi.get(ApiEndpoints.guideMyConfirmations))
          .thenAnswer((_) async => _ok([]));
      when(() => mockApi.get(ApiEndpoints.guideMyVenues))
          .thenAnswer((_) async => _ok([]));

      final ok = await notifier().revokeConfirmation('v1');

      expect(ok, true);
      verify(() => mockApi.delete(ApiEndpoints.venueConfirm('v1'))).called(1);
      expect(state().venues, isEmpty);
    });

    test('rozet değişebildiği için "eklediklerim" listesi de yenilenir',
        () async {
      when(() => mockApi.delete(ApiEndpoints.venueConfirm('v1')))
          .thenAnswer((_) async => _ok({'status': 'unconfirmed'}));
      when(() => mockApi.get(ApiEndpoints.guideMyConfirmations))
          .thenAnswer((_) async => _ok([]));
      when(() => mockApi.get(ApiEndpoints.guideMyVenues))
          .thenAnswer((_) async => _ok([]));

      await notifier().revokeConfirmation('v1');

      verify(() => mockApi.get(ApiEndpoints.guideMyVenues)).called(1);
    });

    test('hata durumunda false döner', () async {
      when(() => mockApi.delete(ApiEndpoints.venueConfirm('v1')))
          .thenThrow(_err());

      final ok = await notifier().revokeConfirmation('v1');

      expect(ok, false);
    });
  });
}
