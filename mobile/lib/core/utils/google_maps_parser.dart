import 'dart:async';
import 'dart:io';

/// Google Maps linklerinden koordinat parse eden utility.
/// Hiçbir ücretli API kullanmaz.
class GoogleMapsParser {
  /// Desteklenen Google Maps link formatlarından koordinat çıkarır.
  /// Başarısız olursa null döner.
  /// Ham "enlem, boylam" girdisi — kullanıcı haritada kendi işaretlediği bir
  /// noktayı paylaştığında link yerine bu metni alır.
  static final RegExp _rawCoordinatePattern =
      RegExp(r'^(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)$');

  static Future<MapCoordinates?> parseLink(String link) async {
    final trimmed = link.trim();
    if (trimmed.isEmpty) return null;

    // Link değil, doğrudan koordinat çifti yapıştırılmış olabilir.
    final raw = _rawCoordinatePattern.firstMatch(trimmed);
    if (raw != null) {
      return _tryParse(raw.group(1)!, raw.group(2)!);
    }

    // Kısa linkleri önce tam URL'e çevir
    final url = await _resolveUrl(trimmed);
    if (url == null) return null;

    final coords = _extractCoordinates(url);
    if (coords == null) return null;

    return MapCoordinates(
      latitude: coords.latitude,
      longitude: coords.longitude,
      placeId: _extractPlaceId(url),
      placeName: _extractPlaceName(url),
    );
  }

  /// URL'den mekan adını çıkarmayı dener.
  /// Örn: /maps/place/Sultan+Ahmet+Camii/@ → "Sultan Ahmet Camii"
  static String? _extractPlaceName(String url) {
    final pattern = RegExp(r'/maps/place/([^/@?]+)');
    final match = pattern.firstMatch(url);
    if (match != null) {
      final raw = match.group(1)!.replaceAll('+', ' ');
      final decoded = Uri.decodeComponent(raw).trim();
      // Koordinat gibi görünen (sadece rakam, virgül, nokta) değerleri reddet
      if (decoded.isEmpty || RegExp(r'^[\d.,\-]+$').hasMatch(decoded)) {
        return null;
      }
      return decoded;
    }
    return null;
  }

  /// URL'den place_id çıkarmayı dener.
  /// Google Maps URL'lerinde iki format kullanılır:
  ///   - !1s0x14cab...:0x... (hex format — yaygın)
  ///   - !1sChIJ...          (base64 format — nadir)
  static String? _extractPlaceId(String url) {
    final dataPattern = RegExp(r'!1s((?:ChIJ|0x)[^!&]+)');
    final match = dataPattern.firstMatch(url);
    if (match != null) {
      return Uri.decodeComponent(match.group(1)!);
    }
    return null;
  }

  /// URL'den koordinat çıkarmayı dener (birden fazla format destekler).
  /// ÖNCELİK SIRASI ÖNEMLİ: !3d/!4d pin koordinatını verir (kamera değil).
  static MapCoordinates? _extractCoordinates(String url) {
    // Format 1 (EN YÜKSEK ÖNCELİK): data=...!8m2!3d{lat}!4d{lng}
    // Mekanın tam pin koordinatı — en güvenilir format.
    final dataPattern = RegExp(r'!8m2!3d(-?\d+\.?\d*)!4d(-?\d+\.?\d*)');
    var match = dataPattern.firstMatch(url);
    if (match != null) {
      return _tryParse(match.group(1)!, match.group(2)!);
    }

    // Format 2: !3d{lat}!4d{lng} (embed / short URL resolved format)
    // Yine pin koordinatı, !8m2 olmadan da gelebilir.
    final embedPattern = RegExp(r'!3d(-?\d+\.?\d*)!4d(-?\d+\.?\d*)');
    match = embedPattern.firstMatch(url);
    if (match != null) {
      return _tryParse(match.group(1)!, match.group(2)!);
    }

    // Format 3: /@lat,lng,zoom — KAMERA merkezi, pin değil.
    // Sadece yukarıdaki formatlar bulunamazsa kullan.
    final atPattern = RegExp(r'/@(-?\d+\.?\d*),(-?\d+\.?\d*)');
    match = atPattern.firstMatch(url);
    if (match != null) {
      return _tryParse(match.group(1)!, match.group(2)!);
    }

    // Format 4: ?q=lat,lng veya ?ll=lat,lng
    final qPattern = RegExp(r'[?&](?:q|ll|query)=(-?\d+\.?\d*),(-?\d+\.?\d*)');
    match = qPattern.firstMatch(url);
    if (match != null) {
      return _tryParse(match.group(1)!, match.group(2)!);
    }

    // Format 5: /maps/place/lat,lng
    final placePattern = RegExp(r'/maps/place/(-?\d+\.?\d*),(-?\d+\.?\d*)');
    match = placePattern.firstMatch(url);
    if (match != null) {
      return _tryParse(match.group(1)!, match.group(2)!);
    }

    return null;
  }

