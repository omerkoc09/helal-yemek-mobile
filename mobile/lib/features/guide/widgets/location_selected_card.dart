import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_theme.dart';

/// Mekanın konumunu salt gösterim olarak sunar.
///
/// Konum her zaman Google Maps linkinden (place_id ile) gelir; elle değiştirme
/// yolu bilinçli olarak yok. Manuel düzenleme place_id'yi geçersiz kılıyor,
/// bu da duplicate kontrolünü ve Places eşleşmesini bozuyordu.
class LocationSelectedCard extends StatelessWidget {
  final double latitude;
  final double longitude;

  const LocationSelectedCard({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    final position = LatLng(latitude, longitude);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'Konum Seçildi',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Ham enlem/boylam yerine önizleme haritası: rehber konumun doğru
          // yere düştüğünü sayılardan değil, haritadan teyit edebiliyor.
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 140,
              child: _MiniMap(position: position),
            ),
          ),
        ],
      ),
    );
  }
}

/// Salt görüntülemelik önizleme haritası. Etkileşim kapalı — konum değişikliği
/// yalnızca "Konumu Değiştir" akışından yapılır, harita kazara kaydırılamaz.
class _MiniMap extends StatefulWidget {
  final LatLng position;

  const _MiniMap({required this.position});

  @override
  State<_MiniMap> createState() => _MiniMapState();
}

class _MiniMapState extends State<_MiniMap> {
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(_MiniMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Konum "Konumu Değiştir" ile güncellenince kamerayı yeni noktaya taşı.
    if (widget.position != oldWidget.position) {
      _controller?.moveCamera(CameraUpdate.newLatLng(widget.position));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: widget.position, zoom: 16),
      onMapCreated: (controller) => _controller = controller,
      markers: {
        Marker(
          markerId: const MarkerId('venue'),
          position: widget.position,
        ),
      },
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      scrollGesturesEnabled: false,
      zoomGesturesEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
    );
  }
}
