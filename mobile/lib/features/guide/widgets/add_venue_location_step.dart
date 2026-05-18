import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addVenueProvider);
    final notifier = ref.read(addVenueProvider.notifier);
    final hasCoords = state.latitude != null && state.longitude != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Google Maps Linki',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mekanı Google Maps\'te bulun ve "Paylaş" butonundan linki kopyalayın.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _linkController,
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

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // Linksiz devam seçeneği
          Container(
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
                        'Mekanın Google Maps linki yok mu?',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Linksiz devam edebilirsiniz. Bir sonraki adımda mekan bilgilerini ve konumunu elle girersiniz.',
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
                    onPressed: () {
                      notifier.setManualMode(true);
                      notifier.nextStep();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: BorderSide(
                        color: AppTheme.textSecondary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Text('Linksiz Devam Et'),
                  ),
                ),
              ],
            ),
          ),
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
                              url,
                              fit: BoxFit.cover,
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

  void _onLinkChanged(String link) {
    if (link.trim().isEmpty) return;
    ref.read(addVenueProvider.notifier).parseMapsLink(link);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _linkController.text = data.text!;
      _onLinkChanged(data.text!);
    }
  }
}
