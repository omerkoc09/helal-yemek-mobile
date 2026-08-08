import 'package:flutter_test/flutter_test.dart';

import 'package:itimat/core/api/api_endpoints.dart';
import 'package:itimat/core/api/media_url.dart';

void main() {
  group('resolveMediaUrl', () {
    test('tam URL olduğu gibi döner', () {
      // Mekan fotoğrafları backend'den tam URL olarak geliyor (yerel disk,
      // S3 veya CDN adresi olabilir) — dokunulmamalı.
      const url = 'https://cdn.caizmi.com/static/foto.jpg';
      expect(resolveMediaUrl(url), url);
    });

    test('http URL olduğu gibi döner', () {
      const url = 'http://192.168.1.5:3000/static/foto.jpg';
      expect(resolveMediaUrl(url), url);
    });

    test('göreli proxy yolu API adresiyle birleştirilir', () {
      // Places fotoğrafları göreli geliyor; istemci kendi API adresine göre
      // çözüyor. Birleştirme bozulursa fotoğraflar sessizce kaybolur.
      final origin = Uri.parse(ApiEndpoints.baseUrl).origin;
      expect(
        resolveMediaUrl('/api/v1/places/photo?ref=abc&w=800'),
        '$origin/api/v1/places/photo?ref=abc&w=800',
      );
    });

    test('göreli /static yolu API adresiyle birleştirilir', () {
      // STORAGE_URL boşken yerel disk fotoğrafları da göreli geliyor. Bu sayede
      // geliştirmede LAN IP'si değiştiğinde hiçbir yapılandırma güncellemesi
      // gerekmiyor — adres istemcinin bağlandığı host'a göre çözülüyor.
      final origin = Uri.parse(ApiEndpoints.baseUrl).origin;
      expect(
        resolveMediaUrl('/static/foto.jpg'),
        '$origin/static/foto.jpg',
      );
    });

    test('sonuç geçerli mutlak URL olur', () {
      final resolved = resolveMediaUrl('/api/v1/places/photo?ref=x');
      final uri = Uri.parse(resolved);
      expect(uri.hasScheme, isTrue);
      expect(uri.host, isNotEmpty);
    });

    test('boş girdi boş döner', () {
      expect(resolveMediaUrl(''), '');
    });
  });

  group('requiresAuthHeader', () {
    test('places proxy adresi yetki ister', () {
      // Bu uç guide/admin korumalı; başlık eklenmezse 401 döner ve
      // önizleme boş görünür.
      expect(requiresAuthHeader('/api/v1/places/photo?ref=abc'), isTrue);
    });

    test('mekan fotoğrafı yetki istemez', () {
      // Statik dosyalar public; gereksiz token göndermeye gerek yok.
      expect(
        requiresAuthHeader('https://cdn.caizmi.com/static/foto.jpg'),
        isFalse,
      );
    });
  });
}
