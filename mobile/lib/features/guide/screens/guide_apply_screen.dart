import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/city_picker_sheet.dart';
import '../../profile/providers/profile_provider.dart';

class GuideApplyScreen extends ConsumerStatefulWidget {
  const GuideApplyScreen({super.key});
  @override
  ConsumerState<GuideApplyScreen> createState() => _GuideApplyScreenState();
}

class _GuideApplyScreenState extends ConsumerState<GuideApplyScreen> {
  String? _city;
  bool _termsAccepted = false;

  // Rehberlik şartları placeholder metni (profil ekranından taşındı).
  static const _termsText =
      'Rehber olarak eklediğiniz mekanların helal kriterlerine uygunluğundan '
      'siz sorumlusunuz. Yanlış veya yanıltıcı bilgi girişi hesabınızın '
      'rehberlikten çıkarılmasına yol açabilir. Beyan ettiğiniz şehirde '
      'rehberlik yapacağınızı kabul edersiniz.';

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(guideApplicationProvider);

    ref.listen(guideApplicationProvider, (prev, next) {
      if (next.isSuccess && (prev?.isSuccess ?? false) == false) {
        Navigator.of(context).pop(true);
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    final canSubmit =
        _city != null && _termsAccepted && !appState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Rehber Olmak İçin Başvur')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('İkamet ettiğiniz şehir',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showCityPickerSheet(context);
                if (picked != null) setState(() => _city = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                child: Text(_city ?? 'Şehir seçin',
                    style: TextStyle(
                        color: _city == null ? Colors.black54 : null)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Rehberlik Şartları',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(_termsText),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _termsAccepted,
              onChanged: (v) => setState(() => _termsAccepted = v ?? false),
              title: const Text('Okudum, onaylıyorum'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSubmit
                    ? () => ref
                        .read(guideApplicationProvider.notifier)
                        .apply(_city!)
                    : null,
                child: appState.isLoading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Başvur'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
