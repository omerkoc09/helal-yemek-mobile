import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:itimat/core/api/api_client.dart';
import 'package:itimat/core/auth/auth_provider.dart';
import 'package:itimat/features/home/providers/home_provider.dart';

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

  // search_provider.dart'taki 500ms debounce deseniyle aynı; test bu süreyi
  // aşarak gerçek fetch'in tetiklenmesini bekler.
  const debounceWait = Duration(milliseconds: 600);

  group('search', () {
    test('boş sorgu API çağırmadan sonuçları temizler', () async {
      await notifier().search('');

      verifyNever(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')));
      expect(state().searchResults, isEmpty);
      expect(state().isSearching, isFalse);
      expect(state().hasSearchQuery, isFalse);
    });

    test('başarılı arama sonuçları state\'e yazar (debounce sonrası)', () async {
      when(() => mockApi.get('/venues', queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({
                'data': [_venue('v1', 'Kafe A'), _venue('v2', 'Kafe B')]
              }));

      await notifier().search('kafe');
      expect(state().isSearching, isTrue);
      await Future.delayed(debounceWait);

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
      await Future.delayed(debounceWait);

      expect(state().searchResults.length, 1);
      expect(state().searchResults.first.name, 'Tek Kafe');
    });

    test('API hatasında sonuçlar temizlenir ve isSearching düşer', () async {
      when(() => mockApi.get('/venues', queryParameters: any(named: 'queryParameters')))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      await notifier().search('kafe');
      await Future.delayed(debounceWait);

      expect(state().searchResults, isEmpty);
      expect(state().isSearching, isFalse);
    });

    test('hızlı ardışık yazımlarda yalnızca son sorgu için API çağrılır', () async {
      when(() => mockApi.get('/venues', queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'data': [_venue('v1', 'Kafe A')]}));

      await notifier().search('k');
      await notifier().search('ka');
      await notifier().search('kafe');
      await Future.delayed(debounceWait);

      expect(state().searchQuery, 'kafe');
      verify(() => mockApi.get('/venues', queryParameters: any(named: 'queryParameters')))
          .called(1);
    });
  });

  group('clearSearch', () {
    test('sorgu ve sonuçları sıfırlar', () async {
      when(() => mockApi.get('/venues', queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'data': [_venue('v1', 'Kafe')]}));
      await notifier().search('kafe');
      await Future.delayed(debounceWait);
      expect(state().searchResults, isNotEmpty);

      notifier().clearSearch();

      expect(state().searchResults, isEmpty);
      expect(state().hasSearchQuery, isFalse);
      expect(state().isSearching, isFalse);
    });

    test('bekleyen debounce zamanlayıcısını iptal eder', () async {
      when(() => mockApi.get('/venues', queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'data': [_venue('v1', 'Kafe')]}));

      await notifier().search('kafe');
      notifier().clearSearch();
      await Future.delayed(debounceWait);

      verifyNever(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')));
      expect(state().searchResults, isEmpty);
    });
  });
}
