import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/correction.dart';
import 'admin_provider_utils.dart';

class AdminCorrectionsState {
  final List<Correction> corrections;
  final bool isLoading;
  final String? error;

  const AdminCorrectionsState({
    this.corrections = const [],
    this.isLoading = false,
    this.error,
  });

  AdminCorrectionsState copyWith({
    List<Correction>? corrections,
    bool? isLoading,
    String? error,
  }) {
    return AdminCorrectionsState(
      corrections: corrections ?? this.corrections,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AdminCorrectionsNotifier extends Notifier<AdminCorrectionsState> {
  @override
  AdminCorrectionsState build() => const AdminCorrectionsState();

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(ApiEndpoints.adminCorrections);
      final corrections =
          parseList<Correction>(response.data, Correction.fromJson);
      state = state.copyWith(corrections: corrections, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Düzeltmeler yüklenemedi.',
      );
    }
  }

  Future<bool> approve(String correctionId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.put(
        ApiEndpoints.adminCorrection(correctionId),
        data: {'status': 'approved'},
      );
      state = state.copyWith(
        corrections:
            state.corrections.where((c) => c.id != correctionId).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reject(String correctionId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.put(
        ApiEndpoints.adminCorrection(correctionId),
        data: {'status': 'rejected'},
      );
      state = state.copyWith(
        corrections:
            state.corrections.where((c) => c.id != correctionId).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

final adminCorrectionsProvider =
    NotifierProvider<AdminCorrectionsNotifier, AdminCorrectionsState>(
  AdminCorrectionsNotifier.new,
);
