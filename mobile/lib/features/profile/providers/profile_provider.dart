import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/user.dart';

class GuideApplicationState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;
  final String? currentStatus; // pending | approved | rejected | null
  final String? note; // ret notu (rejected durumunda)

  const GuideApplicationState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.currentStatus,
    this.note,
  });

  GuideApplicationState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    String? currentStatus,
    String? note,
  }) {
    return GuideApplicationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
      currentStatus: currentStatus ?? this.currentStatus,
      note: note ?? this.note,
    );
  }
}

class GuideApplicationNotifier extends Notifier<GuideApplicationState> {
  @override
  GuideApplicationState build() => const GuideApplicationState();

  Future<void> apply(String city) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post(
        ApiEndpoints.guideApply,
        data: {'city': city, 'terms_accepted': true},
      );
      // Başvuru admin onayına pending düşer; rol değişmez.
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        currentStatus: 'pending',
      );
    } catch (e) {
      String errorMsg = 'Başvuru gönderilemedi. Lütfen tekrar deneyin.';
      if (e.toString().contains('409')) {
        errorMsg = 'Bekleyen bir başvurunuz zaten var.';
      } else if (e.toString().contains('400')) {
        errorMsg = 'Lütfen geçerli bir şehir seçip şartları kabul edin.';
      }
      state = state.copyWith(isLoading: false, error: errorMsg);
    }
  }

  // Açılışta mevcut başvuru durumunu backend'den çeker (kalıcı pending/rejected gösterimi için).
  Future<void> fetchStatus() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.get(ApiEndpoints.guideMyApplication);
      final data = res.data as Map<String, dynamic>;
      state = state.copyWith(
        currentStatus: data['status'] as String?,
        note: data['note'] as String?,
      );
    } catch (_) {
      // 404 = başvuru yok; sessizce geç (normal form gösterilir).
    }
  }
}

final guideApplicationProvider =
    NotifierProvider<GuideApplicationNotifier, GuideApplicationState>(
  GuideApplicationNotifier.new,
);

// Profil düzenleme
class EditProfileState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  const EditProfileState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  EditProfileState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return EditProfileState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class EditProfileNotifier extends Notifier<EditProfileState> {
  @override
  EditProfileState build() => const EditProfileState();

  Future<void> updateProfile({
    required String name,
    String? surname,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        ApiEndpoints.updateProfile,
        data: {
          'name': name,
          if (surname case String s) 'surname': s,
          if (phone case String p) 'phone': p,
        },
      );
      final user = User.fromJson(response.data as Map<String, dynamic>);
      ref.read(authProvider.notifier).updateUser(user);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Profil güncellenemedi. Lütfen tekrar deneyin.',
      );
    }
  }

  void reset() {
    state = const EditProfileState();
  }
}

final editProfileProvider =
    NotifierProvider<EditProfileNotifier, EditProfileState>(
  EditProfileNotifier.new,
);
