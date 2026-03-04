import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/admin_provider.dart';

class GuideApplicationsScreen extends ConsumerStatefulWidget {
  const GuideApplicationsScreen({super.key});

  @override
  ConsumerState<GuideApplicationsScreen> createState() =>
      _GuideApplicationsScreenState();
}

class _GuideApplicationsScreenState
    extends ConsumerState<GuideApplicationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(guideApplicationsProvider.notifier).fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(guideApplicationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guide Başvuruları'),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(GuideApplicationsState state) {
    if (state.isLoading && state.applications.isEmpty) {
      return const LoadingIndicator();
    }

    if (state.error != null && state.applications.isEmpty) {
      return ErrorRetryWidget(
        message: state.error!,
        onRetry: () => ref.read(guideApplicationsProvider.notifier).fetch(),
      );
    }

    if (state.applications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: AppTheme.primary),
            SizedBox(height: 16),
            Text(
              'Bekleyen başvuru yok',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(guideApplicationsProvider.notifier).fetch(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.applications.length,
        itemBuilder: (context, index) {
          final app = state.applications[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            AppTheme.primary.withValues(alpha: 0.12),
                        child: Text(
                          (app.userName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.userName ?? 'Bilinmeyen Kullanıcı',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            if (app.userEmail != null)
                              Text(
                                app.userEmail!,
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
                  if (app.referrerName != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 14, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Referans: ${app.referrerName}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (app.createdAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Başvuru: ${_formatDate(app.createdAt!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showRejectDialog(app.id),
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
                          onPressed: () => _approve(app.id),
                          child: const Text('Onayla'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _approve(String applicationId) async {
    final success = await ref
        .read(guideApplicationsProvider.notifier)
        .approve(applicationId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Başvuru onaylandı!'
              : 'Onaylama başarısız.'),
          backgroundColor: success ? AppTheme.primary : AppTheme.error,
        ),
      );
    }
  }

  Future<void> _showRejectDialog(String applicationId) async {
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Başvuruyu Reddet'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            labelText: 'Ret nedeni (isteğe bağlı)',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final note = noteController.text.trim();
      final success = await ref
          .read(guideApplicationsProvider.notifier)
          .reject(applicationId, note: note.isNotEmpty ? note : null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Başvuru reddedildi.'
                : 'Reddetme başarısız.'),
            backgroundColor: success ? AppTheme.error : AppTheme.error,
          ),
        );
      }
    }
    noteController.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
