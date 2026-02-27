import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../venue/providers/venue_detail_provider.dart';
import '../providers/guide_provider.dart';

class CorrectionScreen extends ConsumerStatefulWidget {
  final String venueId;

  const CorrectionScreen({super.key, required this.venueId});

  @override
  ConsumerState<CorrectionScreen> createState() => _CorrectionScreenState();
}

class _CorrectionScreenState extends ConsumerState<CorrectionScreen> {
  String _selectedField = 'name';
  final _newValueController = TextEditingController();
  final _noteController = TextEditingController();

  static const _correctionFields = [
    ('name', 'Mekan Adı'),
    ('address', 'Adres'),
    ('working_hours', 'Çalışma Saatleri'),
    ('criteria', 'Helal Kriterleri'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(correctionProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _newValueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final venueAsync = ref.watch(venueDetailProvider(widget.venueId));
    final correctionState = ref.watch(correctionProvider);

    ref.listen<CorrectionState>(correctionProvider, (prev, next) {
      if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Düzeltme öneriniz gönderildi!'),
            backgroundColor: AppTheme.primary,
          ),
        );
        context.pop();
      }
      if (next.error != null) {
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
        title: const Text('Düzeltme Öner'),
      ),
      body: venueAsync.when(
        loading: () => const LoadingIndicator(),
        error: (_, _) => ErrorRetryWidget(
          message: 'Mekan bilgisi yüklenemedi.',
          onRetry: () =>
              ref.invalidate(venueDetailProvider(widget.venueId)),
        ),
        data: (venue) {
          // Mevcut alan değerini bul
          final oldValue = switch (_selectedField) {
            'name' => venue.name,
            'address' => venue.address,
            'working_hours' => venue.workingHours?.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .join(', ') ??
                '',
            'criteria' =>
              venue.criteria.map((c) => c.labelTr).join(', '),
            _ => '',
          };

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mekan bilgisi
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.store_outlined,
                          color: AppTheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              venue.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${venue.address}, ${venue.city}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Düzeltilecek alan
                const Text(
                  'Düzeltilecek Alan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(_correctionFields.length, (index) {
                  final (key, label) = _correctionFields[index];
                  // ignore: deprecated_member_use
                  return RadioListTile<String>(
                    value: key,
                    // ignore: deprecated_member_use
                    groupValue: _selectedField,
                    // ignore: deprecated_member_use
                    onChanged: (v) => setState(() {
                      _selectedField = v!;
                      _newValueController.clear();
                    }),
                    title: Text(label),
                    activeColor: AppTheme.primary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  );
                }),
                const SizedBox(height: 16),

                // Mevcut değer
                if (oldValue.isNotEmpty) ...[
                  const Text(
                    'Mevcut Değer',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.textSecondary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      oldValue,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Yeni değer
                const Text(
                  'Önerilen Değer',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _newValueController,
                  decoration: InputDecoration(
                    hintText: 'Doğru değeri girin...',
                    prefixIcon: const Icon(Icons.edit_outlined),
                    helperText: _selectedField == 'working_hours'
                        ? 'Örn: Pzt-Cum 09:00-22:00, Cmt 10:00-23:00'
                        : null,
                  ),
                  maxLines: _selectedField == 'working_hours' ? 3 : 1,
                ),
                const SizedBox(height: 20),

                // Not
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama (isteğe bağlı)',
                    hintText: 'Neden bu düzeltmeyi öneriyorsunuz?',
                    prefixIcon: Icon(Icons.note_outlined),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 32),

                // Gönder butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: correctionState.isLoading ||
                            _newValueController.text.trim().isEmpty
                        ? null
                        : () => _submit(oldValue),
                    child: correctionState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Düzeltme Öner'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _submit(String oldValue) {
    ref.read(correctionProvider.notifier).submitCorrection(
          venueId: widget.venueId,
          fieldName: _selectedField,
          oldValue: oldValue.isNotEmpty ? oldValue : null,
          newValue: _newValueController.text.trim(),
          note: _noteController.text.trim().isNotEmpty
              ? _noteController.text.trim()
              : null,
        );
  }
}
