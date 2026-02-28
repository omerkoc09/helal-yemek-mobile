import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/guide_provider.dart';
import '../widgets/full_map_picker.dart';

class EditVenueScreen extends ConsumerStatefulWidget {
  final String venueId;

  const EditVenueScreen({super.key, required this.venueId});

  @override
  ConsumerState<EditVenueScreen> createState() => _EditVenueScreenState();
}

class _EditVenueScreenState extends ConsumerState<EditVenueScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _notesController = TextEditingController();
  final _mapsLinkController = TextEditingController();
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(editVenueProvider.notifier).reset();
      ref.read(editVenueProvider.notifier).loadVenue(widget.venueId);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    _mapsLinkController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _initControllers(EditVenueState state) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = state.name;
    _addressController.text = state.address;
    _cityController.text = state.city;
    _notesController.text = state.notes ?? '';
    if (state.latitude != null && state.longitude != null) {
      _selectedLocation = LatLng(state.latitude!, state.longitude!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editVenueProvider);

    ref.listen<EditVenueState>(editVenueProvider, (prev, next) {
      // Mekan yüklendiğinde controller'ları doldur
      if (prev?.isLoadingVenue == true && !next.isLoadingVenue && next.error == null) {
        _initControllers(next);
      }
      if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mekan güncellendi! Admin onayına gönderildi.'),
            backgroundColor: AppTheme.primary,
          ),
        );
        // Mekan listesini yenile
        ref.read(myVenuesProvider.notifier).fetchMyVenues();
        context.pop();
      }
      if (next.error != null && !next.isLoadingVenue) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mekanı Düzenle'),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(EditVenueState state) {
    if (state.isLoadingVenue) {
      return const LoadingIndicator();
    }

    if (state.error != null && !_initialized) {
      return ErrorRetryWidget(
        message: state.error!,
        onRetry: () =>
            ref.read(editVenueProvider.notifier).loadVenue(widget.venueId),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mekan Adı
                _buildSectionTitle('Mekan Adı'),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Mekan adı',
                    prefixIcon: Icon(Icons.store_outlined),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) =>
                      ref.read(editVenueProvider.notifier).setName(v),
                ),
                const SizedBox(height: 24),

                // Adres
                _buildSectionTitle('Adres'),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    hintText: 'Adres (ilçe)',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  onChanged: (v) =>
                      ref.read(editVenueProvider.notifier).setAddress(v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    hintText: 'Şehir',
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  onChanged: (v) =>
                      ref.read(editVenueProvider.notifier).setCity(v),
                ),
                const SizedBox(height: 24),

                // Konum
                _buildSectionTitle('Konum'),
                const SizedBox(height: 8),
                _buildLocationSection(state),
                const SizedBox(height: 24),

                // Helal Kriterleri
                _buildSectionTitle('Helal Kriterleri'),
                const SizedBox(height: 8),
                _buildCriteriaSection(state),
                const SizedBox(height: 24),

                // Yemek Çeşitleri
                _buildSectionTitle('Yemek Çeşitleri'),
                const SizedBox(height: 8),
                _buildFoodSection(state),
                const SizedBox(height: 24),

                // Notlar
                _buildSectionTitle('Notlar'),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    hintText: 'Mekan hakkında notlar...',
                    prefixIcon: Icon(Icons.note_outlined),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  onChanged: (v) =>
                      ref.read(editVenueProvider.notifier).setNotes(v),
                ),
                const SizedBox(height: 16),

                // Uyarı
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.pinPending.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.pinPending.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: AppTheme.pinPending),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Düzenleme yapıldığında mekan tekrar admin onayına gönderilecektir.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.pinPending,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        _buildBottomBar(state),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // ─── Konum ───

  Widget _buildLocationSection(EditVenueState state) {
    final hasCoordinates = state.latitude != null && state.longitude != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Google Maps linkini yapıştırarak veya haritadan seçerek konumu güncelleyebilirsiniz.',
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
            labelText: 'Google Maps linki (isteğe bağlı)',
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
                : IconButton(
                    icon: const Icon(Icons.content_paste),
                    onPressed: _pasteFromClipboard,
                  ),
          ),
          onChanged: _onMapsLinkChanged,
          keyboardType: TextInputType.url,
        ),
        if (hasCoordinates) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildMiniMap(state),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _openFullMapPicker,
              icon: const Icon(Icons.fullscreen, size: 18),
              label: const Text('Haritada Düzenle'),
            ),
          ),
        ] else ...[
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
      ],
    );
  }

  Widget _buildMiniMap(EditVenueState state) {
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
      onTap: (position) {
        setState(() => _selectedLocation = position);
        ref.read(editVenueProvider.notifier).setCoordinates(
              latitude: position.latitude,
              longitude: position.longitude,
            );
      },
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

  void _onMapsLinkChanged(String link) {
    if (link.trim().isEmpty) return;

    ref.read(editVenueProvider.notifier).parseMapsLink(link).then((success) {
      if (success && mounted) {
        final state = ref.read(editVenueProvider);
        final target = LatLng(state.latitude!, state.longitude!);
        setState(() => _selectedLocation = target);
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
            setState(() => _selectedLocation = position);
            ref.read(editVenueProvider.notifier).setCoordinates(
                  latitude: position.latitude,
                  longitude: position.longitude,
                );
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // ─── Kriterler ───

  Widget _buildCriteriaSection(EditVenueState state) {
    final criteriaAsync = ref.watch(halalCriteriaProvider);

    return criteriaAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Text('Kriterler yüklenemedi.'),
      data: (criteria) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: criteria.map((c) {
            final isSelected = state.selectedCriteriaIds.contains(c.id);
            return FilterChip(
              label: Text(c.labelTr),
              selected: isSelected,
              onSelected: (_) =>
                  ref.read(editVenueProvider.notifier).toggleCriteria(c.id),
              selectedColor: AppTheme.primary.withValues(alpha: 0.2),
              checkmarkColor: AppTheme.primary,
              avatar: isSelected ? null : const Icon(Icons.add, size: 18),
            );
          }).toList(),
        );
      },
    );
  }

  // ─── Yemekler ───

  Widget _buildFoodSection(EditVenueState state) {
    final categoriesAsync = ref.watch(foodCategoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tüm Yemekler Caiz toggle
        CheckboxListTile(
          value: state.allFoodHalal,
          onChanged: (_) =>
              ref.read(editVenueProvider.notifier).toggleAllFoodHalal(),
          title: const Text('Tüm Yemekler Caiz'),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeColor: AppTheme.primary,
        ),
        if (!state.allFoodHalal)
          categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text('Yemek kategorileri yüklenemedi.'),
            data: (categories) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: categories.map((category) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          category.labelTr,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: category.items.map((item) {
                          final isSelected =
                              state.selectedFoodItemIds.contains(item.id);
                          return FilterChip(
                            label: Text(
                              item.labelTr,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: isSelected,
                            onSelected: (_) => ref
                                .read(editVenueProvider.notifier)
                                .toggleFoodItem(item.id),
                            selectedColor:
                                AppTheme.primary.withValues(alpha: 0.2),
                            checkmarkColor: AppTheme.primary,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  // ─── Bottom Bar ───

  Widget _buildBottomBar(EditVenueState state) {
    final canSubmit = state.name.trim().isNotEmpty &&
        state.address.trim().isNotEmpty &&
        state.city.trim().isNotEmpty &&
        state.latitude != null &&
        state.longitude != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canSubmit && !state.isLoading
                ? () => ref.read(editVenueProvider.notifier).submit()
                : null,
            child: state.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Kaydet'),
          ),
        ),
      ),
    );
  }
}
