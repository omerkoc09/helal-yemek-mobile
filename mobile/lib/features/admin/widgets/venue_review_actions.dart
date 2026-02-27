import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/venue.dart';
import '../../../core/theme/app_theme.dart';
import '../../venue/providers/venue_detail_provider.dart';
import '../providers/admin_provider.dart';

class VenueReviewActions extends ConsumerWidget {
  final String venueId;
  final Venue venue;

  const VenueReviewActions({
    super.key,
    required this.venueId,
    required this.venue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        child: _buildStatusActions(context, ref),
      ),
    );
  }

  Widget _buildStatusActions(BuildContext context, WidgetRef ref) {
    switch (venue.status) {
      case 'approved':
        return Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Onaylandı',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _suspend(context, ref),
              icon: const Icon(Icons.pause_circle_outline,
                  color: Colors.orange),
              label: const Text(
                'Askıya Al',
                style: TextStyle(color: Colors.orange),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orange),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              ),
            ),
          ],
        );
      case 'rejected':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cancel, color: AppTheme.error, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Reddedildi',
                    style: TextStyle(
                      color: AppTheme.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _approve(context, ref),
                  icon: const Icon(Icons.check),
                  label: const Text('Onayla'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 20),
                  ),
                ),
              ],
            ),
            if (venue.rejectionNote != null &&
                venue.rejectionNote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Red nedeni: ${venue.rejectionNote}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.error,
                  ),
                ),
              ),
            ],
          ],
        );
      default: // pending
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showRejectDialog(context, ref),
                icon: const Icon(Icons.close, color: AppTheme.error),
                label: const Text(
                  'Reddet',
                  style: TextStyle(color: AppTheme.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => _approve(context, ref),
                icon: const Icon(Icons.check),
                label: const Text('Onayla'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        );
    }
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final success =
        await ref.read(pendingVenuesProvider.notifier).approveVenue(venueId);
    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mekan onaylandı!'),
            backgroundColor: AppTheme.primary,
          ),
        );
        context.pop();
        ref.invalidate(venueDetailProvider(venueId));
        ref.read(allVenuesProvider.notifier).fetch();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Onaylama başarısız. Tekrar deneyin.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _suspend(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mekanı Askıya Al'),
        content: const Text(
          'Bu mekan tekrar "Beklemede" durumuna alınacak. Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Askıya Al'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await ref
          .read(allVenuesProvider.notifier)
          .updateVenue(venueId, {'status': 'pending'});
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mekan askıya alındı.'),
              backgroundColor: Colors.orange,
            ),
          );
          context.pop();
          ref.invalidate(venueDetailProvider(venueId));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('İşlem başarısız. Tekrar deneyin.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showRejectDialog(BuildContext context, WidgetRef ref) async {
    String? note;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final noteController = TextEditingController();
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: const Text('Mekanı Reddet'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Ret nedeni',
                hintText: 'Neden reddedildiğini açıklayın...',
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Lütfen bir red nedeni yazın';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  note = noteController.text.trim();
                  Navigator.pop(dialogContext);
                }
              },
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
              child: const Text('Reddet'),
            ),
          ],
        );
      },
    );

    if (note == null || !context.mounted) return;

    final success = await ref.read(pendingVenuesProvider.notifier).rejectVenue(
          venueId,
          note: note,
        );
    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mekan reddedildi.'),
            backgroundColor: AppTheme.error,
          ),
        );
        context.pop();
        ref.invalidate(venueDetailProvider(venueId));
        ref.read(allVenuesProvider.notifier).fetch();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reddetme başarısız. Tekrar deneyin.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}
