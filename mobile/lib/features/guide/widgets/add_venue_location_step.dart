import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/media_url.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/venue.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/guide_provider.dart';

class AddVenueLocationStep extends ConsumerStatefulWidget {
  const AddVenueLocationStep({super.key});

  @override
  ConsumerState<AddVenueLocationStep> createState() =>
      _AddVenueLocationStepState();
}

class _AddVenueLocationStepState extends ConsumerState<AddVenueLocationStep> {
  final _linkController = TextEditingController();
  Venue? _duplicateVenue;

  /// Places fotoğraf proxy'si yetki istiyor (guide/admin) ve Image.network
  /// varsayılan olarak Authorization başlığı göndermez. Token bir kez okunup
  /// tüm önizleme görselleri için kullanılıyor.
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
  }

  Future<void> _loadAuthToken() async {
    final token = await ref.read(tokenStorageProvider).getAccessToken();
    if (!mounted) return;
    setState(() => _authToken = token);
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addVenueProvider);
    final hasCoords = state.latitude != null && state.longitude != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mekan Konumu',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mekanı Google Maps\'te bulun ve "Paylaş" butonundan linki kopyalayın. '
            'Haritada kendi işaretlediğiniz bir nokta için "enlem, boylam" '
            'koordinatlarını da yapıştırabilirsiniz.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _linkController,
            decoration: InputDecoration(
              labelText: 'Maps linki veya koordinat',
              hintText: 'https://maps.app.goo.gl/... veya 41.0082, 28.9784',
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
                  : hasCoords && _linkController.text.isNotEmpty
                      ? const Icon(Icons.check_circle, color: AppTheme.primary)
                      : IconButton(
                          icon: const Icon(Icons.content_paste),
                          onPressed: _pasteFromClipboard,
                        ),
            ),
            onChanged: _onLinkChanged,
            keyboardType: TextInputType.url,
          ),
          if (state.error != null && _linkController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: const TextStyle(color: AppTheme.error, fontSize: 12),
            ),
          ],

          // Başarı / preview kartı
          if (hasCoords) ...[
            const SizedBox(height: 20),
            _buildSuccessCard(state),
          ],

          // Duplicate uyarı kartı
          if (_duplicateVenue != null) ...[
            const SizedBox(height: 16),
            _buildDuplicateCard(_duplicateVenue!),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSuccessCard(AddVenueState state) {
    if (state.isLoadingPlaceDetails) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Mekan bilgileri alınıyor...',
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final hasInfo = state.name.isNotEmpty || state.city.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, size: 16, color: AppTheme.primary),
              SizedBox(width: 6),
              Text(
                'Mekan Bulundu',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          if (state.googlePhotoUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Fotoğraf seçin:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.googlePhotoUrls.length,
                separatorBuilder: (context, idx) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final url = state.googlePhotoUrls[index];
                  final isSelected = state.selectedPhotoUrl == url;
                  return GestureDetector(
                    onTap: () =>
                        ref.read(addVenueProvider.notifier).selectPhoto(url),
                    child: Container(
                      width: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              resolveMediaUrl(url),
                              fit: BoxFit.cover,
                              headers: requiresAuthHeader(url) &&
                                      _authToken != null
                                  ? {'Authorization': 'Bearer $_authToken'}
                                  : null,
                              errorBuilder: (context, error, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (hasInfo) ...[
            const SizedBox(height: 10),
            if (state.name.isNotEmpty) _infoRow('Mekan', state.name),
            if (state.city.isNotEmpty) _infoRow('Şehir', state.city),
            if (state.district.isNotEmpty)
              _infoRow('Semt', state.district),
          ],
          if (!state.cityAllowed) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Yalnızca rehberi olduğunuz şehirde (${state.guideCity ?? "-"}) '
                      'mekan ekleyebilirsiniz. Bu mekan ${state.city} şehrinde görünüyor.',
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Devam\'a basın — bir sonraki adımda bilgileri doğrulayabilirsiniz.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              '$label:',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateCard(Venue dup) {
    return Card(
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Bu mekan zaten eklenmiş',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(dup.name),
            if (dup.badge != null && !dup.badge!.isBase)
              Text(
                '${dup.badge!.labelTr} · ${dup.badge!.count} rehber doğruladı',
                style: const TextStyle(color: Colors.black54),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => context.push('/venue/${dup.id}'),
                  child: const Text('Mekana Git'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _duplicateVenue = null),
                  child: const Text('Vazgeç'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onLinkChanged(String link) {
    if (link.trim().isEmpty) return;
    // Link değişince önceki duplicate uyarısını temizle
    if (_duplicateVenue != null) {
      setState(() => _duplicateVenue = null);
    }
    _parseLinkAndCheckDuplicate(link);
  }

  Future<void> _parseLinkAndCheckDuplicate(String link) async {
    final notifier = ref.read(addVenueProvider.notifier);
    final success = await notifier.parseMapsLink(link);
    if (!success) return;
    final placeId = ref.read(addVenueProvider).googlePlaceId;
    if (placeId == null || !placeId.startsWith('ChIJ')) return;
    final dup = await notifier.checkDuplicate(placeId);
    if (mounted && dup != null) {
      setState(() => _duplicateVenue = dup);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _linkController.text = data.text!;
      _onLinkChanged(data.text!);
    }
  }
}
