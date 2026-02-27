import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/guide_application.dart';
import 'admin_provider_utils.dart';

class GuideApplicationsState {
  final List<GuideApplication> applications;
  final bool isLoading;
  final String? error;

  const GuideApplicationsState({
    this.applications = const [],
    this.isLoading = false,
    this.error,
  });

  GuideApplicationsState copyWith({
    List<GuideApplication>? applications,
    bool? isLoading,
    String? error,
  }) {
    return GuideApplicationsState(
      applications: applications ?? this.applications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class GuideApplicationsNotifier extends Notifier<GuideApplicationsState> {
  @override
  GuideApplicationsState build() => const GuideApplicationsState();

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(ApiEndpoints.adminApplications);
      final apps =
          parseList<GuideApplication>(response.data, GuideApplication.fromJson);
      state = state.copyWith(applications: apps, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Başvurular yüklenemedi.',
      );
    }
  }

  Future<bool> approve(String applicationId, {String? note}) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.put(
        ApiEndpoints.adminApproveApplication(applicationId),
        data: note != null ? {'note': note} : null,
      );
      state = state.copyWith(
        applications:
            state.applications.where((a) => a.id != applicationId).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reject(String applicationId, {String? note}) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.put(
        ApiEndpoints.adminRejectApplication(applicationId),
        data: note != null ? {'note': note} : null,
      );
      state = state.copyWith(
        applications:
            state.applications.where((a) => a.id != applicationId).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

final guideApplicationsProvider =
    NotifierProvider<GuideApplicationsNotifier, GuideApplicationsState>(
  GuideApplicationsNotifier.new,
);
