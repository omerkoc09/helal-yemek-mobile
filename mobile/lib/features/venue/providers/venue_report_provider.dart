import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';

class VenueReportState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  const VenueReportState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  VenueReportState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return VenueReportState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class VenueReportNotifier extends Notifier<VenueReportState> {
  @override
  VenueReportState build() => const VenueReportState();

  void reset() => state = const VenueReportState();

  Future<void> submit({
    required String venueId,
    required String reason,
    String? description,
  }) async {
    state = const VenueReportState(isLoading: true);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post(
        ApiEndpoints.venueReports(venueId),
        data: {
          'reason': reason,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        },
      );
      state = const VenueReportState(isSuccess: true);
    } catch (_) {
      state = const VenueReportState(
        error: 'Bildirim gönderilemedi. Lütfen tekrar deneyin.',
      );
    }
  }
}

final venueReportProvider =
    NotifierProvider<VenueReportNotifier, VenueReportState>(
  VenueReportNotifier.new,
);
