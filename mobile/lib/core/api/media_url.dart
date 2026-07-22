import 'api_endpoints.dart';

/// Backend'den gelen medya adreslerini görüntülenebilir tam URL'e çevirir.
///
/// Backend iki tür adres döndürür:
///  1. Mekan fotoğrafları — TAM URL (yerel disk, S3 veya CDN adresi olabilir)
///  2. Google Places fotoğrafları — GÖRELİ proxy yolu (`/api/v1/places/photo?...`)
///
/// İkincisi göreli çünkü kendi API'mize işaret ediyor ve API adresi ortama göre
/// değişiyor (emülatör 10.0.2.2, fiziksel cihaz LAN IP, prod domain). Adresi
/// istemcide çözmek, backend'in kendi genel adresini bilmesi gereğini ortadan
/// kaldırıyor.
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
