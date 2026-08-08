import 'api_endpoints.dart';

/// Backend'den gelen medya adreslerini görüntülenebilir tam URL'e çevirir.
///
/// Adres iki biçimde gelebilir:
///  1. TAM URL — S3/CDN, ya da `STORAGE_URL` tanımlıyken yerel disk (prod).
///  2. GÖRELİ yol — Google Places proxy'si (`/api/v1/places/photo?...`) ve
///     `STORAGE_URL` boşken yerel disk fotoğrafları (`/static/...`).
///
/// Göreli biçim, API adresi ortama göre değiştiği için var: emülatör 10.0.2.2,
/// fiziksel cihaz LAN IP, prod domain. Adresi istemcide çözmek, backend'in kendi
/// genel adresini bilmesi gereğini ortadan kaldırıyor — geliştirmede LAN IP'si
/// değiştiğinde hiçbir yapılandırma güncellemesi gerekmiyor.
///
/// TÜM medya gösterimleri bu fonksiyondan geçmeli; doğrudan `Image.network(url)`
/// çağrısı göreli adreste kırılır.
String resolveMediaUrl(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;

  // baseUrl ".../api/v1" ile bitiyor; göreli yol da "/api/v1/..." ile
  // başladığı için ön ekin yalnızca şema+host kısmı alınır.
  final origin = Uri.parse(ApiEndpoints.baseUrl).origin;
  return '$origin$url';
}

/// Places proxy adresi mi? Bu adresler yetki gerektirir (guide/admin),
/// dolayısıyla `Image.network` çağrısına Authorization başlığı eklenmelidir.
bool requiresAuthHeader(String url) => url.contains('/places/photo');
