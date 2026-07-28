import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/guide_provider.dart';

class EditVenueScreen extends ConsumerStatefulWidget {
  final String venueId;

  const EditVenueScreen({super.key, required this.venueId});

  @override
  ConsumerState<EditVenueScreen> createState() => _EditVenueScreenState();
}

class _EditVenueScreenState extends ConsumerState<EditVenueScreen> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _notesController = TextEditingController();
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
    _cityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _initControllers(EditVenueState state) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = state.name;
    _cityController.text = state.city;
    _notesController.text = state.notes ?? '';
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
        AppToast.success(context, 'Mekan güncellendi.');
        // Mekan listesini yenile
        ref.read(myVenuesProvider.notifier).fetchMyVenues();
        context.pop();
      }
      if (next.error != null && !next.isLoadingVenue) {
        AppToast.error(context, next.error!);
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

                // Şehir
                _buildSectionTitle('Şehir'),
                const SizedBox(height: 8),
                // Şehir değiştirilemez: rehber yetkisi kendi şehriyle sınırlı
                // ve mekanın konumu düzenlemede değişmiyor.
                TextField(
                  controller: _cityController,
                  enabled: false,
                  decoration: const InputDecoration(
                    hintText: 'Şehir',
                    prefixIcon: Icon(Icons.location_city),
                  ),
                ),
                const SizedBox(height: 24),

                // Güven Kriterleri
                _buildSectionTitle('Güven Kriterleri'),
                const SizedBox(height: 8),
                _buildCriteriaSection(state),
                const SizedBox(height: 24),

                // Mutfaklar
                _buildSectionTitle('Mutfaklar'),
                const SizedBox(height: 8),
                _buildFoodSection(state),
                const SizedBox(height: 24),

                // Notlar
                _buildSectionTitle('Notlar'),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  // Çok satırlı alanda prefixIcon dikeyde ortalanıp hint ile
                  // hizasız kaldığı için ikon üste sabitlenir.
                  decoration: const InputDecoration(
                    hintText: 'Mekan hakkında notlar...',
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(left: 12, right: 8),
                      child: Icon(Icons.notes_outlined),
                    ),
                    prefixIconConstraints: BoxConstraints(minWidth: 0),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  onChanged: (v) =>
                      ref.read(editVenueProvider.notifier).setNotes(v),
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

  // ─── Kriterler ───

  Widget _buildCriteriaSection(EditVenueState state) {
    final criteriaAsync = ref.watch(trustCriteriaProvider);

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
              label: Text(c.name),
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

  // ─── Mutfaklar ───

  Widget _buildFoodSection(EditVenueState state) {
    final categoriesAsync = ref.watch(foodCategoriesProvider);
    final notifier = ref.read(editVenueProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 2 modlu radio seçimi
        RadioListTile<String>(
          value: 'all',
          groupValue: state.foodHalalMode,
          onChanged: (v) => notifier.setFoodHalalMode(v!),
          title: const Text('Tüm Mutfaklar Tavsiye Edilir',
              style: TextStyle(fontSize: 14)),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeColor: AppTheme.primary,
        ),
        RadioListTile<String>(
          value: 'except',
          groupValue: state.foodHalalMode,
          onChanged: (v) => notifier.setFoodHalalMode(v!),
          title: const Text('Şunlar Hariç Tavsiye Edilir',
              style: TextStyle(fontSize: 14)),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeColor: AppTheme.primary,
        ),

        // Except modu: tavsiye edilmeyen ürün girişi
        if (state.foodHalalMode == 'except') ...[
          const SizedBox(height: 8),
          const Text(
            'Tavsiye edilmeyen ürünler',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...state.excludedProducts.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: entry.value,
                      onChanged: (v) =>
                          notifier.updateExcludedProduct(entry.key, v),
                      decoration: InputDecoration(
                        hintText: entry.key == 0 ? 'örn. kaşar' : 'Ürün adı',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  if (state.excludedProducts.length > 1)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () =>
                          notifier.removeExcludedProduct(entry.key),
                      color: Colors.red.shade400,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => notifier.addExcludedProduct(''),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ürün ekle'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
          ),
        ],

        const SizedBox(height: 8),
        const Text(
          'Sunulan mutfakları seçin:',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),

        // Mutfak seçimi: her iki modda da gösterilir
        categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text('Mutfaklar yüklenemedi.'),
          data: (categories) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((category) {
                final isSelected =
                    state.selectedCategoryIds.contains(category.id);
                return FilterChip(
                  label: Text(category.name),
                  selected: isSelected,
                  onSelected: (_) => notifier.toggleCategory(category.id),
                  selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                  checkmarkColor: AppTheme.primary,
                  avatar: isSelected ? null : const Icon(Icons.add, size: 18),
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
    // Konum düzenlenmiyor (mevcut mekanın konumu sabit kalır), bu yüzden yalnız
    // düzenlenebilir zorunlu alanlar kontrol edilir.
    final canSubmit =
        state.name.trim().isNotEmpty && state.city.trim().isNotEmpty;

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
