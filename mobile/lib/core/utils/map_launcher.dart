import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

class MapLauncher {
  static Future<void> openDirections({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final Uri url;

    if (Platform.isIOS) {
      // Apple Maps
      final query = label != null ? '&q=${Uri.encodeComponent(label)}' : '';
      url = Uri.parse(
        'https://maps.apple.com/?daddr=$latitude,$longitude$query',
      );
    } else {
      // Google Maps
      url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
      );
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
