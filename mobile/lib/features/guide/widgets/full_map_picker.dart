import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_theme.dart';

class FullMapPicker extends StatefulWidget {
  final LatLng? initialLocation;
  final ValueChanged<LatLng> onLocationSelected;

  const FullMapPicker({
    super.key,
    this.initialLocation,
    required this.onLocationSelected,
  });

  @override
  State<FullMapPicker> createState() => _FullMapPickerState();
}

class _FullMapPickerState extends State<FullMapPicker> {
  GoogleMapController? _controller;
  LatLng? _picked;
  bool _loading = true;
  late LatLng _initialPos;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialLocation;
    _initLocation();
  }

  Future<void> _initLocation() async {
    if (widget.initialLocation != null) {
      _initialPos = widget.initialLocation!;
      setState(() => _loading = false);
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _initialPos = LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      _initialPos = const LatLng(41.0082, 28.9784);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Haritada Konum Seç',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Mekanın konumuna dokunarak pin bırakın.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _initialPos,
                    zoom: 15,
                  ),
                  onMapCreated: (c) => _controller = c,
                  onTap: (pos) => setState(() => _picked = pos),
                  markers: _picked != null
                      ? {
                          Marker(
                            markerId: const MarkerId('picked'),
                            position: _picked!,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueGreen,
                            ),
                          ),
                        }
                      : {},
                  cloudMapId: 'ef50e8cf036dd5b69eab1187',
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _picked != null
                    ? () => widget.onLocationSelected(_picked!)
                    : null,
                child: const Text('Bu Konumu Seç'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
