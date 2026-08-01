import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/turkey_locations.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/guide_provider.dart';
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

          // Konum her zaman Google Maps linkinden gelir; 1. adım koordinat
          // olmadan geçilemediği için burada koordinatsız durum oluşmaz.
          LocationSelectedCard(
            latitude: state.latitude!,
            longitude: state.longitude!,
          ),

          const SizedBox(height: 24),
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

}
