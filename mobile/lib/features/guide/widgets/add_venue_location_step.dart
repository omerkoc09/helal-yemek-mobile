import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/data/turkey_locations.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/guide_provider.dart';
import 'full_map_picker.dart';

class AddVenueLocationStep extends ConsumerStatefulWidget {
  const AddVenueLocationStep({super.key});

  @override
  ConsumerState<AddVenueLocationStep> createState() =>
      _AddVenueLocationStepState();
}

class _AddVenueLocationStepState extends ConsumerState<AddVenueLocationStep> {
  final _mapsLinkController = TextEditingController();
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  bool _locationConfirmed = false;
  bool _noGoogleMapsLink = false;

  @override
  void dispose() {
    _mapsLinkController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addVenueProvider);
    final hasCoordinates = state.latitude != null && state.longitude != null;

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Konum',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mekanın il ve ilçesini seçin, ardından Google Maps linkini yapıştırın. '
                  'Link bulunamazsa haritadan manuel konum seçebilirsiniz.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 20),

                // İl Dropdown
                _buildDropdown(
                  label: 'İl',
                  icon: Icons.location_city,
                  value: state.city.isEmpty ? null : state.city,
                  items: TurkeyLocations.provinces,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(addVenueProvider.notifier).setCity(value);
                    }
                  },
                ),
                const SizedBox(height: 12),

                // İlçe Dropdown
                _buildDropdown(
                  label: 'İlçe',
                  icon: Icons.place_outlined,
                  value: state.district.isEmpty ? null : state.district,
                  items: state.city.isEmpty
                      ? []
                      : TurkeyLocations.getDistrictsOf(state.city),
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(addVenueProvider.notifier).setDistrict(value);
                    }
                  },
                  enabled: state.city.isNotEmpty,
                ),
                const SizedBox(height: 20),

                // Google Maps Link
                const Text(
                  'Google Maps Linki',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Google Maps\'te mekanı bulun ve "Paylaş" butonundan linki kopyalayın. '
                  'Mekan kayıtlı değilse haritada konuma uzun basıp oluşan pin\'in linkini paylaşabilirsiniz.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _mapsLinkController,
                  decoration: InputDecoration(
                    labelText: 'Google Maps linki',
                    hintText: 'https://maps.app.goo.gl/...',
                    prefixIcon: const Icon(Icons.link),
                    suffixIcon: state.isParsingLink
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : hasCoordinates && _mapsLinkController.text.isNotEmpty
                            ? const Icon(Icons.check_circle,
                                color: AppTheme.primary)
                            : IconButton(
                                icon: const Icon(Icons.content_paste),
                                onPressed: _pasteFromClipboard,
                              ),
                  ),
                  onChanged: _onMapsLinkChanged,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Mini Map
          if (hasCoordinates) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.map_outlined,
                      size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Konum doğru mu?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_locationConfirmed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 14, color: AppTheme.primary),
                          SizedBox(width: 4),
                          Text(
                            'Onaylandı',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const Text(
                'Haritada pin\'in konumunu kontrol edin. Yanlışsa haritaya dokunarak düzeltebilirsiniz.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildMiniMap(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ] else ...[
            if (_noGoogleMapsLink) ...[
              // Haritada elle seçim alanı (sadece "link yok" onaylandıktan sonra)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.textSecondary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.touch_app_outlined,
                          size: 32, color: AppTheme.textSecondary),
                      const SizedBox(height: 8),
                      const Text(
                        'Haritada konumu işaretleyin',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Koordinatlar üzerinden konum belirlenir; mekanın Google Maps kaydıyla ilişkilendirilemez.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openFullMapPicker,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Haritada Seç'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Kullanıcıya "link yok mu?" sorusunu sor
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.textSecondary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: AppTheme.textSecondary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bu mekanın Google Maps linki yok mu?',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Google Maps\'te aratıp "Paylaş" butonundan linki kopyalayabilirsiniz. '
                        'Link varsa mekanın resmi kaydıyla eşleştirilir.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () =>
                              setState(() => _noGoogleMapsLink = true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            side: BorderSide(
                              color:
                                  AppTheme.textSecondary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text('Evet, Google Maps\'te kayıtlı değil'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        enabled: enabled,
      ),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              ))
          .toList(),
      onChanged: enabled ? onChanged : null,
      isExpanded: true,
      menuMaxHeight: 300,
    );
  }

  Widget _buildMiniMap() {
    final state = ref.watch(addVenueProvider);
    final target = LatLng(state.latitude!, state.longitude!);

    if (_selectedLocation == null ||
        _selectedLocation!.latitude != target.latitude ||
        _selectedLocation!.longitude != target.longitude) {
      _selectedLocation = target;
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _selectedLocation!,
        zoom: 16,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_selectedLocation!),
        );
      },
      onTap: _onMiniMapTap,
      markers: {
        Marker(
          markerId: const MarkerId('selected'),
          position: _selectedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      },
      cloudMapId: 'ef50e8cf036dd5b69eab1187',
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
    );
  }

  void _onMiniMapTap(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _locationConfirmed = true;
    });
    ref.read(addVenueProvider.notifier).setCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        );
  }

  void _onMapsLinkChanged(String link) {
    if (link.trim().isEmpty) return;

    ref.read(addVenueProvider.notifier).parseMapsLink(link).then((success) {
      if (success && mounted) {
        final state = ref.read(addVenueProvider);
        final target = LatLng(state.latitude!, state.longitude!);
        setState(() {
          _selectedLocation = target;
          _locationConfirmed = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(target, 16),
        );
      }
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _mapsLinkController.text = data.text!;
      _onMapsLinkChanged(data.text!);
    }
  }

  void _openFullMapPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: FullMapPicker(
          initialLocation: _selectedLocation,
          onLocationSelected: (position) {
            setState(() {
              _selectedLocation = position;
              _locationConfirmed = true;
            });
            ref.read(addVenueProvider.notifier).setCoordinates(
                  latitude: position.latitude,
                  longitude: position.longitude,
                );
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}
