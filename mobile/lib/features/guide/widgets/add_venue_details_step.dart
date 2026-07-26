import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/data/turkey_locations.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/guide_provider.dart';
import 'full_map_picker.dart';
import 'location_selected_card.dart';

class AddVenueDetailsStep extends ConsumerStatefulWidget {
  const AddVenueDetailsStep({super.key});

  @override
  ConsumerState<AddVenueDetailsStep> createState() =>
      _AddVenueDetailsStepState();
}

class _AddVenueDetailsStepState extends ConsumerState<AddVenueDetailsStep> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = ref.read(addVenueProvider);
    _nameController.text = state.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addVenueProvider);
    final notifier = ref.read(addVenueProvider.notifier);
    final hasCoordinates = state.latitude != null && state.longitude != null;

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
          const Text(
            'Bilgileri kontrol edin, yanlışsa düzeltin.',
            style: TextStyle(color: AppTheme.textSecondary),
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

          const Text(
            'Konum',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          if (hasCoordinates)
            LocationSelectedCard(
              latitude: state.latitude!,
              longitude: state.longitude!,
              onEdit: _openFullMapPicker,
            )
          else
            _buildLocationPickerCard(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLocationPickerCard() {
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
    // value listede yoksa null'a düşür: aksi halde DropdownButton
    // "exactly one item" assertion'ıyla çöker. Bu, ör. Google Maps'ten gelen
    // "Aydın Merkez" gibi statik ilçe listesinde bulunmayan bir değer
    // state'e yazıldığında olur — crash yerine dropdown boş görünür.
    final safeValue = (value != null && items.contains(value)) ? value : null;

    return DropdownButtonFormField<String>(
      value: safeValue,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        enabled: enabled,
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: enabled ? onChanged : null,
      isExpanded: true,
      menuMaxHeight: 300,
    );
  }

  void _openFullMapPicker() {
    final state = ref.read(addVenueProvider);
    final initial = state.latitude != null && state.longitude != null
        ? LatLng(state.latitude!, state.longitude!)
        : null;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => FullMapPicker(
          initialLocation: initial,
          onLocationSelected: (position) {
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
