import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/models/venue.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/venues_provider.dart';
import '../widgets/venue_bottom_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  static const _defaultLocation = LatLng(41.0082, 28.9784); // İstanbul
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    Position? location;
    try {
      location = await ref.read(userLocationProvider.future);
    } catch (_) {
      // Konum alınamadı
    }
    if (location != null && mounted) {
      setState(() {
        _userLocation = LatLng(location!.latitude, location.longitude);
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, 14),
      );
    }
  }

  /// Haritanın görünen alanına göre mekanları getirir.
  Future<void> _fetchVenuesForVisibleRegion({bool force = false}) async {
    final controller = _mapController;
    if (controller == null) return;

    final bounds = await controller.getVisibleRegion();
    final center = LatLng(
      (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
      (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
    );

    // Görünen alanın yarıçapını metre cinsinden hesapla
    final radius = _calculateRadius(bounds);

    ref.read(venuesProvider.notifier).fetchNearbyVenues(
          latitude: center.latitude,
          longitude: center.longitude,
          radius: radius,
          force: force,
        );
  }

  /// LatLngBounds'dan yaklaşık yarıçap hesaplar (metre).
  double _calculateRadius(LatLngBounds bounds) {
    const metersPerDegree = 111320.0;
    final dLat = (bounds.northeast.latitude - bounds.southwest.latitude).abs();
    final dLng = (bounds.northeast.longitude - bounds.southwest.longitude).abs();
    final avgLat = (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
    final latMeters = dLat * metersPerDegree;
    final lngMeters = dLng * metersPerDegree * cos(avgLat * pi / 180);
    // Köşegen / 2 = yarıçap
    return sqrt(latMeters * latMeters + lngMeters * lngMeters) / 2;
  }

  Set<Marker> _buildMarkers(List<Venue> venues) {
    final markers = venues.map((venue) {
      final isApproved = venue.isApproved;
      return Marker(
        markerId: MarkerId(venue.id),
        position: LatLng(venue.latitude, venue.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isApproved
              ? BitmapDescriptor.hueGreen
              : BitmapDescriptor.hueOrange,
        ),
        onTap: () => showVenueBottomSheet(context, venue),
      );
    }).toSet();

    // Kullanıcı konumunu özel marker olarak ekle
    if (_userLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _userLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'Konumunuz'),
        ),
      );
    }

    return markers;
  }

  void _goToMyLocation() {
    final target = _userLocation ?? _defaultLocation;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final venuesState = ref.watch(venuesProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Harita
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _userLocation ?? _defaultLocation,
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              // Harita hazır olunca ilk mekanları getir
              _fetchVenuesForVisibleRegion(force: true);
            },
            onCameraIdle: () => _fetchVenuesForVisibleRegion(),
            markers: _buildMarkers(venuesState.venues),
            cloudMapId: 'ef50e8cf036dd5b69eab1187',
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Yükleniyor göstergesi
          if (venuesState.isLoading)
            const Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
            ),

          // Hata mesajı
          if (venuesState.error != null)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Card(
                color: AppTheme.error.withValues(alpha: 0.9),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    venuesState.error!,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

          // Sağ alt butonlar: Yenile + Konumuma dön
          Positioned(
            bottom: AppTheme.bottomNavClearance,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'refresh_btn',
                  onPressed: () => _fetchVenuesForVisibleRegion(force: true),
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.refresh, color: AppTheme.primary),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'location_btn',
                  onPressed: _goToMyLocation,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: AppTheme.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