  /// Kısa linkleri (goo.gl, maps.app.goo.gl) tam URL'e çevirir.
  /// Normal linkler olduğu gibi döner.
  static Future<String?> _resolveUrl(String url) async {
    // Eğer zaten tam bir Google Maps URL'iyse direkt döndür
    if (_isFullGoogleMapsUrl(url)) return url;

    // Kısa link mi kontrol et
    if (_isShortLink(url)) {
      try {
        final resolved = await _followRedirects(url);
        return resolved;
      } catch (_) {
        return null;
      }
    }

    // Bilinmeyen format
    if (url.contains('google') || url.contains('goo.gl') || url.contains('maps')) {
      return url;
    }

    return null;
  }

  static bool _isFullGoogleMapsUrl(String url) {
    return url.contains('google.com/maps') ||
        url.contains('google.com.tr/maps') ||
        url.contains('maps.google.com');
  }

  static bool _isShortLink(String url) {
    return url.contains('goo.gl/maps') ||
        url.contains('maps.app.goo.gl') ||
        url.contains('g.co/maps');
  }

  /// HTTP redirect'leri takip ederek tam URL'i alır.
  static Future<String> _followRedirects(String url) async {
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close();
      await response.drain<void>();

      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers.value('location');
        if (location != null) {
          // Recursive redirect takip (max 5)
          return _followRedirectsRecursive(location, 5, client);
        }
      }
      // Redirect yoksa orijinal URL'i döndür
      return url;
    } finally {
      client.close();
    }
  }

  static Future<String> _followRedirectsRecursive(
    String url,
    int maxRedirects,
    HttpClient client,
  ) async {
    if (maxRedirects <= 0) return url;

    // Eğer artık tam bir Google Maps URL'iyse dur
    if (_isFullGoogleMapsUrl(url)) return url;

    try {
      final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close();
      await response.drain<void>();

      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers.value('location');
        if (location != null) {
          return _followRedirectsRecursive(location, maxRedirects - 1, client);
        }
      }
    } catch (_) {
      // Hata durumunda mevcut URL'i döndür
    }
    return url;
  }

  static MapCoordinates? _tryParse(String latStr, String lngStr) {
    try {
      final lat = double.parse(latStr);
      final lng = double.parse(lngStr);

      // Geçerli koordinat aralığı kontrolü
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;

      return MapCoordinates(latitude: lat, longitude: lng);
    } catch (_) {
      return null;
    }
  }

  /// Verilen string'in işlenebilir bir konum girdisi olup olmadığını kontrol eder.
  /// Google Maps linklerinin yanında ham "enlem, boylam" çiftini de kabul eder.
  static bool isValidMapsLink(String link) {
    final trimmed = link.trim().toLowerCase();
    if (_rawCoordinatePattern.hasMatch(trimmed)) return true;
    return trimmed.contains('google.com/maps') ||
        trimmed.contains('google.com.tr/maps') ||
        trimmed.contains('maps.google.com') ||
        trimmed.contains('goo.gl/maps') ||
        trimmed.contains('maps.app.goo.gl') ||
        trimmed.contains('g.co/maps');
  }
}

class MapCoordinates {
  final double latitude;
  final double longitude;
  final String? placeId;
  final String? placeName;

  const MapCoordinates({
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.placeName,
  });

  @override
  String toString() => '($latitude, $longitude, placeId: $placeId)';
}
