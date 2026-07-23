import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:caiz_mi/core/api/api_client.dart';
import 'package:caiz_mi/core/auth/auth_provider.dart';
import 'package:caiz_mi/features/home/providers/home_provider.dart';

class MockApiClient extends Mock implements ApiClient {}

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

// home_provider'ın konum gerektirmeyen search/clearSearch yolları. fetchFeed
// vb. LocationService + geocoding'e bağlı olduğu için kapsam dışı.
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

  HomeNotifier notifier() => container.read(homeProvider.notifier);
  HomeState state() => container.read(homeProvider);

  group('search', () {
    test('boş sorgu API çağırmadan sonuçları temizler', () async {
      await notifier().search('');

      verifyNever(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')));
      expect(state().searchResults, isEmpty);
      expect(state().isSearching, isFalse);
      expect(state().hasSearchQuery, isFalse);
    });

    test('başarılı arama sonuçları state\'e yazar', () async {
      when(() => mockApi.get('/venues', queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({
                'data': [_venue('v1', 'Kafe A'), _venue('v2', 'Kafe B')]
              }));

      await notifier().search('kafe');

      expect(state().searchQuery, 'kafe');
      expect(state().hasSearchQuery, isTrue);
      expect(state().searchResults.length, 2);
      expect(state().searchResults.first.name, 'Kafe A');
      expect(state().isSearching, isFalse);
    });

    test('düz liste yanıtı ({data:...} olmadan) da parse edilir', () async {
      when(() => mockApi.get('/venues', queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok([_venue('v1', 'Tek Kafe')]));

      await notifier().search('kafe');

      expect(state().searchResults.length, 1);
      expect(state().searchResults.first.name, 'Tek Kafe');
    });

    test('API hatasında sonuçlar temizlenir ve isSearching düşer', () async {
      when(() => mockApi.get('/venues', queryParameters: any(named: 'queryParameters')))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      await notifier().search('kafe');

      expect(state().searchResults, isEmpty);
      expect(state().isSearching, isFalse);
    });
  });

  group('clearSearch', () {
    test('sorgu ve sonuçları sıfırlar', () async {
      when(() => mockApi.get('/venues', queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'data': [_venue('v1', 'Kafe')]}));
      await notifier().search('kafe');
      expect(state().searchResults, isNotEmpty);

      notifier().clearSearch();

      expect(state().searchResults, isEmpty);
      expect(state().hasSearchQuery, isFalse);
      expect(state().isSearching, isFalse);
    });
  });
}
