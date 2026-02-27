import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/admin_provider.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(auditLogsProvider.notifier).fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(auditLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log'),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(AuditLogsState state) {
    if (state.isLoading && state.logs.isEmpty) {
      return const LoadingIndicator();
    }

    if (state.error != null && state.logs.isEmpty) {
      return ErrorRetryWidget(
        message: state.error!,
        onRetry: () => ref.read(auditLogsProvider.notifier).fetch(),
      );
    }

    if (state.logs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text(
              'Henüz işlem kaydı yok',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(auditLogsProvider.notifier).fetch(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.logs.length,
        itemBuilder: (context, index) {
          final log = state.logs[index];
          final (icon, color) = _actionVisuals(log.action);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              title: Text(
                _actionLabel(log.action),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    '${log.targetType} | ${log.adminName ?? 'Admin'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (log.note != null && log.note!.isNotEmpty)
                    Text(
                      log.note!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              trailing: log.createdAt != null
                  ? Text(
                      _formatDateTime(log.createdAt!),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          );
        },
      ),
    );
  }

  (IconData, Color) _actionVisuals(String action) {
    return switch (action) {
      'approve_venue' => (Icons.check_circle, AppTheme.primary),
      'reject_venue' => (Icons.cancel, AppTheme.error),
      'approve_guide' => (Icons.person_add, Colors.blue),
      'reject_guide' => (Icons.person_remove, AppTheme.error),
      'approve_correction' => (Icons.edit, AppTheme.primary),
      'reject_correction' => (Icons.edit_off, AppTheme.error),
      _ => (Icons.history, AppTheme.textSecondary),
    };
  }

  String _actionLabel(String action) {
    return switch (action) {
      'approve_venue' => 'Mekan Onaylandı',
      'reject_venue' => 'Mekan Reddedildi',
      'approve_guide' => 'Guide Başvurusu Onaylandı',
      'reject_guide' => 'Guide Başvurusu Reddedildi',
      'approve_correction' => 'Düzeltme Onaylandı',
      'reject_correction' => 'Düzeltme Reddedildi',
      _ => action.replaceAll('_', ' ').toUpperCase(),
    };
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}\n${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
