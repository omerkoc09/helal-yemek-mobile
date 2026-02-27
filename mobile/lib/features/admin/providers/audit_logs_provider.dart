import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/audit_log.dart';
import 'admin_provider_utils.dart';

class AuditLogsState {
  final List<AuditLog> logs;
  final bool isLoading;
  final String? error;

  const AuditLogsState({
    this.logs = const [],
    this.isLoading = false,
    this.error,
  });

  AuditLogsState copyWith({
    List<AuditLog>? logs,
    bool? isLoading,
    String? error,
  }) {
    return AuditLogsState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuditLogsNotifier extends Notifier<AuditLogsState> {
  @override
  AuditLogsState build() => const AuditLogsState();

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(ApiEndpoints.adminAuditLogs);
      final logs = parseList<AuditLog>(response.data, AuditLog.fromJson);
      state = state.copyWith(logs: logs, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Loglar yüklenemedi.');
    }
  }
}

final auditLogsProvider = NotifierProvider<AuditLogsNotifier, AuditLogsState>(
  AuditLogsNotifier.new,
);
