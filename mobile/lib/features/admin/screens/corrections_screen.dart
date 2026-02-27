import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/correction.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/admin_provider.dart';

class CorrectionsScreen extends ConsumerStatefulWidget {
  const CorrectionsScreen({super.key});

  @override
  ConsumerState<CorrectionsScreen> createState() => _CorrectionsScreenState();
}

class _CorrectionsScreenState extends ConsumerState<CorrectionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminCorrectionsProvider.notifier).fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminCorrectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Düzeltme Önerileri'),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(AdminCorrectionsState state) {
    if (state.isLoading && state.corrections.isEmpty) {
      return const LoadingIndicator();
    }

    if (state.error != null && state.corrections.isEmpty) {
      return ErrorRetryWidget(
        message: state.error!,
        onRetry: () => ref.read(adminCorrectionsProvider.notifier).fetch(),
      );
    }

    if (state.corrections.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: AppTheme.primary),
            SizedBox(height: 16),
            Text(
              'Bekleyen düzeltme yok',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(adminCorrectionsProvider.notifier).fetch(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.corrections.length,
        itemBuilder: (context, index) {
          return _CorrectionCard(correction: state.corrections[index]);
        },
      ),
    );
  }
}

class _CorrectionCard extends ConsumerWidget {
  final Correction correction;

  const _CorrectionCard({required this.correction});

  static const _fieldLabels = {
    'name': 'Mekan Adı',
    'address': 'Adres',
    'working_hours': 'Çalışma Saatleri',
    'criteria': 'Helal Kriterleri',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mekan adı + alan
            Row(
              children: [
                Expanded(
                  child: Text(
                    correction.venueName ?? 'Mekan',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _fieldLabels[correction.fieldName] ?? correction.fieldName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (correction.suggestedByName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Öneren: ${correction.suggestedByName}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Mevcut → Yeni
            if (correction.oldValue != null &&
                correction.oldValue!.isNotEmpty) ...[
              const Text(
                'Mevcut',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  correction.oldValue!,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const Text(
              'Önerilen',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                correction.newValue,
                style: const TextStyle(fontSize: 13),
              ),
            ),

            if (correction.note != null && correction.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Not: ${correction.note}',
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reject(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                    ),
                    child: const Text('Reddet'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => _approve(context, ref),
                    child: const Text('Onayla'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(adminCorrectionsProvider.notifier)
        .approve(correction.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(success ? 'Düzeltme onaylandı!' : 'Onaylama başarısız.'),
          backgroundColor: success ? AppTheme.primary : AppTheme.error,
        ),
      );
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(adminCorrectionsProvider.notifier)
        .reject(correction.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(success ? 'Düzeltme reddedildi.' : 'Reddetme başarısız.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
