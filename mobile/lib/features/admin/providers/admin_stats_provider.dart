import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';

class AdminStats {
  final int pendingVenues;
  final int pendingApplications;
  final int pendingCorrections;
  final bool isLoading;
  final String? error;

  const AdminStats({
    this.pendingVenues = 0,
    this.pendingApplications = 0,
    this.pendingCorrections = 0,
    this.isLoading = false,
    this.error,
  });

  AdminStats copyWith({
    int? pendingVenues,
    int? pendingApplications,
    int? pendingCorrections,
    bool? isLoading,
    String? error,
  }) {
    return AdminStats(
      pendingVenues: pendingVenues ?? this.pendingVenues,
      pendingApplications: pendingApplications ?? this.pendingApplications,
      pendingCorrections: pendingCorrections ?? this.pendingCorrections,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AdminStatsNotifier extends Notifier<AdminStats> {
  @override
  AdminStats build() => const AdminStats();

  Future<void> fetchStats() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiClient = ref.read(apiClientProvider);

      final results = await Future.wait([
        apiClient.get(ApiEndpoints.adminPendingVenues),
        apiClient.get(ApiEndpoints.adminApplications),
        apiClient.get(ApiEndpoints.adminCorrections),
      ]);

      state = state.copyWith(
        pendingVenues: _extractCount(results[0].data),
        pendingApplications: _extractCount(results[1].data),
        pendingCorrections: _extractCount(results[2].data),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'İstatistikler yüklenemedi.',
      );
    }
  }

  int _extractCount(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('total')) return data['total'] as int;
      final list = data['data'] as List?;
      return list?.length ?? 0;
    }
    if (data is List) return data.length;
    return 0;
  }
}

final adminStatsProvider = NotifierProvider<AdminStatsNotifier, AdminStats>(
  AdminStatsNotifier.new,
);
