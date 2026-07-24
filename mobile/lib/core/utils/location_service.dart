import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

// Konum servisi provider'ı. Testte fake ile override edilebilir.
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

class LocationService {
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceException('Konum servisi kapalı.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationServiceException('Konum izni reddedildi.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationServiceException(
        'Konum izni kalıcı olarak reddedildi. Ayarlardan izin verin.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  /// Koordinattan il/şehir adını çözer (ör. "İstanbul"). Geocoding başarısız
  /// olursa null döner (çağıran, şehir slider'ını göstermeyerek devam eder).
  /// administrativeArea = il, locality = ilçe; il seviyesi önceliklidir.
  Future<String?> getCityFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        return placemarks.first.administrativeArea ??
            placemarks.first.locality;
      }
    } catch (_) {
      // Geocoding hatası — şehir çözülemedi.
    }
    return null;
  }
}

class LocationServiceException implements Exception {
  final String message;
  const LocationServiceException(this.message);

  @override
  String toString() => message;
}
