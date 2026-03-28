import 'package:url_launcher/url_launcher.dart';

class MapLauncher {
  static Future<void> openDirections({
    required double latitude,
    required double longitude,
    String? label,
    String? address,
    String? googlePlaceId,
  }) async {
    final Uri url;

    if (googlePlaceId != null && googlePlaceId.isNotEmpty) {
      // place_id varsa birebir mekan eşleşmesi
      url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&destination_place_id=$googlePlaceId',
      );
    } else {
      // place_id yoksa kullanıcının işaretlediği koordinat — isim araması birden
      // fazla şubeyi karıştırabileceği için koordinat daha güvenilir
      url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
      );
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> openLocation({
    required double latitude,
    required double longitude,
    String? googlePlaceId,
  }) async {
    final Uri url;

    if (googlePlaceId != null && googlePlaceId.isNotEmpty) {
      // place_id varsa Google Maps'te mekan kaydını aç
      url = Uri.parse(
        'https://www.google.com/maps/place/?q=place_id:$googlePlaceId',
      );
    } else {
      // place_id yoksa koordinat ile ara
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      );
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
