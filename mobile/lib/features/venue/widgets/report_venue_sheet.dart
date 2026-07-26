import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/venue_report_provider.dart';

const _reasons = [
  (value: 'closed', label: 'Mekan artık hizmet vermiyor'),
  (value: 'trust_criteria', label: 'Güven kriterlerini karşılamıyor'),
  (value: 'wrong_address', label: 'Mekanın adresi yanlış'),
  (value: 'wrong_food', label: 'Servis edilen yemekler yanlış'),
  (value: 'other', label: 'Diğer'),
];

// Not (açıklama) yazılması zorunlu olan seçenekler.
const _reasonsRequiringNote = {'trust_criteria', 'wrong_food', 'other'};

// Seçeneğe göre not kutusunun hint metni.
String _noteHintFor(String? reason) {
  switch (reason) {
    case 'trust_criteria':
      return 'Hangi kriterin karşılanmadığını belirtin...';
    case 'wrong_food':
      return 'Hangi yemeklerin yanlış olduğunu belirtin...';
    default:
      return 'Lütfen sorunu açıklayın...';
  }
}

Future<void> showReportVenueSheet(BuildContext context, {required String venueId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ReportVenueSheet(venueId: venueId),
  );
}

class _ReportVenueSheet extends ConsumerStatefulWidget {
  final String venueId;

  const _ReportVenueSheet({required this.venueId});

  @override
  ConsumerState<_ReportVenueSheet> createState() => _ReportVenueSheetState();
}

class _ReportVenueSheetState extends ConsumerState<_ReportVenueSheet> {
  String? _selectedReason;
  final _descController = TextEditingController();

  @override
  void dispose() {
    _descController.dispose();
    ref.read(venueReportProvider.notifier).reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(venueReportProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    ref.listen<VenueReportState>(venueReportProvider, (_, next) {
      if (next.isSuccess) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bildiriminiz alındı, teşekkür ederiz.'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    });

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 16 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Sorun Bildir',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Bu mekanla ilgili bir sorun mu var?',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          // Seçenekler
          RadioGroup<String>(
            groupValue: _selectedReason,
            onChanged: (v) => setState(() {
              _selectedReason = v;
              _descController.clear();
            }),
            child: Column(
              children: _reasons
                  .map((r) => RadioListTile<String>(
                        value: r.value,
                        title: Text(r.label,
                            style: const TextStyle(fontSize: 14)),
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.primary,
                      ))
                  .toList(),
            ),
          ),

          // Not gerektiren seçeneklerde açıklama kutusu
          if (_reasonsRequiringNote.contains(_selectedReason)) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: _noteHintFor(_selectedReason),
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],

          const SizedBox(height: 8),

          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                state.error!,
                style: const TextStyle(color: AppTheme.error, fontSize: 13),
              ),
            ),

          ElevatedButton(
            onPressed: _canSubmit(state) ? _submit : null,
            child: state.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Bildir'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  bool _requiresNote() => _reasonsRequiringNote.contains(_selectedReason);

  bool _canSubmit(VenueReportState state) {
    if (state.isLoading || _selectedReason == null) return false;
    if (_requiresNote() && _descController.text.trim().isEmpty) return false;
    return true;
  }

  void _submit() {
    ref.read(venueReportProvider.notifier).submit(
          venueId: widget.venueId,
          reason: _selectedReason!,
          description: _requiresNote() ? _descController.text : null,
        );
  }
}
