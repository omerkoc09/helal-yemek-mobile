import 'package:flutter_test/flutter_test.dart';

import 'package:itimat/core/utils/google_maps_parser.dart';

// google_maps_parser saf parsing mantığını test eder. Kısa link çözümleme
// (redirect) ağ gerektirdiği için burada test edilmez; tüm girdiler zaten tam
// Google Maps URL'leridir, dolayısıyla parseLink redirect'e girmeden çalışır.
void main() {
  group('parseLink — koordinat format önceliği', () {
    test('!8m2!3d/!4d (pin) en yüksek öncelikli, /@ (kamera) ezilir', () async {
      // URL hem kamera merkezi (/@) hem pin (!3d/!4d) taşır. Pin seçilmeli;
      // yanlış öncelik mekanı kamera merkezine (yanlış konuma) kaydeder.
      const url =
          'https://www.google.com/maps/place/Kafe/@41.0100,29.0100,17z/data=!3m1!4b1!4m6!3m5!1s0x0:0x0!8m2!3d41.0200!4d29.0200';
      final coords = await GoogleMapsParser.parseLink(url);
      expect(coords, isNotNull);
      expect(coords!.latitude, 41.0200);
      expect(coords.longitude, 29.0200);
    });

    test('!3d/!4d (!8m2 olmadan) kamera merkezinden önce gelir', () async {
      const url =
          'https://www.google.com/maps/place/Kafe/@41.0100,29.0100,17z/data=!3d41.0300!4d29.0300';
      final coords = await GoogleMapsParser.parseLink(url);
      expect(coords, isNotNull);
      expect(coords!.latitude, 41.0300);
      expect(coords.longitude, 29.0300);
    });

    test('yalnızca /@ varsa kamera merkezi kullanılır', () async {
      const url = 'https://www.google.com/maps/@41.0082,28.9784,15z';
      final coords = await GoogleMapsParser.parseLink(url);
      expect(coords, isNotNull);
      expect(coords!.latitude, 41.0082);
      expect(coords.longitude, 28.9784);
    });

    test('?q=lat,lng formatı desteklenir', () async {
      const url = 'https://maps.google.com/?q=39.9334,32.8597';
      final coords = await GoogleMapsParser.parseLink(url);
      expect(coords, isNotNull);
      expect(coords!.latitude, 39.9334);
      expect(coords.longitude, 32.8597);
    });

    test('/maps/place/lat,lng formatı desteklenir', () async {
      const url = 'https://www.google.com/maps/place/40.7589,-73.9851';
      final coords = await GoogleMapsParser.parseLink(url);
      expect(coords, isNotNull);
      expect(coords!.latitude, 40.7589);
      expect(coords.longitude, -73.9851);
    });

    test('negatif koordinatlar (batı/güney yarımküre) doğru parse edilir', () async {
      const url = 'https://www.google.com/maps/@-33.8688,-151.2093,15z';
      final coords = await GoogleMapsParser.parseLink(url);
      expect(coords, isNotNull);
      expect(coords!.latitude, -33.8688);
      expect(coords.longitude, -151.2093);
    });
  });

  group('parseLink — place_id çıkarımı', () {
    test('hex format place_id (!1s0x...) çıkarılır', () async {
      const url =
          'https://www.google.com/maps/place/Kafe/data=!4m2!3m1!1s0x14cac7b3e3f1d8e5:0x9a1b2c3d4e5f6a7b!8m2!3d41.0!4d29.0';
      final coords = await GoogleMapsParser.parseLink(url);
      expect(coords, isNotNull);
      expect(coords!.placeId, '0x14cac7b3e3f1d8e5:0x9a1b2c3d4e5f6a7b');
    });

    test('ChIJ format place_id (!1sChIJ...) çıkarılır', () async {
      const url =
          'https://www.google.com/maps/place/Kafe/data=!4m2!3m1!1sChIJN1t_tDeuEmsRUsoyG83frY4!8m2!3d41.0!4d29.0';
      final coords = await GoogleMapsParser.parseLink(url);
      expect(coords, isNotNull);
      expect(coords!.placeId, 'ChIJN1t_tDeuEmsRUsoyG83frY4');
    });

    test('place_id yoksa null döner ama koordinat yine gelir', () async {
      const url = 'https://www.google.com/maps/@41.0,29.0,15z';
      final coords = await GoogleMapsParser.parseLink(url);
      expect(coords, isNotNull);
      expect(coords!.placeId, isNull);
    });
  });

  group('parseLink — placeName çıkarımı', () {
    test('/maps/place/İsim/ mekan adını çözer ve + işaretini boşluğa çevirir', () async {
      const url =
          'https://www.google.com/maps/place/Sultan+Ahmet+Camii/@41.0054,28.9768,17z/data=!8m2!3d41.0054!4d28.9768';
      final coords = await GoogleMapsParser.parseLink(url);
      expect(coords, isNotNull);
      expect(coords!.placeName, 'Sultan Ahmet Camii');
    });

    test('koordinat gibi görünen "isim" reddedilir (placeName null)', () async {
      // /maps/place/41.0,29.0 — bu bir isim değil koordinattır, isim olarak alınmamalı.
      const url = 'https://www.google.com/maps/place/41.0,29.0';
      final coords = await GoogleMapsParser.parseLink(url);
      expect(coords, isNotNull);
      expect(coords!.placeName, isNull);
    });

    test('URL-encoded Türkçe karakterler decode edilir', () async {
      // %C4%B0 = İ
      const url =
          'https://www.google.com/maps/place/%C4%B0stanbul+Kalesi/@41.0,29.0,17z/data=!8m2!3d41.0!4d29.0';
      final coords = await GoogleMapsParser.parseLink(url);
      expect(coords, isNotNull);
      expect(coords!.placeName, 'İstanbul Kalesi');
    });
  });

  group('parseLink — geçerlilik ve sınırlar', () {
    test('boş/whitespace link null döner', () async {
      expect(await GoogleMapsParser.parseLink(''), isNull);
      expect(await GoogleMapsParser.parseLink('   '), isNull);
    });

    test('Google Maps ile ilgisiz URL null döner', () async {
      expect(await GoogleMapsParser.parseLink('https://example.com/foo'), isNull);
    });

    test('Maps URL ama koordinat içermiyorsa null döner', () async {
      final coords =
          await GoogleMapsParser.parseLink('https://www.google.com/maps/search/kafe');
      expect(coords, isNull);
    });

    test('geçersiz enlem (>90) reddedilir', () async {
      final coords =
          await GoogleMapsParser.parseLink('https://www.google.com/maps/@91.0,29.0,15z');
      expect(coords, isNull);
    });

    test('geçersiz boylam (>180) reddedilir', () async {
      final coords =
          await GoogleMapsParser.parseLink('https://www.google.com/maps/@41.0,181.0,15z');
      expect(coords, isNull);
    });

    test('sınır değerler (90, 180) kabul edilir', () async {
      final coords =
          await GoogleMapsParser.parseLink('https://www.google.com/maps/@90.0,180.0,15z');
      expect(coords, isNotNull);
      expect(coords!.latitude, 90.0);
      expect(coords.longitude, 180.0);
    });
  });

  group('isValidMapsLink', () {
    test('geçerli Google Maps host varyantları kabul edilir', () {
      expect(GoogleMapsParser.isValidMapsLink('https://www.google.com/maps/@41,29'), isTrue);
      expect(GoogleMapsParser.isValidMapsLink('https://maps.google.com/?q=41,29'), isTrue);
      expect(GoogleMapsParser.isValidMapsLink('https://maps.app.goo.gl/abc123'), isTrue);
      expect(GoogleMapsParser.isValidMapsLink('https://g.co/maps/xyz'), isTrue);
    });

    test('büyük/küçük harf ve boşluk normalize edilir', () {
      expect(GoogleMapsParser.isValidMapsLink('  HTTPS://WWW.GOOGLE.COM/MAPS/@41,29  '), isTrue);
    });

    test('Maps olmayan link reddedilir', () {
      expect(GoogleMapsParser.isValidMapsLink('https://example.com'), isFalse);
      expect(GoogleMapsParser.isValidMapsLink(''), isFalse);
    });
  });
}
