import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itimat/core/api/api_client.dart';
import 'package:itimat/core/auth/token_storage.dart';

/// Testte gerçek secure storage'a gitmemek için sahte token deposu.
class _FakeTokenStorage implements TokenStorage {
  @override
  Future<String?> getAccessToken() async => 'test-token';

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ApiClient binary indirme', () {
    late HttpServer server;
    late List<int> payload;

    setUp(() async {
      // Fotoğraf proxy'sinden dönene benzer boyutta binary gövde.
      payload = List<int>.generate(200 * 1024, (i) => i % 256);

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add(payload);
        await request.response.close();
      });
    });

    tearDown(() async => server.close(force: true));

    test('büyük binary yanıt hatasız indirilir', () async {
      // Regresyon: LogInterceptor(responseBody: true) tüm gövdeleri metne
      // çevirmeye çalışıyordu; yüz KB'lık JPEG'de istek transport seviyesinde
      // "DioException [unknown]: null" ile düşüyor ve fotoğraflar hiç
      // görünmüyordu. Binary yanıtlar artık gövde olarak loglanmıyor.
      final client = ApiClient(tokenStorage: _FakeTokenStorage());

      final response = await client.dio.get<List<int>>(
        'http://${server.address.host}:${server.port}/api/v1/places/photo',
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {'Accept': 'image/*'},
        ),
      );

      expect(response.statusCode, 200);
      expect(response.data, isNotNull);
      expect(response.data!.length, payload.length);
    });
  });
}
