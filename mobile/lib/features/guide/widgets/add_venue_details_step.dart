import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/data/turkey_locations.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/guide_provider.dart';
import 'full_map_picker.dart';

class AddVenueDetailsStep extends ConsumerStatefulWidget {
  const AddVenueDetailsStep({super.key});

  @override
  ConsumerState<AddVenueDetailsStep> createState() =>
      _AddVenueDetailsStepState();
}

class _AddVenueDetailsStepState extends ConsumerState<AddVenueDetailsStep> {
  final _nameController = TextEditingController();
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    final state = ref.read(addVenueProvider);
    _nameController.text = state.name;
    if (state.latitude != null && state.longitude != null) {
      _selectedLocation = LatLng(state.latitude!, state.longitude!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addVenueProvider);
    final notifier = ref.read(addVenueProvider.notifier);
    final hasCoordinates = state.latitude != null && state.longitude != null;

    // _selectedLocation'ı state ile senkronize tut
    if (hasCoordinates) {
      final target = LatLng(state.latitude!, state.longitude!);
      if (_selectedLocation == null ||
          _selectedLocation!.latitude != target.latitude ||
          _selectedLocation!.longitude != target.longitude) {
        _selectedLocation = target;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mekan Bilgileri',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            state.isManualMode
                ? 'Mekanın bilgilerini girin ve konumunu haritada işaretleyin.'
                : 'Bilgileri kontrol edin, yanlışsa düzeltin.',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),

          // Mekan adı
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Mekan adı',
              hintText: 'Örn: Sultan Ahmet Restaurant',
              prefixIcon: Icon(Icons.store_outlined),
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: notifier.setName,
          ),
          const SizedBox(height: 12),

          // İl dropdown
          _buildDropdown(
            label: 'İl',
            icon: Icons.location_city,
            value: state.city.isEmpty ? null : state.city,
            items: TurkeyLocations.provinces,
            onChanged: (value) {
              if (value != null) notifier.setCity(value);
            },
          ),
          const SizedBox(height: 12),

          // İlçe dropdown
          _buildDropdown(
            label: 'İlçe',
            icon: Icons.place_outlined,
            value: state.district.isEmpty ? null : state.district,
            items: state.city.isEmpty
                ? []
                : TurkeyLocations.getDistrictsOf(state.city),
            onChanged: (value) {
              if (value != null) notifier.setDistrict(value);
            },
            enabled: state.city.isNotEmpty,
          ),
          const SizedBox(height: 24),

          // Konum başlığı
          const Text(
            'Konum',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          if (hasCoordinates) ...[
            const Text(
              'Pin\'in konumunu kontrol edin. Yanlışsa haritaya dokunarak düzeltebilirsiniz.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 220,
                child: _buildMiniMap(),
              ),
            ),
          ] else ...[
            _buildMapPickerCard(),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMapPickerCard() {
    return Container(
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
            'Koordinatlar üzerinden konum belirlenir.',
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
          .map((item) =>
              DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: enabled ? onChanged : null,
      isExpanded: true,
      menuMaxHeight: 300,
    );
  }

  Widget _buildMiniMap() {
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
      onTap: _onMapTap,
      markers: {
        Marker(
          markerId: const MarkerId('selected'),
          position: _selectedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen),
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

  void _onMapTap(LatLng position) {
    setState(() => _selectedLocation = position);
    ref.read(addVenueProvider.notifier).setCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        );
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
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
            setState(() => _selectedLocation = position);
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
