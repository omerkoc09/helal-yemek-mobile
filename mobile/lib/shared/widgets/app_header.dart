import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../core/theme/app_theme.dart';

/// Uygulamanın tüm sayfalarında üstte sabit duran header.
/// Logo | Konum | Favoriler
class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(_locationLabelProvider);

    return AppBar(
      backgroundColor: AppTheme.primary,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Logo
          _Logo(),
          const SizedBox(width: 12),
          // Konum
          Expanded(
            child: GestureDetector(
              onTap: () => context.go('/map'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Flexible(
                      child: locationAsync.when(
                        data: (label) => Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        loading: () => const Text(
                          'Konum alınıyor...',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        error: (_, _) => const Text(
                          'Konumunuzu Seçin',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Favoriler
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.white),
            tooltip: 'Favorilerim',
            onPressed: () => context.push('/favorites'),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/app_logo_nobg.png',
      height: 32,
      errorBuilder: (_, _, _) => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, color: Colors.white, size: 22),
          SizedBox(width: 4),
          Text(
            'Caiz mi?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kullanıcının mevcut konumunu semt/şehir olarak döndürür.
/// Konum servisi kapalıysa veya izin yoksa hata fırlatır.
final _locationLabelProvider = FutureProvider<String>((ref) async {
  final permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw Exception('konum izni yok');
  }

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
  );

  try {
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (placemarks.isNotEmpty) {
      final p = placemarks.first;
      final district = p.locality ?? '';
      final city = p.administrativeArea ?? '';
      if (district.isNotEmpty && city.isNotEmpty) return '$district, $city';
      return district.isNotEmpty ? district : (city.isNotEmpty ? city : 'Konumunuzu Seçin');
    }
  } catch (_) {
    // geocoding başarısız olursa koordinat göster
  }

  final lat = position.latitude.toStringAsFixed(4);
  final lng = position.longitude.toStringAsFixed(4);
  return '$lat° K, $lng° D';
});
